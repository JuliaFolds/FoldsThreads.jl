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
    tasks::Vector{Vector{Task}}
    queues::Vector{WorkQueue}
    occupied::Vector{Bool}
    all_scheduled::Threads.Atomic{Bool}
end

function WorkerPool()
    ntasks = Threads.nthreads()
    tasks = [Task[] for _ in 1:ntasks]
    queues = [WorkQueue() for _ in 1:ntasks]
    occupied = zeros(Bool, ntasks)
    all_scheduled = Threads.Atomic{Bool}(false)
    return WorkerPool(tasks, queues, occupied, all_scheduled)
end

struct WSScheduler
    pool::WorkerPool
    queue::WorkQueue
end

WSScheduler(pool::WorkerPool = WorkerPool()) =
    WSScheduler(pool, pool.queues[Threads.threadid()])

function get_scheduler(sch::WSScheduler)
    pool = sch.pool
    pool.occupied[Threads.threadid()] && return
    pool.occupied[Threads.threadid()] = true
    return WSScheduler(pool, pool.queues[Threads.threadid()])
end
# TODO: Prepare for task migration; use local worker id instead of
# Threads.threadid().

push_task!(sch, task) = push!(sch.pool.tasks[Threads.threadid()], task)
is_all_scheduled(sch::WSScheduler) = sch.pool.all_scheduled[]

""" Work-stealing (WS) divide-and-conquer (DAC) context """
struct WSDACContext
    ctx::TaskContext
    output::Promise
    all_scheduled::Threads.Atomic{Bool}
    isright::Bool
    ntasks::Int
end

WSDACContext(ctx::TaskContext, output::Promise, sch::WSScheduler) =
    WSDACContext(ctx, output, sch.pool.all_scheduled, true, Threads.nthreads() - 1)

function task_spawn!(f, sch::WSScheduler, ctx::WSDACContext)
    output = ctx.output
    task = Threads.@spawn try
        sch2 = get_scheduler(sch)
        sch2 === nothing && return # retry?
        f(sch2)
        help_others(sch2)
    catch err
        tryput!(output, Err(err))
        rethrow()
    end
    push_task!(sch, task)
    cons = listof(Function, f)
    setcdr!(sch.queue, cons)
    queue = setlist(sch.queue, cons)
    return @set sch.queue = queue
end

function spawn!(f, sch::WSScheduler)
    cons = listof(Function, f)
    setcdr!(sch.queue, cons)
    queue = setlist(sch.queue, cons)
    return @set sch.queue = queue
end

should_abort(ctx::WSDACContext) = should_abort(ctx.ctx)
cancel!(ctx::WSDACContext) = cancel!(ctx.ctx)
function splitcontext(ctx::WSDACContext)
    fg, bg = splitcontext(ctx.ctx)
    nl = ctx.ntasks ÷ 2
    nr = ctx.ntasks - nl
    return (
        WSDACContext(fg, ctx.output, ctx.all_scheduled, false, nl),
        WSDACContext(bg, ctx.output, ctx.all_scheduled, ctx.isright, nr),
    )
end

function on_basecase!(ctx::WSDACContext)
    if ctx.isright
        ctx.all_scheduled[] = true
    end
    return
end

function transduce_ws(ctx, rf, init, xs)
    sch = WSScheduler()
    output = Promise()
    try
        transduce_ws_root(sch, WSDACContext(ctx, output, sch), rf, init, xs)
    finally
        close(sch.pool)
    end
    return something(tryfetch(output))[]
end

function Base.close(pool::WorkerPool)
    pool.all_scheduled[] = true
    foreach(empty!, pool.queues)
    for tasks in pool.tasks
        # TODO: make this thread-safe & merge all tasks
        for t in tasks
            wait(t)
        end
    end
end

function transduce_ws_root(sch::WSScheduler, ctx::WSDACContext, rf, init, xs)
    output = ctx.output
    thunk = transduce_ws_cps_dac1(sch, ctx, rf, init, xs) do acc
        tryput!(output, acc)
    end
    thunk()
    while true
        result = tryfetch(output)
        result === nothing || return something(result)
        while help_others_nonblocking(sch)
        end
        yield()
    end
end

function transduce_ws_cps_dac1(
    @nospecialize(_return_),
    sch::WSScheduler,
    ctx::WSDACContext,
    rf,
    init,
    xs,
)
    if ctx.ntasks <= 1 || issmall(xs)
        return transduce_ws_cps_dac2(_return_, sch, ctx, rf, init, xs)
    end
    # @show ctx.ntasks
    _return_ = DynamicFunction(_return_)

    left, right = _halve(xs)
    fg, bg = splitcontext(ctx)
    started = Threads.Atomic{Int}(0)
    bridge = Promise()
    function continuation(sch, accl0)
        local thunk = transduce_ws_cps_dac1(sch, bg, rf, init, right) do accr
            if accl0 === nothing
                accl1 = tryput!(bridge, accr)
                accl1 === nothing && return
                accl = something(accl1)
            else
                accl = something(accl0)
            end
            _return_(_combine(ctx, rf, accl, accr))
        end
        thunk()
    end
    sch1 = task_spawn!(sch, ctx) do sch
        Threads.atomic_xchg!(started, 2) != 0 && return
        continuation(sch, nothing)
    end
    return transduce_ws_cps_dac1(sch1, fg, rf, init, left) do accl
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

"""
Descend into left nodes, try self-steal right nodes as much as possible.

Invariance: Once a function call of `transduce_ws_cps_dac` returns, all the
spawned tasks (the immediate right nodes) are already started. Thus, we can
safely "pop" the queue (i.e., use `setcdr!` in `spawn!`).
"""
function transduce_ws_cps_dac2(
    @nospecialize(_return_),
    sch::WSScheduler,
    ctx::WSDACContext,
    rf,
    init,
    xs,
)
    _return_ = DynamicFunction(_return_)
    if issmall(xs)
        on_basecase!(ctx)
        result = try
            if should_abort(ctx)
                Ok(init)
            else
                acc = _reduce_basecase(rf, init, xs)
                if acc isa Reduced
                    cancel!(ctx)
                end
                Ok(acc)
            end
        catch err
            cancel!(ctx)
            Err(err)
        end
        return function thunk()
            _return_(result)
        end
    else
        left, right = _halve(xs)
        fg, bg = splitcontext(ctx)
        started = Threads.Atomic{Int}(0)
        bridge = Promise()
        function continuation(sch, accl0)
            local thunk = transduce_ws_cps_dac2(sch, bg, rf, init, right) do accr
                if accl0 === nothing
                    accl1 = tryput!(bridge, accr)
                    accl1 === nothing && return
                    accl = something(accl1)
                else
                    accl = something(accl0)
                end
                _return_(_combine(ctx, rf, accl, accr))
            end
            thunk()
        end
        sch1 = spawn!(sch) do sch
            Threads.atomic_xchg!(started, 2) != 0 && return
            continuation(sch, nothing)
        end
        return transduce_ws_cps_dac2(sch1, fg, rf, init, left) do accl
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

function help_others(sch::WSScheduler)
    while !is_all_scheduled(sch)
        while help_others_nonblocking(sch)
        end
        yield()
    end
end

"""
    help_others_nonblocking(sch, queue) -> should_continue::Bool
"""
function help_others_nonblocking(sch::WSScheduler)
    queues = sch.pool.queues
    for _ in 1:8*length(queues)
        other = queues[Int(mod1(time_ns(), length(queues)))]
        isempty(other) && continue  # racy lock-free check
        f = trypopfirst!(other)
        f === nothing && continue
        something(f)(sch)
        return true
    end
    for other in queues
        f = trypopfirst!(other)
        f === nothing && continue
        something(f)(sch)
        return true
    end
    return false
end
