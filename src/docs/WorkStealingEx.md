    WorkStealingEx(; [simd,] [basesize])

Work-stealing scheduling for parallel execution. Useful for load-balancing.

# Examples

```julia
julia> using FoldsThreads
       using Folds

julia> Folds.sum(i -> gcd(i, 42), 1:1000_000, WorkStealingEx())
4642844
```

# Extended help

`WorkStealingEx` implements [work stealing
scheduler](https://en.wikipedia.org/wiki/Work_stealing) (in particular,
[continuation
stealing](https://en.wikipedia.org/wiki/Work_stealing#Child_stealing_vs._continuation_stealing))
for Transducers.jl and other JuliaFolds/*.jl packages. Worker tasks are
cached and re-used so that the number of Julia `Task`s used for a reduction
can be much smaller than `input_length ÷ basesize`. This has a positive
impact on computations that require load-balancing since this does not incur
the overhead of spawning tasks.

**NOTE:** `WorkStealingEx` is more complex and experimental than the default
multi-thread executor `ThreadedEx`.

## More examples

```julia
julia> using FoldsThreads
       using FLoops

julia> @floop WorkStealingEx() for x in 1:1000_000
           y = gcd(x, 42)
           @reduce(acc += y)
       end
       acc
4642844
```

## Keyword Arguments
- `basesize`: The size of base case.
- `simd`: `false`, `true`, `:ivdep`, or `Val` of one of them.  If
  `true`/`:ivdep`, the inner-most loop of each base case is annotated
  by `@simd`/`@simd ivdep`.  Use a plain loop if `false` (default).
