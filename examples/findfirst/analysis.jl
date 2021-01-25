using BenchmarkTools
using DataFrames
using Transducers
using VegaLite

resultpath = joinpath(@__DIR__, "result.json")
result, = BenchmarkTools.load(resultpath)

df_raw =
    BenchmarkTools.leaves(result) |>
    Map() do ((basesize, needleloc, ex), trial)
        (
            basesize = parse(Int, basesize),
            needleloc = parse(Int, needleloc),
            executor = Symbol(ex),
            trial = trial,
        )
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

begin
    df = transform(groupby(df_stats, [:basesize, :needleloc, :time_stat])) do group
        baseline = only(eachrow(filter(:executor => ==(:ThreadedEx), group)))
        (speedup = baseline.time_ns ./ group.time_ns,)
    end
    filter!(:executor => !(==(:ThreadedEx)), df)
    df
end
#-

plt1 = @vlplot(
    facet = {row = {field = :executor, type = :nominal}, column = {field = :time_stat, type = :nominal}},
    spec = {
        layer = [
            {
                mark = {type = :line, point = true},
                encoding = {
                    x = {field = :needleloc, scale = {type = :log, base = 2}},
                    y = {field = :speedup, axis = {title = "Speedup (T_default / T_\$executor)"}},
                    color = {field = :basesize, type = :nominal},
                },
            },
            {
                mark = :rule,
                encoding = {y = {datum = 1}},
            },
        ],
    },
    data = df,
)
#-

plt2 = @vlplot(
    mark = {type = :line, point = true},
    x = {field = :needleloc, scale = {type = :log, base = 2}},
    y = {field = :time_ns, axis = {title = "Time [ns]"}},
    color = {field = :basesize, type = :nominal},
    row = :executor,
    column = :time_stat,
    resolve = {scale = {y = "independent"}},
    data = df_stats,
)
#-

plt3 = @vlplot(
    mark = {type = :line, point = true, clip = true},
    x = {field = :needleloc, scale = {type = :log, base = 2}},
    y = {field = :time_ns, axis = {title = "Time [ns]"}, scale = {domain = [0, 800_000]}},
    color = {field = :basesize, type = :nominal},
    row = :executor,
    column = :time_stat,
    data = df_stats,
)
#-
