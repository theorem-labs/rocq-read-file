(** String-mode performance.  A single primitive string holds up to
    [Pstring.max_length] (~16_777_211) bytes.  Beyond that the
    plugin emits an [array string] (or deeper).
*)

From ReadFile Require Import ReadFile.
From ReadFile_Tests Require dep_hashes.

From ReadFile_Tests Extra Dependency "rand_1k.bin" as rand_1k.
From ReadFile_Tests Extra Dependency "rand_64k.bin" as rand_64k.
From ReadFile_Tests Extra Dependency "rand_1m.bin" as rand_1m.
From ReadFile_Tests Extra Dependency "rand_4m.bin" as rand_4m.
From ReadFile_Tests Extra Dependency "rand_16m.bin" as rand_16m.
From ReadFile_Tests Extra Dependency "rand_64m.bin" as rand_64m.
From ReadFile_Tests Extra Dependency "text_1m.txt" as text_1m.
From ReadFile_Tests Extra Dependency "text_16m.txt" as text_16m.

(* depth 1 — single primitive string *)
Time ReadFileString "rand_1k.bin"   As s_1k.
Time ReadFileString "rand_64k.bin"  As s_64k.
Time ReadFileString "rand_1m.bin"   As s_1m.
Time ReadFileString "rand_4m.bin"   As s_4m.

(* depth 2 — array of primitive strings *)
Time ReadFileString "rand_16m.bin"  As s_16m.
Time ReadFileString "rand_64m.bin"  As s_64m.

(* ASCII text *)
Time ReadFileString "text_1m.txt"   As s_text_1m.
Time ReadFileString "text_16m.txt"  As s_text_16m.

(* slice *)
Time ReadFileString "rand_64m.bin"  As s_64m_head Length 4096.
