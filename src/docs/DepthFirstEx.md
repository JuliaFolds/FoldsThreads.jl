    DepthFirstEx(; [simd,] [basesize])

Depth-first scheduling for parallel execution. Useful for `findfirst`-type of
computation.

# Examples

```julia
julia> using FoldsThreads
       using Folds

julia> Folds.sum(i -> gcd(i, 42), 1:1000_000, DepthFirstEx())
4642844
```

# Extended help

`DepthFirstEx` schedules chunks of size roughly equal to `basesize` in the
order that each chunk appears in the input collection. However, the base case
computation does not wait for all the tasks to be scheduled. This approach
performs better than a more naive approach where the all tasks are scheduled
at once before the reduction starts. `DepthFirstEx` is useful for reductions
that can terminate early (e.g., `findfirst`, `@floop` with `break`).

## More examples

```julia
julia> using FoldsThreads
       using FLoops

julia> @floop DepthFirstEx() for x in 1:1000_000
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
