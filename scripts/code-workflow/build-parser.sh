#!/usr/bin/env bash
# Developer-only grammar build. Nothing is installed into the shell/runtime.
set -euo pipefail
build_dir="${1:?Usage: bash build-parser.sh BUILD_DIR [DOWNLOADED_CRATE]}"
mkdir -p "$build_dir"
build_dir="$(realpath "$build_dir")"
archive="${2:-$build_dir/tree-sitter-qmljs-0.3.1.crate}"
expected='e6ed3a7040df54fed1183801ad482139622bf9b9ec1c5f7ee36c5ece25806c58'
if [[ ! -f "$archive" ]]; then
    curl --fail --location --retry 2 \
        https://static.crates.io/crates/tree-sitter-qmljs/tree-sitter-qmljs-0.3.1.crate \
        -o "$archive"
fi
actual="$(sha256sum "$archive" | cut -d' ' -f1)"
[[ "$actual" == "$expected" ]] || { printf 'Grammar archive checksum mismatch\n' >&2; exit 1; }
tar -xzf "$archive" -C "$build_dir"
grammar_dir="$build_dir/tree-sitter-qmljs-0.3.1"
"${CC:-cc}" -std=c11 -O2 -fPIC -shared -I "$grammar_dir/src" \
    "$grammar_dir/src/parser.c" "$grammar_dir/src/scanner.c" -o "$build_dir/qmljs.so"
printf 'Built %s/qmljs.so (qmljs 0.3.1; upstream de96ed62abded51fcdfcbeaaa120e0dd0d20c697)\n' "$build_dir"
