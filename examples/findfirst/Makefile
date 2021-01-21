JULIA = julia

JULIA_NUM_THREADS = 32
export JULIA_NUM_THREADS

build/analysis.ipynb: analysis.jl build/result.json runliterate.jl
	$(JULIA) runliterate.jl $<
	mv analysis.ipynb $@

build/result.json:
	$(JULIA) runbenchmarks.jl $@
