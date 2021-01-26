"""
    SpawnAllEx

Spawn all tasks first and then fetch all of them.  Currently, there is
no use-case in which this executor performs better than other executors
(and thus it is not exported).
"""
struct SpawnAllEx{K} <: Executor
    kwargs::K
end

Transducers.transduce(xf, rf, init, xs, ex::SpawnAllEx) =
    _transduce_spawnall(xf, rf, init, xs; ex.kwargs...)

function _transduce_spawnall(
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
    tasks = Task[]
    schedule_reduce!(
        tasks,
        stoppable ? CancellableDACContext() : NoopDACContext(),
        rf,
        init,
        SizedReducible(
            coll,
            basesize === nothing ? amount(coll) ÷ Threads.nthreads() : basesize,
        ),
    )
    result = combine_all(rf, (fetch(t) for t in tasks))
    if unreduced(result) isa DefaultInitOf
        throw(EmptyResultError(rf))
    end
    return result
end

function schedule_reduce!(tasks, ctx, rf::R, init::I, reducible::Reducible) where {R,I}
    if issmall(reducible)
        t = @spawn begin
            acc = _reduce_basecase(rf, init, reducible)
            if acc isa Reduced
                cancel!(ctx)
            end
            return acc
        end
        push!(tasks, t)
    else
        left, right = _halve(reducible)
        fg, bg = splitcontext(ctx)
        schedule_reduce!(tasks, fg, rf, init, left)
        schedule_reduce!(tasks, bg, rf, init, right)
    end
    return
end
