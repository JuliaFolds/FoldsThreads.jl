module TestDoctest

import FoldsThreads
using Documenter: doctest
using Test

@testset "doctest" begin
    doctest(FoldsThreads; manual = false)
end

end  # module
