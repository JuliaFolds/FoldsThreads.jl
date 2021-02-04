Transducers.transduce(xf, rf, init, xs, ex::NonThreadedEx) =
    _transduce_nonthreaded(xf, rf, init, xs; ex.kwargs...)

function _transduce_nonthreaded(
    xform::Transducer,
    step::F,
    init,
    coll0;
    simd::SIMDFlag = Val(false),
    basesize::Union{Integer,Nothing} = nothing,
    stoppable::Union{Bool,Nothing} = nothing,
) where {F}
    rf0 = _reducingfunction(xform, step; init = init)
    rf1, coll = retransform(rf0, coll0)
    if stoppable === nothing
        stoppable = _might_return_reduced(rf1, init, coll)
    end
    rf = maybe_usesimd(rf1, simd)
    acc = reduce_nonthreaded(
        stoppable ? CancellableDACContext() : NoopDACContext(),
        rf,
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

function reduce_nonthreaded(ctx, rf::R, init::I, reducible::Reducible) where {R,I}
    if should_abort(ctx)
        return init
    end
    if issmall(reducible)
        acc = _reduce_basecase(rf, init, reducible)
        if acc isa Reduced
            cancel!(ctx)
        end
        return acc
    else
        left, right = _halve(reducible)
        fg, bg = splitcontext(ctx)
        return combine_reduced(
            rf,
            reduce_nonthreaded(fg, rf, init, left),
            reduce_nonthreaded(bg, rf, init, right),
        )
    end
end
