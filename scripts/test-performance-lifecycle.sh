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
world_clock="$repo_root/services/WorldClock.qml"
game_mode="$repo_root/services/GameMode.qml"
overview_window="$repo_root/modules/overview/OverviewWindow.qml"
resource_usage="$repo_root/services/ResourceUsage.qml"
bar_resources="$repo_root/modules/bar/Resources.qml"
vertical_bar_resources="$repo_root/modules/verticalBar/Resources.qml"
recorder_status="$repo_root/services/RecorderStatus.qml"
control_panel_media="$repo_root/modules/controlPanel/MediaSection.qml"
date_time_header="$repo_root/modules/controlPanel/DateTimeHeader.qml"
lock_surface="$repo_root/modules/lock/LockSurface.qml"
waffle_lock="$repo_root/modules/waffle/lock/WaffleLockSurface.qml"
waffle_lock_safe="$repo_root/modules/waffle/lock/WaffleLockSurfaceSafe.qml"
weather="$repo_root/services/Weather.qml"
keyboard_indicators="$repo_root/services/KeyboardIndicators.qml"
sidebar_anime="$repo_root/modules/sidebarLeft/Anime.qml"
sidebar_wallhaven="$repo_root/modules/sidebarLeft/WallhavenView.qml"
sidebar_ai="$repo_root/modules/sidebarLeft/AiChat.qml"
sidebar_quick_wallpaper="$repo_root/modules/sidebarLeft/widgets/QuickWallpaper.qml"
booru_image="$repo_root/modules/sidebarLeft/anime/BooruImage.qml"
booru_response="$repo_root/modules/sidebarLeft/anime/BooruResponse.qml"
ai_think_block="$repo_root/modules/sidebarLeft/aiChat/MessageThinkBlock.qml"
sidebar_right_tasks="$repo_root/modules/sidebarRight/todo/TaskList.qml"
sidebar_right_notifications="$repo_root/modules/sidebarRight/notifications/NotificationList.qml"
sidebar_right_media="$repo_root/modules/sidebarRight/CompactMediaPlayer.qml"
control_panel_wallpaper="$repo_root/modules/controlPanel/WallpaperSection.qml"
dash_media="$repo_root/modules/dashboard/DashMedia.qml"
dash_welcome="$repo_root/modules/dashboard/DashWelcome.qml"
dashboard="$repo_root/modules/dashboard/Dashboard.qml"
ii_panels="$repo_root/modules/ii/ShellIiPanelsImpl.qml"
dashboard_settings="$repo_root/modules/settings/DashboardConfig.qml"
screen_time="$repo_root/services/ScreenTime.qml"
ytmusic="$repo_root/services/YtMusic.qml"
directory_icon="$repo_root/modules/common/widgets/DirectoryIcon.qml"
sysmon_widget="$repo_root/modules/sidebarRight/sysmon/SysMonWidget.qml"
timer_service="$repo_root/services/TimerService.qml"
levendist="$repo_root/modules/common/functions/levendist.js"
loading_indicator="$repo_root/modules/common/widgets/MaterialLoadingIndicator.qml"
circular_progress="$repo_root/modules/common/widgets/CircularProgress.qml"
clipped_filled_progress="$repo_root/modules/common/widgets/ClippedFilledCircularProgress.qml"
clipped_outline_progress="$repo_root/modules/common/widgets/ClippedOutlineCircularProgress.qml"
wavy_line="$repo_root/modules/common/widgets/WavyLine.qml"
cava_wavy_line="$repo_root/modules/common/widgets/CavaWavyLine.qml"
cava_spectrum="$repo_root/modules/common/widgets/CavaSpectrum.qml"
shell_update_indicator="$repo_root/modules/bar/ShellUpdateIndicator.qml"
util_buttons="$repo_root/modules/bar/UtilButtons.qml"
waffle_system_button="$repo_root/modules/waffle/bar/SystemButton.qml"
waffle_timer_button="$repo_root/modules/waffle/bar/TimerButton.qml"

require "$config" 'property int framerate: 30' 'Cava schema default must remain 30 fps'
require "$defaults" '"framerate": 30' 'persisted Cava default must remain 30 fps'
require "$cava" 'Config.options?.appearance?.cava?.framerate ?? 30' 'Cava runtime fallback must remain 30 fps'
require "$date_time_header" 'DateTime.clock.date' 'Control Panel date must use the shared SystemClock'
reject "$date_time_header" 'onTriggered: root._tick++' 'Control Panel must not restore a duplicate minute timer'
for lock_date_surface in "$lock_surface" "$waffle_lock" "$waffle_lock_safe"; do
    require "$lock_date_surface" 'Qt.formatDate(DateTime.clock.date,' 'Lock dates must use the shared SystemClock'
    reject "$lock_date_surface" 'onTriggered: dateText.text = Qt.formatDate(' 'Lock date labels must not restore private minute timers'
done
require "$cava_spectrum" 'function _curveHeadroom(top, bottom): real' 'CavaSpectrum must keep scalar edge geometry'
reject "$cava_spectrum" 'function _surfaceBounds(' 'CavaSpectrum must not allocate surface arrays per sample'
reject "$cava_spectrum" 'function _peakBounds(' 'CavaSpectrum must not allocate surface/peak arrays per sample'
reject "$cava_spectrum" 'function _applyFrequencyProfile(' 'CavaSpectrum selection/profile must stay fused'
reject "$cava_spectrum" 'primary.push([' 'CavaSpectrum wave coordinates must stay flat'
require "$cava_spectrum" 'const baseline = !ribbonMode && !lineMode ? [] : null' 'CavaSpectrum line mode must not build an unused baseline'
reject "$cava_spectrum" 'function _barLevels(' 'CavaSpectrum must calculate levels inside paint loops'
reject "$cava_spectrum" 'function _waveLevels(' 'CavaSpectrum must not allocate a transient level array'
require "$cava" '? Math.min(24, root.requestedFramerate)' 'Low Power must cap Cava at 24 fps'
require "$cava_generator" 'FRAMERATE="${2:-30}"' 'Cava generator fallback must remain 30 fps'
require "$advanced" '"appearance.cava.framerate": 30' 'ii Cava reset must remain 30 fps'
require "$waffle_themes" '"appearance.cava.framerate": 30' 'Waffle Cava reset must remain 30 fps'
require "$media_section" 'root.effectiveIsPlaying && GlobalStates.controlPanelOpen' 'Control Panel Cava must stop while playback is paused'
require "$sidebar_media" 'root.effectiveIsPlaying && GlobalStates.sidebarLeftOpen' 'Sidebar Cava must stop while playback is paused'
require "$sidebar_media" 'layer.enabled: root.visible && GlobalStates.sidebarLeftOpen' 'Sidebar media mask must release its FBO while the sidebar is closed'
require "$sidebar_media" 'sourceSize.width: Math.max(1, Math.ceil(card.width * root._dpr))' 'Sidebar blurred artwork decode must remain bounded to the displayed card'
require "$control_panel_media" 'layer.enabled: root.visible && GlobalStates.controlPanelOpen' 'Control Panel media masks must release their FBOs while closed'
require "$control_panel_media" 'readonly property bool positionTickerActive:' 'Control Panel must expose the position-ticker lifecycle'
require "$control_panel_media" 'running: root.positionTickerActive' 'Control Panel MPRIS position timer must sleep while closed'
require "$control_panel_media" 'triggeredOnStart: true' 'Control Panel position must refresh immediately when reopened'
require "$control_panel_media" 'sourceSize.width: Math.max(1, Math.ceil(card.width * root._dpr))' 'Control Panel blurred artwork decode must remain bounded'
require "$control_panel_media" 'mipmap: false' 'Control Panel artwork must not generate unused mipmaps'

require "$it_thumbnail" 'ClippingRectangle {' 'InnerTune thumbnails must use scene-graph clipping'
reject "$it_thumbnail" 'GE.OpacityMask' 'InnerTune list thumbnails must not allocate an OpacityMask layer'
require "$it_thumbnail" 'GlobalStates.sidebarLeftOpen' 'InnerTune decorative equalizer must stop with the sidebar'

require "$screen_edges" 'readonly property bool physicalShadowActive:' 'Screen Edge must compute physical shadow activity explicitly'
require "$screen_edges" 'layer.enabled: frameShape.physicalShadowActive' 'Screen Edge full-screen layer must sleep when physical shadow is off'
require "$screen_edges" 'fillRule: ShapePath.OddEvenFill' 'Screen Edge geometry lock must remain one odd-even frame'

require "$alt_switcher" 'cacheBuffer: root.skewExpandedWidth' 'ii skew AltSwitcher cache must stay bounded'
reject "$alt_switcher" 'cacheBuffer: root.skewExpandedWidth * 2' 'ii skew AltSwitcher must not restore the doubled preview cache'
require "$alt_switcher" 'layer.samples: Appearance.effectsEnabled ? 4 : 1' 'ii skew mask sampling must scale down with effects'
require "$alt_switcher" 'layer.enabled: root.skewCardVisible' 'ii skew mask FBO must sleep while the switcher is closed'
require "$waffle_alt" 'id: focusRetryTimer' 'Waffle AltSwitcher focus must use bounded retries'
reject "$waffle_alt" 'id: focusTimer' 'Waffle AltSwitcher must not restore 33 Hz focus polling'
require "$waffle_alt_content" 'cacheBuffer: root.skewExpandedWidth' 'Waffle skew AltSwitcher cache must stay bounded'
require "$waffle_alt_content" 'layer.samples: Looks.effectsEnabled ? 4 : 1' 'Waffle skew mask sampling must scale down with effects'
require "$waffle_alt_content" 'layer.enabled: root.cardVisible' 'Waffle skew mask FBO must sleep while the switcher is closed'

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
require "$thinkfan" 'running: root.profileFanControlEnabled || root.active || root.busy' 'ThinkFan polling must sleep while fan control is irrelevant'
require "$tlp_caps" 'interval: 300000' 'TLP runtime capability probes must remain low cadence'
require "$tlp_settings" 'interval: 300000' 'TLP settings background refresh must remain low cadence'
require "$power_profiles" 'interval: 300000' 'tlp-pd ownership probes must remain low cadence'

require "$world_clock" 'id: minuteTick' 'WorldClock must tick at minute precision without a permanent 1 Hz timer'
reject "$world_clock" 'interval: 1000' 'WorldClock must not restore a 1 Hz background timer'
require "$world_clock" 'for tz; do TZ=\"$tz\" date +%z' 'WorldClock offset refresh must batch configured zones into one process'
reject "$world_clock" 'environment: ({ TZ:' 'WorldClock must not restore one date process per timezone'
require "$game_mode" 'Math.max(10000, Math.round(configured))' 'GameMode fallback polling must remain low cadence'
require "$overview_window" 'layer.enabled: GlobalStates.overviewOpen' 'retained Overview window masks must sleep while Overview is closed'
require "$resource_usage" '? Math.max(6000, root._configuredUpdateIntervalMs)' 'Low Power must slow resource sampling to at least 6 seconds'
require "$resource_usage" 'interval: root._effectiveUpdateIntervalMs' 'resource sensor timer must use the effective power-aware cadence'
require "$resource_usage" 'readonly property int _expensiveGpuUpdateIntervalMs:' 'process-backed GPU sampling must use a slower independent cadence'
require "$resource_usage" '? Math.max(15000, root._effectiveUpdateIntervalMs)' 'Low Power must throttle nvidia-smi/intel_gpu_top sampling to at least 15 seconds'
require "$bar_resources" 'ResourceUsageMonitor {' 'horizontal Bar resources must use centralized telemetry lifecycle ownership'
require "$bar_resources" 'active: !GameMode.active' 'horizontal Bar resource polling must pause in GameMode'
require "$vertical_bar_resources" 'ResourceUsageMonitor {' 'vertical Bar resources must use centralized telemetry lifecycle ownership'
require "$vertical_bar_resources" 'active: !GameMode.active' 'vertical Bar resource polling must pause in GameMode'
require "$recorder_status" '(Config.options?.performance?.lowPower ?? false) ? 30000 : 15000' 'idle recorder detection must not spawn pgrep every five seconds'
require "$recorder_status" 'interval: root.idlePollIntervalMs' 'RecorderStatus idle polling must use its power-aware cadence'
require "$weather" 'running: root.enabled' 'Weather minute clock must sleep when weather is disabled'
require "$keyboard_indicators" 'interval: (Config.options?.performance?.lowPower ?? false) ? 120000 : 30000' 'keyboard sysfs hotplug discovery must stay low cadence'
require "$sidebar_anime" 'layer.enabled: root.visible && GlobalStates.sidebarLeftOpen' 'Anime list mask must sleep with the sidebar'
require "$sidebar_wallhaven" 'layer.enabled: root.visible && GlobalStates.sidebarLeftOpen' 'Wallhaven list mask must sleep with the sidebar'
require "$sidebar_ai" 'layer.enabled: root.visible && GlobalStates.sidebarLeftOpen' 'AI history mask must sleep with the sidebar'
require "$sidebar_quick_wallpaper" 'layer.enabled: root.visible && GlobalStates.sidebarLeftOpen' 'Quick Wallpaper masks must sleep with the sidebar'
require "$booru_image" 'layer.enabled: root.visible && GlobalStates.sidebarLeftOpen' 'Booru image masks must sleep with the sidebar'
require "$booru_response" 'layer.enabled: root.visible && GlobalStates.sidebarLeftOpen' 'Booru tag masks must sleep with the sidebar'
require "$ai_think_block" 'layer.enabled: root.visible && GlobalStates.sidebarLeftOpen' 'AI think-block masks must sleep with the sidebar'
require "$sidebar_right_tasks" '(GlobalStates.sidebarRightOpen || GlobalStates.dashboardOpen || GlobalStates.overviewOpen)' 'To-do list mask must remain active in right-sidebar, dashboard, and Overview hosts'
reject "$sidebar_right_notifications" 'layer.effect: OpacityMask' 'rectangular notification clipping must not allocate an OpacityMask FBO'
require "$sidebar_right_media" 'GlobalStates.sidebarRightOpen && root.visible && !root.zzzStyle' 'right-sidebar media mask must sleep while closed'
require "$sidebar_right_media" 'GlobalStates.sidebarRightOpen && root.visible && Appearance.effectsEnabled && visible' 'right-sidebar media blur must sleep while closed'
reject "$sidebar_right_media" 'CavaProcess {' 'right-sidebar media must not run duplicate Cava above the shared EQ'
reject "$sidebar_right_media" 'WaveVisualizer {' 'right-sidebar media must not render duplicate Cava above the shared EQ'
require "$control_panel_wallpaper" 'layer.enabled: root.visible && GlobalStates.controlPanelOpen' 'Control Panel wallpaper mask must sleep while closed'
require "$control_panel_wallpaper" 'mipmap: false' 'Control Panel wallpaper preview must not generate unused mipmaps'
require "$dash_media" 'property bool presentationActive:' 'Dashboard media lifecycle must remain writable for DashboardCanvas and Overview hosts'
reject "$dash_media" 'readonly property bool presentationActive:' 'Dashboard media lifecycle must not become readonly while DashboardCanvas binds it'
reject "$dash_media" 'CavaProcess {' 'Dashboard media must not run duplicate Cava above the shared EQ'
require "$dash_media" 'visualizerPoints: []' 'Dashboard PlayerControl must not consume decorative Cava points'
require "$dash_media" 'showVisualizer: false' 'Dashboard PlayerControl decorative visualizer must remain disabled'
require "$dash_media" 'active: root.hasPlayer' 'Dashboard shared PlayerControl must stay resident so artwork/masks do not rebuild during slide presentation'
require "$dash_media" 'PlayerControl {' 'Dashboard media must reuse the canonical shared player surface'
require "$dash_welcome" 'layer.enabled: root.visible && status === Image.Ready' 'Dashboard avatar mask must stay circular through the visible exit slide and sleep once hidden'
require "$dash_welcome" 'mipmap: false' 'Dashboard avatar must not generate unused mipmaps'
require "$ii_panels" 'keepLoaded: (Config.options?.dashboard?.keepLoaded ?? false) || used' 'Dashboard must remain resident after first use'
require "$dashboard" 'visible: true' 'Dashboard native layer-shell surface must remain mapped after first use'
require "$dashboard" 'updatesEnabled: root._renderUpdatesNeeded' 'Hidden Dashboard must suspend rendering without unmapping'
require "$dashboard" 'mask: dashboardInputRegion' 'Closed mapped Dashboard must expose an empty input region'
require "$dashboard" 'active: true' 'Dashboard widget tree must remain mounted while the retained surface exists'
require "$dashboard" 'visible: root._contentPresented' 'Dashboard content paint must hide only after the exit slide'
require "$dashboard" 'id: _presentationTimer' 'Dashboard reopen must paint a closed frame before entering the open slide state'
require "$dashboard" 'interval: 16' 'Dashboard slide arming must wait for a rendered frame'
require "$dashboard" 'panelTranslateY: SurfaceMotion.dashboardOffset' 'Dashboard closed state must remain a translated slide state'
require "$dashboard" 'duration: SurfaceMotion.dashboardEnterDuration' 'Dashboard entrance must use the tuned smooth slide duration'
require "$dashboard" 'easing.type: SurfaceMotion.dashboardEnterEasingType' 'Dashboard entrance must use the tuned deceleration curve'
require "$dashboard" 'duration: SurfaceMotion.dashboardExitDuration' 'Dashboard exit must use the tuned smooth slide duration'
require "$dashboard" 'easing.type: SurfaceMotion.dashboardExitEasingType' 'Dashboard exit must use the tuned acceleration curve'
reject "$dashboard" '_slideLayerActive' 'Dashboard slide must not wrap nested media effect layers in a transient whole-surface FBO'
require "$dashboard" 'presentationActive: root._contentPresented' 'Standalone Dashboard media lifecycle must remain active through the full exit slide'
require "$dashboard" 'opacity: 1' 'Dashboard entrance must not use opacity fading'
require "$dashboard" 'scale: 1' 'Dashboard entrance must not use scale animation'
reject "$dashboard" 'onTriggered: panelRoot.visible = false' 'Dashboard close must not unmap the native surface after the slide'
reject "$dashboard" 'Qt.callLater(() => { root._presentedOpen' 'Dashboard open must not race compositor mapping with a zero-delay state flip'
require "$dashboard_settings" 'text: Translation.tr("Preload Dashboard")' 'Dashboard keepLoaded option must describe eager preload only'

require "$screen_time" 'target: CompositorService.isNiri ? NiriService : null' 'Screen Time must use Niri focus events'
require "$screen_time" 'interval: CompositorService.isNiri' 'Screen Time must keep only a coarse Niri heartbeat'
require "$ytmusic" 'id: _ipcStateProc' 'YT Music fallback must batch mpv IPC state queries'
reject "$ytmusic" 'id: _ipcQueryProc' 'YT Music must not restore separate time-position subprocess polling'
reject "$ytmusic" 'id: _ipcPauseQueryProc' 'YT Music must not restore separate pause subprocess polling'
reject "$ytmusic" 'id: _ipcEofQueryProc' 'YT Music must not restore separate EOF subprocess polling'
reject "$directory_icon" 'command: ["file", "--mime"' 'DirectoryIcon must not spawn one MIME process per item'
reject "$sysmon_widget" 'command: ["/usr/bin/cat", "/proc/net/dev"]' 'SysMon must reuse shared ResourceUsage network telemetry'
require "$sysmon_widget" 'ResourceUsage.networkRxBytesPerSec' 'SysMon network receive rate must come from ResourceUsage'
require "$sysmon_widget" 'ResourceUsage.networkTxBytesPerSec' 'SysMon network transmit rate must come from ResourceUsage'

require "$timer_service" 'SystemClock {' 'Pomodoro and countdown must share one second-aligned clock'
require "$timer_service" 'precision: SystemClock.Seconds' 'shared timer clock must use second precision'
require "$timer_service" 'function refreshSecondTimers(): void {' 'shared timer refresh fan-out must remain explicit'
require "$timer_service" 'id: stopwatchTimer' 'stopwatch must retain its independent high-frequency timer'
require "$timer_service" 'interval: 33' 'stopwatch must retain the 33 ms presentation cadence'
reject "$timer_service" 'id: pomodoroTimer' 'Pomodoro must not restore a dedicated 200 ms timer'
reject "$timer_service" 'id: countdownTimer' 'Countdown must not restore a dedicated 200 ms timer'

require "$levendist" 'function levenshteinDistance(s1, s2, rows)' 'fuzzy search must accept reusable Levenshtein rows'
require "$levendist" 'if (longS.includes(shortS)) return 1.0;' 'fuzzy search must fast-path exact substring matches'
require "$levendist" 'const rows = [new Array(lenS + 1), new Array(lenS + 1)];' 'partial fuzzy matching must reuse one row workspace'
require "$levendist" 'levenshteinDistance(shortS, sub, rows)' 'partial fuzzy matching must reuse the shared row workspace'

require "$loading_indicator" 'import QtQuick.Window' 'loading indicator must observe owning window visibility'
require "$loading_indicator" '(root.Window.window?.visible ?? true)' 'loading indicator must stop while its owning window is hidden'
require "$circular_progress" 'import QtQuick.Window' 'circular progress must observe owning window visibility'
require "$circular_progress" 'root.visible && (root.Window.window?.visible ?? true)' 'circular progress animations must sleep while hidden'
require "$clipped_filled_progress" 'root.visible && (root.Window.window?.visible ?? true)' 'filled clipped progress animation must sleep while hidden'
require "$clipped_outline_progress" 'root.visible && (root.Window.window?.visible ?? true)' 'outline clipped progress animation must sleep while hidden'
require "$wavy_line" '(root.Window.window?.visible ?? true)' 'wavy line animation must sleep with its owning window'
require "$shell_update_indicator" 'ShellUpdates.isUpdating && root.visible' 'shell update spinner must stop when the indicator is hidden'
require "$shell_update_indicator" '(root.Window.window?.visible ?? true)' 'shell update animations must sleep with the Bar window'
require "$util_buttons" '(root.QsWindow.window?.visible ?? true)' 'ii Bar status pulses must sleep with the Bar window'
require "$waffle_system_button" '(root.Window.window?.visible ?? true)' 'Waffle system status pulses must sleep with the taskbar window'
require "$waffle_timer_button" '(root.Window.window?.visible ?? true)' 'Waffle timer pulse must sleep with the taskbar window'

printf 'performance lifecycle guards: ok\n'
