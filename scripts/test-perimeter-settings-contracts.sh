#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
settings="$root/modules/settings/ShellLayoutConfig.qml"

fail() {
    printf 'FAIL: perimeter settings contract: %s\n' "$1" >&2
    exit 1
}

[[ -f "$settings" ]] || fail 'missing modules/settings/ShellLayoutConfig.qml'

grep -Fq 'readonly property bool perimeterRequested: PerimeterCutoverPolicy.requested' "$settings" \
    || fail 'settings request state bypasses cutover policy'
grep -Fq 'readonly property bool perimeterActive: PerimeterCutoverPolicy.enabled' "$settings" \
    || fail 'settings runtime state bypasses cutover policy'
grep -Fq 'readonly property bool perimeterFallbackActive: PerimeterCutoverPolicy.fallbackActive' "$settings" \
    || fail 'settings fallback state bypasses cutover policy'
grep -Fq 'readonly property string perimeterStatusReason: PerimeterCutoverPolicy.statusReason' "$settings" \
    || fail 'settings does not expose cutover status reason'

grep -Fq 'checked: root.perimeterRequested' "$settings" \
    || fail 'perimeter switch reflects runtime activity instead of request intent'
grep -Fq 'onCheckedChanged: root.setPerimeterRequested(checked)' "$settings" \
    || fail 'perimeter switch no longer mutates request intent'
grep -Fq 'visible: root.perimeterRequested' "$settings" \
    || fail 'perimeter placement editor disappears during fallback'
grep -Fq 'root.perimeterRuntimeStatus()' "$settings" \
    || fail 'settings does not render active/fallback runtime status'
grep -Fq '"fallback · " + root.perimeterStatusReason' "$settings" \
    || fail 'fallback status omits the policy reason'

if grep -Fq 'readonly property bool perimeterEnabled:' "$settings"; then
    fail 'settings reintroduced ambiguous perimeterEnabled request state'
fi

printf 'PASS: perimeter settings contracts\n'
