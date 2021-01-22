    WorkStealingEx(; [simd,] [basesize])

Work-stealing scheduling for parallel (but not concurrent) execution. Useful
for load-balancing.

# Examples

```julia
julia> using FoldsThreads
       using Folds

julia> Folds.sum(i -> gcd(i, 42), 1:1000_000, WorkStealingEx())
4642844
```

# Extended help

`WorkStealingEx` implements [work stealing
scheduler](https://en.wikipedia.org/wiki/Work_stealing) for Transducers.jl
and other JuliaFolds/*.jl packages. Worker tasks are pooled (for each
executor) so that the number of Julia `Task`s used for a reduction can be
much smaller than `input_length ÷ basesize`. This has a positive impact for
reduction that requires load-balancing since this does not incur the overhead
of spawning tasks. However, as the worker tasks are occupied by a base case
until the base case is fully reduced, the user functions (reducing functions
and transducers) cannot use concurrency primitives such as channels and
semaphores to communicate _within them_. See below for discussion on usable
concurrency patterns.

**NOTE:** `WorkStealingEx` is more experimental than the default multi-thread
executor `ThreadedEx`. Importantly, `WorkStealingEx` still does not perform
well than `ThreadedEx` for parallel computation that does not require
load-balancing.

## Keyword Arguments
- `basesize`: The size of base case.
- `simd`: `false`, `true`, `:ivdep`, or `Val` of one of them.  If
  `true`/`:ivdep`, the inner-most loop of each base case is annotated
  by `@simd`/`@simd ivdep`.  Use a plain loop if `false` (default).

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

## Possible concurrency primitive usages

* Each channel is used solely for consuming or producing
  items (not both):
    * User functions that only consumes items from channels that are produced by
      `Task`s outside the reduction.
    * User functions that only produces items to channels that have enough buffer
      size or are consumed by `Task`s outside the reduction.
* Locks that are acquired and released within an iteration.
