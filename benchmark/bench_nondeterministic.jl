module BenchNondeterministic

using BenchmarkTools
using Folds
using FoldsThreads

partially_parallelizable(seq) = (gcd(y, 42) for x in seq for y in 1:10000x)

demo(ex) = Folds.sum(partially_parallelizable(Iterators.Stateful(1:100)), ex)

const SUITE = BenchmarkGroup()
SUITE["seq"] = @benchmarkable(demo(SequentialEx()))
SUITE["nondet"] = @benchmarkable(demo(ThreadedNondeterministicEx()))

end  # module
BenchNondeterministic.SUITE
