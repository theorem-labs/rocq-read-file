# rocq-read-file

A Rocq plugin that reads files from disk into Rocq-side primitive
values: byte arrays, int63 arrays, or primitive strings.

## Installation

```
opam repo add rocq-released https://rocq-prover.org/opam/released
opam install rocq-read-file
```

## Commands

The file argument can be a string literal (`"path/to/file"`) or an
identifier declared via `Extra Dependency` (see below):

```coq
From ReadFile Require Import ReadFile.
From MyTheory Extra Dependency "my_data.bin" as my_data.

ReadFileBytes  my_data          As name.
ReadFileBytes  "path/to/file"   As name.
ReadFileBytes  my_data          As name : MyByteType.
ReadFileInt63  LittleEndian my_data As name.
ReadFileInt63  BigEndian    my_data As name.
ReadFileString my_data          As name.
```

Every command also accepts an optional slice suffix:

```coq
ReadFileBytes  my_data As n Length 1024.
ReadFileBytes  my_data As n Offset 100.
ReadFileBytes  my_data As n Offset 100 Length 1024.
```

`Offset` defaults to `0` and `Length` defaults to "to end of file".

### Extra Dependency (recommended)

Use `Extra Dependency` to declare data files so that Rocq tracks
them as dependencies and the plugin can resolve them by identifier:

```coq
From MyTheory Extra Dependency "my_data.bin" as my_data.

ReadFileBytes my_data As raw.
```

When the file is referenced by identifier, it is resolved through
Rocq's `ComExtraDeps` mechanism.  When referenced by string path,
the plugin resolves the path in order:

1. As-is (relative to the working directory)
2. Via `Extra Dependency` (derived from the filename stem)
3. Via the Rocq load path (`-R`/`-Q` directories)

#### Dune integration

Because dune does not natively support `Extra Dependency`
([ocaml/dune#9591](https://github.com/ocaml/dune/pull/9591)), a
helper tool `rocq-read-file-shafile` is provided.  Add a rule to your
`dune` file to generate a dummy `.v` whose content changes when any
data file changes:

```lisp
(rule
 (target dep_hashes.v)
 (deps (glob_files data/*.bin))
 (action
  (with-stdout-to %{target}
   (run rocq-read-file-shafile %{deps}))))
```

Then `Require dep_hashes` in each `.v` that uses data files.

### Controlling chunk size

The per-array maximum element count defaults to `PArray.max_length`
(4_194_302). You can lower it to force nesting at a smaller threshold:

```coq
Set ReadFile MaxArrayLength 1000.
ReadFileBytes "data.bin" As chunked.   (* arrays of at most 1000 elements *)
Unset ReadFile MaxArrayLength.         (* restore the default *)
```

### Per-command notes

* **`ReadFileBytes`** — leaf type defaults to `Byte.byte`.  You may
  pass any parameterless inductive type living in `Set` with exactly
  256 nullary constructors via the `: T` form.  Byte value `b` maps
  to the `(b+1)`-th constructor (so for `Byte.byte`, `0x00` maps to
  `Byte.x00`, `0xFF` maps to `Byte.xff`, etc.).

* **`ReadFileInt63`** — folds 8 bytes at a time into one `int63`.  If
  the slice length is not a multiple of 8, it is right-padded with
  zero bytes.  In little-endian mode the padding occupies the
  high-order bytes of the last word; in big-endian mode the
  low-order bytes.  The 64th bit is silently dropped because `int63`
  only carries 63 bits.

* **`ReadFileString`** — produces a primitive `string` if the slice
  fits in `Pstring.max_length` bytes; otherwise an `array string`,
  or `array (array string)` for very large inputs (see "Auto-nesting"
  below).

## Auto-nesting

A single primitive array can hold at most `PArray.max_length`
(= 4_194_302) elements.  When the requested slice would exceed this
at any level, the plugin chunks the data and wraps the chunks in an
outer primitive array, recursing as deep as needed.  Concretely:

| Mode    | Leaf type | Capacity per level | When 2 levels are needed |
|---------|-----------|--------------------|--------------------------|
| Bytes   | `byte`    | 4_194_302 bytes    | slice > 4 MB             |
| Int63   | `int`     | 4_194_302 ints     | slice > 32 MB            |
| String  | `string`  | ~16_777_211 bytes  | slice > 16 MB            |

For depth 1 the result type is `array byte` / `array int` / `string`
respectively.  For depth 2 it becomes `array (array byte)` /
`array (array int)` / `array string`.  In practice 2 levels suffice
for any file under ~16 TB.

The `ReadFile.NestedArray` module (in `theories/NestedArray.v`)
provides flat-index accessors (`get1`, `get2`, `get3`) that take the
inner-block size as a parameter:

```coq
From ReadFile Require Import ReadFile NestedArray.

ReadFileBytes "huge.bin" As huge.   (* huge : array (array byte) *)

Definition byte_at (i : int) : Byte.byte :=
  NestedArray.get2 PArray.max_length huge i.
```

## Build

```sh
dune build
```

Or via the convenience Makefile:

```sh
make build        # plugin, theories, and correctness tests
make tests        # build the correctness-test alias
make perf         # generate perf data and run the isolated perf project
```

`make perf` stages the current package in the active opam switch, then builds
the separate `tests/perf` Dune project. That project generates about 100 MB of
test data under its `_build` directory.

## Running the tests

`tests/Tests.v` contains correctness tests against a fixed-content
fixture (`tests/fixtures/small.bin`, the bytes of `"Hello!"`).  It is
compiled by `dune build` along with everything else, so a build
failure in that file means a behaviour regression.

`tests/perf/Perf{Bytes,Int63,String}.v` contain `Time` lines at sizes 1 KB
through 64 MB. Their compile-time output is the timing data. The perf suite is
an isolated Dune project and only runs via `make perf` (or an equivalent
`dune build --root tests/perf` after installing the package).

## Build dependencies

* Rocq 9.0+.
* OCaml 4.14+, Dune 3.21+ (including Dune 3.24), and `ppx_optcomp`.
* `rocq-runtime` and `rocq-stdlib`; a standard opam install resolves them.

## Implementation notes

* `Bytes` mode caches the 256 constructor terms once per call and
  reuses them across all elements.  Memory cost is `8 * N` bytes for
  the OCaml reference array plus the kernel's primitive-array
  overhead.  At 64 MB inputs that's ~512 MB of in-flight references;
  larger inputs are likely to be more comfortable in `String` mode,
  which keeps the bytes packed inside a single `Pstring`.

* `Int63` mode reads via OCaml `Int64.t` arithmetic and converts with
  `Uint63.of_int64`, which masks bit 63.  No explicit overflow
  handling beyond that.

* `String` mode goes through `Pstring.of_string`.  Primitive strings
  carry raw bytes, not validated UTF-8, so this is safe for
  arbitrary binary input.

* The plugin defines a single `ARGUMENT EXTEND slice_spec` rule with
  an empty alternative, which is what lets all five vernacular forms
  share a uniform `[Offset N] [Length N]` suffix without enumerating
  every combination.

* Globals (`Byte.byte`, the array type constant, the int63 type
  constant, and the primitive-string type constant) are looked up
  via `Rocqlib.lib_ref`.  The array type has no stdlib registration,
  so `ReadFile.v` registers it as `readfile.array.type`.

* File sources can be an `Extra Dependency` identifier (resolved via
  `ComExtraDeps.query_extra_dep`) or a string path (resolved as-is,
  then via Extra Dependency fallback, then via the Rocq load path).
