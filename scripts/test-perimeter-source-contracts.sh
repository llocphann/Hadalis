#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
critical="$root/modules/ii/critical/ShellIiCriticalPanels.qml"
deferred="$root/ShellIiPanels.qml"
media="$root/modules/bar/Media.qml"
weather="$root/modules/bar/weather/WeatherBar.qml"

fail() {
    printf 'FAIL: perimeter source retirement contract: %s\n' "$1" >&2
    exit 1
}

for file in "$critical" "$deferred" "$media" "$weather"; do
    [[ -f "$file" ]] || fail "missing ${file#$root/}"
done

# No active QML outside the legacy broad/common perimeter implementation may
# revive the full cutover runtime or its registry bootstrap.
unexpected="$(git -C "$root" grep -n -E \
    'import[[:space:]]+qs\.modules\.perimeter|PerimeterRuntime|PerimeterFeatureRegistry' \
    -- '*.qml' \
    ':(exclude)modules/perimeter/**' \
    ':(exclude)modules/common/perimeter/**' || true)"
if [[ -n "$unexpected" ]]; then
    printf '%s\n' "$unexpected" >&2
    fail 'tracked QML outside the legacy perimeter implementation still references broad cutover runtime symbols'
fi

for target in \
    '../../screenCorners/ScreenEdges.qml' \
    '../../sidebar/SidebarEdgeConnectors.qml' \
    '../../background/Background.qml' \
    '../../bar/Bar.qml' \
    '../../verticalBar/VerticalBar.qml' \
    '../../dock/Dock.qml'; do
    grep -Fq "source: Qt.resolvedUrl(\"$target\")" "$critical" \
        || fail "critical ii shell must source-load supported target $target"
done

grep -Fq 'StyledPopup {' "$media" \
    || fail 'normal Media UX must stay on StyledPopup'
grep -Fq 'GlobalStates.openSidebarRight' "$weather" \
    || fail 'normal Weather click route must stay on right-sidebar Weather UX'

printf 'PASS: broad perimeter runtime has no tracked external QML caller in the supported shell paths\n'
