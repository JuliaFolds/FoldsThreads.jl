baremodule FoldsThreads

export ThreadedNondeterministicEx, ThreadedTaskPoolEx, WorkStealingEx

import Transducers
const FoldsBase = Transducers

struct ThreadedTaskPoolEx{K} <: FoldsBase.Executor
    kwargs::K
end

struct ThreadedNondeterministicEx{K} <: FoldsBase.Executor
    kwargs::K
end

struct WorkStealingEx{K} <: FoldsBase.Executor
    kwargs::K
end

module Implementations
using Base.Threads: @spawn

using Accessors: @set
using FunctionWrappers: FunctionWrapper
using SplittablesBase: amount
using Transducers:
    @return_if_reduced,
    Executor,
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
    SizedReducible,
    TaskContext,
    _halve,
    _reduce_basecase,
    _reducingfunction,
    combine_right_reduced,
    extract_transducer,
    issmall,
    retransform
import Transducers: cancel!, should_abort, splitcontext

using ..FoldsThreads: ThreadedNondeterministicEx, ThreadedTaskPoolEx, WorkStealingEx

include("utils.jl")
include("linkedlist.jl")
include("trampoline.jl")
include("root_spawners.jl")
include("dac.jl")
include("taskpool.jl")
include("nondeterministic.jl")
include("workstealing.jl")

function __init__()
    init_primary_task()
    init_each_thread()
    init_taskpool()
    init_background_taskpool()
end

end  # module Implementations

end
