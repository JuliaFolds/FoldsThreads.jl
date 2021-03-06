JULIA = julia
JULIA_NUM_THREADS = 32
export JULIA_LOAD_PATH = $(PWD)/..:

TARGET = HEAD
BASELINE = master

TARGET_REV := $(shell git rev-parse $(TARGET))
BASELINE_REV := $(shell git rev-parse $(BASELINE))

.PHONY: benchmark-* report judge

default: benchmark-$(TARGET_REV)

benchmark-%:
	$(MAKE) build/benchmarkpkg/"$$(git rev-parse $*)".json

build/benchmarkpkg/%.json:
	@git rev-parse $*
	JULIA_NUM_THREADS=$(JULIA_NUM_THREADS) CHECK_LOAD_PATH=true $(JULIA) benchmarkpkg.jl $@ $*

report: build/report.md
build/report.md: build/report-$(TARGET_REV).md
	cp $< $@
build/report-%.md: build/benchmarkpkg/%.json
	$(JULIA) report-markdown.jl $@ $<

judge: build/judge.md
build/judge.md: build/judge-$(TARGET_REV)-$(BASELINE_REV).md
	cp $< $@

build/judge-$(TARGET_REV)-$(BASELINE_REV).md: \
build/benchmarkpkg/$(TARGET_REV).json \
build/benchmarkpkg/$(BASELINE_REV).json
	$(JULIA) judge-markdown.jl $@ $+
