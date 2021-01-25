module BenchLoadBalancing

using BenchmarkTools
using Folds
using FoldsThreads

const SUITE = BenchmarkGroup()
const DATA_LENGTH = 2^10

function unbalanced_work(nworks, data_length)
    nworks == 0 && return nowork(_) = 0
    space = cld(data_length, nworks)
    function work(i)
        n = 0
        if mod(i, space) == 0
            # Sping for 100 μs
            t = time_ns() + 100_0000
            while t > time_ns()
                n += 1
            end
        end
        return n
    end
end

for nworks in [0, 5, 10, 30, 35]
    f = unbalanced_work(nworks, DATA_LENGTH)
    xs = 1:DATA_LENGTH
    SUITE[(nworks = nworks,)] =
        @benchmarkable(Folds.sum($f, $xs, WorkStealingEx(basesize = 1)))
end

end  # module
BenchLoadBalancing.SUITE
