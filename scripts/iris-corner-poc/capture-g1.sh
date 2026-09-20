#!/usr/bin/env bash
set -euo pipefail

here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$here/../.." && pwd)"
mode="${HADALIS_IRIS_POC_MODE:-card-owner}"

if [[ "$mode" != "card-owner" ]]; then
    printf 'G1 acceptance must use HADALIS_IRIS_POC_MODE=card-owner (got %s).\n' "$mode" >&2
    exit 2
fi

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
out_dir="${HADALIS_IRIS_POC_CAPTURE_DIR:-$here/captures/g1-$stamp}"
mkdir -p "$out_dir"

printf 'G1 preflight: iRiS corner PoC source contract\n'
python3 "$repo_root/scripts/test-iris-corner-poc-contract.py"

repo_head="$(git -C "$repo_root" rev-parse HEAD 2>/dev/null || printf 'unknown')"
cat > "$out_dir/g1-run.txt" <<EOF
started_at_utc=$stamp
repo_head=$repo_head
requested_output=${HADALIS_IRIS_POC_OUTPUT:-}
mode=card-owner
profiles=diagnostic,upstream-relative
EOF

for profile in diagnostic upstream-relative; do
    printf '\nG1 capture profile: %s\n' "$profile"
    HADALIS_IRIS_POC_CAPTURE_DIR="$out_dir" \
    HADALIS_IRIS_POC_MODE=card-owner \
    HADALIS_IRIS_POC_PROFILE="$profile" \
        "$here/capture-matrix.sh"
done

printf '\nG1 evidence directory: %s\n' "$out_dir"
printf 'Review:\n'
printf '  %s\n' "$out_dir/detail-sheet-card-owner-diagnostic.png"
printf '  %s\n' "$out_dir/detail-sheet-card-owner-upstream-relative.png"
printf '  %s\n' "$out_dir/manifest-card-owner-diagnostic.tsv"
printf '  %s\n' "$out_dir/manifest-card-owner-upstream-relative.tsv"
printf '  %s\n' "$out_dir/session-card-owner-diagnostic.json"
printf '  %s\n' "$out_dir/session-card-owner-upstream-relative.json"
