module BenchFindfirst

using BenchmarkTools
using Folds
using FoldsThreadsExtras

const SUITE = BenchmarkGroup()
const DATA_LENGTH = 2^20

for param in [
    (basesize = 2^10, needleloc = 2^18),
    (basesize = 2^10, needleloc = 2^19),
    (basesize = 2^12, needleloc = 2^20),
    (basesize = 2^14, needleloc = 2^20),
]
    basesize = param.basesize
    needleloc = param.needleloc
    xs = rand(DATA_LENGTH)
    xs[needleloc] = 2
    SUITE[param] =
        @benchmarkable(Folds.findfirst(>(1), $xs, WorkStealingEx(basesize = $basesize)))
end
SUITE

end  # module
BenchFindfirst.SUITE
