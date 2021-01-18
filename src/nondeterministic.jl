make_nondeterministicthreading(; basesize = 1, ntasks = Threads.nthreads(), kwargs...) =
    (NondeterministicThreading(; basesize = basesize, ntasks = ntasks), (; kwargs...))

function Transducers.transduce(xf, rf, init, xs, ex::ThreadedNondeterministicEx)
    ndt, kwargs = make_nondeterministicthreading(; ex.kwargs...)
    return transduce(xf ∘ ndt, rf, init, xs; kwargs...)
end

# TODO: move ThreadedNondeterministicEx to this file
