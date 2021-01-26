module TestWithSequential

using FoldsThreads
using FoldsThreads.Implementations: SpawnAllEx
using Folds.Testing: test_with_sequential

executors = [
    NondeterministicEx(),
    NondeterministicEx(ntasks = 2),
    NondeterministicEx(basesize = 3),
    NondeterministicEx(basesize = 3, ntasks = 2),
    TaskPoolEx(),
    TaskPoolEx(ntasks = 2),
    TaskPoolEx(basesize = 3),
    TaskPoolEx(basesize = 3, ntasks = 2),
    WorkStealingEx(),
    WorkStealingEx(basesize = 3),
    DepthFirstEx(),
    DepthFirstEx(basesize = 3),
    SpawnAllEx(),
    SpawnAllEx(basesize = 3),
]

if Threads.nthreads() > 1
    append!(
        executors,
        [
            TaskPoolEx(background = true, basesize = 3),
            TaskPoolEx(background = true, basesize = 3, ntasks = 2),
        ],
    )
end

test_with_sequential(executors)

end
