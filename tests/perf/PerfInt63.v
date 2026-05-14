(** Int63-mode performance.  One int63 is produced per 8 bytes of
    input, so the result has [size/8] elements.

    Auto-nesting kicks in once the element count exceeds
    [PArray.max_length] = 4_194_302, i.e. for input slices larger
    than ~32 MB.  The 64 MB file below is the only one in this list
    that triggers it.
*)

From ReadFile Require Import ReadFile.
From ReadFile_Perf Require dep_hashes.

From ReadFile_Perf Extra Dependency "rand_1k.bin" as rand_1k.
From ReadFile_Perf Extra Dependency "rand_64k.bin" as rand_64k.
From ReadFile_Perf Extra Dependency "rand_1m.bin" as rand_1m.
From ReadFile_Perf Extra Dependency "rand_4m.bin" as rand_4m.
From ReadFile_Perf Extra Dependency "rand_16m.bin" as rand_16m.
From ReadFile_Perf Extra Dependency "rand_64m.bin" as rand_64m.

(* depth 1 *)
Time ReadFileInt63 LittleEndian "rand_1k.bin"   As i_le_1k.
Time ReadFileInt63 LittleEndian "rand_64k.bin"  As i_le_64k.
Time ReadFileInt63 LittleEndian "rand_1m.bin"   As i_le_1m.
Time ReadFileInt63 LittleEndian "rand_4m.bin"   As i_le_4m.
Time ReadFileInt63 LittleEndian "rand_16m.bin"  As i_le_16m.

(* depth 2 — 64M / 8 = 8M elements > PArray.max_length *)
Time ReadFileInt63 LittleEndian "rand_64m.bin"  As i_le_64m.

(* big-endian path *)
Time ReadFileInt63 BigEndian    "rand_4m.bin"   As i_be_4m.
Time ReadFileInt63 BigEndian    "rand_64m.bin"  As i_be_64m.

(* slice + non-multiple-of-8 length exercises the zero-padding path *)
Time ReadFileInt63 LittleEndian "rand_1m.bin"   As i_le_pad Length 5.
