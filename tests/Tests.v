(** Correctness tests against the [small.bin] fixture, which contains
    exactly the 6 ASCII bytes of "Hello!" — i.e.
    [0x48; 0x65; 0x6C; 0x6C; 0x6F; 0x21]. *)

From ReadFile Require Import ReadFile.

From ReadFile_Tests Extra Dependency "small.bin" as small.

Open Scope uint63_scope.

(* ------------------------------------------------------------------ *)
(* ReadFileBytes — default Byte.byte type, whole file                 *)
(* ------------------------------------------------------------------ *)

ReadFileBytes small As fb_full.
Check fb_full : array Byte.byte.

Goal PArray.length fb_full = 6.
Proof. reflexivity. Qed.

Goal fb_full.[0] = Byte.x48.   (* 'H' *) Proof. reflexivity. Qed.
Goal fb_full.[1] = Byte.x65.   (* 'e' *) Proof. reflexivity. Qed.
Goal fb_full.[5] = Byte.x21.   (* '!' *) Proof. reflexivity. Qed.

(* ------------------------------------------------------------------ *)
(* Slicing                                                            *)
(* ------------------------------------------------------------------ *)

ReadFileBytes small As fb_head Length 3.
Goal PArray.length fb_head = 3. Proof. reflexivity. Qed.
Goal fb_head.[0] = Byte.x48. Proof. reflexivity. Qed.
Goal fb_head.[2] = Byte.x6c. Proof. reflexivity. Qed.

ReadFileBytes small As fb_tail Offset 4.
Goal PArray.length fb_tail = 2. Proof. reflexivity. Qed.
Goal fb_tail.[0] = Byte.x6f. Proof. reflexivity. Qed.
Goal fb_tail.[1] = Byte.x21. Proof. reflexivity. Qed.

ReadFileBytes small As fb_mid Offset 1 Length 3.
Goal PArray.length fb_mid = 3. Proof. reflexivity. Qed.
Goal fb_mid.[0] = Byte.x65. Proof. reflexivity. Qed.
Goal fb_mid.[2] = Byte.x6c. Proof. reflexivity. Qed.

(* Empty slice is allowed. *)
ReadFileBytes small As fb_empty Offset 6 Length 0.
Goal PArray.length fb_empty = 0. Proof. reflexivity. Qed.

(* ------------------------------------------------------------------ *)
(* Custom byte type via the [: T] form (here just Byte.byte again).   *)
(* ------------------------------------------------------------------ *)

ReadFileBytes small As fb_typed : Byte.byte.
Goal PArray.length fb_typed = 6. Proof. reflexivity. Qed.

(* ------------------------------------------------------------------ *)
(* ReadFileInt63 — 6 input bytes are zero-padded to 8.                *)
(* ------------------------------------------------------------------ *)

(* Little-endian: the file bytes are the *low* 6 bytes of the word.
     0x216F6C6C6548 = 36_762_444_129_608 *)
ReadFileInt63 LittleEndian small As fi_le.
Goal PArray.length fi_le = 1. Proof. reflexivity. Qed.
Goal fi_le.[0] = 36762444129608. Proof. reflexivity. Qed.

(* Big-endian: file bytes are the *high* 6 bytes; padded zeros end up
   in the low 2 bytes.  0x48656C6C6F210000 = 5_216_694_956_355_289_088.
   That value's high bit (bit 63) is 0, so it survives Uint63
   truncation untouched. *)
ReadFileInt63 BigEndian small As fi_be.
Goal PArray.length fi_be = 1. Proof. reflexivity. Qed.
Goal fi_be.[0] = 5216694956355289088. Proof. reflexivity. Qed.

(* ------------------------------------------------------------------ *)
(* ReadFileString                                                     *)
(* ------------------------------------------------------------------ *)

ReadFileString small As fs_full.
Check fs_full : string.

Goal PrimString.length fs_full = 6. Proof. reflexivity. Qed.
Goal PrimString.get fs_full 0 = 72. Proof. reflexivity. Qed.   (* 'H' *)
Goal PrimString.get fs_full 5 = 33. Proof. reflexivity. Qed.   (* '!' *)

ReadFileString small As fs_mid Offset 1 Length 4.
Goal PrimString.length fs_mid = 4. Proof. reflexivity. Qed.
Goal PrimString.get fs_mid 0 = 101. Proof. reflexivity. Qed.   (* 'e' *)
