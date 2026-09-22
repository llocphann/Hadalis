pragma Singleton
import QtQuick
import Quickshell
import qs.modules.common

Singleton {
    id: root

    // Runtime declarations are owned by the shell loaders that actually decide
    // whether a surface exists. This registry is the migration path away from
    // the temporary static catalog below; it deliberately records lifecycle
    // truth without forcing LazyLoader.item while asynchronous loading is active.
    property var declarations: ({})
    property int declarationSerial: 0

    function _kebabCase(value: string): string {
        return String(value ?? "")
            .replace(/([A-Z]+)([A-Z][a-z])/g, "$1-$2")
            .replace(/([a-z0-9])([A-Z])/g, "$1-$2")
            .replace(/[_\s]+/g, "-")
            .toLowerCase()
    }

    function targetIdForPanel(panelId: string): string {
        const id = String(panelId ?? "")
        if (id === "iiSidebarLeft")
            return "sidebar/left"
        if (id === "iiSidebarRight")
            return "sidebar/right"
        if (id.startsWith("ii"))
            return root._kebabCase(id.slice(2))
        if (id.startsWith("w"))
            return "waffle/" + root._kebabCase(id.slice(1))
        return root._kebabCase(id)
    }

    function labelForPanel(panelId: string): string {
        const id = String(panelId ?? "")
        const waffle = id.startsWith("w") && !id.startsWith("ii")
        const bare = id.startsWith("ii") ? id.slice(2)
            : waffle ? id.slice(1) : id
        const spaced = bare
            .replace(/([A-Z]+)([A-Z][a-z])/g, "$1 $2")
            .replace(/([a-z0-9])([A-Z])/g, "$1 $2")
            .trim()
        return waffle ? "Waffle " + spaced : spaced
    }

    function relativeSourcePath(rawSource): string {
        let source = String(rawSource ?? "")
        if (source.length === 0)
            return ""
        source = source.replace(/^file:\/\//, "")
        let shellRoot = String(Quickshell.shellPath(".") ?? "")
            .replace(/^file:\/\//, "")
            .replace(/\/$/, "")
        if (source.startsWith(shellRoot + "/"))
            return source.slice(shellRoot.length + 1)
        return source
    }

    function registerDeclaration(registration): string {
        if (!registration)
            return ""
        const token = root.epoch + ":declaration:" + (++root.declarationSerial)
        const next = Object.assign({}, root.declarations)
        next[token] = registration
        root.declarations = next
        root._event(
            "declared",
            String(registration.targetId ?? registration.panelId ?? ""),
            token)
        return token
    }

    function unregisterDeclaration(
        token: string, registration
    ): void {
        if (String(token ?? "").length === 0
                || root.declarations[token] !== registration)
            return
        const targetId = String(registration?.targetId ?? "")
        const next = Object.assign({}, root.declarations)
        delete next[token]
        root.declarations = next
        root._event("declaration-stale", targetId, token)
    }

    function touchDeclaration(token: string): void {
        if (String(token ?? "").length === 0
                || !root.declarations[token])
            return
        root.revision++
    }

    function discoveredDescriptors(): var {
        const byTarget = ({})
        for (const token of Object.keys(root.declarations)) {
            const declaration = root.declarations[token]
            const descriptor = declaration?.descriptorSnapshot?.() ?? null
            if (!descriptor || String(descriptor.targetId ?? "").length === 0)
                continue
            const current = byTarget[descriptor.targetId]
            const nextRank = Number(descriptor.stateRank ?? 0)
            const currentRank = Number(current?.stateRank ?? -1)
            if (!current || nextRank > currentRank)
                byTarget[descriptor.targetId] = descriptor
        }
        return Object.keys(byTarget)
            .map(key => byTarget[key])
            .sort((a, b) => String(a.label).localeCompare(String(b.label)))
    }

    readonly property var discoveredCatalog: {
        const dependency = root.revision
        if (dependency < 0)
            return []
        return root.discoveredDescriptors()
    }

    // Shell-surface inventory. Reviewed IR can add deeper semantic graphs, but
    // every configured top-level panel/component still appears in Code Workflow
    // and gets a source-backed fallback graph.
    readonly property var catalog: [
        { targetId: "bar", label: "Bar", icon: "toolbar", kind: "surface", family: "ii", panelId: "iiBar", parentId: "", depth: 0, sourcePath: "modules/bar/BarContent.qml" },
        { targetId: "bar/media", label: "Bar · Media", icon: "music_note", kind: "component", family: "ii", panelId: "iiBar", parentId: "bar", depth: 1, sourcePath: "modules/bar/Media.qml" },
        { targetId: "bar/clock", label: "Bar · Clock", icon: "schedule", kind: "component", family: "ii", panelId: "iiBar", parentId: "bar", depth: 1, sourcePath: "modules/bar/ClockWidget.qml" },
        { targetId: "bar/resources", label: "Bar · Resources", icon: "memory", kind: "component", family: "ii", panelId: "iiBar", parentId: "bar", depth: 1, sourcePath: "modules/bar/Resources.qml" },

        { targetId: "background", label: "Background", icon: "wallpaper", kind: "surface", family: "ii", panelId: "iiBackground", parentId: "", depth: 0, sourcePath: "modules/background/Background.qml" },
        { targetId: "backdrop", label: "Backdrop", icon: "layers", kind: "surface", family: "ii", panelId: "iiBackdrop", parentId: "", depth: 0, sourcePath: "modules/background/Backdrop.qml" },
        { targetId: "control-panel", label: "Control Panel", icon: "tune", kind: "surface", family: "ii", panelId: "iiControlPanel", parentId: "", depth: 0, sourcePath: "modules/controlPanel/ControlPanel.qml" },
        { targetId: "dashboard", label: "Dashboard", icon: "dashboard", kind: "surface", family: "ii", panelId: "iiDashboard", parentId: "", depth: 0, sourcePath: "modules/dashboard/Dashboard.qml" },
        { targetId: "dock", label: "Dock", icon: "dock_to_bottom", kind: "surface", family: "ii", panelId: "iiDock", parentId: "", depth: 0, sourcePath: "modules/dock/Dock.qml" },
        { targetId: "media-controls", label: "Media Controls", icon: "music_video", kind: "surface", family: "ii", panelId: "iiMediaControls", parentId: "", depth: 0, sourcePath: "modules/mediaControls/MediaControls.qml" },
        { targetId: "notification-popup", label: "Notification Popup", icon: "notifications", kind: "surface", family: "ii", panelId: "iiNotificationPopup", parentId: "", depth: 0, sourcePath: "modules/notificationPopup/NotificationPopup.qml" },
        { targetId: "osd", label: "On-screen Display", icon: "display_settings", kind: "surface", family: "ii", panelId: "iiOnScreenDisplay", parentId: "", depth: 0, sourcePath: "modules/onScreenDisplay/OnScreenDisplay.qml" },
        { targetId: "sidebar/left", label: "Sidebar Left", icon: "left_panel_open", kind: "surface", family: "ii", panelId: "iiSidebarLeft", parentId: "", depth: 0, sourcePath: "modules/sidebarLeft/SidebarLeft.qml" },
        { targetId: "sidebar/right", label: "Sidebar Right", icon: "right_panel_open", kind: "surface", family: "ii", panelId: "iiSidebarRight", parentId: "", depth: 0, sourcePath: "modules/sidebarRight/SidebarRight.qml" },
        { targetId: "vertical-bar", label: "Vertical Bar", icon: "view_sidebar", kind: "surface", family: "ii", panelId: "iiVerticalBar", parentId: "", depth: 0, sourcePath: "modules/verticalBar/VerticalBar.qml" },
        { targetId: "shell-update", label: "Shell Update", icon: "system_update", kind: "surface", family: "ii", panelId: "iiShellUpdate", parentId: "", depth: 0, sourcePath: "modules/shellUpdate/ShellUpdateOverlay.qml" },

        { targetId: "boot-greeting", label: "Boot Greeting", icon: "waving_hand", kind: "surface", family: "shared", panelId: "iiBootGreeting", parentId: "", depth: 0, sourcePath: "modules/bootGreeting/BootGreeting.qml" },
        { targetId: "cheatsheet", label: "Cheatsheet", icon: "keyboard", kind: "surface", family: "shared", panelId: "iiCheatsheet", parentId: "", depth: 0, sourcePath: "modules/cheatsheet/Cheatsheet.qml" },
        { targetId: "osk", label: "On-screen Keyboard", icon: "keyboard", kind: "surface", family: "shared", panelId: "iiOnScreenKeyboard", parentId: "", depth: 0, sourcePath: "modules/onScreenKeyboard/OnScreenKeyboard.qml" },
        { targetId: "overlay", label: "Overlay", icon: "select_window", kind: "surface", family: "shared", panelId: "iiOverlay", parentId: "", depth: 0, sourcePath: "modules/ii/overlay/Overlay.qml" },
        { targetId: "overview", label: "Overview", icon: "overview_key", kind: "surface", family: "shared", panelId: "iiOverview", parentId: "", depth: 0, sourcePath: "modules/overview/Overview.qml" },
        { targetId: "region-selector", label: "Region Selector", icon: "crop_free", kind: "surface", family: "shared", panelId: "iiRegionSelector", parentId: "", depth: 0, sourcePath: "modules/regionSelector/RegionSelector.qml" },
        { targetId: "screen-corners", label: "Screen Corners", icon: "rounded_corner", kind: "surface", family: "shared", panelId: "iiScreenCorners", parentId: "", depth: 0, sourcePath: "modules/screenCorners/ScreenCorners.qml" },
        { targetId: "tiling-overlay", label: "Tiling Overlay", icon: "grid_view", kind: "surface", family: "shared", panelId: "iiTilingOverlay", parentId: "", depth: 0, sourcePath: "modules/tilingOverlay/TilingOverlay.qml" },
        { targetId: "wallpaper-selector", label: "Wallpaper Selector", icon: "image_search", kind: "surface", family: "shared", panelId: "iiWallpaperSelector", parentId: "", depth: 0, sourcePath: "modules/wallpaperSelector/WallpaperSelector.qml" },
        { targetId: "wallpaper-launcher", label: "Wallpaper Launcher", icon: "collections", kind: "surface", family: "shared", panelId: "iiWallpaperLauncher", parentId: "", depth: 0, sourcePath: "modules/wallpaperLauncher/WallpaperLauncher.qml" },
        { targetId: "coverflow-selector", label: "Coverflow Selector", icon: "view_carousel", kind: "surface", family: "shared", panelId: "iiCoverflowSelector", parentId: "", depth: 0, sourcePath: "modules/wallpaperSelector/WallpaperCoverflow.qml" },
        { targetId: "recording-osd", label: "Recording OSD", icon: "screen_record", kind: "surface", family: "shared", panelId: "iiRecordingOsd", parentId: "", depth: 0, sourcePath: "modules/recordingOsd/RecordingOsd.qml" },

        { targetId: "lock", label: "Lock Screen", icon: "lock", kind: "surface", family: "ii", panelId: "iiLock", parentId: "", depth: 0, sourcePath: "modules/lock/Lock.qml" },
        { targetId: "polkit", label: "Polkit", icon: "admin_panel_settings", kind: "surface", family: "ii", panelId: "iiPolkit", parentId: "", depth: 0, sourcePath: "modules/polkit/Polkit.qml" },
        { targetId: "session-screen", label: "Session Screen", icon: "power_settings_new", kind: "surface", family: "ii", panelId: "iiSessionScreen", parentId: "", depth: 0, sourcePath: "modules/sessionScreen/SessionScreen.qml" },
        { targetId: "clipboard", label: "Clipboard", icon: "content_paste", kind: "surface", family: "ii", panelId: "iiClipboard", parentId: "", depth: 0, sourcePath: "modules/clipboard/ClipboardPanel.qml" },

        { targetId: "waffle/bar", label: "Waffle Bar", icon: "toolbar", kind: "surface", family: "waffle", panelId: "wBar", parentId: "", depth: 0, sourcePath: "modules/waffle/bar/WaffleBar.qml" },
        { targetId: "waffle/background", label: "Waffle Background", icon: "wallpaper", kind: "surface", family: "waffle", panelId: "wBackground", parentId: "", depth: 0, sourcePath: "modules/waffle/background/WaffleBackground.qml" },
        { targetId: "waffle/backdrop", label: "Waffle Backdrop", icon: "layers", kind: "surface", family: "waffle", panelId: "wBackdrop", parentId: "", depth: 0, sourcePath: "modules/waffle/backdrop/WaffleBackdrop.qml" },
        { targetId: "waffle/start-menu", label: "Waffle Start Menu", icon: "apps", kind: "surface", family: "waffle", panelId: "wStartMenu", parentId: "", depth: 0, sourcePath: "modules/waffle/startMenu/WaffleStartMenu.qml" },
        { targetId: "waffle/action-center", label: "Waffle Action Center", icon: "settings_suggest", kind: "surface", family: "waffle", panelId: "wActionCenter", parentId: "", depth: 0, sourcePath: "modules/waffle/actionCenter/WaffleActionCenter.qml" },
        { targetId: "waffle/notification-center", label: "Waffle Notification Center", icon: "notifications_active", kind: "surface", family: "waffle", panelId: "wNotificationCenter", parentId: "", depth: 0, sourcePath: "modules/waffle/notificationCenter/WaffleNotificationCenter.qml" },
        { targetId: "waffle/notification-popup", label: "Waffle Notification Popup", icon: "notifications", kind: "surface", family: "waffle", panelId: "wNotificationPopup", parentId: "", depth: 0, sourcePath: "modules/waffle/notificationPopup/WaffleNotificationPopup.qml" },
        { targetId: "waffle/osd", label: "Waffle OSD", icon: "display_settings", kind: "surface", family: "waffle", panelId: "wOnScreenDisplay", parentId: "", depth: 0, sourcePath: "modules/waffle/onScreenDisplay/WaffleOSD.qml" },
        { targetId: "waffle/widgets", label: "Waffle Widgets", icon: "widgets", kind: "surface", family: "waffle", panelId: "wWidgets", parentId: "", depth: 0, sourcePath: "modules/waffle/widgets/WaffleWidgets.qml" },
        { targetId: "waffle/task-view", label: "Waffle Task View", icon: "view_quilt", kind: "surface", family: "waffle", panelId: "wTaskView", parentId: "", depth: 0, sourcePath: "modules/waffle/taskview/WaffleTaskView.qml" },
        { targetId: "waffle/lock", label: "Waffle Lock", icon: "lock", kind: "surface", family: "waffle", panelId: "wLock", parentId: "", depth: 0, sourcePath: "modules/lock/Lock.qml" },
        { targetId: "waffle/polkit", label: "Waffle Polkit", icon: "admin_panel_settings", kind: "surface", family: "waffle", panelId: "wPolkit", parentId: "", depth: 0, sourcePath: "modules/polkit/Polkit.qml" },
        { targetId: "waffle/session-screen", label: "Waffle Session Screen", icon: "power_settings_new", kind: "surface", family: "waffle", panelId: "wSessionScreen", parentId: "", depth: 0, sourcePath: "modules/sessionScreen/SessionScreen.qml" },
        { targetId: "waffle/clipboard", label: "Waffle Clipboard", icon: "content_paste", kind: "surface", family: "waffle", panelId: "", parentId: "", depth: 0, sourcePath: "modules/waffle/clipboard/WaffleClipboard.qml" },
        { targetId: "waffle/alt-switcher", label: "Waffle Alt Switcher", icon: "switch_access_shortcut", kind: "surface", family: "waffle", panelId: "", parentId: "", depth: 0, sourcePath: "modules/waffle/altSwitcher/WaffleAltSwitcher.qml" }
    ]

    readonly property string panelFamily:
        String(Config.options?.panelFamily ?? "ii")
    readonly property var enabledPanels:
        Config.options?.enabledPanels ?? []
    readonly property var activeCatalog: root.catalog.filter(descriptor => {
        const family = String(descriptor?.family ?? "shared")
        if (family !== "shared" && family !== root.panelFamily)
            return false
        const panelId = String(descriptor?.panelId ?? "")
        return panelId.length === 0 || root.enabledPanels.includes(panelId)
    })

    function isActiveTarget(targetId: string): bool {
        return root.activeCatalog.some(item => item.targetId === targetId)
    }

    readonly property string epoch: Date.now().toString() + "-" + Math.random().toString(36).slice(2)
    property var entries: ({})
    property var events: []
    property int serial: 0
    property int revision: 0

    function descriptor(targetId: string): var {
        return root.catalog.find(item => item.targetId === targetId) ?? null
    }

    function _event(kind: string, instanceId: string, token: string): void {
        root.events = root.events.concat([{ kind: kind, instanceId: instanceId, token: token }]).slice(-64)
        root.revision++
    }

    function attach(registration): string {
        const key = String(registration?.instanceId ?? "")
        if (key.length === 0 || !registration?.runtimeObject)
            return ""
        const current = root.entries[key]
        if (current && current !== registration)
            throw new Error("duplicate Code Workflow runtime instance: " + key)

        const next = Object.assign({}, root.entries)
        next[key] = registration
        root.entries = next
        const token = root.epoch + ":" + (++root.serial)
        root._event("resident", key, token)
        return token
    }

    function detach(instanceId: string, registration, token: string): void {
        if (root.entries[instanceId] !== registration)
            return
        const next = Object.assign({}, root.entries)
        delete next[instanceId]
        root.entries = next
        root._event("stale/unloading", instanceId, token)
    }

    function snapshot(): var {
        const outputs = Quickshell.screens.map(screen => screen.name)
        const records = []

        if (outputs.length === 0) {
            for (const descriptor of root.activeCatalog) {
                records.push({
                    targetId: descriptor.targetId, instanceId: "", output: "",
                    sourcePath: descriptor.sourcePath, depth: descriptor.depth,
                    state: "unloaded", runtimeToken: null, rect: null, values: null
                })
            }
        } else {
            for (const output of outputs) {
                for (const descriptor of root.activeCatalog) {
                    const key = descriptor.targetId + "@" + output
                    const registration = root.entries[key]
                    records.push({
                        targetId: descriptor.targetId,
                        instanceId: key,
                        output: output,
                        sourcePath: descriptor.sourcePath,
                        depth: descriptor.depth,
                        state: registration?.runtimeObject ? "resident" : "unloaded",
                        runtimeToken: registration?.token ?? null,
                        rect: registration ? registration.rectSnapshot() : null,
                        values: registration ? registration.safeValues() : null
                    })
                }
            }
        }
        return { epoch: root.epoch, outputs: outputs, records: records, events: root.events }
    }

    function hit(output: string, x: real, y: real): string {
        const candidates = root.snapshot().records.filter(record => {
            const rect = record.rect
            return record.output === output
                && record.state === "resident"
                && rect?.eligible
                && x >= rect.x && y >= rect.y
                && x < rect.x + rect.width
                && y < rect.y + rect.height
        })

        candidates.sort((a, b) =>
            b.depth - a.depth
            || a.rect.width * a.rect.height
                - b.rect.width * b.rect.height)

        return candidates.length > 0 ? candidates[0].instanceId : ""
    }
}
