(** Vernacular commands for reading binary files into Rocq.

    Three commands are provided. All accept an optional
    [Offset N] and/or [Length N] suffix; both default to "whole file".

      ReadFileBytes  "file" As name [: T] [Offset N] [Length N].
        - Default leaf type: [Byte.byte].
        - [T] may be any parameterless inductive in Set with exactly
          256 nullary constructors. Byte value [b] is mapped to its
          [(b+1)]-th constructor.

      ReadFileInt63  LittleEndian "file" As name [Offset N] [Length N].
      ReadFileInt63  BigEndian    "file" As name [Offset N] [Length N].
        - Each 8-byte chunk becomes one int63. The slice is right-
          padded with zero bytes if its length is not a multiple of 8.
        - The 64th bit is silently dropped.

      ReadFileString "file" As name [Offset N] [Length N].
        - Result is a primitive [string] when the slice fits in
          [Pstring.max_length]; otherwise an array of strings (or an
          array of arrays of strings, etc).

    All commands auto-nest in primitive arrays when the result would
    exceed [PArray.max_length] elements at any level. The per-chunk
    maximum can be lowered with:

      Set ReadFile MaxArrayLength N.   (** 1 <= N <= 4194302 *)
      Unset ReadFile MaxArrayLength.   (** restore the default *)
*)

From Stdlib.Init Require Export Byte.
From Stdlib Require Export PArray.
From Stdlib Require Export Uint63.
From Stdlib Require Export PrimString.

From ReadFile Require Import NestedArray.

Register NestedArray as readfile.nested_array.type.
Register PArray.array as readfile.array.type.

Declare ML Module "rocq-read-file.plugin".
