using BenchmarkTools
using DataFrames
using Transducers
using VegaLite

resultpath = joinpath(@__DIR__, "build", "result.json")
result, = BenchmarkTools.load(resultpath)

df_raw =
    BenchmarkTools.leaves(result) |>
    Map() do ((basesize, needleloc, ex), trial)
        (
            basesize = parse(Int, basesize),
            needleloc = parse(Int, needleloc),
            executor = ex,
            trial = trial,
        )
    end |>
    DataFrame
#-

begin
    df_stats = select(df_raw, Not(:trial))
    df_stats[!, :time_ns] = map(trial -> minimum(trial).time, df_raw.trial)
    df_stats[!, :memory] = map(trial -> trial.memory, df_raw.trial)
    df_stats
end
#-

df = combine(groupby(df_stats, [:basesize, :needleloc])) do group
    d = Dict(zip(group.executor, group.time_ns))
    (speedup = d["ThreadedEx"] / d["WorkStealingEx"],
    speedup_nonstoppable = d["ThreadedEx-stoppable=false"] / d["WorkStealingEx"],
    )
end
#-

plt1 = @vlplot(
    layer = [
        {
            mark = {type = :line, point = true},
            encoding = {
                x = {field = :needleloc},
                y = {field = :speedup, axis = {title = "Speedup (T_default / T_WS)"}},
                color = {field = :basesize, type = :nominal},
            },
        },
        {
            mark = :rule,
            encoding = {y = {datum = 1}},
        },
    ],
    data = df,
    width = 400,
    height = 200,
)
#-

plt2 = @vlplot(
    layer = [
        {
            mark = {type = :line, point = true},
            encoding = {
                x = {field = :needleloc},
                y = {field = :speedup_nonstoppable, axis = {title = "Speedup (T_nonstoppable / T_WS)"}},
                color = {field = :basesize, type = :nominal},
            },
        },
        {
            mark = :rule,
            encoding = {y = {datum = 1}},
        },
    ],
    data = df,
    width = 400,
    height = 200,
)
#-

plt3 = @vlplot(
    mark = {type = :line, point = true},
    x = :needleloc,
    y = {field = :time_ns, axis = {title = "Time [ns]"}},
    color = {field = :basesize, type = :nominal},
    column = :executor,
    data = df_stats,
)
#-
