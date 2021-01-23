mdpath, targetpath, baselinepath = ARGS
using PkgBenchmark: PkgBenchmark, baseline_result, export_markdown, target_result
group_target = PkgBenchmark.readresults(targetpath)
group_baseline = PkgBenchmark.readresults(baselinepath)
judgement = PkgBenchmark.judge(group_target, group_baseline)

function printresultmd(io, judgement)
    println(io, "# Judge result")
    export_markdown(io, judgement)
    println(io)
    println(io)
    println(io, "---")
    println(io, "# Target result")
    export_markdown(io, target_result(judgement))
    println(io)
    println(io)
    println(io, "---")
    println(io, "# Baseline result")
    export_markdown(io, baseline_result(judgement))
    println(io)
end

if mdpath == "-"
    printresultmd(stdout, judgement)
else
    open(mdpath, write = true) do io
        printresultmd(io, judgement)
    end
end
