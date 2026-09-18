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

if [[ -e "$root/modules/perimeter" ]]; then
    fail 'retired broad perimeter implementation must be absent from the active source tree'
fi

# No tracked QML may revive the old module import or its retired common
# host/config/cutover/route compatibility objects.
unexpected="$(git -C "$root" grep -n -E \
    'import[[:space:]]+qs\.modules\.perimeter|PerimeterRuntime|PerimeterFeatureRegistry|PerimeterPresentationPolicy|PerimeterReservationPolicy|PerimeterConfig|PerimeterCutoverPolicy|PerimeterRuntimeHealth|AnchorRegistry|SurfaceRouteController|PerimeterContext|PerimeterSlotModel|PerimeterModuleHost|PerimeterSlotHost|PerimeterOutputHost|AnchorPublisher|ConnectedSurfaceRouteState' \
    -- '*.qml' || true)"
if [[ -n "$unexpected" ]]; then
    printf '%s\n' "$unexpected" >&2
    fail 'tracked QML still references retired perimeter runtime/common compatibility symbols'
fi

for target in \
    '../../screenCorners/ScreenEdges.qml' \
    '../../background/Background.qml' \
    '../../bar/Bar.qml' \
    '../../verticalBar/VerticalBar.qml' \
    '../../dock/Dock.qml'; do
    grep -Fq "source: Qt.resolvedUrl(\"$target\")" "$critical" \
        || fail "critical ii shell must source-load supported target $target"
done

if grep -Fq 'SidebarEdgeConnectors.qml' "$critical"; then
    fail 'critical shell must not load the retired standalone sidebar bridge window'
fi
grep -Fq 'ConnectedSurfaceConnector {' "$root/modules/sidebar/SidebarHost.qml" \
    || fail 'SidebarHost must own the active sidebar edge connector'

grep -Fq 'StyledPopup {' "$media" \
    || fail 'normal Media UX must stay on StyledPopup'
grep -Fq 'GlobalStates.openSidebarRight' "$weather" \
    || fail 'normal Weather click route must stay on right-sidebar Weather UX'

printf 'PASS: broad perimeter runtime/common compatibility is absent; supported shell routes remain authoritative\n'
