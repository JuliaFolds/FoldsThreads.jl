Transducers.transduce(xf, rf, init, xs, ex::DepthFirstEx) =
    _transduce_depthfirst(xf, rf, init, xs; ex.kwargs...)

function _transduce_depthfirst(
    xform::Transducer,
    step::F,
    init,
    coll0;
    simd::SIMDFlag = Val(false),
    basesize::Union{Integer,Nothing} = nothing,
    stoppable::Union{Bool,Nothing} = nothing,
) where {F}
    rf0 = _reducingfunction(xform, step; init = init)
    rf, coll = retransform(rf0, coll0)
    if stoppable === nothing
        stoppable = _might_return_reduced(rf, init, coll)
    end
    acc = @return_if_reduced _reduce_df(
        stoppable ? CancellableDACContext() : NoopDACContext(),
        DummyTask(),
        maybe_usesimd(rf, simd),
        init,
        SizedReducible(
            coll,
            basesize === nothing ? amount(coll) ÷ Threads.nthreads() : basesize,
        ),
    )
    result = complete(rf, acc)
    if unreduced(result) isa DefaultInitOf
        throw(EmptyResultError(rf))
    end
    return result
end

struct DummyTask end
Base.schedule(::DummyTask) = nothing

function _reduce_df(ctx, next_task, rf::R, init::I, reducible::Reducible) where {R,I}
    if should_abort(ctx)
        # As other tasks may be calling `fetch` on `next_task`, it
        # _must_ be scheduled at some point to avoid dead lock:
        schedule(next_task)
        # Maybe use `error=false`?  Or pass something and get it via `yieldto`?
        return init
    end
    if issmall(reducible)
        schedule(next_task)
        acc = _reduce_basecase(rf, init, reducible)
        if acc isa Reduced
            cancel!(ctx)
        end
        return acc
    else
        left, right = _halve(reducible)
        fg, bg = splitcontext(ctx)
        task = nonsticky!(@task _reduce_df(bg, next_task, rf, init, right))
        a0 = _reduce_df(fg, task, rf, init, left)
        b0 = fetch(task)
        a = @return_if_reduced a0
        should_abort(ctx) && return a  # slight optimization
        b0 isa Reduced && return combine_right_reduced(rf, a, b0)
        return combine(rf, a, b0)
    end
end
