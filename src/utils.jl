@static if VERSION >= v"1.5-"
    function _foreach_thread(f)
        ids = zeros(Threads.nthreads())
        Threads.@threads :static for i in 1:Threads.nthreads()
            ids[i] = Threads.threadid()
            f()
        end
        return check_threadids(ids)
    end
else
    function _foreach_thread(f)
        ids = zeros(Threads.nthreads())
        Threads.@threads for i in 1:Threads.nthreads()
            ids[i] = Threads.threadid()
            f()
        end
        return check_threadids(ids)
    end
end

check_threadids(ids) = length(Set(ids)) == length(ids)

struct Err{T}
    value::T
end

struct Ok{T}
    value::T
end

Base.getindex(err::Err) = throw(err.value)
Base.getindex(ok::Ok) = ok.value


struct Promise
    value::Base.RefValue{Any}
    isset::Threads.Atomic{Bool}
    notify::Threads.Condition
end

Promise() = Promise(Ref{Any}(), Threads.Atomic{Bool}(false), Threads.Condition())

tryfetch(::Nothing) = nothing
tryfetch(p::Promise) = p.isset[] ? Some(p.value[]) : nothing

function tryput!(p::Promise, value)
    p.isset[] && return Some(p.value[])
    lock(p.notify) do
        p.isset[] && return Some(p.value[])
        p.value[] = value
        p.isset[] = true
        notify(p.notify)
        return nothing
    end
end

function Base.fetch(p::Promise)
    p.isset[] && return p.value[]
    lock(p.notify) do
        while !p.isset[]
            wait(p.notify)
        end
        return p.value[]
    end
end

struct Future
    f::Any
    p::Promise
end

Future(@nospecialize f) = Future(f, Promise())

function run!(future::Future)
    ans = try
        Ok(future.f())
    catch err
        @debug("FUTURE FAILED", objectid(future), future.f, exception = (err, catch_backtrace()))
        Err(err)
    end
    @assert tryput!(future.p, ans) === nothing
end

Base.fetch(future::Future) = fetch(future.p)[]

runner(f::Future) = function run_future()
    run!(f)
end

struct Counter
    value::Threads.Atomic{Int}
    notify::Threads.Condition
end
# TODO: use Event instead?

Counter(n::Int = 0) = Counter(Threads.Atomic{Int}(n), Threads.Condition())

function inc!(c::Counter)
    lock(c.notify) do
        x = Threads.atomic_add!(c.value, 1)
        if x == typemax(Int)
            c.value[] = typemax(Int)
        end
        notify(c.notify)
        x
    end
end

function try_inc_to!(c::Counter, x)
    lock(c.notify) do
        v = c.value[]
        if v ≤ x
            c.value[] = x
            return nothing
        else
            return Some(v)
        end
    end
end

Base.getindex(c::Counter) = c.value[]

function wait_cross(c::Counter, old::Int)
    v = c.value[]
    v > old && return v
    lock(c.notify) do
        while c.value[] ≤ old
            wait(c.notify)
        end
        return c.value[]
    end
end
