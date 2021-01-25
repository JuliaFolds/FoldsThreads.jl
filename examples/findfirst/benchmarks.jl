using BenchmarkTools
using Folds
using FoldsThreads

const SUITE = BenchmarkGroup()
const DATA_LENGTH = 2^23

for log2_basesize in 12:14
    basesize = 2^log2_basesize
    SUITE[basesize] = s1 = BenchmarkGroup()
    for log2_needleloc in 11:23
        needleloc = 2^log2_needleloc
        s1[needleloc] = s2 = BenchmarkGroup()
        xs = rand(DATA_LENGTH)
        xs[needleloc] = 2
        s2["ThreadedEx"] =
            @benchmarkable( Folds.findfirst(>(1), $xs, ThreadedEx(basesize = $basesize)))
        s2["WorkStealingEx"] =
            @benchmarkable(Folds.findfirst(>(1), $xs, WorkStealingEx(basesize = $basesize)))
        s2["DepthFirstEx"] =
            @benchmarkable(Folds.findfirst(>(1), $xs, DepthFirstEx(basesize = $basesize)))
        #=
        s2["SpawnAllEx"] =
            @benchmarkable(Folds.findfirst(>(1), $xs, SpawnAllEx(basesize = $basesize)))
        =#
    end
end
