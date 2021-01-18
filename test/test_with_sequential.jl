module TestWithSequential

using FoldsThreadsExtras
using Folds.Testing: test_with_sequential

executors = [
    ThreadedNondeterministicEx(),
    ThreadedNondeterministicEx(ntasks = 2),
    ThreadedNondeterministicEx(basesize = 3),
    ThreadedNondeterministicEx(basesize = 3, ntasks = 2),
    ThreadedTaskPoolEx(),
    ThreadedTaskPoolEx(ntasks = 2),
    ThreadedTaskPoolEx(basesize = 3),
    ThreadedTaskPoolEx(basesize = 3, ntasks = 2),
]

if Threads.nthreads() > 1
    append!(
        executors,
        [
            ThreadedTaskPoolEx(background = true, basesize = 3),
            ThreadedTaskPoolEx(background = true, basesize = 3, ntasks = 2),
        ],
    )
end

test_with_sequential(executors)

end
