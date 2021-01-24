@info "Using $(Threads.nthreads()) threads"

resultpath = get(ARGS, 1, joinpath(@__DIR__, "build", "result.json"))
mkpath(dirname(resultpath))

using BenchmarkTools
include("benchmarks.jl")
_, time, = @timed result = run(SUITE; verbose = true)
BenchmarkTools.save(resultpath, result)

write(joinpath(dirname(resultpath), "time"), string(time))
