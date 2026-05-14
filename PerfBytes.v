(** Bytes-mode performance.  Each [Time] line prints user/system/wall
    timing for the read + term-construction + kernel checking.

    Sizes that exceed [PArray.max_length] (= 4_194_302) trigger
    auto-nesting: the result type changes from [array byte] to
    [array (array byte)].
*)

From ReadFile Require Import ReadFile.

(* depth 1 — single primitive array *)
Time ReadFileBytes "rand_1k.bin"   As b_1k.
Time ReadFileBytes "rand_64k.bin"  As b_64k.
Time ReadFileBytes "rand_1m.bin"   As b_1m.

(* depth 2 — array of arrays of bytes *)
Time ReadFileBytes "rand_4m.bin"   As b_4m.
Time ReadFileBytes "rand_16m.bin"  As b_16m.
Time ReadFileBytes "rand_64m.bin"  As b_64m.

(* slicing scales with the slice size, not the file size *)
Time ReadFileBytes "rand_64m.bin"  As b_64m_head Length 1024.
Time ReadFileBytes "rand_64m.bin"  As b_64m_mid  Offset 1000000 Length 1000000.
