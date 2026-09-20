#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
common="$root/modules/common/perimeter"
widgets="$root/modules/common/widgets"
sidebar="$root/modules/sidebar/SidebarHost.qml"
dashboard="$root/modules/overview/OverviewDashboard.qml"
search="$root/modules/overview/SearchWidget.qml"
osk="$root/modules/onScreenKeyboard/OnScreenKeyboard.qml"
screen_corners="$root/modules/screenCorners/ScreenCorners.qml"
waffle="$root/modules/waffle/bar/BarPopup.qml"

fail() {
    printf 'FAIL: perimeter source retirement contract: %s\n' "$1" >&2
    exit 1
}

bash "$root/scripts/test-perimeter-contracts.sh" >/dev/null

# Whole-runtime-QML sweep: old round-wedge/corner implementations must be gone,
# not merely disconnected from the most visible callers.
unexpected="$(git -C "$root" grep -n -E \
    'ConnectedSurfaceJoinFlares|PerimeterCornerShadow|RoundCorner[[:space:]]*\{|RoundCorner\.CornerEnum|fakeScreenRounding|joinFlareRadius|joinFlareCrossScale' \
    -- '*.qml' || true)"
if [[ -n "$unexpected" ]]; then
    printf '%s\n' "$unexpected" >&2
    fail 'tracked runtime QML still references retired round-wedge/corner geometry'
fi

[[ ! -e "$common/ConnectedSurfaceJoinFlares.qml" ]] || fail 'ConnectedSurfaceJoinFlares.qml still exists'
[[ ! -e "$common/PerimeterCornerShadow.qml" ]] || fail 'PerimeterCornerShadow.qml still exists'
[[ ! -e "$widgets/RoundCorner.qml" ]] || fail 'RoundCorner.qml still exists'
! grep -Fq 'ConnectedSurfaceJoinFlares 1.0' "$common/qmldir" || fail 'JoinFlares export remains'
! grep -Fq 'PerimeterCornerShadow 1.0' "$common/qmldir" || fail 'PerimeterCornerShadow export remains'
! grep -Fq 'RoundCorner 1.0' "$widgets/qmldir" || fail 'RoundCorner export remains'
! grep -Fq '"fakeScreenRounding"' "$root/defaults/config.json" || fail 'fakeScreenRounding default remains'
! grep -Fq 'property int fakeScreenRounding' "$root/modules/common/Config.qml" || fail 'fakeScreenRounding schema remains'

for token in \
    'ConnectedSurfaceIrisEdgeSurface {' \
    'id: sidebarIrisSurface' \
    'readonly property real hiddenTranslateDistance:' \
    'PerimeterTokens.irisFuseDepth' \
    '? -root.hiddenTranslateDistance' \
    ': root.hiddenTranslateDistance'; do
    grep -Fq -- "$token" "$sidebar" || fail "Sidebar iRiS/full-hide contract missing: $token"
done

for token in \
    'ConnectedSurfaceIrisEdgeSurface {' \
    'id: dashboardIrisSurface' \
    'ownerThickness: root.attachmentThickness'; do
    grep -Fq "$token" "$dashboard" || fail "Dashboard iRiS edge contract missing: $token"
done

for file in "$search" "$osk" "$common/ConnectedSurfaceFrame.qml"; do
    ! grep -Fq 'ConnectedSurfaceJoinFlares' "$file" || fail "${file#$root/} restored JoinFlares"
    ! grep -Fq 'joinFlareRadius' "$file" || fail "${file#$root/} restored joinFlareRadius"
done

for token in RoundCorner fakeScreenRounding showFakeRounding roundingSize; do
    ! grep -Fq "$token" "$screen_corners" || fail "ScreenCorners restored visual corner geometry: $token"
done
grep -Fq 'GlobalStates.toggleSidebarLeft' "$screen_corners" || fail 'ScreenCorners lost sidebar interaction'
grep -Fq 'GlobalStates.openOrbit(' "$screen_corners" || fail 'ScreenCorners lost Orbit interaction'

grep -Fq 'ConnectedSurfaceFrame {' "$waffle" || fail 'Waffle lost shared non-iRiS frame'
grep -Fq 'connectorVisible: false' "$waffle" || fail 'Waffle connector painter must stay disabled'

printf 'PASS: runtime QML is free of retired round-wedge geometry; current iRiS/direct-seam routes are authoritative\n'
