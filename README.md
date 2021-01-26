# FoldsThreads: Extra threaded executors for JuliaFolds/*.jl

FoldsThreads.jl provides extra thread-based executors usable with
various JuliaFolds/*.jl packages:

* `WorkStealingEx` implements work stealing (continuation stealing).
  Useful for load-balancing.
* `DepthFirstEx` implements depth-first scheduling. Useful for `findfirst`-type
  computations.
* `TaskPoolEx`: Task pool executor. Useful for fine execution control
  (e.g., back pressure and "background" threads).
* `NondeterministicEx`: An executor for parallelizing computations with
  non-parallelizable iterators.
