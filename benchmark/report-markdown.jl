mdpath, resultpath = ARGS
using PkgBenchmark: PkgBenchmark, export_markdown
result = PkgBenchmark.readresults(resultpath)

if mdpath == "-"
    export_markdown(stdout, result)
else
    open(mdpath, write = true) do io
        export_markdown(io, result)
    end
end
