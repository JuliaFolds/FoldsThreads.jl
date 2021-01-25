JULIA = julia --startup-file=no

JULIA_NUM_THREADS = 32
export JULIA_NUM_THREADS

REV = HEAD
GIT_SHA1 = $(shell git rev-parse $(REV))

build/analysis.ipynb: build/revisions/$(GIT_SHA1)/analysis.ipynb
	ln -sf revisions/$(GIT_SHA1)/analysis.ipynb $@

build/revisions/%/analysis.ipynb: build/revisions/%/result.json analysis.jl
	cp analysis.jl build/revisions/$*/
	(cd build/revisions/$* && \
		$(JULIA) -e 'using Literate; Literate.notebook("analysis.jl")')

build/revisions/$(GIT_SHA1)/result.json:
	@mkdir -pv "$$(dirname $@)"
	@date > "$$(dirname $@)/started"
	$(JULIA) runbenchmarks.jl $@
	@date > "$$(dirname $@)/finished"
