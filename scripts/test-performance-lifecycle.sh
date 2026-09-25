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
voice_search="$repo_root/services/VoiceSearch.qml"
gtk_theme="$repo_root/scripts/colors/apply-gtk-theme.sh"
terminal_theme="$repo_root/scripts/colors/modules/10-terminals.sh"
directories="$repo_root/modules/common/Directories.qml"
editor_theme="$repo_root/scripts/colors/modules/30-editors.sh"
system24_theme="$repo_root/scripts/colors/system24_palette.py"
steam_theme="$repo_root/scripts/colors/modules/70-steam.sh"
cava_theme_module="$repo_root/scripts/colors/modules/90-cava.sh"
desktop_media_widget="$repo_root/modules/background/widgets/mediaControls/MediaControlsWidget.qml"
player_base="$repo_root/modules/mediaControls/components/PlayerBase.qml"
media_presets=(
    "$repo_root/modules/mediaControls/presets/FullPlayer.qml"
    "$repo_root/modules/mediaControls/presets/CompactPlayer.qml"
    "$repo_root/modules/mediaControls/presets/MinimalPlayer.qml"
    "$repo_root/modules/mediaControls/presets/ClassicPlayer.qml"
    "$repo_root/modules/mediaControls/presets/AlbumArtPlayer.qml"
    "$repo_root/modules/mediaControls/presets/VisualizerPlayer.qml"
    "$repo_root/modules/mediaControls/presets/LyricsPlayer.qml"
    "$repo_root/modules/mediaControls/presets/LyricsSplitPlayer.qml"
    "$repo_root/modules/mediaControls/presets/ExpandingLyricsPlayer.qml"
)

require "$config" 'property int framerate: 30' 'Cava schema default must remain 30 fps'
require "$defaults" '"framerate": 30' 'persisted Cava default must remain 30 fps'
require "$cava" 'Config.options?.appearance?.cava?.framerate ?? 30' 'Cava runtime fallback must remain 30 fps'
require "$cava" '? Math.min(24, root.requestedFramerate)' 'Low Power must cap Cava at 24 fps'
require "$cava_generator" 'FRAMERATE="${2:-30}"' 'Cava generator fallback must remain 30 fps'
require "$advanced" '"appearance.cava.framerate": 30' 'ii Cava reset must remain 30 fps'
require "$waffle_themes" '"appearance.cava.framerate": 30' 'Waffle Cava reset must remain 30 fps'
require "$media_section" 'root.effectiveIsPlaying && GlobalStates.controlPanelOpen' 'Control Panel Cava must stop while playback is paused'
require "$sidebar_media" 'root.effectiveIsPlaying && GlobalStates.sidebarLeftOpen' 'Sidebar Cava must stop while playback is paused'
require "$sidebar_media" 'layer.enabled: root.visible && GlobalStates.sidebarLeftOpen' 'Sidebar media mask must release its FBO while the sidebar is closed'
require "$sidebar_media" 'sourceSize.width: Math.max(1, Math.ceil(card.width * root._dpr))' 'Sidebar blurred artwork decode must remain bounded to the displayed card'
require "$control_panel_media" 'layer.enabled: root.visible && GlobalStates.controlPanelOpen' 'Control Panel media masks must release their FBOs while closed'
require "$control_panel_media" 'sourceSize.width: Math.max(1, Math.ceil(card.width * root._dpr))' 'Control Panel blurred artwork decode must remain bounded'
require "$control_panel_media" 'mipmap: false' 'Control Panel artwork must not generate unused mipmaps'

require "$desktop_media_widget" 'item.positionUpdatesActive = Qt.binding(() => root.powerActive)' 'Desktop media position refresh must sleep with widget power state'
require "$player_base" 'running: root.positionUpdatesActive' 'PlayerBase position timer must honor the host lifecycle gate'
require "$player_base" 'onPositionUpdatesActiveChanged:' 'PlayerBase must refresh position immediately when lifecycle updates resume'
for preset in "${media_presets[@]}"; do
    require "$preset" 'property alias positionUpdatesActive: playerBase.positionUpdatesActive' 'Media presets must expose the shared position lifecycle gate'
done

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
require "$tlp" 'running: root.enabled || root.managed || root.busy' 'battery/TLP polling must sleep while charge limiting is disabled and unmanaged'
require "$thinkfan" 'interval: 30000' 'ThinkFan background polling must remain reduced'
require "$thinkfan" 'running: root.profileFanControlEnabled || root.active || root.busy' 'ThinkFan polling must sleep while fan control is irrelevant'
require "$tlp_caps" 'interval: 300000' 'TLP runtime capability probes must remain low cadence'
require "$tlp_caps" 'driver_path=$(readlink -f' 'GPU capability probe must keep direct driver resolution'
require "$tlp_caps" 'IFS= read -r lo <' 'GPU capability probe must read sysfs values with shell built-ins'
reject "$tlp_caps" 'driver=$(basename ' 'GPU capability probe must not spawn basename per DRM card'
reject "$tlp_caps" 'lo=$(cat ' 'GPU capability probe must not spawn cat for minimum frequency'
reject "$tlp_caps" 'hi=$(cat ' 'GPU capability probe must not spawn cat for maximum frequency'
require "$tlp_settings" 'interval: 300000' 'TLP settings background refresh must remain low cadence'
require "$power_profiles" 'interval: 300000' 'tlp-pd ownership probes must remain low cadence'
require "$power_profiles" 'command: ["/usr/bin/systemctl", "is-active", "--quiet", "tlp-pd.service"]' 'tlp-pd ownership probe must start systemctl directly'
require "$power_profiles" 'tlpPdProbe.command = ["/usr/bin/systemctl", "is-enabled", "--quiet", "tlp-pd.service"]' 'tlp-pd ownership probe must preserve enabled fallback'
require "$power_profiles" 'property string probeStage: "active"' 'tlp-pd ownership probe must retain explicit active/enabled stages'
reject "$power_profiles" '"/usr/bin/sh",' 'tlp-pd ownership probe must avoid a shell wrapper'

require "$world_clock" 'id: minuteTick' 'WorldClock must tick at minute precision without a permanent 1 Hz timer'
reject "$world_clock" 'interval: 1000' 'WorldClock must not restore a 1 Hz background timer'
require "$game_mode" 'Math.max(10000, Math.round(configured))' 'GameMode fallback polling must remain low cadence'
require "$overview_window" 'layer.enabled: GlobalStates.overviewOpen' 'retained Overview window masks must sleep while Overview is closed'
require "$resource_usage" '? Math.max(6000, root._configuredUpdateIntervalMs)' 'Low Power must slow resource sampling to at least 6 seconds'
require "$resource_usage" 'interval: root._effectiveUpdateIntervalMs' 'resource sensor timer must use the effective power-aware cadence'
require "$resource_usage" 'readonly property int _expensiveGpuUpdateIntervalMs:' 'process-backed GPU sampling must use a slower independent cadence'
require "$resource_usage" '? Math.max(15000, root._effectiveUpdateIntervalMs)' 'Low Power must throttle nvidia-smi/intel_gpu_top sampling to at least 15 seconds'
require "$bar_resources" 'root.visible && !GameMode.active' 'horizontal Bar resource polling must pause in GameMode'
require "$vertical_bar_resources" 'root.visible && !GameMode.active' 'vertical Bar resource polling must pause in GameMode'
require "$recorder_status" '(Config.options?.performance?.lowPower ?? false) ? 30000 : 15000' 'idle recorder detection must not spawn pgrep every five seconds'
require "$recorder_status" 'interval: root.idlePollIntervalMs' 'RecorderStatus idle polling must use its power-aware cadence'
require "$recorder_status" 'id: storedConfigFile' 'RecorderStatus config compatibility read must stay in-process'
require "$recorder_status" 'id: metadataFile' 'RecorderStatus metadata read must stay in-process'
require "$recorder_status" 'storedConfigFile.reload()' 'RecorderStatus config compatibility refresh must reuse FileView'
require "$recorder_status" 'metadataFile.reload()' 'RecorderStatus metadata refresh must reuse FileView'
reject "$recorder_status" 'command: ["/usr/bin/cat", Config.filePath]' 'RecorderStatus must not spawn cat for config compatibility'
reject "$recorder_status" 'command: ["/usr/bin/cat", root.recorderStatusPath]' 'RecorderStatus must not spawn cat for recording metadata'
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

require "$screen_time" 'target: NiriService' 'Screen Time must use Niri focus events'
require "$screen_time" 'interval: 30000' 'Screen Time must keep only a coarse Niri heartbeat'
require "$screen_time" 'id: startupTodayFile' 'Screen Time startup history must use FileView'
require "$screen_time" 'root._finishStartupRead(text())' 'Screen Time startup history must preserve in-process completion'
reject "$screen_time" 'id: startupReadProc' 'Screen Time startup history must not spawn a shell reader'
reject "$screen_time" 'test -f "${path}" && cat "${path}"' 'Screen Time startup history must not restore bash+cat file reads'
require "$screen_time" 'id: rangeReadFile' 'Screen Time range history must use FileView'
require "$screen_time" 'rangeReadFile.pendingPaths = paths' 'Screen Time range history must queue file reads in-process'
require "$screen_time" 'onLoadFailed: root._appendRangeChunk("{}")' 'Screen Time range history must preserve missing-day semantics'
reject "$screen_time" 'id: rangeReadProc' 'Screen Time range history must not spawn bash plus one cat per day'
reject "$screen_time" 'CompositorService.isHyprland' 'Screen Time must not restore retired Hyprland branching'
require "$ytmusic" 'id: _ipcStateProc' 'YT Music fallback must batch mpv IPC state queries'
reject "$ytmusic" 'id: _ipcQueryProc' 'YT Music must not restore separate time-position subprocess polling'
reject "$ytmusic" 'id: _ipcPauseQueryProc' 'YT Music must not restore separate pause subprocess polling'
reject "$ytmusic" 'id: _ipcEofQueryProc' 'YT Music must not restore separate EOF subprocess polling'
reject "$directory_icon" 'command: ["file", "--mime"' 'DirectoryIcon must not spawn one MIME process per item'
reject "$sysmon_widget" 'command: ["/usr/bin/cat", "/proc/net/dev"]' 'SysMon must reuse shared ResourceUsage network telemetry'
require "$sysmon_widget" 'ResourceUsage.networkRxBytesPerSec' 'SysMon network receive rate must come from ResourceUsage'
require "$sysmon_widget" 'ResourceUsage.networkTxBytesPerSec' 'SysMon network transmit rate must come from ResourceUsage'
require "$voice_search" 'root._startLocalProbe()' 'VoiceSearch backend refresh must use the centralized probe lifecycle'
require "$voice_search" 'command -v whisper-cli' 'VoiceSearch normal local-backend probe must avoid Python interpreter startup'
require "$voice_search" 'if (localProbe.usePythonFallback)' 'VoiceSearch must retain Python probe compatibility for edge-case paths'
require "$voice_search" 'root.localAvailable = executable.length > 0 && model.length > 0' 'VoiceSearch lightweight probe must preserve availability semantics'

require "$gtk_theme" 'theme_config_fields="$(' 'GTK theming config reads must remain batched'
require "$gtk_theme" 'palette_fields="$(' 'GTK palette reads must remain batched'
reject "$gtk_theme" 'BG=$(jq -r ' 'GTK theming must not restore one jq process per palette token'
reject "$gtk_theme" 'enable_apps_shell=$(jq -r ' 'GTK theming must not restore separate config jq processes'
gtk_jq_reads="$(grep -Ec '^[[:space:]]*jq -r ' "$gtk_theme")"
if (( gtk_jq_reads > 2 )); then
    fail "GTK theming parser must use at most two jq reads, found $gtk_jq_reads"
fi

require "$terminal_theme" 'load_terminal_theme_config() {' 'terminal theming must snapshot config once per apply'
require "$terminal_theme" 'terminal_fields="$(' 'terminal palette reads must remain batched'
require "$terminal_theme" 'sed_args+=(-e ' 'terminal OSC substitutions must remain batched into one sed'
reject "$terminal_theme" 'enabled=$(config_bool ".appearance.wallpaperTheming.terminals.${term}" true)' 'terminal theming must not restore one config jq per target'
reject "$terminal_theme" 'value=$(jq -r ".term${idx} // empty"' 'terminal theming must not restore one palette jq per color'
reject "$terminal_theme" 'for idx in $(seq 0 15)' 'terminal palette batching must not restore an external seq loop'
terminal_jq_reads="$(grep -Ec '^[[:space:]]*jq -r ' "$terminal_theme")"
if (( terminal_jq_reads > 2 )); then
    fail "terminal theming parser must use at most two jq reads, found $terminal_jq_reads"
fi

require "$directories" 'id: preparePersistentDirsProc' 'Directories startup must serialize persistent directory creation'
require "$directories" 'onExited: cleanupSessionDirsProc.running = true' 'Directories persistent setup must continue into cache cleanup'
require "$directories" 'id: cleanupSessionDirsProc' 'Directories startup must batch session cache cleanup'
require "$directories" 'onExited: prepareSessionDirsProc.running = true' 'Directories cache cleanup must continue into cache recreation'
require "$directories" 'id: prepareSessionDirsProc' 'Directories startup must batch session cache recreation'
require "$directories" 'Component.onCompleted: preparePersistentDirsProc.running = true' 'Directories startup must enter the serialized preparation chain'
reject "$directories" 'Quickshell.execDetached(["mkdir"' 'Directories startup must not restore detached mkdir fan-out'
reject "$directories" 'Quickshell.execDetached(["rm"' 'Directories startup must not restore detached rm fan-out'

require "$editor_theme" 'editor_config_rows="$(' 'editor theming must snapshot config once per apply'
require "$editor_theme" 'local -A vscode_editor_enabled=(' 'editor theming must cache VS Code fork toggles'
reject "$editor_theme" 'enable_vscode=$(config_json ' 'editor theming must not restore a separate VS Code config jq'
reject "$editor_theme" 'enable_neovim=$(config_bool ' 'editor theming must not restore a separate Neovim config jq'
reject "$editor_theme" 'enable_opencode=$(config_bool ' 'editor theming must not restore a separate OpenCode config jq'
reject "$editor_theme" 'echo "$editors_config" | jq -r' 'editor theming must not restore one jq process per VS Code fork'
reject "$editor_theme" 'has(\"enableVSCode\")' 'editor jq program must not escape nested has() quotes'
editor_jq_reads="$(grep -Ec '^[[:space:]]*jq -r ' "$editor_theme")"
if (( editor_jq_reads > 1 )); then
    fail "editor theming parser must use at most one jq read, found $editor_jq_reads"
fi

require "$system24_theme" 'def _write_if_changed(path: Path, content: str) -> bool:' 'System24 outputs must avoid unchanged rewrites'
require "$system24_theme" '_write_if_changed(out, system24_content)' 'System24 primary theme must use idempotent writes'
require "$system24_theme" '_write_if_changed(out, midnight_content)' 'System24 midnight theme must use idempotent writes'
require "$system24_theme" '_write_if_changed(out, tui_content)' 'System24 TUI theme must use idempotent writes'

require "$steam_theme" 'load_color_tokens() {' 'Steam Millennium palette must be snapshotted once per CSS generation'
require "$steam_theme" 'declare -A COLOR_TOKENS=()' 'Steam Millennium token lookups must stay in-process'
require "$steam_theme" 'hex="${COLOR_TOKENS[$token]-}"' 'Steam Millennium token reads must use the palette snapshot'
reject "$steam_theme" 'hex=$(jq -r ".${token} // empty"' 'Steam Millennium CSS generation must not spawn jq per token'
steam_palette_jq_reads="$(grep -Fc "jq -r 'to_entries[] | select(.value != null)" "$steam_theme")"
if (( steam_palette_jq_reads != 1 )); then
    fail "Steam Millennium palette must use exactly one batched jq read, found $steam_palette_jq_reads"
fi

require "$cava_theme_module" 'load_cava_config() {' 'Cava theming must snapshot config once per apply'
require "$cava_theme_module" 'load_cava_palette() {' 'Cava theming must snapshot the palette once per apply'
require "$cava_theme_module" 'CAVA_CONFIG_VALUES["$key"]="$value"' 'Cava config reads must use the in-process snapshot'
require "$cava_theme_module" 'CAVA_PALETTE["$key"]="$value"' 'Cava palette reads must use the in-process snapshot'
reject "$cava_theme_module" 'config_json ".appearance.cava.${key}' 'Cava theming must not restore one config jq per setting'
reject "$cava_theme_module" 'jq -r ".${key} // empty" "$PALETTE_FILE"' 'Cava theming must not restore one palette jq per color'
require "$cava_theme_module" 'jq -r --argjson count "$count"' 'Cava cover gradients must batch color-array reads'
reject "$cava_theme_module" 'cover_color() {' 'Cava cover gradients must not restore one jq process per color'
reject "$cava_theme_module" 'for i in $(seq 0 $((count - 1)))' 'Cava cover gradients must not restore an external seq loop'
require "$cava_theme_module" 'saturate_colors() {' 'Cava vibrant gradients must batch saturation into one interpreter'
require "$cava_theme_module" 'mapfile -t colors < <(saturate_colors 1.6 "${raw_colors[@]}")' 'Cava vibrant gradient must consume the batched saturation output'
reject "$cava_theme_module" 'saturate_hex() {' 'Cava vibrant gradients must not restore one Python interpreter per color'
reject "$cava_theme_module" 'sat=$(saturate_hex "$c" 1.6)' 'Cava vibrant gradients must not restore per-color Python startup'
cava_theme_jq_reads="$(grep -Ec '^[[:space:]]*jq -r ' "$cava_theme_module")"
if (( cava_theme_jq_reads > 3 )); then
    fail "Cava theming must keep config, palette, and cover JSON reads batched, found $cava_theme_jq_reads jq sites"
fi

printf 'performance lifecycle guards: ok\n'
