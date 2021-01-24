import FoldsThreadsExtras
let actual = realpath(pathof(FoldsThreadsExtras)),
    expected = realpath(joinpath(@__DIR__, "..", "src", "FoldsThreadsExtras.jl"))

    if actual != expected
        msg = ("FoldsThreadsExtras.jl loaded from an unexpected path. This may be due to" *
            " misconfigured load-path.")
        @warn msg actual expected
        if get(ENV, "CHECK_LOAD_PATH", "false") == "true"
            error(msg)
        end
    end
end

using BenchmarkTools
SUITE = BenchmarkGroup()
for file in readdir(@__DIR__)
    if startswith(file, "bench_") && endswith(file, ".jl")
        SUITE[file[length("bench_")+1:end-length(".jl")]] = include(file)
    end
end
