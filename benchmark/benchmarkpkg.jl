resultfile, target, = ARGS
using PkgBenchmark
mkpath(dirname(resultfile))
PkgBenchmark.benchmarkpkg(dirname(@__DIR__), target; resultfile = resultfile)
