#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
shell="$root/shell.qml"
critical="$root/modules/ii/critical/ShellIiCriticalPanels.qml"
waffle="$root/modules/waffle/critical/ShellWaffleCriticalPanels.qml"

fail() {
    printf 'FAIL: panel family contract: %s\n' "$1" >&2
    exit 1
}

for file in "$shell" "$critical" "$waffle"; do
    [[ -f "$file" ]] || fail "missing ${file#$root/}"
done

for token in \
    'source: "modules/ii/critical/ShellIiCriticalPanels.qml"' \
    'source: "ShellIiPanels.qml"' \
    'source: "modules/waffle/critical/ShellWaffleCriticalPanels.qml"' \
    'source: "ShellWafflePanels.qml"' \
    'property list<string> families: ["ii", "waffle"]'; do
    grep -Fq "$token" "$shell" || fail "shell family routing missing: $token"
done

if grep -Fq 'iiPerimeter' "$shell" || grep -Fq 'PerimeterRuntime' "$shell"; then
    fail 'retired perimeter runtime must not become a third shell panel family'
fi

for token in \
    '../../screenCorners/ScreenEdges.qml' \
    '../../sidebar/SidebarEdgeConnectors.qml' \
    '../../bar/Bar.qml' \
    '../../verticalBar/VerticalBar.qml' \
    '../../dock/Dock.qml'; do
    grep -Fq "$token" "$critical" || fail "ii critical family lost supported surface: $token"
done

printf 'PASS: ii and Waffle remain the supported panel families without perimeter cutover family\n'
