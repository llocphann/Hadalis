#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

fail() {
    printf 'not ok - %s\n' "$1" >&2
    exit 1
}

tool="translations/tools/apply-reviewed-replacements.py"

shopt -s nullglob
manifests=(translations/l10n/*-repairs.json)

# Runtime localization is currently English-only. The reviewed-replacement
# helper was intentionally retired with the non-English catalogs, so an empty
# manifest set is a valid release state rather than a missing-tool failure.
if (( ${#manifests[@]} == 0 )); then
    grep -Fq '"$script_dir/test-reviewed-replacement-manifests.sh"' scripts/release.sh \
        || fail 'release helper no longer checks reviewed replacement manifest state'
    printf '%s\n' '1..1'
    printf '%s\n' 'ok 1 - no reviewed replacement manifests are tracked'
    exit 0
fi

[[ -f "$tool" ]] || fail "missing reviewed replacement helper: $tool"

for manifest in "${manifests[@]}"; do
    python3 "$tool" "$manifest" --status \
        || fail "reviewed replacement manifest is partial, drifted, or invalid: $manifest"
done

grep -Fq '"$script_dir/test-reviewed-replacement-manifests.sh"' scripts/release.sh \
    || fail 'release helper no longer requires reviewed replacement manifest integrity'

printf '%s\n' '1..1'
printf 'ok 1 - %d reviewed replacement manifest(s) are provenance-consistent\n' "${#manifests[@]}"
