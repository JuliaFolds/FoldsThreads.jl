make_nondeterministicthreading(; basesize = 1, ntasks = Threads.nthreads(), kwargs...) =
    (NondeterministicThreading(; basesize = basesize, ntasks = ntasks), (; kwargs...))

function Transducers.transduce(xf, rf, init, xs, ex::NondeterministicEx)
    ndt, kwargs = make_nondeterministicthreading(; ex.kwargs...)
    xf0, xs0 = extract_transducer(xs)
    # TODO: don't assume all transducers are parallelizable
    return transduce(xf ∘ xf0 ∘ ndt, rf, init, xs0; kwargs...)
end

# TODO: move ThreadedNondeterministicEx to this file
