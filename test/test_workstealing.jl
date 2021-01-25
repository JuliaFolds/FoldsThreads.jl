module TestWorkStealing

using Folds
using FoldsThreads
using Test
using Transducers

@testset "many self-steals" begin
    @testset for basesize in [2^6, 2^8, 2^10]
        @testset for nchunks in [2^6, 2^8, 2^10]
            len = basesize * nchunks + 1
            xs = rand(typemin(UInt):typemax(UInt), len)
            @test Folds.reduce(
                xor,
                xs,
                WorkStealingEx(basesize = basesize);
                init = UInt(0),  # TODO: get rid of this
            ) == reduce(xor, xs)
            @test Folds.collect(xs |> Filter(isodd), WorkStealingEx(basesize = basesize)) ==
                  filter(isodd, xs)
        end
    end
end

function random_work(i)
    n = 0
    t0 = time_ns()
    if mod(t0, 32) == 0
        t1 = t0 + 100_000
        while t1 > time_ns()
        end
    end
    return i
end

@testset "random scheduling" begin
    @testset for _trial_ in 1:5
        xs = 1:1000
        @test Folds.collect(xs |> Map(random_work), WorkStealingEx(basesize = 1)) == xs
    end
end

end  # module
