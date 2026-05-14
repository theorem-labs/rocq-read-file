.PHONY: all build data tests perf clean

all: build

data:
	./tests/gen.sh

build: data
	dune build

tests: build

perf: data
	dune build src theories
	@echo "=== bytes ===";  coqc -R _build/default/theories ReadFile -I _build/default/src tests/PerfBytes.v
	@echo "=== int63 ===";  coqc -R _build/default/theories ReadFile -I _build/default/src tests/PerfInt63.v
	@echo "=== string ==="; coqc -R _build/default/theories ReadFile -I _build/default/src tests/PerfString.v

clean:
	dune clean
	rm -f tests/data/*.bin tests/data/*.txt
