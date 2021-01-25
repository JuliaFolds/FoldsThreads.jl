using BenchmarkTools
using DataFrames
using Statistics
using Transducers
using VegaLite

resultpath = joinpath(@__DIR__, "result.json")
result, = BenchmarkTools.load(resultpath)

df_raw =
    BenchmarkTools.leaves(result) |>
    Map() do ((nworks, ex), trial)
        (nworks = parse(Int, nworks), executor = ex, trial = trial)
    end |>
    DataFrame
#-

begin
    df_tmp = select(df_raw, Not(:trial))
    df_tmp[!, :minimum] = map(trial -> minimum(trial).time, df_raw.trial)
    df_tmp[!, :median] = map(trial -> median(trial).time, df_raw.trial)
    df_tmp[!, :memory] = map(trial -> trial.memory, df_raw.trial)
    df_stats = stack(
        df_tmp,
        [:minimum, :median],
        variable_name = :time_stat,
        value_name = :time_ns,
    )
end
#-

df = combine(groupby(df_stats, [:nworks, :time_stat])) do group
    d = Dict(zip(group.executor, group.time_ns))
    (speedup = d["ThreadedEx"] / d["WorkStealingEx"],)
end
#-

plt1 = @vlplot(
    layer = [
        {
            mark = {type = :line, point = true},
            encoding = {
                x = {field = :nworks},
                y = {field = :speedup, axis = {title = "Speedup (T_default / T_WS)"}},
                color = {field = :time_stat},
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
    mark = {type = :line, point = true},
    x = :nworks,
    y = {field = :time_ns, axis = {title = "Time [ns]"}},
    color = {field = :time_stat},
    column = :executor,
    data = df_stats,
)
#-
