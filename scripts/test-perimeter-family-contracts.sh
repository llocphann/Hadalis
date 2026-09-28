#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
shell="$root/shell.qml"
critical="$root/modules/ii/critical/ShellIiCriticalPanels.qml"
abyss="$root/modules/abyss/critical/ShellAbyssCriticalPanels.qml"
waffle="$root/modules/waffle/critical/ShellWaffleCriticalPanels.qml"
backdrop="$root/modules/background/Backdrop.qml"
niri_layers="$root/defaults/niri/config.d/80-layer-rules.kdl"

fail() {
    printf 'FAIL: panel family contract: %s\n' "$1" >&2
    exit 1
}

for file in "$shell" "$critical" "$abyss" "$waffle" "$backdrop" "$niri_layers"; do
    [[ -f "$file" ]] || fail "missing ${file#$root/}"
done

for token in \
    'source: "modules/ii/critical/ShellIiCriticalPanels.qml"' \
    'source: "ShellIiPanels.qml"' \
    'source: "modules/waffle/critical/ShellWaffleCriticalPanels.qml"' \
    'source: "ShellWafflePanels.qml"' \
    'property list<string> families: ["abyss", "waffle"]'; do
    grep -Fq "$token" "$shell" || fail "shell family routing missing: $token"
done

if grep -Fq 'iiPerimeter' "$shell" || grep -Fq 'PerimeterRuntime' "$shell"; then
    fail 'retired perimeter runtime must not become a shell panel family'
fi

for token in \
    '../../screenCorners/ScreenEdges.qml' \
    '../../background/Background.qml' \
    '../../bar/Bar.qml' \
    '../../verticalBar/VerticalBar.qml' \
    '../../dock/Dock.qml'; do
    grep -Fq "$token" "$critical" || fail "ii critical family lost supported surface: $token"
done

for token in \
    '../../background/Background.qml' \
    '../../background/Backdrop.qml' \
    'Config.options?.background?.backdrop?.enable ?? false'; do
    grep -Fq "$token" "$abyss" || fail "Abyss background lost stable overview wallpaper path: $token"
done

for token in \
    'WlrLayershell.namespace: "quickshell:iiBackdrop"' \
    'WlrLayershell.layer: WlrLayer.Background' \
    'WlrLayershell.exclusionMode: ExclusionMode.Ignore'; do
    grep -Fq "$token" "$backdrop" || fail "shared backdrop surface contract missing: $token"
done

for token in \
    'match namespace="quickshell:iiBackdrop"' \
    'place-within-backdrop true'; do
    grep -Fq "$token" "$niri_layers" || fail "Niri overview backdrop rule missing: $token"
done

if grep -Fq 'SidebarEdgeConnectors.qml' "$critical"; then
    fail 'critical ii family must not revive the retired standalone Sidebar bridge window'
fi

printf 'PASS: Material aliases to Abyss; Abyss keeps the stable Niri overview wallpaper backdrop; Waffle stays isolated\n'
