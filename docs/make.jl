using Documenter
using FoldsThreads

makedocs(
    sitename = "FoldsThreads",
    format = Documenter.HTML(),
    modules = [FoldsThreads]
)

deploydocs(; repo = "github.com/JuliaFolds/FoldsThreads.jl", push_preview = true)
