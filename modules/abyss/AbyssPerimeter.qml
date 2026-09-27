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
import "looks/AbyssLayout.js" as ModuleLayout
import "looks/AbyssPresentation.js" as Presentation

Scope {
    id: root
    property string largeTargetOutput: GlobalStates.resolveOutputName("",[])
    readonly property string utilityKind: GlobalStates.sessionOpen ? "session" : GlobalStates.cheatsheetOpen ? "cheatsheet" : ShellUpdates.overlayOpen ? "update" : ""
    readonly property string utilityIdentifier: utilityKind === "session" ? "abyssSessionScreen" : utilityKind === "cheatsheet" ? "iiCheatsheet" : "iiShellUpdate"
    function closeUtility(): void {
        if (utilityKind === "session") GlobalStates.sessionOpen = false
        else if (utilityKind === "cheatsheet") GlobalStates.cheatsheetOpen = false
        else ShellUpdates.closeOverlay()
    }
    onUtilityKindChanged: if (utilityKind) largeTargetOutput = GlobalStates.resolveOutputName("",[])
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
        const result = Geometry.insets(AbyssStyle.perimeterThickness,root.barEdge,AbyssStyle.perimeterThickness,false)
        if (!root.barOnOutput(name) || (reservation && (Config.options?.bar?.autoHide?.enable ?? false))) return result
        const screen = Quickshell.screens.find(s => s.name === name)
        const vertical = !Geometry.horizontal(root.barEdge)
        const zones = Geometry.barZones((vertical ? Config.options?.bar?.verticalLayout : Config.options?.bar?.layout) ?? {},vertical,Config.options?.bar?.modules ?? {})
        const placements = ModuleLayout.resolve(Config.options?.abyss?.modules,name,ModuleLayout.seed(zones,root.barEdge,screen?.width ?? 1920,screen?.height ?? 1080))
        placements.filter(p => p.enabled).forEach(p => result[p.edge] = Math.max(AbyssStyle.barThickness,ModuleLayout.stripDepth(placements,p.edge,Object.assign({},ModuleLayout.optionsForOutput(Config.options?.abyss?.modules,name),{edgeThickness:AbyssStyle.perimeterThickness}),Appearance.fontSizeScale)))
        return result
    }
    Connections {
        target: GlobalStates
        function onDashboardOpenChanged(): void { if (GlobalStates.dashboardOpen) root.largeTargetOutput = GlobalStates.resolveOutputName("",[]) }
        function onControlPanelOpenChanged(): void { if (GlobalStates.controlPanelOpen) root.largeTargetOutput = GlobalStates.resolveOutputName("",[]) }
        function onOverviewOpenChanged(): void { if (GlobalStates.overviewOpen) GlobalStates.clipboardOpen = false }
        function onClipboardOpenChanged(): void {
            if (GlobalStates.clipboardOpen) {
                GlobalStates.abyssClipboardTargetOutput = GlobalStates.resolveOutputName("",[])
                GlobalStates.overviewOpen = false
            }
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
            function presentation(kind) { return Presentation.resolve(Config.options?.abyss?.positions,kind,outputName) }
            function positionEdge(kind,fallback) { return Presentation.edge(presentation(kind),fallback) }
            function positionAlong(kind,edge,span,fallback) { return Presentation.along(presentation(kind),edge,span,width,height,fallback,nativeInsets) }
            readonly property bool fullscreenCovered: GameMode.hasFullscreenOnOutput(outputName)
            readonly property bool presented: !GlobalStates.screenLocked
                && (!fullscreenCovered || (Config.options?.abyss?.perimeter?.visibleInFullscreen ?? false))
            readonly property bool editorOpen: GlobalStates.abyssEditing && GlobalStates.abyssEditorTargetOutput === outputName
            onPresentedChanged: if (!presented && editorOpen) GlobalStates.abyssEditing = false
            screen: modelData
            // Keep the Top surface mapped across fullscreen, preserving stack order.
            visible: Config.ready && !GlobalStates.screenLocked
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            WlrLayershell.namespace: "hadalis:abyss-perimeter"
            WlrLayershell.layer: GlobalStates.settingsNativeDialogOpen ? WlrLayer.Bottom : PolkitService.active ? WlrLayer.Top : (window.editorOpen || utility.open || styledPopup.open || dialogBody.open || settings.open || dashboardBody.open || controls.open || (window.fullscreenCovered && window.presented)) ? WlrLayer.Overlay : WlrLayer.Top
            WlrLayershell.keyboardFocus: !window.presented || !field.ready || GlobalStates.regionSelectorOpen || GlobalStates.settingsNativeDialogOpen || PolkitService.active || window.overviewDragging
                ? WlrKeyboardFocus.None
                : (window.editorOpen || (utility.open && utility.ready) || (styledPopup.open && (liquid.activePopup?.keyboardFocus ?? false)) || (popup.open && (popup.contentItem.item?.keyboardFocus ?? false)) || (dialogBody.open && dialogBody.ready) || (aux.open && aux.ready) || (settings.open && settings.ready) || (dashboardBody.open && dashboardBody.ready) || (controls.open && controls.ready)) ? WlrKeyboardFocus.Exclusive
                : ((styledPopup.open && (liquid.activePopup?.keyboardFocusOnDemand ?? false)) || (leftPanel.open && leftPanel.ready) || (rightPanel.open && rightPanel.ready) || (popup.open && popup.ready) || (notification.open && notification.ready && notification.contentKind === "center"))
                    ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            anchors { top: true; bottom: true; left: true; right: true }
            Item { id: emptyInput; width: 0; height: 0 }
            readonly property bool overviewDragging: aux.open && (aux.contentItem.item?.applicationDragActive ?? false)
            readonly property Region dragPassThrough: Region {}
            mask: window.overviewDragging ? dragPassThrough : liquid.activeDialog ? dialogInputMask : utility.open ? utilityInputMask : nativeInputMask
            readonly property Region dialogInputMask: Region {
                x: dialogBody.inputBounds.x; y: dialogBody.inputBounds.y
                width: window.presented && field.ready ? dialogBody.inputBounds.width : 0
                height: dialogBody.inputBounds.height
            }
            readonly property Region utilityInputMask: Region {
                x: utility.inputBounds.x; y: utility.inputBounds.y
                width: window.presented && field.ready ? utility.inputBounds.width : 0
                height: utility.inputBounds.height
            }
            readonly property Region nativeInputMask: Region {
                Region { regions: window.presented && field.ready && bar.visible ? bar.inputRegions : [] }
                Region { regions: window.presented && field.ready && editor.visible ? editor.regions : [] }
                Region { item: window.presented && revealTrigger.visible ? revealTrigger : emptyInput }
                Region { item: window.presented && dockTrigger.visible ? dockTrigger : emptyInput }
                Region { x: leftReveal.x; y: leftReveal.y; width: leftReveal.available ? leftReveal.width : 0; height: leftReveal.height }
                Region { x: rightReveal.x; y: rightReveal.y; width: rightReveal.available ? rightReveal.width : 0; height: rightReveal.height }
                Region { x: leftPanel.inputBounds.x; y: leftPanel.inputBounds.y; width: window.presented && field.ready ? leftPanel.inputBounds.width : 0; height: leftPanel.inputBounds.height }
                Region { x: rightPanel.inputBounds.x; y: rightPanel.inputBounds.y; width: window.presented && field.ready ? rightPanel.inputBounds.width : 0; height: rightPanel.inputBounds.height }
                Region { x: styledPopup.inputBounds.x; y: styledPopup.inputBounds.y; width: window.presented && field.ready ? styledPopup.inputBounds.width : 0; height: styledPopup.inputBounds.height }
                Region { x: popup.inputBounds.x; y: popup.inputBounds.y; width: window.presented && field.ready ? popup.inputBounds.width : 0; height: popup.inputBounds.height }
                Region { x: dock.inputBounds.x; y: dock.inputBounds.y; width: window.presented && field.ready ? dock.inputBounds.width : 0; height: dock.inputBounds.height }
                Region { item:corners.notesAvailable ? corners.notesAnchor : emptyInput }
                Region { item:corners.centerAvailable ? corners.centerAnchor : emptyInput }
                Region { regions:corners.sidebarRegions }
                Region { x: notification.inputBounds.x; y: notification.inputBounds.y; width: window.presented && field.ready ? notification.inputBounds.width : 0; height: notification.inputBounds.height }
                Region { x: osd.inputBounds.x; y: osd.inputBounds.y; width: window.presented && field.ready ? osd.inputBounds.width : 0; height: osd.inputBounds.height }
                Region { x: dashboardBody.inputBounds.x; y: dashboardBody.inputBounds.y; width: window.presented && field.ready ? dashboardBody.inputBounds.width : 0; height: dashboardBody.inputBounds.height }
                Region { x: controls.inputBounds.x; y: controls.inputBounds.y; width: window.presented && field.ready ? controls.inputBounds.width : 0; height: controls.inputBounds.height }
                Region { x: settings.inputBounds.x; y: settings.inputBounds.y; width: window.presented && field.ready && !GlobalStates.settingsNativeDialogOpen ? settings.inputBounds.width : 0; height: settings.inputBounds.height }
                Region { x: aux.inputBounds.x; y: aux.inputBounds.y; width: window.presented && field.ready ? aux.inputBounds.width : 0; height: aux.inputBounds.height }
            }
            function closePopup(): void {
                if (liquid.activePopup) liquid.activePopup.dismissPresentation()
                GlobalStates.abyssPopupKind = ""
                GlobalStates.mediaControlsOpen = false
            }
            Item {
                anchors.fill: parent
                focus: aux.open || leftPanel.open || rightPanel.open || popup.open
                Keys.onEscapePressed: {
                    window.closePopup()
                    if (root.utilityKind) root.closeUtility()
                    GlobalStates.closeSidebarLeft()
                    GlobalStates.closeSidebarRight()
                    GlobalStates.dashboardOpen = false
                    GlobalStates.controlPanelOpen = false
                    GlobalStates.settingsOverlayOpen = false
                    GlobalStates.clipboardOpen = false
                    GlobalStates.overviewOpen = false
                    GlobalStates.closeNotificationCenter()
                }
            }
            AbyssEdgeEditor {
                id: editor
                z: 30
                anchors.fill: parent
                visible: window.editorOpen && window.presented && field.ready
                outputName: window.outputName
                moduleLayer: bar
                controller: liquid
            }
            AbyssBar {
                id: bar
                outputName: window.outputName
                liquidController: liquid
                edge: root.barEdge
                editing: editor.visible
                draftPlacements: editor.visible ? editor.draft : null
                draftOptions: editor.visible ? editor.draftOptions : null
                visible: window.presented && field.ready && (window.editorOpen || root.barOnOutput(window.outputName))
                anchors.fill: parent
                HoverHandler { id: barHover; onHoveredChanged: { if (hovered) { barClose.stop(); root.setBarRevealed(window.outputName,true) } else barClose.restart() } }
                onInteraction: (edge,along,span,strength) => liquid.impulse(edge,along,span,strength)
                onPopupRequested: (kind,edge,along) => {
                    const same = (GlobalStates.abyssPopupKind === kind || (kind === "media" && GlobalStates.mediaControlsOpen))
                        && GlobalStates.abyssPopupTargetOutput === window.outputName
                    window.closePopup()
                    if (!same) {
                        GlobalStates.abyssPopupTargetOutput = window.outputName
                        GlobalStates.abyssPopupAlong = along
                        GlobalStates.abyssPopupEdge = edge
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
                onTriggered: if (!barHover.hovered && !revealHover.hovered && !popup.open && !styledPopup.open) root.setBarRevealed(window.outputName,false)
            }
            property real barProgress: root.barOnOutput(window.outputName) ? 1 : 0
            Behavior on barProgress {
                enabled: AbyssStyle.motionEnabled
                NumberAnimation { duration: AbyssStyle.motionNormal; easing.type: Easing.OutCubic }
            }
            readonly property var nativeInsets: {
                const result = Geometry.insets(AbyssStyle.perimeterThickness,root.barEdge,AbyssStyle.perimeterThickness,false)
                if (bar.visible) bar.placements.filter(p => p.enabled).forEach(p => result[p.edge] = Math.max(AbyssStyle.barThickness,ModuleLayout.stripDepth(bar.placements,p.edge,bar.layoutOptions,Appearance.fontSizeScale)))
                return result
            }
            AbyssSurfaceController {
                id: liquid
                outputName: window.outputName
                outputWidth: window.width
                outputHeight: window.height
                presented: window.presented
                presentationItem: field
                dialogHost: dialogBody
                popupHost: styledPopup
                edgeInsets: window.nativeInsets
                moduleRecords: bar.visible ? bar.deformations : []
            }
            readonly property var sideObstacles: [leftPanel,rightPanel].filter(body => body.progress > 0.001).map(body => body.record)
            AbyssSpectrumController {
                waves:liquid.waves
                outputName:window.outputName
                barEdge:root.barEdge
                presented:window.presented && field.ready && !window.editorOpen
            }
            readonly property bool sidebarRevealAvailable: window.presented && field.ready && !window.editorOpen
                && (Config.options?.abyss?.sidebars?.hoverEnabled ?? true)
                && Geometry.targets(window.outputName,Config.options?.sidebar?.screenList ?? [],Quickshell.screens.map(s=>s.name))
            readonly property bool sidebarOpeningAllowed: !utility.open && !settings.open && !dashboardBody.open
                && !controls.open && !aux.open && !dialogBody.open && !GlobalStates.settingsNativeDialogOpen
                && !PolkitService.active && !GlobalStates.regionSelectorOpen
            component SidebarReveal: AbyssSidebarReveal {
                y: (window.height-height)/2
                width: Math.max(AbyssStyle.perimeterThickness,Config.options?.sidebar?.edgeOpen?.regionWidth ?? 2)
                height: Math.min(180,window.height*.25)
                openingAllowed: window.sidebarOpeningAllowed
                closeBlocked: GlobalStates.activeContextMenuCount>0 || dialogBody.open || GlobalStates.settingsNativeDialogOpen
                z: 220
            }
            SidebarReveal {
                id: leftReveal
                x: 0
                available: window.sidebarRevealAvailable && (Config.options?.enabledPanels ?? []).includes("abyssSidebarLeft")
                open: leftPanel.open
                bodyItem: leftPanel.contentItem
                onRevealRequested: GlobalStates.openSidebarLeft(window.outputName)
                onHideRequested: if (GlobalStates.sidebarLeftPresentationOutput===window.outputName) GlobalStates.closeSidebarLeft()
            }
            SidebarReveal {
                id: rightReveal
                x: window.width-width
                available: window.sidebarRevealAvailable && (Config.options?.enabledPanels ?? []).includes("abyssSidebarRight")
                open: rightPanel.open
                bodyItem: rightPanel.contentItem
                onRevealRequested: GlobalStates.openSidebarRight(window.outputName)
                onHideRequested: if (GlobalStates.sidebarRightPresentationOutput===window.outputName) GlobalStates.closeSidebarRight()
            }
            AbyssCorners {
                id:corners;anchors.fill:parent;controller:liquid;outputName:window.outputName
                attachmentThickness:window.nativeInsets.bottom
                presentationEnabled:window.presented && field.ready && !window.editorOpen
                blocked:settings.open || dashboardBody.open || utility.open || controls.open || aux.open
                    || GlobalStates.settingsNativeDialogOpen || PolkitService.active || GlobalStates.regionSelectorOpen
            }
            AbyssBodyHost {
                id: leftPanel
                identity: "leftPanel"
                controller: liquid
                anchors.fill: parent
                edge: window.positionEdge(identity,ShellLayoutController.sidebarAssignments().featureSidebar)
                outputName: window.outputName
                open: window.presented && field.ready && (Config.options?.enabledPanels ?? []).includes("abyssSidebarLeft")
                    && GlobalStates.sidebarLeftOpen && GlobalStates.sidebarLeftPresentationOutput === window.outputName
                    && !(popup.open && popup.edge === edge)
                    && !(notification.centerOnOutput && edge === "right")
                edgeInsets: window.nativeInsets
                along: window.positionAlong(identity,edge,span,Geometry.horizontal(edge) ? (window.width-span)/2 : edgeInsets.top+36)
                readonly property var sizeState:ShellLayoutController.currentState("featureSidebar",window.outputName)
                readonly property real bodyWidth:Math.min(window.width*.8,(sizeState.width ?? 460)+(GlobalStates.sidebarLeftExpanded ? 190 : 0))
                readonly property real bodyHeight:Math.min(window.height-edgeInsets.top-edgeInsets.bottom-72,
                    sizeState.sizeMode === "custom" ? sizeState.customHeight : Math.max(320,contentItem.item?.preferredContentHeight ?? window.height*.7))
                span:Geometry.horizontal(edge) ? bodyWidth : bodyHeight
                depth:Geometry.horizontal(edge) ? bodyHeight : bodyWidth
                source: "content/AbyssLeftContent.qml"
                onCloseRequested: GlobalStates.closeSidebarLeft()
            }
            AbyssBodyHost {
                id: rightPanel
                identity: "rightPanel"
                controller: liquid
                anchors.fill: parent
                edge: window.positionEdge(identity,ShellLayoutController.sidebarAssignments().systemSidebar)
                outputName: window.outputName
                open: window.presented && field.ready && (Config.options?.enabledPanels ?? []).includes("abyssSidebarRight")
                    && GlobalStates.sidebarRightOpen && GlobalStates.sidebarRightPresentationOutput === window.outputName
                    && !(popup.open && popup.edge === edge)
                    && !(notification.centerOnOutput && edge === "right")
                edgeInsets: window.nativeInsets
                along: window.positionAlong(identity,edge,span,Geometry.horizontal(edge) ? (window.width-span)/2 : edgeInsets.top+36)
                readonly property var sizeState:ShellLayoutController.currentState("systemSidebar",window.outputName)
                readonly property real bodyWidth:Math.min(window.width*.8,sizeState.width ?? 460)
                readonly property real bodyHeight:Math.min(window.height-edgeInsets.top-edgeInsets.bottom-72,
                    sizeState.sizeMode === "custom" ? sizeState.customHeight : Math.max(420,contentItem.item?.preferredContentHeight ?? window.height*.7))
                span:Geometry.horizontal(edge) ? bodyWidth : bodyHeight
                depth:Geometry.horizontal(edge) ? bodyHeight : bodyWidth
                source: "content/AbyssRightContent.qml"
                onCloseRequested: GlobalStates.closeSidebarRight()
            }
            AbyssBodyHost {
                id: popup
                identity: "popup"
                controller: liquid
                anchors.fill: parent
                edge: window.positionEdge(contentKind,GlobalStates.abyssPopupEdge || root.barEdge)
                outputName: window.outputName
                open: window.presented && field.ready && (Config.options?.enabledPanels ?? []).includes("abyssPopup")
                    && (GlobalStates.abyssPopupKind.length > 0 || GlobalStates.mediaControlsOpen)
                    && GlobalStates.resolveOutputName(GlobalStates.abyssPopupTargetOutput,[]) === window.outputName
                edgeInsets: window.nativeInsets
                along: window.positionAlong(contentKind,edge,span,GlobalStates.abyssPopupAlong-span/2)
                padding: 14
                span: (Geometry.horizontal(edge) ? (contentItem.item?.desiredWidth ?? 390) : (contentItem.item?.desiredHeight ?? 300))+padding*2
                depth: (Geometry.horizontal(edge) ? (contentItem.item?.desiredHeight ?? 300) : (contentItem.item?.desiredWidth ?? 390))+padding*2
                obstacles: window.sideObstacles
                contentKind: GlobalStates.abyssPopupKind || "media"
                source: "content/AbyssPopupContent.qml"
                onCloseRequested: window.closePopup()
            }
            AbyssBodyHost {
                id: styledPopup
                identity: "styledPopup"
                joinedEdge: liquid.activePopup?._liquidAnchor?.popupJoinedEdge ?? ""
                controller: liquid
                anchors.fill: parent
                readonly property string presentationKind: liquid.activePopup?._liquidAnchor?.kind ?? "popup"
                edge: window.positionEdge(presentationKind,liquid.activePopup?._attachmentEdge ?? root.barEdge)
                outputName: window.outputName
                open: window.presented && field.ready && (liquid.activePopup?.presentationActive ?? false)
                    && ((liquid.activePopup?.requestedVisible ?? false)
                        || ((liquid.activePopup?.hoverActivates ?? false) && (liquid.activePopup?._lingerVisible ?? false)))
                animatePresentation: false
                progress: liquid.activePopup?.revealProgress ?? 0
                embeddedItem: liquid.activePopup?.contentItem ?? null
                edgeInsets: window.nativeInsets
                padding: 14
                span: (Geometry.horizontal(edge) ? (embeddedItem?.implicitWidth ?? 1) : (embeddedItem?.implicitHeight ?? 1))+padding*2
                depth: (Geometry.horizontal(edge) ? (embeddedItem?.implicitHeight ?? 1) : (embeddedItem?.implicitWidth ?? 1))+padding*2
                largeSurface: depth > (Geometry.horizontal(edge) ? window.height : window.width)*.42
                readonly property rect anchorBounds: liquid.activePopup?._anchorRect(window.width,window.height) ?? Qt.rect(0,0,0,0)
                along: window.positionAlong(presentationKind,edge,span,(Geometry.horizontal(edge) ? anchorBounds.x+anchorBounds.width/2 : anchorBounds.y+anchorBounds.height/2)-span/2)
                obstacles: window.sideObstacles
                onCloseRequested: if (liquid.activePopup) liquid.activePopup.dismissPresentation()
                HoverHandler {
                    parent: styledPopup.contentParent
                    onHoveredChanged: if (liquid.activePopup) liquid.activePopup._contentHovered = hovered
                }
            }
            property bool dockHovered: false
            readonly property string dockEdge: ["top","bottom","left","right"].includes(Config.options?.dock?.position) ? Config.options.dock.position : "bottom"
            AbyssBodyHost {
                id: dock
                stableContentSize: true
                property real cachedSpan: 220
                readonly property real measuredSpan: contentItem.item?.desiredSpan ?? cachedSpan
                onMeasuredSpanChanged: if(contentItem.item && measuredSpan>0) cachedSpan=measuredSpan
                identity: "dock"
                controller: liquid
                anchors.fill: parent
                edge: window.dockEdge
                outputName: window.outputName
                open: window.presented && field.ready && GlobalStates.shellEntryReady && !GlobalStates.widgetEditMode
                    && (Config.options?.enabledPanels ?? []).includes("abyssDock") && (Config.options?.dock?.enable ?? true)
                    && Geometry.targets(window.outputName,Config.options?.dock?.screenList ?? [],Quickshell.screens.map(s => s.name))
                    && !window.editorOpen && !settings.open && !dashboardBody.open && !controls.open
                    && !aux.open && !utility.open && !(popup.open && popup.edge === edge) && !(styledPopup.open && styledPopup.edge === edge)
                    && (((Config.options?.dock?.pinnedOnStartup ?? false) && !(Config.options?.dock?.hoverToReveal ?? false)) || window.dockHovered
                        || (contentItem.item?.requestDockShow ?? false)
                        || ((Config.options?.dock?.showOnDesktop ?? true) && !ToplevelManager.activeToplevel?.activated))
                edgeInsets: window.nativeInsets
                span: Math.min((Geometry.horizontal(edge) ? window.width : window.height)-80,
                    Math.max(140,measuredSpan))
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
                identity: "aux"
                controller: liquid
                anchors.fill: parent
                readonly property string presentationKind: GlobalStates.clipboardOpen ? "clipboard" : "overview"
                edge: window.positionEdge(presentationKind,"bottom")
                outputName: window.outputName
                open: window.presented && field.ready && ((GlobalStates.clipboardOpen && (Config.options?.enabledPanels ?? []).includes("abyssClipboard")
                    && GlobalStates.resolveOutputName(GlobalStates.abyssClipboardTargetOutput,[]) === window.outputName)
                    || (GlobalStates.overviewOpen && (Config.options?.enabledPanels ?? []).includes("abyssOverview") && GlobalStates.overviewPresentationOutput === window.outputName))
                edgeInsets: window.nativeInsets
                largeSurface: !GlobalStates.clipboardOpen
                readonly property real contentWidth: GlobalStates.clipboardOpen ? 640 : GlobalStates.overviewMode === "taskview" ? window.width*.9 : window.width*(Config.options?.dashboard?.widthRatio ?? .72)+40
                readonly property real contentHeight: GlobalStates.clipboardOpen ? window.height*.42 : (contentItem.item?.desiredHeight ?? window.height*.72)+padding*2
                span: Geometry.horizontal(edge) ? contentWidth : contentHeight
                along: window.positionAlong(presentationKind,edge,span,(Geometry.horizontal(edge) ? window.width : window.height)/2-span/2)
                depth: Geometry.horizontal(edge) ? contentHeight : contentWidth
                obstacles: GlobalStates.clipboardOpen ? window.sideObstacles : []
                source: GlobalStates.clipboardOpen ? "content/AbyssClipboardContent.qml" : "content/AbyssOverviewContent.qml"
                onCloseRequested: { GlobalStates.clipboardOpen = false; GlobalStates.overviewOpen = false }
            }
            AbyssBodyHost {
                id: settings
                identity: "settings"
                controller: liquid
                anchors.fill: parent
                edge: window.positionEdge(identity,"bottom")
                outputName: window.outputName
                open: window.presented && field.ready && GlobalStates.settingsOverlayOpen
                    && GlobalStates.settingsOverlayPresentationOutput === window.outputName
                largeSurface: true
                edgeInsets: window.nativeInsets
                span: Geometry.horizontal(edge) ? Math.min(1600,Math.max(900,window.width*.9)) : Math.min(1080,Math.max(720,window.height*.92))
                along: window.positionAlong(identity,edge,span,((Geometry.horizontal(edge) ? window.width : window.height)-span)/2)
                depth: Geometry.horizontal(edge) ? Math.min(1080,Math.max(720,window.height*.92)) : Math.min(1600,Math.max(900,window.width*.9))
                source: "content/AbyssSettingsContent.qml"
                onCloseRequested: GlobalStates.settingsOverlayOpen = false
            }
            AbyssBodyHost {
                id: dashboardBody
                identity: "dashboard"
                controller: liquid
                anchors.fill: parent
                edge: window.positionEdge(identity,"bottom")
                outputName: window.outputName
                open: window.presented && field.ready && GlobalStates.dashboardOpen
                    && root.largeTargetOutput === window.outputName && (Config.options?.enabledPanels ?? []).includes("iiDashboard")
                largeSurface: true
                edgeInsets: window.nativeInsets
                span: Geometry.horizontal(edge) ? window.width*(Config.options?.dashboard?.widthRatio ?? .72)+40 : window.height*(Config.options?.dashboard?.heightRatio ?? .72)+40
                along: window.positionAlong(identity,edge,span,((Geometry.horizontal(edge) ? window.width : window.height)-span)/2)
                depth: Geometry.horizontal(edge) ? window.height*(Config.options?.dashboard?.heightRatio ?? .72)+40 : window.width*(Config.options?.dashboard?.widthRatio ?? .72)+40
                source: "content/AbyssDashboardContent.qml"
                onCloseRequested: GlobalStates.dashboardOpen = false
            }
            AbyssBodyHost {
                id: controls
                identity: "controls"
                controller: liquid
                anchors.fill: parent
                edge: window.positionEdge(identity,"right")
                outputName: window.outputName
                open: window.presented && field.ready && GlobalStates.controlPanelOpen
                    && root.largeTargetOutput === window.outputName && (Config.options?.enabledPanels ?? []).includes("iiControlPanel")
                edgeInsets: window.nativeInsets
                span: Geometry.horizontal(edge) ? Math.max(380,window.width*.23) : Math.min(950,window.height-100)
                along: window.positionAlong(identity,edge,span,((Geometry.horizontal(edge) ? window.width : window.height)-span)/2)
                depth: Geometry.horizontal(edge) ? Math.min(950,window.height-100) : Math.max(380,window.width*.23)
                source: "content/AbyssControlContent.qml"
                onCloseRequested: GlobalStates.controlPanelOpen = false
            }
            AbyssBodyHost {
                id: notification
                identity: "notification"
                controller: liquid
                anchors.fill: parent
                readonly property bool centerOnOutput: GlobalStates.notificationCenterOpen && GlobalStates.notificationCenterPresentationOutput === window.outputName
                readonly property string position: Config.options?.notifications?.position ?? "topRight"
                readonly property string presentationKind: centerOnOutput ? "notificationCenter" : "notifications"
                edge: window.positionEdge(presentationKind,centerOnOutput ? "right" : position.startsWith("bottom") ? "bottom" : "top")
                outputName: window.outputName
                open: window.presented && field.ready && (!GlobalStates.notificationCenterOpen && !popup.open && !aux.open && !Notifications.popupInhibited && Notifications.popupList.length > 0
                        && (Config.options?.enabledPanels ?? []).includes("abyssNotificationPopup")
                        && Geometry.targets(window.outputName,Config.options?.notifications?.screenList ?? [],Quickshell.screens.map(s => s.name)))
                edgeInsets: window.nativeInsets
                readonly property real contentWidth: centerOnOutput ? 390 : (contentItem.item?.desiredWidth ?? Appearance.sizes.notificationPopupWidth)+padding*2
                readonly property real contentHeight: centerOnOutput ? window.height-edgeInsets.top-edgeInsets.bottom-72 : Math.min(window.height*.42,Math.max(100,(contentItem.item?.desiredHeight ?? 130)+padding*2))
                span: Geometry.horizontal(edge) ? contentWidth : contentHeight
                along: window.positionAlong(presentationKind,edge,span,centerOnOutput ? (Geometry.horizontal(edge) ? (window.width-span)/2 : edgeInsets.top+36) : position.endsWith("Left") ? 40 : (Geometry.horizontal(edge) ? window.width : window.height)-span-40)
                depth: Geometry.horizontal(edge) ? contentHeight : contentWidth
                obstacles: centerOnOutput ? [] : window.sideObstacles.concat(popup.open ? [popup.record] : [])
                contentKind: centerOnOutput ? "center" : "popup"
                source: "content/AbyssNotificationsContent.qml"
                onCloseRequested: GlobalStates.closeNotificationCenter()
            }
            AbyssBodyHost {
                id: osd
                identity: "osd"
                controller: liquid
                anchors.fill: parent
                readonly property string presentationKind: GlobalStates.abyssOsdKind === "media" ? "mediaOsd" : GlobalStates.abyssOsdKind
                edge: window.positionEdge(presentationKind,root.barEdge)
                outputName: window.outputName
                open: window.presented && field.ready && (Config.options?.enabledPanels ?? []).includes("abyssOnScreenDisplay")
                    && (GlobalStates.osdVolumeOpen || GlobalStates.osdBrightnessOpen || GlobalStates.osdMicOpen || GlobalStates.osdMediaOpen || GlobalStates.osdKeyboardLayoutOpen)
                    && Geometry.targets(window.outputName,Config.options?.osd?.screenList ?? [],Quickshell.screens.map(s => s.name))
                    && !rightPanel.open && !leftPanel.open && !notification.open
                edgeInsets: window.nativeInsets
                padding: 12
                span: (Geometry.horizontal(edge) ? (contentItem.item?.desiredWidth ?? Appearance.sizes.osdWidth) : (contentItem.item?.desiredHeight ?? 48))+padding*2
                along: window.positionAlong(presentationKind,edge,span,(Geometry.horizontal(edge) ? window.width : window.height)/2-span/2)
                depth: (Geometry.horizontal(edge) ? (contentItem.item?.desiredHeight ?? 48) : (contentItem.item?.desiredWidth ?? Appearance.sizes.osdWidth))+padding*2
                source: "content/AbyssOsdContent.qml"
                HoverHandler {
                    parent: osd.contentItem
                    enabled: osd.open
                    onHoveredChanged: {
                        if (GlobalStates.abyssOsdKind === "media") {
                            if (hovered) GlobalStates.abyssOsdHoverOutput = window.outputName
                            else if (GlobalStates.abyssOsdHoverOutput === window.outputName) GlobalStates.abyssOsdHoverOutput = ""
                        } else if (hovered && GlobalStates.abyssOsdKind !== "voiceSearch") GlobalStates.osdDismissed()
                    }
                }
            }
            AbyssBodyHost {
                id: utility
                z: 15
                identity: "utility"
                controller: liquid
                anchors.fill: parent
                edge: window.positionEdge(contentKind,"bottom")
                outputName: window.outputName
                open: window.presented && field.ready && root.utilityKind.length > 0
                    && root.largeTargetOutput === window.outputName
                    && (Config.options?.enabledPanels ?? []).includes(root.utilityIdentifier)
                largeSurface: true
                edgeInsets: window.nativeInsets
                span: (Geometry.horizontal(edge) ? (contentItem.item?.desiredWidth ?? 640) : (contentItem.item?.desiredHeight ?? 700))+padding*2
                along: window.positionAlong(contentKind,edge,span,((Geometry.horizontal(edge) ? window.width : window.height)-span)/2)
                depth: (Geometry.horizontal(edge) ? (contentItem.item?.desiredHeight ?? 700) : (contentItem.item?.desiredWidth ?? 640))+padding*2
                contentKind: root.utilityKind
                source: "content/AbyssUtilityContent.qml"
                onCloseRequested: root.closeUtility()
            }
            AbyssBodyHost {
                id: dialogBody
                z: 20
                identity: "dialog"
                controller: liquid
                anchors.fill: parent
                edge: window.positionEdge(identity,"right")
                outputName: window.outputName
                open: window.presented && field.ready && liquid.activeDialog !== null
                embeddedItem: liquid.activeDialog
                span: (Geometry.horizontal(edge) ? (liquid.activeDialog?.liquidWidth ?? 350) : (liquid.activeDialog?.liquidHeight ?? 450))+padding*2
                depth: (Geometry.horizontal(edge) ? (liquid.activeDialog?.liquidHeight ?? 450) : (liquid.activeDialog?.liquidWidth ?? 350))+padding*2
                along: window.positionAlong(identity,edge,span,((Geometry.horizontal(edge) ? window.width : window.height)-span)/2)
                edgeInsets: window.nativeInsets
                onCloseRequested: if (liquid.activeDialog) liquid.activeDialog.dismiss()
            }
            AbyssField {
                id: field
                outputName: window.outputName
                renderScale: window.modelData?.devicePixelRatio ?? 1
                z: -1
                anchors.fill: parent
                visible: window.presented
                edgeInsets: window.nativeInsets
                records: liquid.records
                waveTexture: liquid.waves.texture
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
