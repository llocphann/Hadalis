#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
    printf 'FAIL: Bar connected-popup coverage: %s\n' "$1" >&2
    exit 1
}

# Interactive popups/menus owned by a Bar must not create compositor popup
# windows directly. Presentation belongs to StyledPopup (ii) or BarPopup
# (Waffle), which in turn own connected geometry, output routing and masking.
detached_popup_hits="$(
    git -C "$root" grep -n -E '^[[:space:]]*PopupWindow[[:space:]]*\{' --         'modules/bar/*.qml'         'modules/bar/**/*.qml'         'modules/verticalBar/*.qml'         'modules/verticalBar/**/*.qml'         'modules/waffle/bar/*.qml'         'modules/waffle/bar/**/*.qml'         2>/dev/null || true
)"
if [[ -n "$detached_popup_hits" ]]; then
    printf '%s\n' "$detached_popup_hits" >&2
    fail 'a Bar-owned runtime surface recreated a detached PopupWindow'
fi

# ii Bar callers must not bypass BarContextMenu with the generic detached
# ContextMenu. The definition of BarContextMenu itself is allowed.
generic_context_hits="$(
    git -C "$root" grep -n -E '^[[:space:]]*ContextMenu[[:space:]]*\{' --         'modules/bar/*.qml'         'modules/bar/**/*.qml'         'modules/verticalBar/*.qml'         'modules/verticalBar/**/*.qml'         2>/dev/null || true
)"
if [[ -n "$generic_context_hits" ]]; then
    printf '%s\n' "$generic_context_hits" >&2
    fail 'ii Bar/Vertical Bar caller bypasses connected BarContextMenu'
fi

require_token() {
    local file="$1" token="$2" message="$3"
    grep -Fq -- "$token" "$root/$file" || fail "$message"
}

# Horizontal ii Bar coverage.
require_token 'modules/bar/SysTrayMenu.qml' 'StyledPopup {'     'System Tray menu must remain on StyledPopup'
require_token 'modules/bar/BarTaskbarButton.qml' 'BarContextMenu {'     'Bar taskbar right-click menu must remain connected'
require_token 'modules/bar/BarContent.qml' 'BarContextMenu {'     'Bar background context menu must remain connected'
require_token 'modules/bar/Media.qml' 'StyledPopup {'     'horizontal Media popup must remain connected'
require_token 'modules/bar/BatteryPopup.qml' 'StyledPopup {'     'Battery popup must remain connected'
require_token 'modules/bar/ResourcesPopup.qml' 'StyledPopup {'     'Resources popup must remain connected'
require_token 'modules/bar/ClockCalendarPopup.qml' 'StyledPopup {'     'Clock calendar popup must remain connected'
require_token 'modules/bar/weather/WeatherPopup.qml' 'StyledPopup {'     'Weather popup must remain connected'
require_token 'modules/bar/TimerIndicatorTooltip.qml' 'StyledPopup {'     'Timer interactive popout must remain connected'
require_token 'modules/bar/BarTaskbarPreview.qml' 'StyledPopup {'     'taskbar/workspace window preview must remain connected'

# Vertical ii Bar coverage.
require_token 'modules/verticalBar/VerticalBarContent.qml' 'Bar.BarContextMenu {'     'Vertical Bar background menu must remain connected'
require_token 'modules/verticalBar/VerticalBarContent.qml' 'Bar.ClockCalendarPopup {'     'Vertical Clock calendar popup must remain connected'
require_token 'modules/verticalBar/VerticalMedia.qml' 'Bar.StyledPopup {'     'Vertical Media popouts must remain connected'

# Waffle remains a separate panel family/API, but its BarPopup must consume
# shared ConnectedSurface primitives and all Waffle Bar menus/previews must use
# that entrypoint.
for token in     'ConnectedSurfaceGeometry {'     'ConnectedSurfaceFrame {'     'ConnectedSurfaceContentHost {'     'ConnectedSurfaceMask {'; do
    require_token 'modules/waffle/bar/BarPopup.qml' "$token"         "Waffle BarPopup lost shared connected-surface primitive: $token"
done
for file in     'modules/waffle/bar/BarMenu.qml'     'modules/waffle/bar/tray/WaffleTrayMenu.qml'     'modules/waffle/bar/tray/TrayOverflowMenu.qml'     'modules/waffle/bar/tasks/TaskPreview.qml'; do
    require_token "$file" 'BarPopup {'         "$file must remain on connected Waffle BarPopup"
done

printf 'PASS: supported Bar-owned menus/popouts stay on connected presentation paths\n'
