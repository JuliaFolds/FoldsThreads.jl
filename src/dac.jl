# TODO: copy some Transducers.jl internals here, instead of importing them.

abstract type AbstractScheduler end
# TODO: Find a better name. It's a bit strange to call it a "scheduler" when it
# can't handle concurrency(?).

struct ThreadsScheduler <: AbstractScheduler end

spawn(@nospecialize(f), ::ThreadsScheduler) = @spawn f()

struct DynamicFunction <: Function
    f::Any
end

(f::DynamicFunction)(x) = f.f(x)

function transduce_dac(sch::AbstractScheduler, ctx, rf, init, xs)
    output = Promise()
    transduce_cps_dac(sch, ctx, rf, init, xs) do acc
        tryput!(output, acc)
    end
    return fetch(output)[]
end

# Using CPS to avoid deadlock (= don't require full concurrency handling for
# the scheduler) and minimize spawn.
function transduce_cps_dac(_return_, sch::AbstractScheduler, ctx, rf, init, xs)
    _return_ = DynamicFunction(_return_)  # avoid type explosion
    if should_abort(ctx)
        _return_(Ok(init))
        return
    end
    if issmall(xs)
        spawn(sch) do
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
        end
    else
        left, right = _halve(xs)
        fg, bg = splitcontext(ctx)
        bridge = Promise()
        transduce_cps_dac(sch, fg, rf, init, left) do a
            b0 = tryput!(bridge, a)
            b0 === nothing && return
            b = something(b0)
            _return_(_combine(ctx, rf, a, b))
        end
        transduce_cps_dac(sch, bg, rf, init, right) do b
            a0 = tryput!(bridge, b)
            a0 === nothing && return
            a = something(a0)
            _return_(_combine(ctx, rf, a, b))
        end
    end
end

function _combine(ctx, rf, a0, b0)
    result = try
        # TODO: merge errors
        if a0 isa Err
            a0
        elseif b0 isa Err
            b0
        else
            Ok(__combine(rf, a0[], b0[]))
        end
    catch err
        Err(err)
    end
    if result isa Err
        cancel!(ctx)
    end
    return result
end

function __combine(rf, a, b)
    a isa Reduced && return a
    b isa Reduced && return combine_right_reduced(rf, a, b)
    return combine(rf, a, b)
end
