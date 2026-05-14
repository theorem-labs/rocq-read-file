#!/usr/bin/env bash
#
# Generate the test-data files used by the perf and correctness tests.
# Run this once before `dune build`. Re-running overwrites the files.
#
# Sizes are chosen to exercise specific code paths:
#
#   bytes path   (PArray.max_length = 4194302):
#     fits in 1 array : 1k, 64k, 1m
#     forces 2-level  : 4m, 16m, 64m
#
#   int63 path (one int63 per 8 bytes, same array bound):
#     fits in 1 array : 1k .. 16m  (16m / 8 = 2M elems)
#     forces 2-level  : 64m         (64m / 8 = 8M elems)
#
#   string path (Pstring.max_length ~ 16777211):
#     fits in 1 string : 1k .. 1m, 4m
#     forces 2-level   : 16m, 64m

set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIR="${SELF_DIR}/data"
mkdir -p "${DIR}"

echo "Generating test data in ${DIR}"

# ---- helpers ----

gen_random () {
  local out="$1" size="$2"
  printf '  %-22s %10d bytes\n' "$(basename "${out}")" "${size}"
  head -c "${size}" /dev/urandom > "${out}"
}

gen_text () {
  # Filter /dev/urandom down to ASCII letters, digits, spaces and
  # newlines. LC_ALL=C avoids locale-dependent character classes.
  local out="$1" size="$2"
  printf '  %-22s %10d bytes (ASCII)\n' "$(basename "${out}")" "${size}"
  # Run in a subshell with pipefail disabled: when head has read enough
  # bytes it closes its stdin, tr receives SIGPIPE and exits non-zero,
  # which is expected and must not fail the script.
  ( set +o pipefail
    LC_ALL=C tr -dc 'A-Za-z0-9 \n' < /dev/urandom \
      | head -c "${size}" > "${out}"
  )
}

# ---- correctness fixture: bytes [0x48,0x65,0x6C,0x6C,0x6F,0x21] ----

printf 'Hello!' > "${DIR}/small.bin"
printf '  %-22s %10d bytes (fixed)\n' small.bin 6

# ---- random binary ----

gen_random "${DIR}/rand_1k.bin"          1024
gen_random "${DIR}/rand_64k.bin"        65536
gen_random "${DIR}/rand_1m.bin"       1048576
gen_random "${DIR}/rand_4m.bin"       4194304     # > PArray.max_length
gen_random "${DIR}/rand_16m.bin"     16777216     # > Pstring.max_length too
gen_random "${DIR}/rand_64m.bin"     67108864     # forces nesting in int63 path

# ---- random ASCII text ----

gen_text   "${DIR}/text_1m.txt"       1048576
gen_text   "${DIR}/text_16m.txt"     16777216

echo "Done."
