.PHONY: all build tests perf clean

all: build

build:
	dune build

tests:
	dune build @runtest

perf:
	dune build @install
	dune install -p rocq-read-file
	dune build --root tests/perf --force

clean:
	dune clean
	dune clean --root tests/perf
	rm -rf tests/perf/data
