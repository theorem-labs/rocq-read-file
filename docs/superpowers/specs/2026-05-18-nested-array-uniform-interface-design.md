# Uniform NestedArray Interface

## Summary

Replace the ad-hoc `get1`/`get2`/`get3` helpers and bare `array (array ...)` type chains with a uniform `NestedArray n A` type family and depth-parameterized operations. Update the OCaml plugin to emit `NestedArray n A` in type annotations.

## Type Definition

```coq
Polymorphic Fixpoint NestedArray (n : nat) (A : Type) : Type :=
  match n with
  | 0 => A
  | S n' => array (NestedArray n' A)
  end.
```

- `NestedArray 0 A = A` (base type, no array wrapper)
- `NestedArray 1 A = array A`
- `NestedArray 2 A = array (array A)`
- `NestedArray 3 A = array (array (array A))`

Transparent and universe-polymorphic. Definitionally equals the bare `array` chains.

Plugin output types:
- ReadFileBytes: `NestedArray 1 byte`, `NestedArray 2 byte`, `NestedArray 3 byte`
- ReadFileInt63: `NestedArray 1 int`, etc.
- ReadFileString: `NestedArray 0 string`, `NestedArray 1 string`, etc.

## Array Iteration Helpers

`PArray` has no built-in `fold` or `map`. Define helpers using `nat` fuel from `Uint63.to_nat`:

```coq
Fixpoint array_fold_left_nat {A B} (f : B -> int -> A -> B)
  (a : array A) (fuel : nat) (acc : B) (i : int) : B :=
  match fuel with
  | 0 => acc
  | S fuel' =>
    if (i <? PArray.length a)%uint63
    then array_fold_left_nat f a fuel' (f acc i a.[i]) (i + 1)
    else acc
  end.

Definition array_fold_left {A B} (f : B -> int -> A -> B)
  (init : B) (a : array A) : B :=
  array_fold_left_nat f a (Uint63.to_nat (PArray.length a)) init 0.

Definition array_init {A} (len : int) (default : A) (f : int -> A) : array A :=
  array_fold_left
    (fun acc i _ => PArray.set acc i (f i))
    (PArray.make len default)
    (PArray.make len default).
```

An early-termination variant for `compare`:

```coq
Fixpoint array_fold_left_early_nat {A B} (f : B -> int -> A -> option B)
  (a : array A) (fuel : nat) (acc : B) (i : int) : B :=
  match fuel with
  | 0 => acc
  | S fuel' =>
    if (i <? PArray.length a)%uint63
    then match f acc i a.[i] with
         | Some acc' => array_fold_left_early_nat f a fuel' acc' (i + 1)
         | None => acc
         end
    else acc
  end.
```

Returns `acc` immediately when `f` returns `None` (early termination).

Under `vm_compute`/`native_compute`, sequential `PArray.set` calls are optimized to in-place mutation. Under kernel `compute`, large arrays will be slow — expected and acceptable.

## Operations

### get

Auto-discovers block sizes by inspecting `PArray.length` of the first element at each nesting level, with `PArray.max_length` as fallback for empty arrays:

```coq
Polymorphic Fixpoint get {n : nat} {A : Type}
  (a : NestedArray (S n) A) (i : int) {struct n} : A :=
  match n return NestedArray (S n) A -> A with
  | 0 => fun a => a.[i]
  | S n' => fun a =>
    let sz := PArray.length a.[0] in
    let sz := if (sz =? 0)%uint63 then PArray.max_length else sz in
    get a.[i / sz] (i mod sz)
  end a.
```

Out-of-bounds access inherits `PArray`'s behavior (returns default element).

### length

O(depth) formula exploiting uniform inner sizes (all blocks except the last are the same size):

```coq
Polymorphic Fixpoint length {n : nat} {A : Type}
  (a : NestedArray (S n) A) {struct n} : int :=
  match n return NestedArray (S n) A -> int with
  | 0 => fun a => PArray.length a
  | S n' => fun a =>
    let m := PArray.length a in
    if (m =? 0)%uint63 then 0
    else (m - 1) * length a.[0] + length a.[m - 1]
  end a.
```

For depth-3 arrays at max capacity (~7.4 x 10^19 elements), `int63` multiplication overflows. In practice, such arrays would be exabytes and don't occur.

### leaf_default

Extracts the leaf-level default `A` by recursing into array defaults:

```coq
Polymorphic Fixpoint leaf_default {n : nat} {A : Type}
  (a : NestedArray (S n) A) {struct n} : A :=
  match n return NestedArray (S n) A -> A with
  | 0 => fun a => PArray.default a
  | S n' => fun a => leaf_default (PArray.default a)
  end a.
```

### rechunk (shared builder)

Constructs a `NestedArray (S n) A` from a flat element accessor function:

```coq
Polymorphic Fixpoint rechunk {n : nat} {A : Type}
  (get_elem : int -> A) (total_len : int)
  (max_len : int) (inner_flat_cap : int) (default : A)
  {struct n} : NestedArray (S n) A :=
  match n return NestedArray (S n) A with
  | 0 => array_init total_len default get_elem
  | S n' =>
    let n_blocks := (total_len + inner_flat_cap - 1) / inner_flat_cap in
    let default_inner := rechunk (fun _ => default) 0 max_len
                                  (inner_flat_cap / max_len) default in
    array_init n_blocks default_inner (fun j =>
      let o := j * inner_flat_cap in
      let l := if (total_len - o <? inner_flat_cap)%uint63
               then total_len - o else inner_flat_cap in
      rechunk (fun i => get_elem (o + i)) l max_len
              (inner_flat_cap / max_len) default)
  end.
```

- `max_len`: PArray size at each level (typically `PArray.max_length`)
- `inner_flat_cap`: flat capacity of each inner block (`max_len^n`), divided by `max_len` at each recursive step

### sub

```coq
Definition sub {n A} (a : NestedArray (S n) A) (offset len : int)
  : NestedArray (S n) A :=
  let max_len := PArray.length a.[0] in
  let max_len := if (max_len =? 0)%uint63 then PArray.max_length else max_len in
  rechunk (fun i => get a (offset + i)) len max_len
          (max_len ^ n) (leaf_default a).
```

Same depth as input, uniform inner sizes (as if flatten + re-chunk).

### cat

```coq
Definition cat {n A} (a b : NestedArray (S n) A) : NestedArray (S n) A :=
  let la := length a in
  let max_len := PArray.length a.[0] in
  let max_len := if (max_len =? 0)%uint63 then PArray.max_length else max_len in
  rechunk (fun i => if (i <? la)%uint63 then get a i else get b (i - la))
          (la + length b) max_len (max_len ^ n) (leaf_default a).
```

Same depth as inputs, uniform inner sizes.

### compare

Recursive on depth for efficiency — avoids recomputing div/mod per element:

```coq
Definition array_compare {A} (cmp : A -> A -> comparison)
  (a b : array A) : comparison :=
  let la := PArray.length a in
  let lb := PArray.length b in
  let min_len := if (la <? lb)%uint63 then la else lb in
  let c := array_fold_left_early
             (fun i => cmp a.[i] b.[i]) min_len Eq in
  match c with Eq => Uint63.compare la lb | _ => c end.

Polymorphic Fixpoint compare {n : nat} {A : Type}
  (cmp : A -> A -> comparison)
  (a b : NestedArray (S n) A) {struct n} : comparison :=
  match n return NestedArray (S n) A -> NestedArray (S n) A -> comparison with
  | 0 => fun a b => array_compare cmp a b
  | S n' => fun a b => array_compare (compare cmp) a b
  end a b.
```

Takes an element comparison function `A -> A -> comparison`. At depth 0, compares element-wise then by length. At depth S n, compares outer arrays using recursive `compare` on inner arrays.

## File Organization

**`theories/NestedArray.v`** — self-contained, no dependency on `ReadFile.v`:
- Imports `PArray`, `Uint63`, `Byte`, etc. directly
- Defines `NestedArray` type
- Defines all operations: `get`, `length`, `sub`, `cat`, `compare`
- Defines iteration helpers: `array_fold_left`, `array_init`, `array_fold_left_early`
- Defines `rechunk`, `leaf_default`

**`theories/ReadFile.v`** — imports (not exports) `NestedArray`:
```coq
From ReadFile Require Import NestedArray.
(* ...existing exports... *)

Register NestedArray as readfile.nested_array.type.
Register PArray.array as readfile.array.type.

Declare ML Module "rocq-read-file.plugin".
```

Users import `NestedArray` separately if they want the operations.

## OCaml Plugin Changes

In `src/read_file.ml`:

1. **Look up `NestedArray`** via `Rocqlib.lib_ref "readfile.nested_array.type"`.

2. **Emit `NestedArray n A` types** instead of bare `array` chains. The plugin computes nesting depth `n` (already known from the auto-nester) and builds:
   ```ocaml
   mkApp (nested_array_const, [| nat_of_int depth; element_type |])
   ```
   where `nat_of_int` builds `O`, `S O`, `S (S O)`, etc.

3. **Term bodies unchanged.** The actual primitive array values are the same. Only the declared type annotation changes. Since `NestedArray n A` is transparent, the kernel accepts the same term at the new type.

4. **All three commands affected:** `ReadFileBytes`, `ReadFileInt63`, `ReadFileString`. For `ReadFileString` with no nesting, the type becomes `NestedArray 0 string`.

## Existing Code

- `get1`, `get2`, `get3` are removed (superseded by `get`)
- The old `NestedArray` module wrapper is replaced by the new definitions
