#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
validator="$repo_root/scripts/validate-maintainer-local.sh"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT

fail() {
    printf 'FAIL: maintainer validator log contract: %s\n' "$1" >&2
    exit 1
}

[[ -f "$validator" ]] || fail 'canonical validator is missing'
mkdir -p "$tmp/caller" "$tmp/workspace"

# Execute the real validator initialization prefix, stopping before clone/log I/O.
# Fail closed if that boundary changes so this test can never recurse into the
# full validator accidentally.
grep -Fq 'cleanup() {' "$validator" \
    || fail 'validator initialization boundary changed; refusing prefix execution'
prefix="$tmp/validator-prefix.sh"
sed '/^cleanup()/,$d' "$validator" > "$prefix"
cat >> "$prefix" <<'SH'
printf '%s\n' "$log_path"
SH

relative='logs/maintainer validation.log'
resolved_relative="$(
    cd "$tmp/caller"
    TMPDIR="$tmp/workspace" HADALIS_VALIDATION_LOG="$relative" bash "$prefix"
)"
expected_relative="$tmp/caller/$relative"
[[ "$resolved_relative" == "$expected_relative" ]] \
    || fail "relative log path resolved to '$resolved_relative', expected '$expected_relative'"
[[ "$resolved_relative" == /* ]] \
    || fail 'relative custom log path did not become absolute before checkout cwd changes'

absolute="$tmp/absolute validation.log"
resolved_absolute="$(
    cd "$tmp/caller"
    TMPDIR="$tmp/workspace" HADALIS_VALIDATION_LOG="$absolute" bash "$prefix"
)"
[[ "$resolved_absolute" == "$absolute" ]] \
    || fail 'absolute custom log path was unexpectedly rewritten'

printf 'PASS: maintainer validator keeps one canonical log path across cwd changes\n'
