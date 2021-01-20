Transducers.transduce(xf, rf, init, xs, ex::WorkStealingEx) =
    _transduce_ws(xf, rf, init, xs; ex.kwargs...)

function _transduce_ws(
    xf::Transducer,
    rf,
    init,
    xs;
    simd = Val(false),
    basesize::Union{Nothing,Integer} = nothing,
    # ntasks::Int = Threads.nthreads(),
    # background::Bool = false,
)
    rf0 = _reducingfunction(xf, rf; init = init, simd = simd)
    rf1, xs0 = retransform(rf0, xs)
    if basesize === nothing
        basesize = amount(xs0) ÷ Threads.nthreads()
    end
    xs1 = SizedReducible(xs0, basesize)
    return transduce_ws(TaskContext(), rf1, init, xs1)
end

const WorkQueue = LockedLinkedList{Function}

struct WorkerPool
    tasks::Vector{Task}
    queues::Vector{WorkQueue}
    counter::Counter
end

struct Worker
    id::Int
    pool::WorkerPool
end

struct WSScheduler
    queue::WorkQueue
    counter::Counter
end

WSScheduler(worker::Worker) =
    WSScheduler(worker.pool.queues[worker.id], worker.pool.counter)

function spawn!(f, sch::WSScheduler)
    cons = listof(Function, f)
    setcdr!(sch.queue, cons)
    queue = WorkQueue(cons, sch.queue.lock)
    return @set sch.queue = queue
end

finish_schedule!(c::Counter) = @assert try_inc_to!(c, typemax(Int)) === nothing
is_all_scheduled(x::Int) = x == typemax(Int)

""" Work-stealing (WS) divide-and-conquer (DAC) context """
struct WSDACContext
    ctx::TaskContext
    counter::Counter
end

WSDACContext(ctx::TaskContext, worker::Worker) = WSDACContext(ctx, worker.pool.counter)

should_abort(ctx::WSDACContext) = should_abort(ctx.ctx)
function cancel!(ctx::WSDACContext)
    finish_schedule!(ctx.counter)
    cancel!(ctx.ctx)
end
function splitcontext(ctx::WSDACContext)
    fg, bg = splitcontext(ctx.ctx)
    return WSDACContext(fg, ctx.counter), WSDACContext(bg, ctx.counter)
end

function transduce_ws(ctx, rf, init, xs)
    output = Promise()
    pool = make_worker_pool() do worker
        try
            help_others(worker)
        catch err
            tryput!(output, Err(err))
        end
    end
    queue = pool.queues[1]
    worker = Worker(1, pool)
    try
        transduce_ws_root(worker, ctx, output, rf, init, xs)
    finally
        close(pool)
    end
    return something(tryfetch(output))[]
end

function make_worker_pool(f)
    pool = WorkerPool(
        Vector{Task}(undef, Threads.nthreads()),
        Vector{WorkQueue}(undef, Threads.nthreads()),
        Counter(),
    )
    pool.tasks[1] = current_task()
    pool.queues[1] = WorkQueue()

    go = Promise()
    counter = Threads.Atomic{Int}(1)
    id0 = Threads.threadid()
    foreach_thread() do
        id0 == Threads.threadid() && return
        i = Threads.atomic_add!(counter, 1) + 1
        worker = Worker(i, pool)
        pool.queues[i] = WorkQueue()
        pool.tasks[i] = @async try
            fetch(go)
            f(worker)
        catch
            close(pool)
        end
    end
    n = counter[]
    resize!(pool.queues, n)
    resize!(pool.tasks, n)

    tryput!(go, nothing)

    return pool
end

function Base.close(pool::WorkerPool)
    finish_schedule!(pool.counter)
    foreach(empty!, pool.queues)
end

function transduce_ws_root(worker::Worker, ctx::TaskContext, output::Promise, rf, init, xs)
    transduce_ws_cps_dac(WSScheduler(worker), WSDACContext(ctx, worker), true, rf, init, xs) do acc
        tryput!(output, acc)
    end
    while true
        result = tryfetch(output)
        result === nothing || return something(result)
        help_others_nonblocking(worker)
    end
end

"""
Descend into left nodes, try self-steal right nodes as much as possible.

Invariance: Once a function call of `transduce_ws_cps_dac` returns, all the
spawned tasks (the immediate right nodes) are already started. Thus, we can
safely "pop" the queue (i.e., use `setcdr!` in `spawn!`).
"""
function transduce_ws_cps_dac(
    @nospecialize(_return_),
    sch::WSScheduler,
    ctx::WSDACContext,
    isright::Bool,
    rf,
    init,
    xs,
)
    _return_ = DynamicFunction(_return_)
    if issmall(xs)
        isright && finish_schedule!(sch.counter)
        result = try
            if should_abort(ctx)
                _return_(Ok(init))
                return
            end
            acc = _reduce_basecase(rf, init, xs)
            if acc isa Reduced
                cancel!(ctx)
            end
            Ok(acc)
        catch err
            cancel!(ctx)
            Err(err)
        end
        _return_(result)
    else
        left, right = _halve(xs)
        fg, bg = splitcontext(ctx)
        started = Threads.Atomic{Int}(0)
        bridge = Promise()
        function continuation(sch, accl0)
            transduce_ws_cps_dac(sch, bg, isright, rf, init, right) do accr
                if accl0 === nothing
                    accl0 = tryput!(bridge, accr)
                    accl0 === nothing && return
                    accl = something(accl0)
                else
                    accl = something(accl0)
                end
                _return_(_combine(ctx, rf, accl, accr))
            end
        end
        sch1 = spawn!(sch) do sch
            Threads.atomic_xchg!(started, 2) != 0 && return
            continuation(sch, nothing)
        end
        transduce_ws_cps_dac(sch1, fg, false, rf, init, left) do accl
            if Threads.atomic_xchg!(started, 1) == 0  # self-steal
                # Using `sch` instead of `sch1` here would "pop" the task that
                # we just stole:
                continuation(sch, Some(accl))
            else
                accr0 = tryput!(bridge, accl)
                accr0 === nothing && return
                accr = something(accr0)
                _return_(_combine(ctx, rf, accl, accr))
            end
        end
    end
end

function help_others(worker::Worker)
    counter = worker.pool.counter
    lastvalue = counter[]
    while true
        n = 0
        while true
            if help_others_nonblocking(worker)
                n = 0
                continue
            end
            is_all_scheduled(lastvalue) && return
            n += 1
            n > 5 && break  # spin a bit; TODO: check if 5 makes sense.
        end
        lastvalue = wait_cross(counter, lastvalue + 1)
    end
end

"""
    help_others_nonblocking(worker, queue) -> should_continue::Bool
"""
function help_others_nonblocking(worker::Worker)
    # TODO: randomize
    queues = worker.pool.queues
    others = Iterators.flatten((
        view(queues, worker.id+1:lastindex(queues)),
        view(queues, firstindex(queues):worker.id),
    ))
    for other in others
        f = trypopfirst!(other)
        f === nothing && continue
        something(f)(WSScheduler(worker))
        return true
    end
    return false
end
