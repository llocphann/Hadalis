//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env INIR_STANDALONE_WINDOW=1
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings
import qs.modules.abyss.looks

ApplicationWindow {
    id: root
    readonly property int previewWidth: Number(Quickshell.env("WULL_SETTINGS_WIDTH") || 1040)
    readonly property int previewHeight: Number(Quickshell.env("WULL_SETTINGS_HEIGHT") || 960)
    width: previewWidth
    height: previewHeight
    visible: true
    title: "Wull Companion settings preview"
    color: Appearance.colors.colLayer1Base
    readonly property string phase: Quickshell.env("WULL_SETTINGS_PHASE") || "preview"
    readonly property string capturePath: Quickshell.env("WULL_SETTINGS_CAPTURE") || ""
    property int bootTicks: 0

    function require(condition, message): void {
        if (!condition) {
            console.error("WULL_SETTINGS_CHECK=FAIL " + message)
            Qt.quit()
            throw new Error(message)
        }
    }

    function control(item, name) {
        if (item.objectName === name) return item
        for (const child of item.children ?? []) {
            const found = root.control(child, name)
            if (found) return found
        }
        return null
    }

    function choose(name, index): void {
        const choice = root.control(page, name + "Control")
        root.require(choice !== null, name + " control missing")
        choice.activated(index)
    }

    function toggle(name, value): void {
        const choice = root.control(page, name)
        root.require(choice !== null, name + " control missing")
        choice.toggledByUser(value)
    }

    function slide(name, value): void {
        const slider = root.control(page, name + "Control")
        root.require(slider !== null, name + " control missing")
        slider.value = value
        slider.moved()
    }

    function verifySaved(): void {
        const saved = page.preferences
        root.require(saved.enabled && !saved.interactive && saved.hideInFullscreen, "switches did not persist")
        root.require(saved.personality === "calm" && saved.appearanceFrequency === "occasional", "behavior did not persist")
        root.require(!saved.animationsEnabled && !saved.effectsEnabled, "render policy did not persist")
        root.require(saved.renderQuality === "quality", "render quality did not persist")
        root.require(Math.abs(saved.translucency - 0.24) < 0.001, "translucency did not persist")
        root.require(Math.abs(saved.size - 1.27) < 0.001, "size did not persist")
        root.require(saved.output === "" && saved.edge === "auto" && saved.along === .72, "old placement pinned Wull")
        for (const name of ["companionOutput","companionEdge","companionPosition"])
            root.require(root.control(page,name)===null,"fixed placement control remains")
        const preview = root.control(page, "companionPreview")
        root.require(!preview.motionEnabled && !preview.effectsEnabled && preview.motionScale === 0.55, "preview did not follow persisted policy")
        root.require(Math.abs(preview.translucency - 0.24) < 0.001, "preview translucency binding lost")
        root.require(SettingsPageRegistry.pageIndexForKey("companion") === 37, "stable route missing")
        root.require(SettingsPageRegistry.searchIndex().some(entry => entry.pageIndex === 37), "search route missing")
    }

    Rectangle {
        id: board
        // Niri may tile the native window to another size. Capture the fixed
        // board so both desktop-width and narrow-page layouts are exercised.
        width: root.previewWidth
        height: root.previewHeight
        color: Appearance.colors.colLayer1Base
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12
            RowLayout {
                Layout.fillWidth: true
                MaterialSymbol { text: "water_drop"; iconSize: 27; color: Appearance.colors.colPrimary }
                StyledText { text: "Settings  /  Abyss  /  Companion"; font.pixelSize: 19; Layout.fillWidth: true }
            }
            CompanionConfig { id: page; Layout.fillWidth: true; Layout.fillHeight: true }
        }
    }

    Timer {
        id: boot
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            if (!Config.ready) {
                root.require(++root.bootTicks < 80, "config startup timeout")
                return
            }
            stop()
            Appearance.colors.colPrimary = "#478dff"
            if (root.phase === "write") {
                root.require(page.preferences.personality === "balanced"
                    && page.preferences.appearanceFrequency === "always"
                    && page.preferences.renderQuality === "balanced"
                    && page.preferences.translucency === 0.16
                    && page.preferences.animationsEnabled && page.preferences.effectsEnabled,
                    "new defaults were not available to existing configurations")
                root.toggle("companionEnabled", true)
                root.toggle("companionInteractive", false)
                root.toggle("companionFullscreen", true)
                root.choose("companionPersonality", 0)
                root.choose("companionFrequency", 2)
                root.toggle("companionMotion", false)
                root.toggle("companionEffects", false)
                root.choose("companionQuality", 2)
                root.slide("companionTranslucency", 0.24)
                root.slide("companionSize", 1.27)
                // Simulate an old persisted config; it must no longer pin Wull.
                page.setPreference("edge", "right")
                page.setPreference("along", 0.41)
                page.setPreference("output", "disconnected-test-output")
                Qt.callLater(() => {
                    root.verifySaved()
                    Config.flushWrites()
                    saveExit.start()
                })
            } else {
                if (root.phase === "read") {
                    root.verifySaved()
                    root.control(page, "companionReset").clicked()
                }
                Qt.callLater(() => {
                    root.require(!page.preferences.enabled && page.preferences.personality === "balanced"
                        && page.preferences.appearanceFrequency === "always" && page.preferences.effectsEnabled
                        && page.preferences.translucency === 0.16,
                        "reset/default policy mismatch")
                    page.activeSection = Quickshell.env("WULL_SETTINGS_SECTION") || "behavior"
                    root.choose("companionPersonality", 2)
                    root.choose("companionFrequency", 2)
                    const quality = Quickshell.env("WULL_SETTINGS_QUALITY") || "quality"
                    root.choose("companionQuality", ["performance", "balanced", "quality"].indexOf(quality))
                    capture.start()
                })
            }
        }
    }
    Timer {
        id: saveExit
        interval: 700
        onTriggered: { console.log("WULL_SETTINGS_PERSISTENCE=WRITTEN"); Qt.quit() }
    }
    Timer {
        id: capture
        interval: 1200
        onTriggered: {
            const preview = root.control(page, "companionPreview")
            root.require(preview.materialReady && preview.effectsEnabled && preview.motionScale === 1.35, "live liquid preview unavailable")
            root.require(preview.renderQuality === (Quickshell.env("WULL_SETTINGS_QUALITY") || "quality"), "preview quality binding lost")
            root.require(preview.accentColor.toString() === AbyssStyle.accent.toString(), "live theme binding lost")
            root.require(board.grabToImage(result => {
                root.require(result.saveToFile(root.capturePath), "capture save failed")
                console.log("WULL_SETTINGS_CAPTURE=SAVED")
                Qt.quit()
            }), "capture unavailable")
        }
    }
}
