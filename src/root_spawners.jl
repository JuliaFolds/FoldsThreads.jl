request_channel() = Channel{Any}(Threads.nthreads() * 8)
# 8 is a rather random number...

function request_handler(request::Channel{Any})
    try
        for f in request
            @debug "Processing request $(f)"
            try
                Base.invokelatest(f)
            catch err
                @error("UNHANDLED EXCEPTION", f, exception = (err, catch_backtrace()))
            end
        end
    finally
        close(request)
    end
end

const RefChannelAny = typeof(Ref(request_channel()))

const PRIMARY_TASK = RefChannelAny()

function init_primary_task()
    @debug "`init_primary_task`: Initializing `PRIMARY_TASK` channel..."
    PRIMARY_TASK[] = request = request_channel()
    ok = Ref(false)
    _foreach_thread() do
        if Threads.threadid() == 1
            @async request_handler(request)
            ok[] = true
        end
    end
    if !ok[]
        @error "failed to start primary task"
    end
    @debug "`init_primary_task`: Initializing `PRIMARY_TASK` channel... DONE"
end

function get_primary_task_channel()
    ch = PRIMARY_TASK[]
    isopen(ch) && return ch
    init_primary_task()
    isopen(ch) && return ch
    error("failed to get primary task")
end

function on_primary_task(@nospecialize f)
    request = get_primary_task_channel()
    t = Future(f)
    put!(request, runner(t))
    return fetch(t)
end

const EACH_THREAD = Vector{Union{Channel{Any},Nothing}}(undef, 0)

function init_each_thread()
    @debug "`init_each_thread`: Initializing `EACH_THREAD` channels..."
    resize!(EACH_THREAD, Threads.nthreads())
    EACH_THREAD .= Ref(nothing)
    ok = _foreach_thread() do
        i = Threads.threadid()
        EACH_THREAD[i] = request = request_channel()
        @async request_handler(request)
    end
    if !ok
        @warn "failed to start task pool workers on all threads"
    end
    @debug "`init_each_thread`: Initializing `EACH_THREAD` channels... DONE"
end

function foreach_thread(@nospecialize f)
    n = foreach_thread_impl(f)
    n > 0 && return n == Threads.nthreads()
    # TODO: lock?
    on_primary_task(init_each_thread)
    n = foreach_thread_impl(f)
    n > 0 && return n == Threads.nthreads()
    error("failed to obtain spawner tasks")
end

function foreach_thread_impl(@nospecialize f)
    futures = Future[]
    for ch in EACH_THREAD
        ch === nothing && continue
        t = Future(f)
        put!(ch, runner(t))
        push!(futures, t)
    end
    foreach(fetch, futures)
    return length(futures)
end
