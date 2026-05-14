#!/usr/bin/env bash

set -e

cd "$(git rev-parse --show-toplevel)"

version="${1:-$(git tag --sort=-v:refname | head -1)}"

if [ -z "$version" ]; then
    echo "Error: No version provided and no git tags found" >&2
    exit 1
fi

version_num="${version#v}"
version_tag="v${version_num}"

opam_file="rocq-read-file.opam"

if [ ! -f "$opam_file" ]; then
    echo "Error: $opam_file not found" >&2
    exit 1
fi

echo "Preparing $opam_file for release ${version_tag}..."

tarball_url="https://github.com/theorem-labs/rocq-read-file/archive/refs/tags/${version_tag}.tar.gz"
echo "Downloading ${tarball_url}..."

tmpfile=$(mktemp)
trap "rm -f '$tmpfile'" EXIT

if ! wget -q "$tarball_url" -O "$tmpfile"; then
    echo "Error: Failed to download tarball from $tarball_url" >&2
    exit 1
fi

if command -v sha512sum >/dev/null 2>&1; then
    sha512=$(sha512sum "$tmpfile" | cut -d' ' -f1)
elif command -v shasum >/dev/null 2>&1; then
    sha512=$(shasum -a 512 "$tmpfile" | cut -d' ' -f1)
else
    echo "Error: Neither sha512sum nor shasum found" >&2
    exit 1
fi

echo "SHA512: $sha512"

sed -i.bak '/^version:/d' "$opam_file"

awk '
/^url \{/ { in_url=1; next }
in_url && /^\}/ { in_url=0; next }
!in_url { print }
' "$opam_file" > "${opam_file}.tmp"

cat >> "${opam_file}.tmp" << EOF
url {
  src: "${tarball_url}"
  checksum: "sha512=${sha512}"
}
EOF

mv "${opam_file}.tmp" "$opam_file"
rm -f "${opam_file}.bak"

echo "Done. Updated $opam_file:"
echo "---"
cat "$opam_file"
