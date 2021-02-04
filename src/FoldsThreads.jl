baremodule FoldsThreads

export DepthFirstEx, NonThreadedEx, NondeterministicEx, TaskPoolEx, WorkStealingEx

import Transducers
const FoldsBase = Transducers

struct WorkStealingEx{K} <: FoldsBase.Executor
    kwargs::K
end

struct DepthFirstEx{K} <: FoldsBase.Executor
    kwargs::K
end

struct TaskPoolEx{K} <: FoldsBase.Executor
    kwargs::K
end

struct NondeterministicEx{K} <: FoldsBase.Executor
    kwargs::K
end

struct NonThreadedEx{K} <: FoldsBase.Executor
    kwargs::K
end

module Implementations
using Base.Threads: @spawn

using Accessors: @set
using FunctionWrappers: FunctionWrapper
using InitialValues: asmonoid
using SplittablesBase: amount, halve
using Transducers:
    @return_if_reduced,
    Completing,
    Executor,
    Init,
    Map,
    NondeterministicThreading,
    PreferParallel,
    Reduced,
    Transducer,
    Transducers,
    combine,
    complete,
    next,
    opcompose,
    reduced,
    start,
    transduce,
    unreduced

# TODO: Don't import internals from Transducers:
using Transducers:
    DefaultInit,
    DefaultInitOf,
    EmptyResultError,
    IdentityTransducer,
    Reducible,
    _might_return_reduced,
    _reducingfunction,
    combine_reduced,
    combine_right_reduced,
    ensurerf,
    extract_transducer,
    foldl_nocomplete,
    maybe_usesimd,
    restack,
    retransform

using ..FoldsThreads:
    DepthFirstEx,
    FoldsThreads,
    NonThreadedEx,
    NondeterministicEx,
    TaskPoolEx,
    WorkStealingEx

include("utils.jl")
include("threading_utils.jl")
include("linkedlist.jl")
include("trampoline.jl")
include("root_spawners.jl")
include("dac.jl")
include("taskpool.jl")
include("nondeterministic.jl")
include("workstealing.jl")
include("depthfirst.jl")
include("spawnall.jl")
include("nonthreaded.jl")
include("misc.jl")

function __init__()
    init_primary_task()
    init_each_thread()
    init_taskpool()
    init_background_taskpool()
end

end  # module Implementations

Implementations.define_docstrings()

end
