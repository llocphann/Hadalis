#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

fail() {
    printf 'not ok - %s\n' "$1" >&2
    exit 1
}

tool="translations/tools/apply-reviewed-replacements.py"
[[ ! -e "$tool" ]] || fail "retired reviewed replacement helper returned: $tool"

shopt -s nullglob
manifests=(translations/l10n/*-repairs.json)
[[ ${#manifests[@]} -eq 0 ]] \
    || fail "retired reviewed replacement manifests returned under translations/l10n"

python3 translations/tools/l10n.py audit-all >/dev/null \
    || fail 'English-only translation catalog audit failed'
python3 translations/tools/source-parity.py >/dev/null \
    || fail 'English source catalog parity audit failed'

grep -Fq '"$script_dir/test-reviewed-replacement-manifests.sh"' scripts/release.sh \
    || fail 'release helper no longer requires translation catalog integrity'

printf '%s\n' '1..1'
printf '%s\n' 'ok 1 - retired replacement manifests stay absent and English catalog is canonical'
