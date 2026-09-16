#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
stage="$(mktemp -d)"
trap 'rm -rf -- "$stage"' EXIT

export REPO_ROOT="$repo_root"
export XDG_CONFIG_HOME="$stage/config"
export XDG_STATE_HOME="$stage/state"

# robust-update.sh is a sourced library; provide the logging hooks used by the
# cleanup helper so this regression can exercise it without the setup TUI.
log_info() { :; }
log_warning() { :; }
log_error() { :; }
log_success() { :; }
log_header() { :; }

# shellcheck source=/dev/null
source "$repo_root/sdata/lib/robust-update.sh"

fail() {
    printf 'not ok - %s\n' "$1" >&2
    exit 1
}

runtime="$stage/runtime"
manifest="$runtime/.inir-manifest"
mkdir -p "$runtime/modules/pill" "$runtime/scripts"

# Build the expected installed manifest from the same canonical payload policy
# used by setup, then add files representing an older mixed runtime tree.
generate_manifest "$repo_root" "$manifest" \
    || fail 'could not generate runtime manifest fixture'
printf '%s\n' 'import QtQuick' > "$runtime/RetiredRoot.qml"
printf '%s\n' 'import QtQuick' > "$runtime/modules/pill/Stale.qml"
printf '%s\n' '# private excluded artifact' > "$runtime/scripts/test-local-private.sh"

cleanup_orphans "$runtime" "$manifest" \
    || fail 'runtime orphan cleanup helper failed'

for stale_path in \
    "$runtime/RetiredRoot.qml" \
    "$runtime/modules/pill/Stale.qml"; do
    if [[ -e "$stale_path" || -L "$stale_path" ]]; then
        fail "runtime orphan cleanup preserved stale managed path: ${stale_path#$runtime/}"
    fi
done

[[ -f "$runtime/scripts/test-local-private.sh" ]] \
    || fail 'runtime orphan cleanup deleted an excluded private/test artifact'
[[ ! -d "$runtime/modules/pill" ]] \
    || fail 'runtime orphan cleanup left the retired empty module directory'

grep -Fq 'generate_manifest "$II_SOURCE" "${II_TARGET}/.inir-manifest"' "$repo_root/setup" \
    || fail 'setup update no longer generates the canonical installed manifest'
grep -Fq 'cleanup_orphans "$II_TARGET" "${II_TARGET}/.inir-manifest"' "$repo_root/setup" \
    || fail 'setup update no longer invokes runtime orphan cleanup'

printf '%s\n' '1..1'
printf '%s\n' 'ok 1 - repo-copy update cleanup removes retired runtime QML without deleting excluded artifacts'
