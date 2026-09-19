#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
    printf 'performance lifecycle guard failed: %s\n' "$1" >&2
    exit 1
}

require() {
    local file="$1" needle="$2" message="$3"
    grep -Fq -- "$needle" "$file" || fail "$message"
}

reject() {
    local file="$1" needle="$2" message="$3"
    if grep -Fq -- "$needle" "$file"; then
        fail "$message"
    fi
}

config="$repo_root/modules/common/Config.qml"
defaults="$repo_root/defaults/config.json"
cava="$repo_root/services/deferred/CavaService.qml"
cava_generator="$repo_root/scripts/cava/generate_config.sh"
advanced="$repo_root/modules/settings/AdvancedConfig.qml"
waffle_themes="$repo_root/modules/waffle/settings/pages/WThemesPage.qml"
media_section="$repo_root/modules/controlPanel/MediaSection.qml"
sidebar_media="$repo_root/modules/sidebarLeft/widgets/MediaPlayerWidget.qml"
it_thumbnail="$repo_root/modules/sidebarLeft/innertune/ITThumbnail.qml"
screen_edges="$repo_root/modules/screenCorners/ScreenEdges.qml"
alt_switcher="$repo_root/modules/altSwitcher/AltSwitcher.qml"
waffle_alt="$repo_root/modules/waffle/altSwitcher/WaffleAltSwitcher.qml"
waffle_alt_content="$repo_root/modules/waffle/altSwitcher/WaffleAltSwitcherContent.qml"
workspace_thumb="$repo_root/modules/waffle/taskview/WorkspaceThumbnail.qml"
window_thumb="$repo_root/modules/waffle/taskview/WindowThumbnail.qml"
easyeffects="$repo_root/services/deferred/EasyEffects.qml"
tlp="$repo_root/services/TlpService.qml"
thinkfan="$repo_root/services/ThinkFanService.qml"
tlp_caps="$repo_root/services/TlpRuntimeCapabilities.qml"
tlp_settings="$repo_root/services/TlpSettingsService.qml"
power_profiles="$repo_root/services/PowerProfilePersistence.qml"

require "$config" 'property int framerate: 30' 'Cava schema default must remain 30 fps'
require "$defaults" '"framerate": 30' 'persisted Cava default must remain 30 fps'
require "$cava" 'Config.options?.appearance?.cava?.framerate ?? 30' 'Cava runtime fallback must remain 30 fps'
require "$cava" '? Math.min(24, root.requestedFramerate)' 'Low Power must cap Cava at 24 fps'
require "$cava_generator" 'FRAMERATE="${2:-30}"' 'Cava generator fallback must remain 30 fps'
require "$advanced" '"appearance.cava.framerate": 30' 'ii Cava reset must remain 30 fps'
require "$waffle_themes" '"appearance.cava.framerate": 30' 'Waffle Cava reset must remain 30 fps'
require "$media_section" 'root.effectiveIsPlaying && GlobalStates.controlPanelOpen' 'Control Panel Cava must stop while playback is paused'
require "$sidebar_media" 'root.effectiveIsPlaying && GlobalStates.sidebarLeftOpen' 'Sidebar Cava must stop while playback is paused'

require "$it_thumbnail" 'ClippingRectangle {' 'InnerTune thumbnails must use scene-graph clipping'
reject "$it_thumbnail" 'GE.OpacityMask' 'InnerTune list thumbnails must not allocate an OpacityMask layer'
require "$it_thumbnail" 'GlobalStates.sidebarLeftOpen' 'InnerTune decorative equalizer must stop with the sidebar'

require "$screen_edges" 'readonly property bool physicalShadowActive:' 'Screen Edge must compute physical shadow activity explicitly'
require "$screen_edges" 'layer.enabled: frameShape.physicalShadowActive' 'Screen Edge full-screen layer must sleep when physical shadow is off'
require "$screen_edges" 'fillRule: ShapePath.OddEvenFill' 'Screen Edge geometry lock must remain one odd-even frame'

require "$alt_switcher" 'cacheBuffer: root.skewExpandedWidth' 'ii skew AltSwitcher cache must stay bounded'
reject "$alt_switcher" 'cacheBuffer: root.skewExpandedWidth * 2' 'ii skew AltSwitcher must not restore the doubled preview cache'
require "$alt_switcher" 'layer.samples: Appearance.effectsEnabled ? 4 : 1' 'ii skew mask sampling must scale down with effects'
require "$waffle_alt" 'id: focusRetryTimer' 'Waffle AltSwitcher focus must use bounded retries'
reject "$waffle_alt" 'repeat: true\n        onTriggered: {\n            if (GlobalStates.waffleAltSwitcherOpen)\n                keyHandler.forceActiveFocus()' 'Waffle AltSwitcher must not restore 33 Hz focus polling'
require "$waffle_alt_content" 'cacheBuffer: root.skewExpandedWidth' 'Waffle skew AltSwitcher cache must stay bounded'
require "$waffle_alt_content" 'layer.samples: Looks.effectsEnabled ? 4 : 1' 'Waffle skew mask sampling must scale down with effects'

require "$workspace_thumb" 'readonly property bool wallpaperPresented:' 'TaskView must gate hidden workspace wallpaper presentation'
require "$workspace_thumb" 'sourceSize.width: Math.max(1, Math.ceil(root.thumbnailWidth * 1.5))' 'TaskView workspace wallpapers must use bounded decode size'
require "$window_thumb" 'GlobalStates.waffleTaskViewOpen && shimmerBg.visible' 'TaskView shimmer must stop when TaskView closes'
require "$window_thumb" 'mipmap: false' 'TaskView window previews must avoid unnecessary mipmap generation'
require "$window_thumb" 'sourceSize.width: Math.max(1, Math.ceil(root.thumbnailWidth * 1.5))' 'TaskView window previews must use bounded decode size'

require "$easyeffects" 'readonly property bool uiDemand:' 'EasyEffects must expose demand-aware state polling'
require "$easyeffects" 'interval: root.uiDemand ? 5000 : 30000' 'EasyEffects must use slow background verification'
require "$easyeffects" 'running: Config.ready && root.available && (root.uiDemand || root.active)' 'EasyEffects polling must sleep when inactive and hidden'

require "$tlp" 'interval: 120000' 'battery/TLP status polling must not run every 30 seconds'
require "$thinkfan" 'interval: 30000' 'ThinkFan background polling must remain reduced'
require "$tlp_caps" 'interval: 300000' 'TLP runtime capability probes must remain low cadence'
require "$tlp_settings" 'interval: 300000' 'TLP settings background refresh must remain low cadence'
require "$power_profiles" 'interval: 300000' 'tlp-pd ownership probes must remain low cadence'

printf 'performance lifecycle guards: ok\n'
