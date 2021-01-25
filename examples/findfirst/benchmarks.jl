using BenchmarkTools
using Folds
using FoldsThreads

const SUITE = BenchmarkGroup()
const DATA_LENGTH = 2^25

for log2_basesize in 10:2:15
    basesize = 2^log2_basesize
    SUITE[basesize] = s1 = BenchmarkGroup()
    for needleloc in floor.(Int, range(2, DATA_LENGTH, length = 10))
        s1[needleloc] = s2 = BenchmarkGroup()
        xs = rand(DATA_LENGTH)
        xs[needleloc] = 2
        s2["ThreadedEx"] =
            @benchmarkable(Folds.findfirst(>(1), $xs, ThreadedEx(basesize = $basesize)))
        s2["ThreadedEx-stoppable=false"] = @benchmarkable(
            Folds.findfirst(>(1), $xs, ThreadedEx(basesize = $basesize, stoppable = false))
        )
        s2["WorkStealingEx"] =
            @benchmarkable(Folds.findfirst(>(1), $xs, WorkStealingEx(basesize = $basesize)))
    end
end
