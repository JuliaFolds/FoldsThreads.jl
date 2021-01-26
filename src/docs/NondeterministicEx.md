    NondeterministicEx(; [simd,] [basesize,] [ntasks,])

Batched parallel reduction for non-parallelizable collections (e.g.,
`Channel`, `Iterators.Stateful`).

This is a simple wrapper of
[`NondeterministicThreading`](https://juliafolds.github.io/Transducers.jl/dev/reference/manual/#Transducers.NondeterministicThreading)
transducer. Use `NondeterministicThreading` directly for explicit control on
what transducers are parallelized.

# Examples

```julia
julia> using FoldsThreads
       using Folds

julia> partially_parallelizable(seq) = (gcd(y, 42) for x in seq for y in 1:10000x);

julia> Folds.sum(partially_parallelizable(Iterators.Stateful(1:100)), NondeterministicEx())
234462500
```

In the above example, we can run `gcd(y, 42)` (mapping), `for y in 1:10000x`
(flattening), and `+` for `sum` (reduction) in parallel even though the
iteration of `Iterators.Stateful(1:100)` is not parallelizable. Note that, as
indicated in the example, the computation per each iteration of the
non-parallelizable collection should be very CPU-intensive in order for
`NondeterministicEx` to show any kind of performance benefits.

Same computation using FLoops.jl:

```julia
julia> using FoldsThreads
       using FLoops

julia> @floop NondeterministicEx() for x in Iterators.Stateful(1:100)
           for y in 1:10000x
               z = gcd(y, 42)
               @reduce(acc += z)
           end
       end
       acc
234462500
```
