    ThreadedTaskPoolEx(; [simd,] [basesize,] [ntasks,] [background,])

Executor using pooled tasks for reduction. Useful for reductions with I/O and
managing back pressure. With `background = true`, it can also be used to
isolate throughput-oriented tasks and use the primary thread for
latency-oriented tasks.

# Examples

```julia
julia> using FoldsThreads
       using Folds

julia> Folds.sum(i -> gcd(i, 42), 1:1000_000, ThreadedTaskPoolEx())
4642844
```

# Extended help

Worker tasks are pooled (for each executor) so that the number of Julia
`Task`s used for a reduction can be much smaller than `input_length ÷
basesize`. This strategy is used mainly for limiting resource (e.g., memory)
required by the reduction than for load-balancing. `WorkStealingEx` performs
better for load-balancing of compute-intensive reductions.

**NOTE:** This executor is inspired by
[ThreadPools.jl](https://github.com/tro3/ThreadPools.jl). The hack for
assigning a task to a dedicated thread is stolen from ThreadPools.jl.

!!! warning
    **It is highly discouraged to use this executor in Julia _packages_**;
    especially those that are used as libraries rather than end-user
    applications. This is because the whole purpose of this executor is to
    _prevent_ Julia runtime from doing the right thing for managing tasks.
    Ideally, the library user should be able to pass an executor as an
    argument so that your library function can be used with any executors
    including `ThreadedTaskPoolEx`.

## Keyword Arguments
- `background = false`: Do not run tasks on `threadid() == 1`.
- `ntasks`: The number of tasks to be used.
- `basesize`: The size of base case.
- `simd`: `false`, `true`, `:ivdep`, or `Val` of one of them.  If
  `true`/`:ivdep`, the inner-most loop of each base case is annotated
  by `@simd`/`@simd ivdep`.  Use a plain loop if `false` (default).

## More examples

```julia
julia> using FoldsThreads
       using FLoops

julia> @floop ThreadedTaskPoolEx() for x in 1:1000_000
           y = gcd(x, 42)
           @reduce(acc += y)
       end
       acc
4642844
```
