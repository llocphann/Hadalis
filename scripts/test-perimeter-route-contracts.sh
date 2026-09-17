#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
styled="$root/modules/bar/StyledPopup.qml"
media="$root/modules/bar/Media.qml"
weather_bar="$root/modules/bar/weather/WeatherBar.qml"
weather_popup="$root/modules/bar/weather/WeatherPopup.qml"
sidebar="$root/modules/sidebar/SidebarEdgeConnectors.qml"

fail() {
    printf 'FAIL: supported connected route contract: %s\n' "$1" >&2
    exit 1
}

for file in "$styled" "$media" "$weather_bar" "$weather_popup" "$sidebar"; do
    [[ -f "$file" ]] || fail "missing ${file#$root/}"
done

for token in \
    'property bool requestedVisible' \
    'property bool _lingerVisible' \
    'property real revealProgress' \
    'retractTimer' \
    'progress: root.revealProgress'; do
    grep -Fq "$token" "$styled" || fail "StyledPopup route lifecycle missing: $token"
done

grep -Fq 'StyledPopup {' "$media" \
    || fail 'Media expanded presentation must use StyledPopup'
grep -Fq 'keyboardFocus: true' "$media" \
    || fail 'Media expanded presentation must preserve focused connected-popup routing'
grep -Fq 'StyledPopup {' "$weather_popup" \
    || fail 'Weather hover presentation must use StyledPopup'
grep -Fq 'GlobalStates.sidebarRightRequestedWidget = "weather"' "$weather_bar" \
    || fail 'Weather primary activation must target the right-sidebar Weather tab'
grep -Fq 'GlobalStates.openSidebarRight' "$weather_bar" \
    || fail 'Weather primary activation must use the supported right-sidebar route'
grep -Fq 'ConnectedSurfaceConnector' "$sidebar" \
    || fail 'left/right sidebars must retain semantic connected edge routes'

for file in "$media" "$weather_bar" "$weather_popup" "$sidebar"; do
    if grep -Fq 'SurfaceRouteController' "$file" || grep -Fq 'qs.modules.perimeter' "$file"; then
        fail "normal UX route must not depend on retired broad perimeter routing: ${file#$root/}"
    fi
done

printf 'PASS: Media/Weather/sidebar routes use supported connected presentation paths\n'
