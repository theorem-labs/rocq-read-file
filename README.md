# rocq-read-file

A Rocq plugin that reads files from disk into Rocq-side primitive
values: byte arrays, int63 arrays, or primitive strings.

## Commands

```coq
From ReadFile Require Import ReadFile.

ReadFileBytes  "path/to/file"  As name.
ReadFileBytes  "path/to/file"  As name : MyByteType.
ReadFileInt63  LittleEndian "path/to/file" As name.
ReadFileInt63  BigEndian    "path/to/file" As name.
ReadFileString "path/to/file"  As name.
```

Every command also accepts an optional slice suffix:

```coq
ReadFileBytes  "f" As n Length 1024.
ReadFileBytes  "f" As n Offset 100.
ReadFileBytes  "f" As n Offset 100 Length 1024.
```

`Offset` defaults to `0` and `Length` defaults to "to end of file".

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
./tests/gen.sh    # generate test data (only needed for tests/)
dune build
```

Or via the convenience Makefile:

```sh
make build        # data + dune build
make perf         # run timing tests via coqc directly
```

The data step writes about 100 MB of random data into `tests/data/`.

## Running the tests

`tests/Tests.v` contains correctness tests against a fixed-content
fixture (`tests/data/small.bin`, the bytes of `"Hello!"`).  It is
compiled by `dune build` along with everything else, so a build
failure in that file means a behaviour regression.

`tests/Perf{Bytes,Int63,String}.v` contain `Time` lines at sizes 1 KB
through 64 MB.  Their compile-time output is the timing data.  Use
`make perf` to see it on your terminal — `dune build` will compile
them but tuck the output into per-target log files.

## Build dependencies

* Coq 8.18+ or Rocq 9.x.
* `coq-core` (or `rocq-runtime`) must be installed and visible to
  dune. Standard opam install is fine.

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
  via `Rocqlib.lib_ref` first, then falling back to `Nametab.locate`
  on a list of common qualified names so the plugin works against
  several stdlib layouts (Corelib, Stdlib, legacy Coq paths).

* File paths are resolved first as-is (relative to the working
  directory), then via the Rocq load path. This means files placed
  alongside `.v` sources (or in directories registered with `-R`/`-Q`)
  are found automatically.
