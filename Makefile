# Convenience targets. The real build is `dune build`; this file
# just wraps the data-generation step that has to happen first.

.PHONY: all build data tests perf clean

all: build

# 1. Generate the test data files (idempotent).
data:
	./tests/gen.sh

# 2. Build everything (plugin + theories + tests).
#    Tests will fail to compile if `data` hasn't been run yet.
build: data
	dune build

# Alias: same as `build`.
tests: build

# Run perf .v files via coqc directly so Time output reaches the
# terminal rather than dune's per-target log files.  Requires the
# plugin to have been installed, e.g. via `dune build && dune install`.
perf: data
	dune build src theories
	@echo "=== bytes ===";  coqc -R _build/default/theories ReadFile -I _build/default/src tests/PerfBytes.v
	@echo "=== int63 ===";  coqc -R _build/default/theories ReadFile -I _build/default/src tests/PerfInt63.v
	@echo "=== string ==="; coqc -R _build/default/theories ReadFile -I _build/default/src tests/PerfString.v

clean:
	dune clean
	rm -f tests/data/*.bin tests/data/*.txt
