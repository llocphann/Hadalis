pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.abyss.bar
import qs.modules.abyss.looks
import "looks/AbyssGeometry.js" as Geometry

Scope {
    id: root
    property var revealedBars: ({})
    function setBarRevealed(name, value): void {
        const next = Object.assign({},revealedBars)
        if (value) next[name] = true
        else delete next[name]
        revealedBars = next
    }
    readonly property string barEdge: Geometry.edge(Config.options?.bar?.vertical ?? false, Config.options?.bar?.bottom ?? false)
    function barOnOutput(name): bool {
        return (Config.options?.enabledPanels ?? []).includes("abyssBar")
            && GlobalStates.barOpen
            && (!(Config.options?.bar?.autoHide?.enable ?? false)
                || root.revealedBars[name]
                || (GlobalStates.superDown && (Config.options?.bar?.autoHide?.showWhenPressingSuper ?? true))
                || ((GlobalStates.abyssPopupKind.length > 0 || GlobalStates.mediaControlsOpen)
                    && GlobalStates.resolveOutputName(GlobalStates.abyssPopupTargetOutput,[]) === name))
            && Geometry.targets(name, Config.options?.bar?.screenList ?? [], Quickshell.screens.map(s => s.name))
    }
    function outputInsets(name, reservation = false) {
        return Geometry.insets(AbyssStyle.perimeterThickness, root.barEdge, AbyssStyle.barThickness, root.barOnOutput(name) && (!reservation || !(Config.options?.bar?.autoHide?.enable ?? false)))
    }
    Connections {
        target: GlobalStates
        function onClipboardOpenChanged(): void {
            if (GlobalStates.clipboardOpen)
                GlobalStates.abyssClipboardTargetOutput = GlobalStates.resolveOutputName("",[])
        }
    }
    AbyssOsdController {}
    Component.onCompleted: Notifications.ensureInitialized()
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: window
            required property var modelData
            readonly property string outputName: modelData?.name ?? ""
            readonly property bool fullscreenCovered: GameMode.hasFullscreenOnOutput(outputName)
            readonly property bool presented: !GlobalStates.screenLocked
                && (!fullscreenCovered || (Config.options?.abyss?.perimeter?.visibleInFullscreen ?? false))
            screen: modelData
            // Keep the Top surface mapped across fullscreen, preserving stack order.
            visible: Config.ready && !GlobalStates.screenLocked
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            WlrLayershell.namespace: "hadalis:abyss-perimeter"
            WlrLayershell.layer: window.fullscreenCovered && window.presented ? WlrLayer.Overlay : WlrLayer.Top
            WlrLayershell.keyboardFocus: !window.presented || !field.ready || GlobalStates.regionSelectorOpen
                ? WlrKeyboardFocus.None
                : (aux.open && aux.ready) ? WlrKeyboardFocus.Exclusive
                : ((leftPanel.open && leftPanel.ready) || (rightPanel.open && rightPanel.ready) || (popup.open && popup.ready) || (notification.open && notification.ready && notification.contentKind === "center"))
                    ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            anchors { top: true; bottom: true; left: true; right: true }
            Item { id: emptyInput; width: 0; height: 0 }
            mask: Region {
                Region { item: window.presented && field.ready && bar.visible ? bar : emptyInput }
                Region { item: window.presented && revealTrigger.visible ? revealTrigger : emptyInput }
                Region { item: window.presented && dockTrigger.visible ? dockTrigger : emptyInput }
                Region { x: leftPanel.inputBounds.x; y: leftPanel.inputBounds.y; width: window.presented && field.ready ? leftPanel.inputBounds.width : 0; height: leftPanel.inputBounds.height }
                Region { x: rightPanel.inputBounds.x; y: rightPanel.inputBounds.y; width: window.presented && field.ready ? rightPanel.inputBounds.width : 0; height: rightPanel.inputBounds.height }
                Region { x: popup.inputBounds.x; y: popup.inputBounds.y; width: window.presented && field.ready ? popup.inputBounds.width : 0; height: popup.inputBounds.height }
                Region { x: dock.inputBounds.x; y: dock.inputBounds.y; width: window.presented && field.ready ? dock.inputBounds.width : 0; height: dock.inputBounds.height }
                Region { x: notification.inputBounds.x; y: notification.inputBounds.y; width: window.presented && field.ready ? notification.inputBounds.width : 0; height: notification.inputBounds.height }
                Region { x: aux.inputBounds.x; y: aux.inputBounds.y; width: window.presented && field.ready ? aux.inputBounds.width : 0; height: aux.inputBounds.height }
            }
            function closePopup(): void {
                GlobalStates.abyssPopupKind = ""
                GlobalStates.mediaControlsOpen = false
            }
            Item {
                anchors.fill: parent
                focus: aux.open || leftPanel.open || rightPanel.open || popup.open
                Keys.onEscapePressed: {
                    window.closePopup()
                    GlobalStates.closeSidebarLeft()
                    GlobalStates.closeSidebarRight()
                    GlobalStates.clipboardOpen = false
                    GlobalStates.overviewOpen = false
                    GlobalStates.closeNotificationCenter()
                }
            }
            AbyssBar {
                id: bar
                outputName: window.outputName
                edge: root.barEdge
                visible: window.presented && field.ready && root.barOnOutput(window.outputName)
                x: edge === "right" ? window.width-width : 0
                y: edge === "bottom" ? window.height-height : 0
                width: vertical ? AbyssStyle.barThickness : window.width
                height: vertical ? window.height : AbyssStyle.barThickness
                HoverHandler { id: barHover; onHoveredChanged: { if (hovered) { barClose.stop(); root.setBarRevealed(window.outputName,true) } else barClose.restart() } }
                onPopupRequested: (kind,along) => {
                    const same = (GlobalStates.abyssPopupKind === kind || (kind === "media" && GlobalStates.mediaControlsOpen))
                        && GlobalStates.abyssPopupTargetOutput === window.outputName
                    window.closePopup()
                    if (!same) {
                        GlobalStates.abyssPopupTargetOutput = window.outputName
                        GlobalStates.abyssPopupAlong = along
                        if (kind === "media") GlobalStates.mediaControlsOpen = true
                        else GlobalStates.abyssPopupKind = kind
                    }
                }
            }
            Item {
                id: revealTrigger
                visible: window.presented && field.ready && (Config.options?.bar?.autoHide?.enable ?? false)
                    && GlobalStates.barOpen && (Config.options?.enabledPanels ?? []).includes("abyssBar")
                    && Geometry.targets(window.outputName,Config.options?.bar?.screenList ?? [],Quickshell.screens.map(s => s.name))
                x: root.barEdge === "right" ? window.width-width : 0
                y: root.barEdge === "bottom" ? window.height-height : 0
                width: Geometry.horizontal(root.barEdge) ? window.width : AbyssStyle.perimeterThickness
                height: Geometry.horizontal(root.barEdge) ? AbyssStyle.perimeterThickness : window.height
                HoverHandler { id: revealHover; onHoveredChanged: { if (hovered) root.setBarRevealed(window.outputName,true); else barClose.restart() } }
            }
            Timer {
                id: barClose; interval: 220; repeat: false
                onTriggered: if (!barHover.hovered && !revealHover.hovered && !popup.open) root.setBarRevealed(window.outputName,false)
            }
            property real barProgress: root.barOnOutput(window.outputName) ? 1 : 0
            Behavior on barProgress {
                enabled: AbyssStyle.motionEnabled
                NumberAnimation { duration: AbyssStyle.motionNormal; easing.type: Easing.OutCubic }
            }
            readonly property var nativeInsets: Geometry.insets(AbyssStyle.perimeterThickness,root.barEdge,
                AbyssStyle.perimeterThickness+(AbyssStyle.barThickness-AbyssStyle.perimeterThickness)*barProgress,barProgress > 0.001)
            readonly property var sideObstacles: [leftPanel,rightPanel].filter(body => body.progress > 0.001).map(body => body.record)
            AbyssBodyHost {
                id: leftPanel
                anchors.fill: parent
                edge: ShellLayoutController.sidebarAssignments().featureSidebar
                outputName: window.outputName
                open: window.presented && field.ready && (Config.options?.enabledPanels ?? []).includes("abyssSidebarLeft")
                    && GlobalStates.sidebarLeftOpen && GlobalStates.sidebarLeftPresentationOutput === window.outputName
                    && !(popup.open && popup.edge === edge)
                    && !(notification.centerOnOutput && edge === "right")
                edgeInsets: window.nativeInsets
                along: edgeInsets.top+36
                span: window.height-edgeInsets.top-edgeInsets.bottom-72
                depth: GlobalStates.sidebarLeftExpanded ? 560 : 370
                source: "content/AbyssLeftContent.qml"
                onCloseRequested: GlobalStates.closeSidebarLeft()
            }
            AbyssBodyHost {
                id: rightPanel
                anchors.fill: parent
                edge: ShellLayoutController.sidebarAssignments().systemSidebar
                outputName: window.outputName
                open: window.presented && field.ready && (Config.options?.enabledPanels ?? []).includes("abyssSidebarRight")
                    && GlobalStates.sidebarRightOpen && GlobalStates.sidebarRightPresentationOutput === window.outputName
                    && !(popup.open && popup.edge === edge)
                    && !(notification.centerOnOutput && edge === "right")
                edgeInsets: window.nativeInsets
                along: edgeInsets.top+36
                span: window.height-edgeInsets.top-edgeInsets.bottom-72
                depth: 370
                source: "content/AbyssRightContent.qml"
                onCloseRequested: GlobalStates.closeSidebarRight()
            }
            AbyssBodyHost {
                id: popup
                anchors.fill: parent
                edge: root.barEdge
                outputName: window.outputName
                open: window.presented && field.ready && (Config.options?.enabledPanels ?? []).includes("abyssPopup")
                    && (GlobalStates.abyssPopupKind.length > 0 || GlobalStates.mediaControlsOpen)
                    && GlobalStates.resolveOutputName(GlobalStates.abyssPopupTargetOutput,[]) === window.outputName
                edgeInsets: window.nativeInsets
                along: GlobalStates.abyssPopupAlong-span/2
                span: Geometry.horizontal(edge) ? 390 : 440
                depth: Geometry.horizontal(edge) ? 380 : 390
                obstacles: window.sideObstacles
                contentKind: GlobalStates.abyssPopupKind || "media"
                source: "content/AbyssPopupContent.qml"
                onCloseRequested: window.closePopup()
            }
            property bool dockHovered: false
            readonly property string dockEdge: ["top","bottom","left","right"].includes(Config.options?.dock?.position) ? Config.options.dock.position : "bottom"
            AbyssBodyHost {
                id: dock
                anchors.fill: parent
                edge: window.dockEdge
                outputName: window.outputName
                open: window.presented && field.ready && GlobalStates.shellEntryReady && !GlobalStates.widgetEditMode
                    && (Config.options?.enabledPanels ?? []).includes("abyssDock") && (Config.options?.dock?.enable ?? true)
                    && Geometry.targets(window.outputName,Config.options?.dock?.screenList ?? [],Quickshell.screens.map(s => s.name))
                    && !aux.open && !(popup.open && popup.edge === edge)
                    && (((Config.options?.dock?.pinnedOnStartup ?? false) && !(Config.options?.dock?.hoverToReveal ?? false)) || window.dockHovered
                        || ((Config.options?.dock?.showOnDesktop ?? true) && !ToplevelManager.activeToplevel?.activated))
                edgeInsets: window.nativeInsets
                span: Math.min(640,Math.max(140,TaskbarApps.apps.length*48+80))
                along: (Geometry.horizontal(edge) ? window.width : window.height)/2-span/2
                depth: AbyssStyle.dockThickness
                padding: 12
                obstacles: window.sideObstacles.concat(notification.progress > 0.001 ? [notification.record] : []).concat(popup.progress > 0.001 ? [popup.record] : [])
                source: "content/AbyssDockContent.qml"
                HoverHandler { id: dockHover; parent: dock.contentItem; onHoveredChanged: { if (hovered) { dockClose.stop(); window.dockHovered = true } else dockClose.restart() } }
            }
            Item {
                id: dockTrigger
                visible: window.presented && field.ready && (Config.options?.dock?.hoverToReveal ?? false)
                    && (Config.options?.dock?.enable ?? true) && (Config.options?.enabledPanels ?? []).includes("abyssDock")
                    && Geometry.targets(window.outputName,Config.options?.dock?.screenList ?? [],Quickshell.screens.map(s => s.name))
                width: Geometry.horizontal(window.dockEdge) ? dock.span : AbyssStyle.perimeterThickness
                height: Geometry.horizontal(window.dockEdge) ? AbyssStyle.perimeterThickness : dock.span
                x: Geometry.horizontal(window.dockEdge) ? (window.width-width)/2 : window.dockEdge === "left" ? 0 : window.width-width
                y: Geometry.horizontal(window.dockEdge) ? window.dockEdge === "top" ? 0 : window.height-height : (window.height-height)/2
                HoverHandler { id: dockRevealHover; onHoveredChanged: { if (hovered) { dockClose.stop(); window.dockHovered = true } else dockClose.restart() } }
            }
            Timer { id: dockClose; interval: 260; repeat: false; onTriggered: if (!dockRevealHover.hovered && !dockHover.hovered) window.dockHovered = false }
            AbyssBodyHost {
                id: aux
                anchors.fill: parent
                edge: "bottom"
                outputName: window.outputName
                open: window.presented && field.ready && ((GlobalStates.clipboardOpen && (Config.options?.enabledPanels ?? []).includes("abyssClipboard")
                    && GlobalStates.resolveOutputName(GlobalStates.abyssClipboardTargetOutput,[]) === window.outputName)
                    || (GlobalStates.overviewOpen && (Config.options?.enabledPanels ?? []).includes("abyssOverview") && GlobalStates.overviewPresentationOutput === window.outputName))
                edgeInsets: window.nativeInsets
                span: 640
                along: window.width/2-span/2
                depth: window.height*0.42
                obstacles: window.sideObstacles
                source: GlobalStates.clipboardOpen ? "content/AbyssClipboardContent.qml" : "content/AbyssLauncherContent.qml"
                onCloseRequested: { GlobalStates.clipboardOpen = false; GlobalStates.overviewOpen = false }
            }
            AbyssBodyHost {
                id: notification
                anchors.fill: parent
                readonly property bool centerOnOutput: GlobalStates.notificationCenterOpen && GlobalStates.notificationCenterPresentationOutput === window.outputName
                readonly property string position: Config.options?.notifications?.position ?? "topRight"
                edge: centerOnOutput ? "right" : position.startsWith("bottom") ? "bottom" : "top"
                outputName: window.outputName
                open: window.presented && field.ready && (centerOnOutput && (Config.options?.enabledPanels ?? []).includes("abyssNotificationCenter")
                    || (!GlobalStates.notificationCenterOpen && !popup.open && !aux.open && !Notifications.popupInhibited && Notifications.popupList.length > 0
                        && (Config.options?.enabledPanels ?? []).includes("abyssNotificationPopup")
                        && Geometry.targets(window.outputName,Config.options?.notifications?.screenList ?? [],Quickshell.screens.map(s => s.name))))
                edgeInsets: window.nativeInsets
                span: centerOnOutput ? window.height-edgeInsets.top-edgeInsets.bottom-72 : 360
                along: centerOnOutput ? edgeInsets.top+36 : position.endsWith("Left") ? 40 : window.width-span-40
                depth: centerOnOutput ? 390 : Math.min(340,Notifications.popupList.length*130+48)
                obstacles: centerOnOutput ? [] : window.sideObstacles.concat(popup.open ? [popup.record] : [])
                contentKind: centerOnOutput ? "center" : "popup"
                source: "content/AbyssNotificationsContent.qml"
                onCloseRequested: GlobalStates.closeNotificationCenter()
            }
            AbyssBodyHost {
                id: osd
                anchors.fill: parent
                edge: root.barEdge === "right" ? "left" : "right"
                outputName: window.outputName
                open: window.presented && field.ready && (Config.options?.enabledPanels ?? []).includes("abyssOnScreenDisplay")
                    && (GlobalStates.osdVolumeOpen || GlobalStates.osdBrightnessOpen || GlobalStates.osdMicOpen || GlobalStates.osdMediaOpen || GlobalStates.osdKeyboardLayoutOpen)
                    && Geometry.targets(window.outputName,Config.options?.osd?.screenList ?? [],Quickshell.screens.map(s => s.name))
                    && !rightPanel.open && !leftPanel.open && !notification.open
                edgeInsets: window.nativeInsets
                span: 120
                along: window.height/2-span/2
                depth: 240
                source: "content/AbyssOsdContent.qml"
            }
            AbyssField {
                id: field
                outputName: window.outputName
                renderScale: window.modelData?.devicePixelRatio ?? 1
                z: -1
                anchors.fill: parent
                visible: window.presented
                edgeInsets: window.nativeInsets
                records: (bar.visible ? bar.deformations.map(rec => Geometry.panel(window.width,window.height,edgeInsets,root.barEdge,rec.along+12,rec.span-24,rec.depth,1,0)) : [])
                    .concat([leftPanel,rightPanel,popup,dock,aux,notification,osd].filter(body => body.progress > 0.001).map(body => body.record))
            }
        }
    }
    component Reservation: PanelWindow {
        id: reservation
        required property var modelData
        required property string edge
        readonly property bool horizontal: Geometry.horizontal(edge)
        readonly property bool mapped: Config.ready && !GlobalStates.screenLocked
            && !GameMode.hasFullscreenOnOutput(modelData?.name ?? "")
        readonly property bool persistentDock: (Config.options?.enabledPanels ?? []).includes("abyssDock")
            && (Config.options?.dock?.enable ?? true) && (Config.options?.dock?.pinnedOnStartup ?? false)
            && !(Config.options?.dock?.hoverToReveal ?? false) && !GlobalStates.widgetEditMode
            && Geometry.targets(modelData?.name ?? "",Config.options?.dock?.screenList ?? [],Quickshell.screens.map(s => s.name))
        readonly property string dockEdge: ["top","bottom","left","right"].includes(Config.options?.dock?.position) ? Config.options.dock.position : "bottom"
        readonly property real thickness: root.outputInsets(modelData?.name ?? "",true)[edge]
            + (root.barOnOutput(modelData?.name ?? "") && !(Config.options?.bar?.autoHide?.enable ?? false) && edge === root.barEdge ? 5 : 0)
            + (persistentDock && edge === dockEdge ? AbyssStyle.dockThickness : 0)
        screen: modelData
        visible: mapped
        color: "transparent"
        exclusiveZone: mapped ? thickness : 0
        implicitWidth: horizontal ? 1 : thickness
        implicitHeight: horizontal ? thickness : 1
        WlrLayershell.namespace: "hadalis:abyss-reservation-" + edge
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors {
            top: edge !== "bottom"
            bottom: edge !== "top"
            left: edge !== "right"
            right: edge !== "left"
        }
        mask: Region {}
    }
    Variants { model: Quickshell.screens; Reservation { edge: "top" } }
    Variants { model: Quickshell.screens; Reservation { edge: "bottom" } }
    Variants { model: Quickshell.screens; Reservation { edge: "left" } }
    Variants { model: Quickshell.screens; Reservation { edge: "right" } }
}
