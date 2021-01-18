Transducers.transduce(xf, rf, init, xs, ex::ThreadedTaskPoolEx) =
    transduce_taskpool(xf, rf, init, xs; ex.kwargs...)

function transduce_taskpool(
    xf::Transducer,
    rf,
    init,
    xs;
    simd = Val(false),
    basesize = nothing,
    ntasks::Int = Threads.nthreads(),
    background::Bool = false,
)
    rf0 = _reducingfunction(xf, rf; init = init, simd = simd)
    rf1, xs0 = retransform(rf0, xs)
    if basesize === nothing
        basesize = amount(xs0) ÷ Threads.nthreads()
    end
    xs1 = SizedReducible(xs0, basesize)
    return transduce_dac(
        TaskPoolScheduler(ntasks, background),
        TaskContext(),
        rf1,
        init,
        xs1,
    )
end

struct TaskPoolScheduler <: AbstractScheduler
    ntasks::Int
    semaphore::Union{Base.Semaphore,Nothing}
    request::Channel{Any}
end

TaskPoolScheduler(ntasks::Int, background::Bool) = TaskPoolScheduler(
    ntasks,
    ntasks > Threads.nthreads() ? nothing : Base.Semaphore(ntasks),
    background ? get_background_taskpool_request() : get_taskpool_request(),
)

function spawn(@nospecialize(f), sch::TaskPoolScheduler)
    semaphore = sch.semaphore
    if semaphore === nothing
        put!(sch.request, f)
    else
        Base.acquire(semaphore)
        function wrapper()
            try
                return f()
            finally
                Base.release(semaphore)
            end
        end
        put!(sch.request, wrapper)
    end
    return
end

const TASKPOOL_REQUEST = Ref{typeof(Channel{Any}(Inf))}()
const BACKGROUND_TASKPOOL_REQUEST = Ref{typeof(Channel{Any}(Inf))}()

get_taskpool_request() = _get_taskpool_request(TASKPOOL_REQUEST, init_taskpool)

function get_background_taskpool_request()
    if Threads.nthreads() == 1
        error(
            "background thread not usable when Julia is not started with multiple threads.",
        )
    end
    return _get_taskpool_request(BACKGROUND_TASKPOOL_REQUEST, init_background_taskpool)
end

function _get_taskpool_request(ref, init)
    ch = ref[]
    isopen(ch) && return ch
    @error "taskpool closed; trying to recover..."
    # TODO: lock
    init()
    ch = ref[]
    isopen(ch) && return ch
    error("failed to create a root task pool")
end

function init_taskpool()
    @debug "`init_taskpool`: Initializing `TASKPOOL_REQUEST` channels..."
    TASKPOOL_REQUEST[] = request = request_channel()
    start_taskpool(() -> true, request)
    @debug "`init_taskpool`: Initializing `TASKPOOL_REQUEST` channels... DONE"
end

function init_background_taskpool()
    @debug "`init_background_taskpool`: Initializing `BACKGROUND_TASKPOOL_REQUEST` channels..."
    BACKGROUND_TASKPOOL_REQUEST[] = request = request_channel()
    start_taskpool(() -> Threads.threadid() != 1, request)
    @debug "`init_background_taskpool`: Initializing `BACKGROUND_TASKPOOL_REQUEST` channels... DONE"
end

function start_taskpool(p, request)
    ok = foreach_thread() do
        p() || return
        @async request_handler(request)
    end
    if !ok
        @warn "failed to start task pool workers on all threads"
    end
end
