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
local_music_view="$repo_root/modules/sidebarLeft/LocalMusicView.qml"
local_music="$repo_root/services/LocalMusic.qml"
local_music_mpd="$repo_root/scripts/local_music_mpd.py"
native_dispatch="$repo_root/scripts/native-dispatch"
screen_edges="$repo_root/modules/screenCorners/ScreenEdges.qml"
alt_switcher="$repo_root/modules/altSwitcher/AltSwitcher.qml"
waffle_alt="$repo_root/modules/waffle/altSwitcher/WaffleAltSwitcher.qml"
waffle_alt_content="$repo_root/modules/waffle/altSwitcher/WaffleAltSwitcherContent.qml"
waffle_notification_group="$repo_root/modules/waffle/notificationCenter/WNotificationGroup.qml"
waffle_single_notification="$repo_root/modules/waffle/notificationCenter/WSingleNotification.qml"
waffle_notification_pane="$repo_root/modules/waffle/notificationCenter/NotificationPaneContent.qml"
waffle_notification_center="$repo_root/modules/waffle/notificationCenter/NotificationCenterContent.qml"
waffle_notification_list="$repo_root/modules/waffle/notificationPopup/WNotificationListView.qml"
waffle_notification_popup="$repo_root/modules/waffle/notificationPopup/WaffleNotificationPopup.qml"
waffle_popup_group="$repo_root/modules/waffle/notificationPopup/WNotificationGroup.qml"
waffle_popup_item="$repo_root/modules/waffle/notificationPopup/WNotificationItem.qml"
workspace_thumb="$repo_root/modules/waffle/taskview/WorkspaceThumbnail.qml"
window_thumb="$repo_root/modules/waffle/taskview/WindowThumbnail.qml"
dock_window_preview="$repo_root/modules/dock/DockWindowPreview.qml"
dock_preview="$repo_root/modules/dock/DockPreview.qml"
notification_item="$repo_root/modules/common/widgets/NotificationItem.qml"
bar_taskbar_window_preview="$repo_root/modules/bar/BarTaskbarWindowPreview.qml"
bar_taskbar_preview="$repo_root/modules/bar/BarTaskbarPreview.qml"
easyeffects="$repo_root/services/deferred/EasyEffects.qml"
tlp="$repo_root/services/TlpService.qml"
thinkfan="$repo_root/services/ThinkFanService.qml"
tlp_caps="$repo_root/services/TlpRuntimeCapabilities.qml"
tlp_settings="$repo_root/services/TlpSettingsService.qml"
power_profiles="$repo_root/services/PowerProfilePersistence.qml"
world_clock="$repo_root/services/WorldClock.qml"
game_mode="$repo_root/services/GameMode.qml"
session="$repo_root/modules/common/functions/Session.qml"
overview_window="$repo_root/modules/overview/OverviewWindow.qml"
resource_usage="$repo_root/services/ResourceUsage.qml"
bar_resources="$repo_root/modules/bar/Resources.qml"
bar_surface="$repo_root/modules/bar/Bar.qml"
bar_content="$repo_root/modules/bar/BarContent.qml"
bar_media="$repo_root/modules/bar/Media.qml"
bar_util_buttons="$repo_root/modules/bar/UtilButtons.qml"
bar_timer_indicator="$repo_root/modules/bar/TimerIndicator.qml"
bar_shell_update_indicator="$repo_root/modules/bar/ShellUpdateIndicator.qml"
vertical_bar_surface="$repo_root/modules/verticalBar/VerticalBar.qml"
vertical_bar_content="$repo_root/modules/verticalBar/VerticalBarContent.qml"
vertical_bar_media="$repo_root/modules/verticalBar/VerticalMedia.qml"
vertical_bar_resources="$repo_root/modules/verticalBar/Resources.qml"
recorder_status="$repo_root/services/RecorderStatus.qml"
timer_service="$repo_root/services/TimerService.qml"
stopwatch_view="$repo_root/modules/sidebarRight/pomodoro/Stopwatch.qml"
control_panel_media="$repo_root/modules/controlPanel/MediaSection.qml"
volume_mixer="$repo_root/modules/ii/overlay/volumeMixer/VolumeMixer.qml"
weather="$repo_root/services/Weather.qml"
keyboard_indicators="$repo_root/services/KeyboardIndicators.qml"
sidebar_anime="$repo_root/modules/sidebarLeft/Anime.qml"
sidebar_anime_schedule="$repo_root/modules/sidebarLeft/animeSchedule/AnimeScheduleView.qml"
sidebar_wallhaven="$repo_root/modules/sidebarLeft/WallhavenView.qml"
wallhaven_service="$repo_root/services/Wallhaven.qml"
sidebar_ai="$repo_root/modules/sidebarLeft/AiChat.qml"
sidebar_news="$repo_root/modules/sidebarLeft/news/NewsView.qml"
sidebar_left_content="$repo_root/modules/sidebarLeft/SidebarLeftContent.qml"
sidebar_quick_wallpaper="$repo_root/modules/sidebarLeft/widgets/QuickWallpaper.qml"
status_rings="$repo_root/modules/sidebarLeft/widgets/StatusRings.qml"
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
shell_updates="$repo_root/services/ShellUpdates.qml"
directory_icon="$repo_root/modules/common/widgets/DirectoryIcon.qml"
sysmon_widget="$repo_root/modules/sidebarRight/sysmon/SysMonWidget.qml"
graph_widget="$repo_root/modules/common/widgets/Graph.qml"
overlay_resources="$repo_root/modules/ii/overlay/resources/Resources.qml"
overlay_floating_image="$repo_root/modules/ii/overlay/floatingImage/FloatingImage.qml"
overlay_taskbar="$repo_root/modules/ii/overlay/OverlayTaskbar.qml"
styled_overlay_widget="$repo_root/modules/ii/overlay/StyledOverlayWidget.qml"
voice_search="$repo_root/services/VoiceSearch.qml"
gtk_theme="$repo_root/scripts/colors/apply-gtk-theme.sh"
terminal_theme="$repo_root/scripts/colors/modules/10-terminals.sh"
directories="$repo_root/modules/common/Directories.qml"
editor_theme="$repo_root/scripts/colors/modules/30-editors.sh"
system24_theme="$repo_root/scripts/colors/system24_palette.py"
steam_theme="$repo_root/scripts/colors/modules/70-steam.sh"
cava_theme_module="$repo_root/scripts/colors/modules/90-cava.sh"
themes_config="$repo_root/modules/settings/ThemesConfig.qml"
desktop_media_widget="$repo_root/modules/background/widgets/mediaControls/MediaControlsWidget.qml"
bar_media_popup="$repo_root/modules/mediaControls/BarMediaPopup.qml"
player_base="$repo_root/modules/mediaControls/components/PlayerBase.qml"
player_lyrics="$repo_root/modules/mediaControls/components/PlayerLyrics.qml"
player_control="$repo_root/modules/mediaControls/PlayerControl.qml"
media_cross_slide="$repo_root/modules/common/widgets/MediaCrossSlideImage.qml"
equalizer_panel="$repo_root/modules/mediaControls/EqualizerPanel.qml"
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
lyrics_presets=(
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
require "$bar_content" 'property bool presentationActive: true' 'Bar presentation lifecycle gate must preserve standalone behavior'
require "$bar_content" '&& root.presentationActive' 'Off-screen auto-hidden Bar must release its Cava subscription'
require "$bar_surface" 'presentationActive: !barRoot.fullscreenCovered' 'Bar Cava lifecycle must follow actual painted presentation'
require "$bar_surface" 'barContent.anchors.bottomMargin > -barRoot.panelSurfaceHeight + 1' 'Bottom Bar Cava must remain live through its visible exit slide'
require "$bar_surface" 'barContent.anchors.topMargin > -barRoot.panelSurfaceHeight + 1' 'Top Bar Cava must remain live through its visible exit slide'
require "$bar_media" 'property bool presentationActive: true' 'Horizontal Bar media lifecycle gate must preserve standalone behavior'
require "$bar_media" 'running: root.presentationActive' 'Auto-hidden horizontal Bar must stop its MPRIS position timer'
require "$bar_media" 'enableAnimation: root.presentationActive' 'Auto-hidden horizontal Bar must stop circular media progress animation'
require "$bar_media" 'if (!root.presentationActive || !titleScroller.visible' 'Auto-hidden horizontal Bar must stop its title marquee'
require "$bar_content" 'presentationActive: root.presentationActive' 'Horizontal Bar media must follow the Bar presentation lifecycle'
require "$vertical_bar_media" 'property bool presentationActive: true' 'Vertical Bar media lifecycle gate must preserve standalone behavior'
require "$vertical_bar_media" 'running: root.presentationActive' 'Auto-hidden vertical Bar must stop its MPRIS position timer'
require "$vertical_bar_content" 'VerticalMedia { presentationActive: root.presentationActive }' 'Vertical Bar media must follow its content presentation lifecycle'
require "$vertical_bar_surface" 'barContent.anchors.rightMargin > -Appearance.sizes.verticalBarWidth + 1' 'Right Vertical Bar media must remain live through its visible exit slide'
require "$vertical_bar_surface" 'barContent.anchors.leftMargin > -Appearance.sizes.verticalBarWidth + 1' 'Left Vertical Bar media must remain live through its visible exit slide'
require "$bar_util_buttons" 'property bool presentationActive: true' 'Utility pulse lifecycle gate must preserve real caller behavior'
require "$bar_util_buttons" 'running: root.presentationActive && recordButtonWrapper.isRecording' 'Hidden utility probes must not pulse recording state'
require "$bar_util_buttons" 'running: root.presentationActive && micButton.isInUse && !micButton.isMuted' 'Hidden utility probes must not pulse microphone state'
require "$bar_util_buttons" 'running: root.presentationActive && screenCastButton.isCasting' 'Hidden utility probes must not pulse screencast state'
require "$bar_timer_indicator" 'property bool presentationActive: true' 'Bar timer pulse must expose a presentation lifecycle gate'
require "$bar_timer_indicator" 'running: root.presentationActive && root.pomodoroActive' 'Hidden Bar must stop Pomodoro pulse animation'
require "$bar_shell_update_indicator" 'property bool presentationActive: true' 'Shell update indicator must expose a presentation lifecycle gate'
require "$bar_shell_update_indicator" 'running: root.presentationActive && ShellUpdates.isUpdating' 'Hidden Bar must stop update spinner rotation'
require "$bar_shell_update_indicator" 'visible: root.presentationActive && updatePopup.active' 'Closed Shell Update popup must stop retained LoadingText animation'
require "$bar_content" 'TimerIndicator { presentationActive: root.presentationActive; Layout.alignment: Qt.AlignVCenter }' 'Bar timer indicator must follow Bar presentation lifecycle'
require "$bar_content" 'ShellUpdateIndicator { presentationActive: root.presentationActive; Layout.alignment: Qt.AlignVCenter }' 'Bar update indicator must follow Bar presentation lifecycle'
require "$bar_content" 'presentationActive: false' 'Horizontal Bar natural-size utility probe must stay animation-idle'
require "$vertical_bar_content" 'presentationActive: false' 'Vertical Bar natural-size utility probe must stay animation-idle'
require "$media_section" 'root.effectiveIsPlaying && GlobalStates.controlPanelOpen' 'Control Panel Cava must stop while playback is paused'
require "$sidebar_media" 'root.effectiveIsPlaying && GlobalStates.sidebarLeftOpen' 'Sidebar Cava must stop while playback is paused'
require "$local_music_view" 'active: root.visible && GlobalStates.sidebarLeftOpen && LocalMusic.playing' 'Local Music Cava must sleep while the retained Sidebar is closed'
require "$local_music_view" 'positionUpdatesActive: root.visible && GlobalStates.sidebarLeftOpen' 'Local Music retained PlayerControl must sleep with the Sidebar'
require "$waffle_notification_group" 'property bool presentationActive: true' 'Waffle notification groups must expose a host lifecycle gate'
require "$waffle_notification_group" 'running: root.presentationActive && root.hasCritical' 'Hidden Waffle notification groups must stop critical pulse animations'
require "$waffle_single_notification" 'running: root.presentationActive && root.isCritical' 'Hidden Waffle notification rows must stop critical pulse animations'
require "$waffle_notification_pane" 'presentationActive: root.presentationActive' 'Notification Center group delegates must inherit panel presentation state'
require "$waffle_notification_center" 'presentationActive: root.presented || root.closing' 'Notification Center pulses must stay live through exit motion and sleep after close'
require "$waffle_notification_list" 'presentationActive: root.presentationActive' 'Notification popup group delegates must inherit native-window visibility'
require "$waffle_notification_popup" 'presentationActive: panelWindow.visible' 'Suppressed Waffle notification popups must suspend retained pulse animations'
require "$waffle_popup_group" 'property bool presentationActive: true' 'Waffle popup notification groups must accept host presentation state'
require "$waffle_popup_group" 'presentationActive: root.presentationActive' 'Waffle popup notification items must inherit popup presentation state'
require "$waffle_popup_item" 'running: root.presentationActive && root.isCritical && Looks.transition.enabled' 'Suppressed Waffle popup critical pulses must stop'
require "$local_music" 'property bool _mpdSubscriptionEligible: false' 'Local Music must track event-subscription availability separately from the Rust daemon'
require "$local_music" 'pythonReady && !(mode === "rust" && strict === "1")' 'Local Music Python subscriber must honor strict Rust mode'
require "$local_music" 'running: root.enabled && !root._mpdSubscriptionActive' 'Local Music 900ms status polling must remain fallback-only'
require "$local_music_mpd" 'client.command("idle", *IDLE_SUBSYSTEMS)' 'Python Local Music fallback must use blocking MPD idle events'
require "$native_dispatch" 'python_exec "$ROOT_DIR/scripts/local_music_mpd.py" subscribe "$@"' 'Local Music selector must prefer event-driven Python fallback over 900ms polling'
require "$sidebar_media" 'layer.enabled: root.visible && GlobalStates.sidebarLeftOpen' 'Sidebar media mask must release its FBO while the sidebar is closed'
require "$sidebar_media" 'sourceSize.width: Math.max(1, Math.ceil(card.width * root._dpr))' 'Sidebar blurred artwork decode must remain bounded to the displayed card'
require "$control_panel_media" 'layer.enabled: root.visible && GlobalStates.controlPanelOpen' 'Control Panel media masks must release their FBOs while closed'
require "$control_panel_media" 'sourceSize.width: Math.max(1, Math.ceil(card.width * root._dpr))' 'Control Panel blurred artwork decode must remain bounded'
require "$control_panel_media" 'mipmap: false' 'Control Panel artwork must not generate unused mipmaps'
require "$control_panel_media" 'readonly property bool presentationActive: GlobalStates.controlPanelOpen && root.visible' 'Control Panel media lifecycle must follow actual presentation state'
require "$control_panel_media" 'wavy: root.presentationActive && (root.player?.isPlaying ?? false)' 'Hidden retained Control Panel must stop wavy progress animation'
require "$control_panel_media" 'animateWave: root.presentationActive && (root.player?.isPlaying ?? false)' 'Hidden retained Control Panel must stop infinite wave motion'
require "$control_panel_media" 'running: root.presentationActive' 'Hidden retained Control Panel must stop its MPRIS position timer'
require "$volume_mixer" 'readonly property bool presentationActive: root.visible && SwipeView.isCurrentItem' 'Volume Mixer Music lifecycle must follow actual overlay/tab presentation'
require "$volume_mixer" 'running: musicContent.presentationActive' 'Hidden/non-Music Volume Mixer must stop its MPRIS position timer'
require "$volume_mixer" 'wavy: musicContent.presentationActive' 'Hidden/non-Music Volume Mixer must stop infinite progress motion'

require "$desktop_media_widget" 'item.positionUpdatesActive = Qt.binding(() => root.powerActive)' 'Desktop media position refresh must sleep with widget power state'
require "$bar_media_popup" 'positionUpdatesActive: root.presentationActive && playerDelegate.enabled' 'Bar media position refresh must sleep while popup is hidden and for off-screen tabs'
require "$player_base" 'running: root.positionUpdatesActive' 'PlayerBase position timer must honor the host lifecycle gate'
require "$player_base" 'onPositionUpdatesActiveChanged:' 'PlayerBase must refresh position immediately when lifecycle updates resume'
for preset in "${media_presets[@]}"; do
    require "$preset" 'property alias positionUpdatesActive: playerBase.positionUpdatesActive' 'Media presets must expose the shared position lifecycle gate'
    preset_visualizer_lifecycle="$(grep -Fc 'live: root.positionUpdatesActive && playerBase.effectiveIsPlaying' "$preset")"
    if (( preset_visualizer_lifecycle != 2 )); then
        fail "Media preset visualizers must both sleep with the shared lifecycle gate: $preset has $preset_visualizer_lifecycle guarded visualizers"
    fi
done
require "$player_lyrics" 'property bool serviceActive: true' 'PlayerLyrics lifecycle gate must preserve default standalone behavior'
require "$player_lyrics" 'const shouldSubscribe = root.visible && root.serviceActive;' 'PlayerLyrics must unsubscribe when its host lifecycle sleeps'
require "$player_lyrics" 'onServiceActiveChanged: root.syncSubscription()' 'PlayerLyrics must react immediately to host lifecycle changes'
for preset in "${lyrics_presets[@]}"; do
    require "$preset" 'serviceActive: root.positionUpdatesActive' 'Desktop lyrics presets must share the media power lifecycle gate'
done


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
require "$dock_window_preview" 'property bool presentationActive: true' 'Dock preview tiles must expose a retained-surface lifecycle gate'
require "$dock_window_preview" 'running: root.presentationActive && shimmerBg.visible' 'Hidden Dock preview tiles must stop shimmer animation'
require "$dock_window_preview" 'layer.enabled: root.presentationActive && windowPreview.status === Image.Ready' 'Hidden Dock preview tiles must release thumbnail mask layers'
require "$dock_preview" 'presentationActive: root.visible' 'Dock preview host must power tiles only while its popup is visible'
require "$dock_preview" 'layer.enabled: root.visible' 'Hidden Dock preview popup must release its content mask FBO'
require "$dock_preview" 'layer.mipmap: false' 'Dock preview content mask must not generate an unused mip chain'
require "$notification_item" 'layer.enabled: !root.modernLayout && expandedContentColumn.visible' 'Collapsed notification actions must release their legacy rounded-mask FBO'
require "$bar_taskbar_window_preview" 'property bool presentationActive: true' 'Bar taskbar preview tiles must expose a retained-surface lifecycle gate'
require "$bar_taskbar_window_preview" 'running: root.presentationActive && shimmerBg.visible' 'Hidden Bar taskbar preview tiles must stop shimmer animation'
require "$bar_taskbar_window_preview" 'layer.enabled: root.presentationActive && windowPreview.status === Image.Ready' 'Hidden Bar taskbar preview tiles must release thumbnail mask layers'
require "$bar_taskbar_preview" 'presentationActive: root.active' 'Bar taskbar preview host must keep tiles live through retract and sleep afterward'

require "$easyeffects" 'readonly property bool uiDemand:' 'EasyEffects must expose demand-aware state polling'
require "$easyeffects" 'interval: root.uiDemand ? 5000 : 30000' 'EasyEffects must use slow background verification'
require "$easyeffects" 'running: Config.ready && root.available && (root.uiDemand || root.active)' 'EasyEffects polling must sleep when inactive and hidden'

require "$tlp" 'interval: 120000' 'battery/TLP status polling must not run every 30 seconds'
require "$tlp" 'running: root.enabled || root.managed || root.busy' 'battery/TLP polling must sleep while charge limiting is disabled and unmanaged'
require "$thinkfan" 'interval: 30000' 'ThinkFan background polling must remain reduced'
require "$thinkfan" 'running: root.profileFanControlEnabled || root.active || root.busy' 'ThinkFan polling must sleep while fan control is irrelevant'
require "$tlp_caps" 'interval: 300000' 'TLP runtime capability probes must remain low cadence'
require "$tlp_caps" 'readonly property bool standaloneSettingsWindow:' 'TLP runtime capabilities must recognize standalone Settings'
require "$tlp_caps" 'root.standaloneSettingsWindow || (GlobalStates.settingsOverlayOpen ?? false)' 'TLP runtime capability demand must follow actual Settings presentation'
require "$tlp_caps" 'onUiDemandChanged:' 'TLP runtime capabilities must refresh immediately when Settings opens'
require "$tlp_caps" 'running: root.uiDemand' 'TLP runtime GPU/RDW/sysfs probes must sleep after Settings closes'
reject "$tlp_caps" 'Component.onCompleted: root.refresh()' 'TLP runtime capabilities must not probe eagerly outside Settings'
require "$tlp_caps" 'driver_path=$(readlink -f' 'GPU capability probe must keep direct driver resolution'
require "$tlp_caps" 'IFS= read -r lo <' 'GPU capability probe must read sysfs values with shell built-ins'
reject "$tlp_caps" 'driver=$(basename ' 'GPU capability probe must not spawn basename per DRM card'
reject "$tlp_caps" 'lo=$(cat ' 'GPU capability probe must not spawn cat for minimum frequency'
reject "$tlp_caps" 'hi=$(cat ' 'GPU capability probe must not spawn cat for maximum frequency'
require "$tlp_settings" 'interval: 300000' 'TLP settings background refresh must remain low cadence'
require "$tlp_settings" 'readonly property bool standaloneSettingsWindow:' 'TLP settings lifecycle must recognize the standalone settings process'
require "$tlp_settings" 'root.standaloneSettingsWindow || (GlobalStates.settingsOverlayOpen ?? false)' 'TLP settings demand must follow actual Settings presentation'
require "$tlp_settings" 'onUiDemandChanged:' 'TLP settings must refresh immediately when Settings reopens'
require "$tlp_settings" 'running: root.schemaLoaded && root.uiDemand' 'TLP settings status helper must sleep after Settings closes'
require "$power_profiles" 'interval: 300000' 'tlp-pd ownership probes must remain low cadence'
require "$power_profiles" 'command: ["/usr/bin/systemctl", "is-active", "--quiet", "tlp-pd.service"]' 'tlp-pd ownership probe must start systemctl directly'
require "$power_profiles" 'tlpPdProbe.command = ["/usr/bin/systemctl", "is-enabled", "--quiet", "tlp-pd.service"]' 'tlp-pd ownership probe must preserve enabled fallback'
require "$power_profiles" 'property string probeStage: "active"' 'tlp-pd ownership probe must retain explicit active/enabled stages'
reject "$power_profiles" '"/usr/bin/sh",' 'tlp-pd ownership probe must avoid a shell wrapper'

require "$world_clock" 'target: DateTime' 'WorldClock must share the shell minute cadence'
require "$world_clock" 'function onMinuteEpochChanged(): void' 'WorldClock must refresh from minute-precision DateTime events'
reject "$world_clock" 'interval: 1000' 'WorldClock must not restore a 1 Hz background timer'
require "$game_mode" 'Math.max(10000, Math.round(configured))' 'GameMode fallback polling must remain low cadence'
require "$session" 'function onSessionOpenChanged()' 'Sleep capability detection must remain presentation-driven'
require "$session" 'root.refreshSleepCapabilities()' 'Opening the session screen must refresh hibernate capability'
require "$session" 'running: false' 'Session hibernate capability probe must stay idle until needed'
require "$overview_window" 'layer.enabled: GlobalStates.overviewOpen' 'retained Overview window masks must sleep while Overview is closed'
require "$resource_usage" '? Math.max(6000, root._configuredUpdateIntervalMs)' 'Low Power must slow resource sampling to at least 6 seconds'
require "$resource_usage" 'interval: root._effectiveUpdateIntervalMs' 'resource sensor timer must use the effective power-aware cadence'
require "$resource_usage" 'readonly property int _expensiveGpuUpdateIntervalMs:' 'process-backed GPU sampling must use a slower independent cadence'
require "$resource_usage" '? Math.max(15000, root._effectiveUpdateIntervalMs)' 'Low Power must throttle nvidia-smi/intel_gpu_top sampling to at least 15 seconds'
require "$resource_usage" 'const firstLine = nvidiaGpuCollector.text.trim().split("\n")[0] ?? "";' 'NVIDIA GPU sampling must preserve first-device semantics without head'
require "$resource_usage" 'command: ["timeout", "1", root._intelGpuTopPath, "-J", "-s", "500"]' 'Intel GPU sampling must invoke timeout directly without a shell wrapper'
reject "$resource_usage" '2>/dev/null | head -n 1' 'NVIDIA GPU sampling must not spawn bash and head around nvidia-smi'
reject "$resource_usage" 'command: ["/usr/bin/bash", "-c", "timeout 1 " + root._intelGpuTopPath' 'Intel GPU sampling must not spawn bash around timeout'
require "$bar_resources" 'root.visible && !GameMode.active' 'horizontal Bar resource polling must pause in GameMode'
require "$vertical_bar_resources" 'root.visible && !GameMode.active' 'vertical Bar resource polling must pause in GameMode'
require "$recorder_status" '(Config.options?.performance?.lowPower ?? false) ? 30000 : 15000' 'idle recorder detection must not spawn pgrep every five seconds'
require "$recorder_status" 'interval: root.idlePollIntervalMs' 'RecorderStatus idle polling must use its power-aware cadence'
require "$timer_service" 'property int stopwatchHighPrecisionSubscribers: 0' 'Stopwatch service must track visible centisecond consumers'
require "$timer_service" 'interval: root.stopwatchHighPrecisionActive ? 33 : 250' 'Background stopwatch refresh must downshift when centisecond UI is hidden'
require "$stopwatch_view" 'stopwatchTab.visible && GlobalStates.sidebarRightOpen' 'Stopwatch centisecond refresh must follow actual Sidebar Right presentation'
require "$stopwatch_view" 'TimerService.subscribeStopwatchHighPrecision()' 'Visible Stopwatch UI must request high precision updates'
require "$stopwatch_view" 'TimerService.unsubscribeStopwatchHighPrecision()' 'Hidden/destroyed Stopwatch UI must release high precision updates'
require "$recorder_status" 'id: storedConfigFile' 'RecorderStatus config compatibility read must stay in-process'
require "$recorder_status" 'id: metadataFile' 'RecorderStatus metadata read must stay in-process'
require "$recorder_status" 'storedConfigFile.reload()' 'RecorderStatus config compatibility refresh must reuse FileView'
require "$recorder_status" 'metadataFile.reload()' 'RecorderStatus metadata refresh must reuse FileView'
reject "$recorder_status" 'command: ["/usr/bin/cat", Config.filePath]' 'RecorderStatus must not spawn cat for config compatibility'
reject "$recorder_status" 'command: ["/usr/bin/cat", root.recorderStatusPath]' 'RecorderStatus must not spawn cat for recording metadata'
require "$recorder_status" 'id: activePidFile' 'RecorderStatus active verification must use an in-process /proc reader'
require "$recorder_status" 'const target = "/proc/" + root.recorderPid + "/comm"' 'RecorderStatus must verify the known recorder PID directly'
active_recorder_poll="$(sed -n '/id: activePollTimer/,/^[[:space:]]*}/p' "$recorder_status")"
grep -Fq 'root.refreshActivePid()' <<<"$active_recorder_poll" \
    || fail 'RecorderStatus active poll must verify the known PID without pgrep'
if grep -Fq 'root.refreshStatus()' <<<"$active_recorder_poll"; then
    fail 'RecorderStatus active poll must not spawn pgrep once per second'
fi
require "$weather" 'running: root.enabled' 'Weather minute clock must sleep when weather is disabled'
require "$keyboard_indicators" 'interval: (Config.options?.performance?.lowPower ?? false) ? 120000 : 30000' 'keyboard sysfs hotplug discovery must stay low cadence'
require "$sidebar_anime" 'layer.enabled: root.presentationActive && root.visible' 'Anime list mask must sleep outside the selected tab'
require "$sidebar_anime" 'loading: root.presentationActive && (root.pullLoading || Booru.runningRequests > 0)' 'Hidden Anime tab must stop its loading gear'
require "$sidebar_anime_schedule" 'property bool presentationActive: true' 'Anime Schedule must expose a host lifecycle gate'
require "$sidebar_anime_schedule" 'visible: root.presentationActive && AnimeService.loading' 'Hidden Anime Schedule must stop loading presentation animations'
require "$sidebar_anime_schedule" 'loading: root.presentationActive' 'Hidden Anime Schedule must stop its loading gear'
require "$sidebar_anime_schedule" 'running: root.presentationActive && AnimeService.loading' 'Hidden Anime Schedule must stop refresh icon rotation'
require "$sidebar_wallhaven" 'layer.enabled: root.visible && GlobalStates.sidebarLeftOpen' 'Wallhaven list mask must sleep with the sidebar'
require "$wallhaven_service" 'running: root.pendingSearch !== null' 'Wallhaven search scheduler must sleep when no search is pending'
require "$wallhaven_service" 'running: root._tagCountQueue && root._tagCountQueue.length > 0' 'Wallhaven tag-count scheduler must sleep with an empty queue'
require "$wallhaven_service" 'running: root.tagQueue && root.tagQueue.length > 0' 'Wallhaven tag-detail scheduler must sleep with an empty queue'
reject "$wallhaven_service" 'running: root._active || (root.pendingSearch !== null)' 'Opening Sidebar Left must not start idle Wallhaven search polling'
reject "$wallhaven_service" 'running: root._active || (root._tagCountQueue' 'Opening Sidebar Left must not start idle Wallhaven tag-count polling'
reject "$wallhaven_service" 'running: root._active || ((root.tagQueue' 'Opening Sidebar Left must not start idle Wallhaven tag-detail polling'
require "$sidebar_ai" 'layer.enabled: root.visible && GlobalStates.sidebarLeftOpen' 'AI history mask must sleep with the sidebar'
require "$sidebar_news" 'property bool presentationActive: true' 'News view must expose a host lifecycle gate'
require "$sidebar_news" 'visible: root.presentationActive && NewsService.loading && NewsService.articles.length === 0' 'Hidden News tab must stop LoadingText animations'
require "$sidebar_news" 'loading: root.presentationActive' 'Hidden News tab must stop its loading gear animation'
require "$sidebar_news" 'running: root.presentationActive && NewsService.loading' 'Hidden News tab must stop refresh icon rotation'
require "$sidebar_left_content" '&& root.selectedTabId === "news"' 'Sidebar Left must power News animations only for the selected tab'
require "$sidebar_left_content" '&& root.selectedTabId === "anime"' 'Sidebar Left must power Anime animations only for the selected tab'
require "$sidebar_left_content" '&& root.selectedTabId === "animeSchedule"' 'Sidebar Left must power Anime Schedule animations only for the selected tab'
require "$sidebar_quick_wallpaper" 'layer.enabled: root.visible && GlobalStates.sidebarLeftOpen' 'Quick Wallpaper masks must sleep with the sidebar'
require "$status_rings" 'GlobalStates.sidebarLeftOpen && ring.visible' 'Status rings must expose explicit sidebar presentation state'
require "$status_rings" 'onProgressValueChanged: canvas.queuePaint()' 'Hidden status-ring value updates must use the lifecycle-gated paint path'
require "$status_rings" 'onPresentationActiveChanged(): void' 'Status rings must repaint their latest values when the sidebar returns'
status_ring_animation_gates="$(grep -Fc 'enabled: ring.presentationActive && Appearance.animationsEnabled' "$status_rings")"
if (( status_ring_animation_gates != 2 )); then
    fail "Status ring progress animations must both sleep with Sidebar Left, found $status_ring_animation_gates gates"
fi
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
require "$dash_media" 'positionUpdatesActive: root.presentationActive && root.visible' 'Hidden Dashboard media must pause retained PlayerControl position refreshes'
require "$dash_media" 'visible: root.presentationActive && root.visible' 'Hidden Dashboard PlayerControl must stop visibility-aware child animations while remaining resident'
require "$player_control" 'property bool positionUpdatesActive: true' 'PlayerControl must expose an opt-in lifecycle gate without changing existing callers'
require "$player_control" 'running: root.positionUpdatesActive' 'PlayerControl position timer must honor the host lifecycle gate'
require "$player_control" 'animateWave: root.positionUpdatesActive && root.effectiveIsPlaying' 'PlayerControl wavy progress must honor the host lifecycle gate'
require "$player_control" 'onPositionUpdatesActiveChanged:' 'PlayerControl must refresh position immediately when lifecycle updates resume'
require "$player_control" 'layer.enabled: root.visible' 'Hidden retained PlayerControl must release its rounded-mask FBO'
require "$media_cross_slide" 'layer.enabled: root.visible' 'Hidden retained media artwork must release its rounded-mask FBO'
require "$equalizer_panel" 'if (root.active && analyzerCanvas.visible)' 'Equalizer Canvas paint requests must sleep outside active presentation'
require "$equalizer_panel" 'running: root.active && analyzerCanvas.visible' 'Equalizer live graph must keep one 33 ms presentation cadence'
reject "$equalizer_panel" 'target: eqCava' 'Equalizer must not schedule a second Canvas paint stream from CAVA sample signals'
equalizer_direct_paints="$(grep -Fc 'analyzerCanvas.requestPaint()' "$equalizer_panel")"
if (( equalizer_direct_paints != 1 )); then
    fail "Equalizer Canvas must centralize direct repaint scheduling, found $equalizer_direct_paints direct sites"
fi
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

require "$shell_updates" 'id: resumeStatusProbe' 'ShellUpdates restart recovery must probe the status marker in-process before spawning validation'
require "$shell_updates" 'onTriggered: root._probeResumeStatusFile()' 'ShellUpdates startup recovery must avoid unconditional shell startup'
reject "$shell_updates" 'onTriggered: updateResumeReader.running = true' 'ShellUpdates must not spawn the resume shell when no status marker exists'


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
reject "$directory_icon" 'command: ["file", "--mime"' 'DirectoryIcon must not spawn one MIME process per item'
reject "$sysmon_widget" 'command: ["/usr/bin/cat", "/proc/net/dev"]' 'SysMon must reuse shared ResourceUsage network telemetry'
require "$sysmon_widget" 'ResourceUsage.networkRxBytesPerSec' 'SysMon network receive rate must come from ResourceUsage'
require "$sysmon_widget" 'ResourceUsage.networkTxBytesPerSec' 'SysMon network transmit rate must come from ResourceUsage'
require "$graph_widget" 'onValuesChanged: root._queuePaint()' 'Hidden retained Graph canvases must not repaint on every history sample'
require "$graph_widget" 'onVisibleChanged: root._queuePaint()' 'Graph canvases must repaint the latest history when presented again'
require "$graph_widget" 'if (root.visible)' 'Graph repaint scheduling must be visibility-gated'
require "$overlay_resources" 'layer.enabled: root.visible' 'Hidden Resources overlay must release its rounded graph mask FBO'
require "$overlay_floating_image" 'layer.enabled: root.visible' 'Hidden unpinned Floating Image must release its rounded-mask FBO'
require "$overlay_floating_image" 'playing: root.visible && status === Image.Ready' 'Hidden unpinned Floating Image must stop animated image playback'
require "$overlay_taskbar" 'GlobalStates.overlayOpen || root.opacity > 0.001' 'Overlay taskbar heavy resources must stay live through exit fade only'
require "$overlay_taskbar" 'layer.enabled: root.presentationActive && Appearance.angelEverywhere' 'Hidden Overlay taskbar must release its Angel mask FBO'
require "$overlay_taskbar" 'visible: root.presentationActive && Appearance.angelEverywhere' 'Hidden Overlay taskbar must release its fullscreen Angel wallpaper source'
require "$overlay_taskbar" 'layer.enabled: root.presentationActive && Appearance.effectsEnabled && Appearance.angelEverywhere' 'Hidden Overlay taskbar must release its Angel blur FBO'
require "$overlay_taskbar" 'visible: root.presentationActive && Appearance.regaliaEverywhere' 'Hidden Overlay taskbar must suspend retained Regalia presentation work'
overlay_visibility_animation_gates="$(grep -Fc 'enabled: root.visible' "$styled_overlay_widget")"
if (( overlay_visibility_animation_gates != 2 )); then
    fail "Retained overlay opacity transitions must both sleep while hidden, found $overlay_visibility_animation_gates lifecycle gates"
fi
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

require "$themes_config" 'shopt -s nullglob; files=(' 'saved-theme discovery must batch matching files before parsing'
require "$themes_config" 'input_filename | split("/")[-1] | rtrimstr(".json")' 'saved-theme discovery must derive names inside the batched jq process'
require "$themes_config" '"\${files[@]}"' 'saved-theme discovery must feed all theme files to one jq invocation'
reject "$themes_config" '/usr/bin/basename "$f" .json' 'saved-theme discovery must not spawn basename per theme'
reject "$themes_config" 'for f in "${root.savedThemesDir}"/*.json' 'saved-theme discovery must not restore per-file parser fan-out'
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
