(** Sketches of every command and option.

    This file is for documentation: it does not actually run because
    "demo.bin" doesn't exist. Copy it next to a real file and adjust
    paths to try things out interactively.
*)

From ReadFile Require Import ReadFile.
From ReadFile Require Import NestedArray.

(* ------------------------------------------------------------------ *)
(* 1. Bytes, default Byte.byte type, whole file.                      *)
(* ------------------------------------------------------------------ *)

(*
ReadFileBytes "demo.bin" As demo_bytes.
Check demo_bytes : array Byte.byte.
*)

(* ------------------------------------------------------------------ *)
(* 2. Bytes with a custom 256-constructor inductive.                  *)
(* ------------------------------------------------------------------ *)

(*
ReadFileBytes "demo.bin" As demo_bytes_typed : Byte.byte.
*)

(* ------------------------------------------------------------------ *)
(* 3. Int63, both endiannesses. Zero-padded if the slice length is    *)
(*    not a multiple of 8.                                            *)
(* ------------------------------------------------------------------ *)

(*
ReadFileInt63 LittleEndian "demo.bin" As demo_le.
ReadFileInt63 BigEndian    "demo.bin" As demo_be.
Check demo_le : array int.
*)

(* ------------------------------------------------------------------ *)
(* 4. Primitive string. Auto-nests if file > Pstring.max_length.      *)
(* ------------------------------------------------------------------ *)

(*
ReadFileString "demo.bin" As demo_str.
Check demo_str : string.
*)

(* ------------------------------------------------------------------ *)
(* 5. Slice variants: any combination of Offset and Length.           *)
(* ------------------------------------------------------------------ *)

(*
ReadFileBytes  "demo.bin" As demo_head Length 16.
ReadFileBytes  "demo.bin" As demo_tail Offset 1024.
ReadFileBytes  "demo.bin" As demo_mid  Offset 100 Length 200.

ReadFileString "demo.bin" As demo_str_slice Offset 0 Length 4096.

ReadFileInt63 LittleEndian "demo.bin" As demo_int_slice
                                          Offset 0 Length 64.
*)

(* ------------------------------------------------------------------ *)
(* 6. Indexing into a result that may have been auto-nested.          *)
(*                                                                    *)
(* For a small file (<= PArray.max_length bytes) the result is        *)
(* [array byte], and you index with the usual [a.[i]].                *)
(*                                                                    *)
(* For a larger file the result is [array (array byte)] (or deeper).  *)
(* In that case use NestedArray.get2 / get3 with                      *)
(* PArray.max_length as the inner-block size.                         *)
(*                                                                    *)
(*   Definition byte_at (a : array (array Byte.byte)) (i : int) :=    *)
(*     NestedArray.get2 PArray.max_length a i.                        *)
(* ------------------------------------------------------------------ *)
