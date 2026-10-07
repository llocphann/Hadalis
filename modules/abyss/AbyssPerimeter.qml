pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.abyss.bar
import qs.modules.abyss.companion
import qs.modules.abyss.looks
import "looks/AbyssGeometry.js" as Geometry
import "looks/AbyssLayout.js" as ModuleLayout
import "looks/AbyssPresentation.js" as Presentation
import "companion/WullHostPolicy.js" as WullHostPolicy
import "companion/WullScene.js" as WullScene
import "companion/WullPreferences.js" as WullPreferences

Scope {
    id: root
    readonly property var outputHosts:outputWindows.instances
    property string largeTargetOutput: GlobalStates.resolveOutputName("",[])
    readonly property var companionOptions: Config.options?.abyss?.companion
    readonly property var companionPreferences: WullPreferences.normalize(companionOptions)
    readonly property string selectedCompanion: companionPreferences.character
    readonly property bool alternatingCompanions: companionPreferences.alternateCompanions
    property string companionCharacter: selectedCompanion
    Binding {target:WullMind;property:"character";value:root.companionCharacter}
    function resetCompanionCast(): void {
        companionCharacter=selectedCompanion
        for (const window of outputWindows.instances) window.resetCompanionCast()
    }
    onSelectedCompanionChanged: Qt.callLater(root.resetCompanionCast)
    onAlternatingCompanionsChanged: if (!alternatingCompanions) Qt.callLater(root.resetCompanionCast)
    readonly property bool companionEnabled: Config.ready && companionPreferences.enabled
    Binding {target:WullMind;property:"hostVisible";value:root.companionSessionVisible && companionBridge.ready && companionBridge.visibility==="present"}
    Binding {target:WullMind;property:"hostIdle";value:companionBridge.activity==="idle"}
    Connections {
        target:WullMind
        function onReactionRequested(expression): void {
            if(root.companionSessionVisible && companionBridge.visibility==="present")
                companionBridge.sendIntent(expression,.5,3000)
        }
    }
    readonly property string companionTargetOutput: GlobalStates.resolveOutputName(
        "", Config.options?.bar?.screenList ?? [])
    readonly property string companionEdge: root.barEdge
    readonly property real companionScale: companionPreferences.size
    readonly property bool companionInteractive: companionPreferences.interactive
    readonly property bool companionSessionVisible: companionEnabled
        && companionTargetOutput.length > 0
        && !GlobalStates.screenLocked
        && !Appearance.gameModeMinimal
        && (!GameMode.hasFullscreenOnOutput(companionTargetOutput)
            || (!companionPreferences.hideInFullscreen
                && (Config.options?.abyss?.perimeter?.visibleInFullscreen ?? false)))

    function syncCompanionVisibility(): void {
        if (root.companionSessionVisible)
            companionBridge.show()
        else
            companionBridge.hide()
    }

    onCompanionSessionVisibleChanged: root.syncCompanionVisibility()

    CompanionBridge {
        id: companionBridge
        // Guard the development binary override as well as the dispatcher.
        // An inherited INIR_COMPANIOND must not bypass default-off.
        binaryPath: root.companionEnabled ? (Quickshell.env("INIR_COMPANIOND") ?? "") : ""
        useNativeDispatcher: root.companionEnabled
        personality: root.companionPreferences.personality
        appearanceFrequency: root.companionPreferences.appearanceFrequency
    }
    // Read the existing gates on demand; no polling, state mutation or backend
    // activation. This also explains why an enabled companion stays hidden.
    IpcHandler {
        target: "wull"
        function chat(): void {
            if (!root.companionSessionVisible || !root.companionInteractive || !WullMind.talkEnabled) return
            if (WullMind.conversationOpen) {WullMind.cancel();WullMind.dismiss();return}
            companionBridge.show()
            companionBridge.sendEvent("hover",true)
            for (const window of outputWindows.instances)
                if(window.outputName===root.companionTargetOutput)window.requestCompanionChat()
        }
        function status(): string {
            const outputs=[]
            for (let i=0;i<outputWindows.instances.length;i++)
                outputs.push(outputWindows.instances[i].companionStatus())
            return JSON.stringify({enabled:root.companionEnabled,
                sessionVisible:root.companionSessionVisible,
                targetOutput:root.companionTargetOutput,
                backend:{ready:companionBridge.ready,
                    requestedVisible:companionBridge.requestedVisible,
                    visibility:companionBridge.visibility,
                    sequence:companionBridge.inboundSeq,
                    restartAttempts:companionBridge.restartAttempts},outputs:outputs})
        }
    }
    // Match the mature ScreenCorners keyboard lease: hover previews may exist on
    // several outputs, but only one Quick Notes editor may own keyboard focus.
    property string quickNotesEditorOutput: ""
    function setQuickNotesEditorOutput(outputName, focused): void {
        const name = String(outputName ?? "")
        if (focused) {
            if (name && (!root.quickNotesEditorOutput
                    || root.quickNotesEditorOutput === name))
                root.quickNotesEditorOutput = name
            return
        }
        if (root.quickNotesEditorOutput === name)
            root.quickNotesEditorOutput = ""
    }
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
                || GlobalStates.barPopupHoverHeld(name)
                || (GlobalStates.superDown && (Config.options?.bar?.autoHide?.showWhenPressingSuper ?? true))
                || (GlobalStates.abyssPopupKind.length > 0
                    && GlobalStates.resolveOutputName(GlobalStates.abyssPopupTargetOutput,[]) === name))
            && Geometry.targets(name, Config.options?.bar?.screenList ?? [], Quickshell.screens.map(s => s.name))
    }
    function outputInsets(name, reservation = false) {
        const options=Object.assign({},ModuleLayout.optionsForOutput(Config.options?.abyss?.modules,name),{edgeThickness:AbyssStyle.perimeterThickness})
        const result = ModuleLayout.edgeInsetsForModules([],options,Appearance.fontSizeScale,AbyssStyle.perimeterThickness,AbyssStyle.barThickness,false)
        if (!root.barOnOutput(name) || (reservation && (Config.options?.bar?.autoHide?.enable ?? false))) return result
        const screen = Quickshell.screens.find(s => s.name === name)
        const vertical = !Geometry.horizontal(root.barEdge)
        const zones = Geometry.barZones((vertical ? Config.options?.bar?.verticalLayout : Config.options?.bar?.layout) ?? {},vertical,Config.options?.bar?.modules ?? {})
        const placements = ModuleLayout.resolve(Config.options?.abyss?.modules,name,ModuleLayout.seed(zones,root.barEdge,screen?.width ?? 1920,screen?.height ?? 1080))
        return ModuleLayout.edgeInsetsForModules(placements,options,Appearance.fontSizeScale,AbyssStyle.perimeterThickness,AbyssStyle.barThickness,reservation)
    }
    Connections {
        target: Quickshell
        function onScreensChanged(): void {
            const owner = root.quickNotesEditorOutput
            if (!owner) return
            if (!Quickshell.screens.some(screen =>
                    String(screen?.name ?? "") === owner))
                root.quickNotesEditorOutput = ""
        }
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
    Component.onCompleted: {
        Notifications.ensureInitialized()
        root.syncCompanionVisibility()
    }
    Variants {
        id: outputWindows
        model: Quickshell.screens
        PanelWindow {
            id: window
            objectName:"abyssOutputHost_"+modelData.name
            required property var modelData
            readonly property string outputName: modelData?.name ?? ""
            function presentation(kind) { return Presentation.resolve(Config.options?.abyss?.positions,kind,outputName) }
            function positionEdge(kind,fallback) { return Presentation.edge(presentation(kind),fallback) }
            function positionAlong(kind,edge,span,fallback) { return Presentation.along(presentation(kind),edge,span,width,height,fallback,nativeInsets) }
            function bodyInsets(edge,along,span) { return ModuleLayout.clearanceInsets(nativeInsets,bar.visible ? bar.deformations : [],edge,along,span) }
            readonly property bool fullscreenCovered: GameMode.hasFullscreenOnOutput(outputName)
            readonly property bool presented: !GlobalStates.screenLocked
                && (!fullscreenCovered || (Config.options?.abyss?.perimeter?.visibleInFullscreen ?? false))
            readonly property bool editorOpen: GlobalStates.abyssEditing && GlobalStates.abyssEditorTargetOutput === outputName
            // Ordinary Abyss surfaces are Wull's habitat. Actual modal/security
            // owners still preempt it; moving bodies remain scene obstacles.
            readonly property bool companionOccluded: window.editorOpen
                || liquid.activeDialog || GlobalStates.settingsNativeDialogOpen
                || PolkitService.active || GlobalStates.regionSelectorOpen || window.overviewDragging
            readonly property var companionScene: WullScene.fromParticipants({
                width:window.width,height:window.height,
                hostWidth:112*root.companionScale,hostHeight:98*root.companionScale,
                scale:root.companionScale,insets:window.nativeInsets,rimRadius:AbyssStyle.neckRadius},
                liquid.participants,bar.visible ? bar.layoutRecords.map(record=>({
                    edge:record.edge,along:record.along,span:record.span})) : [])
            readonly property bool companionPermission: WullHostPolicy.hostActive(
                root.companionSessionVisible,companionBridge.ready,
                root.companionTargetOutput,window.outputName,window.presented,field.ready)
                && !window.companionOccluded
                && liquid.records.length<=field.capacity
            readonly property bool companionHostActive: window.companionPermission && companionPresence.qualified
            function requestCompanionChat(): void {
                if(!window.companionPermission) return
                companionTurns.cancel()
                companionCuriosity.interrupt()
                companionPresence.hiddenUntil=0
                if(!companionPresence.visitActive || companionPresence.retreating)companionPresence.appear()
                companionPresence.peekOnly=false;companionPresence.peekIntro=false;companionPresence.renderedReveal=1
                WullMind.openChat()
            }
            function resetCompanionCast(): void {
                companionTurns.cancel()
                companionPresence.hideImmediately()
                Qt.callLater(companionPresence.synchronize)
            }
            function companionStatus() {
                const scene=window.companionScene
                return {output:outputName,presented:window.presented,
                    occluded:window.companionOccluded,permission:window.companionPermission,
                    active:window.companionHostActive,
                    field:{ready:field.ready,framePresented:field.framePresented,
                        diagnostic:String(field.diagnostic).slice(0,512),
                        records:liquid.records.length,capacity:field.capacity},
                    scene:{valid:WullScene.valid(scene),width:scene.width,height:scene.height,
                        hostWidth:scene.hostWidth,hostHeight:scene.hostHeight,insets:scene.insets,
                        records:scene.records?.slice(0,256),blockers:scene.blockers?.slice(0,128),
                        surfaces:scene.surfaces?.slice(0,40)},
                    presence:{qualified:companionPresence.qualified,
                        portalActive:companionPresence.portalActive,portalProgress:companionPresence.portalProgress,
                        visitActive:companionPresence.visitActive,
                        traveling:companionPresence.traveling,mode:companionPresence.mode,
                        dragging:companionPresence.dragging,arc:companionPresence.arc,
                        requestedReveal:companionPresence.requestedReveal,
                        renderedReveal:companionPresence.renderedReveal,
                        placement:companionPresence.placement},
                    curiosity:{enabled:root.companionPreferences.exploreFeatures,
                        stage:companionCuriosity.stage,owned:companionCuriosity.owned,
                        feature:companionCuriosity.feature?.kind ?? ""},
                    turns:{enabled:root.alternatingCompanions,active:companionTurns.active,paired:companionTurns.paired,
                        incoming:companionTurns.active ? companionTurns.incoming : ""},
                    actor:{character:companion.character,visible:companion.visible,inputReady:companion.inputReady,
                        moving:companion.moving,walking:companion.walking,rolling:companion.rolling,flying:companion.flying,
                        presentation:companion.presentation,opacity:companion.opacity,
                        x:companion.x,y:companion.y}}
            }
            readonly property bool companionHoverHeld: window.companionHostActive
                && companion.interactive && (companion.hovered || cloudActions.hovered || cloudActions.visible || companion.dragging || talkCloud.controlsVisible || WullMind.conversationOpen)
            onCompanionHoverHeldChanged: if (root.companionTargetOutput===window.outputName && companionBridge.ready)
                companionBridge.sendEvent("hover",window.companionHoverHeld)
            WullPresence {
                id: companionPresence
                scene: window.companionScene
                actor: companion
                permitted: window.companionPermission
                requestedReveal: companionBridge.visibility==="present" ? 1
                    : companionBridge.visibility==="peeking" ? .46 : 0
                motionEnabled: root.companionPreferences.animationsEnabled && AbyssStyle.motionEnabled
                interactionHeld: companionBridge.activity!=="idle" || talkCloud.controlsVisible || WullMind.conversationOpen
                pointerFresh: window.companionPointerFresh
                pointerX: window.companionPointerX
                pointerY: window.companionPointerY
                pointerReactionsEnabled: root.companionInteractive && !talkCloud.controlsVisible
                    && !WullMind.conversationOpen
                personality: root.companionPreferences.personality
                travelId: companionBridge.travelId
                travelFraction: companionBridge.travelTarget
                onStopRequested: companion.stopTravel()
                onResetRequested: (px,py,sourceEdge)=>companion.resetTo(
                    px+(root.companionScale-1)*companion.implicitWidth/2,
                    py+(root.companionScale-1)*companion.implicitHeight/2,sourceEdge)
            }
            WullAbyssLink {
                id: companionWater
                presence: companionPresence
                actor: companion
                controller: liquid
                allowed: window.companionHostActive
            }
            CompanionTurns {
                id:companionTurns
                presence:companionPresence;actor:companion
                allowed:window.companionHostActive && companionBridge.ready
                alternating:root.alternatingCompanions
                interactionHeld:companionPresence.interactionHeld || companionCuriosity.busy
                onStarting:companionCuriosity.interrupt()
                onCharacterChosen:character=>root.companionCharacter=character
            }
            CompanionChallenger {turns:companionTurns;actor:companion;z:24}
            function companionFeaturesIdle(): bool {
                return !companionTurns.active && window.companionPermission && !window.companionOccluded
                    && !liquid.popupsOpen && !GlobalStates.abyssPopupKind
                    && !GlobalStates.sidebarLeftOpen && !GlobalStates.sidebarRightOpen
                    && !GlobalStates.settingsOverlayOpen && !GlobalStates.overviewOpen
                    && !GlobalStates.clipboardOpen && !GlobalStates.dashboardOpen
                    && !GlobalStates.controlPanelOpen && !GlobalStates.notificationCenterOpen
                    && !GlobalStates.widgetEditMode && !utility.open && !window.dockHovered
                    && !barHover.hovered && !revealHover.hovered
            }
            readonly property var companionFeatures: {
                const result=[]
                if (!root.companionEnabled || !root.companionPreferences.exploreFeatures) return result
                const panels=Config.options?.enabledPanels ?? []
                const gestures={clock:"inspect",resources:"inspect",battery:"inspect",
                    weather:"inspect",media:"wave",utilButtons:"press"}
                if (bar.visible && panels.includes("abyssPopup")) {
                    for (const record of bar.layoutRecords) {
                        const module=bar.itemForId(record.id)
                        const kind=module?.kind
                        const mature=module?.companionPopup ?? null
                        if (record.span>0 && gestures[kind] && (mature || kind==="utilButtons")) result.push({
                            kind:kind==="utilButtons" ? "utilities" : kind,
                            popup:mature,key:kind==="utilButtons" ? "popup" : "",edge:record.edge,
                            along:record.along+record.span/2,openGesture:"press",gesture:gestures[kind]})
                    }
                }
                const sidebarOutput=GlobalStates.resolveOutputName(window.outputName,Config.options?.sidebar?.screenList ?? [])
                for (const side of ["left","right"]) {
                    const key=side+"Panel", body=side==="left" ? leftPanel : rightPanel
                    if (panels.includes(side==="left" ? "abyssSidebarLeft" : "abyssSidebarRight")
                            && sidebarOutput===window.outputName && !body.open)
                        result.push({kind:key,key:key,edge:body.edge,along:body.along+body.span/2,
                            openGesture:"reach",gesture:side==="left" ? "inspect" : "press"})
                }
                for (const [kind,available,mature,along] of [
                        ["quickNotes",corners.notesAvailable,corners.notesPopup,window.nativeInsets.left+80],
                        ["notificationCenter",corners.centerAvailable,corners.centerPopup,window.width-window.nativeInsets.right-80]]) {
                    if (available && !mature.presentationActive)
                        result.push({kind:kind,popup:mature,key:"",edge:"bottom",along:along,
                            openGesture:"reach",gesture:kind==="quickNotes" ? "inspect" : "wave"})
                }
                return result
            }
            function companionSurfaceKey(feature): string {
                if (!feature?.popup) return feature?.key ?? ""
                const slot=liquid._popupSlot(feature.popup)
                return slot>=0 ? "styledPopup"+slot : ""
            }
            function openCompanionFeature(feature): bool {
                if (!companionFeaturesIdle() || !feature) return false
                if (["clock","resources","battery","weather","media","quickNotes","notificationCenter"].includes(feature.kind)) {
                    // Borrow the module/corner's mature StyledPopup. Its hover
                    // path and Wull share one slot, one content and one host.
                    return !!feature.popup && feature.popup.acquireCompanion(window)
                }
                if (feature.kind==="leftPanel") GlobalStates.openSidebarLeft(window.outputName,false)
                else if (feature.kind==="rightPanel") GlobalStates.openSidebarRight(window.outputName,false)
                else if (feature.kind==="utilities") {
                    GlobalStates.abyssPopupTargetOutput=window.outputName
                    GlobalStates.abyssPopupEdge=feature.edge
                    GlobalStates.abyssPopupAlong=feature.along
                    GlobalStates.abyssPopupKind="utilities"
                } else return false
                return ownsCompanionFeature(feature)
            }
            function ownsCompanionFeature(feature): bool {
                if (!feature) return false
                if (feature.popup) return feature.popup.companionLease===window
                if (feature.kind==="leftPanel") return GlobalStates.sidebarLeftOpen
                    && GlobalStates.sidebarLeftTargetOutput===window.outputName
                if (feature.kind==="rightPanel") return GlobalStates.sidebarRightOpen
                    && GlobalStates.sidebarRightTargetOutput===window.outputName
                return feature.kind==="utilities" && GlobalStates.abyssPopupTargetOutput===window.outputName
                    && GlobalStates.abyssPopupKind==="utilities"
            }
            function closeCompanionFeature(feature): void {
                if (!ownsCompanionFeature(feature)) return
                if (feature.popup) feature.popup.releaseCompanion(window)
                else if (feature.kind==="leftPanel") GlobalStates.closeSidebarLeft()
                else if (feature.kind==="rightPanel") GlobalStates.closeSidebarRight()
                else if (feature.kind==="utilities") window.closeGenericPopup("utilities")
            }
            function releaseCompanionFeature(feature): void {
                if (feature?.popup) feature.popup.releaseCompanion(window)
                else if (ownsCompanionFeature(feature)) {
                    // A sidebar visited by Wull becomes an ordinary transient
                    // hover surface after a real user hand-off, not a sticky IPC open.
                    if (feature.kind==="leftPanel") GlobalStates.sidebarLeftTransient=true
                    else if (feature.kind==="rightPanel") GlobalStates.sidebarRightTransient=true
                }
            }
            readonly property string companionFeatureState: [GlobalStates.sidebarLeftOpen,
                GlobalStates.sidebarLeftTargetOutput,GlobalStates.sidebarRightOpen,GlobalStates.sidebarRightTargetOutput,
                GlobalStates.abyssPopupKind,GlobalStates.abyssPopupTargetOutput].join("|")
            onCompanionFeatureStateChanged: if (companionCuriosity) companionCuriosity.checkOwnership()
            Connections {
                target: companionCuriosity.feature?.popup ?? null
                function onCompanionLeaseChanged(): void {companionCuriosity.checkOwnership()}
            }
            WullCuriosity {
                id: companionCuriosity
                presence: companionPresence
                actor: companion
                adapter: window
                features: window.companionFeatures
                allowed: window.companionHostActive && root.companionPreferences.exploreFeatures
                    && root.companionPreferences.animationsEnabled && AbyssStyle.motionEnabled
                idle: companionBridge.activity==="idle" && companionBridge.visibility==="present"
                eventId: companionBridge.travelId
            }
            property real companionPointerX: 0
            property real companionPointerY: 0
            property bool companionPointerFresh: false
            Item {
                anchors.fill: parent
                HoverHandler {
                    id: companionPointer
                    target: null
                    blocking: false
                    enabled: window.companionHostActive && (root.companionInteractive || companionCuriosity.busy)
                    onPointChanged: if (hovered) {
                        window.companionPointerX=point.scenePosition.x
                        window.companionPointerY=point.scenePosition.y
                        window.companionPointerFresh=true
                        companionPointerExpiry.restart()
                        companionCuriosity.pointerMoved(window.companionPointerX,window.companionPointerY)
                    }
                    onHoveredChanged: if (!hovered) window.companionPointerFresh=false
                }
                PointHandler {
                    enabled: window.companionHostActive && root.companionInteractive
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onActiveChanged: if (active) {
                        if (companionCuriosity.containsPoint(point.scenePosition.x,point.scenePosition.y))
                            companionCuriosity.yieldToUser()
                        else companionCuriosity.interrupt()
                        if (!talkCloud.containsScenePoint(point.scenePosition))
                            companionPresence.nearbyClick(point.scenePosition.x,point.scenePosition.y)
                    }
                }
            }
            Timer {
                id: companionPointerExpiry
                interval: 1400; repeat: false
                onTriggered: window.companionPointerFresh=false
            }
            onPresentedChanged: if (!presented && editorOpen) GlobalStates.abyssEditing = false
            screen: modelData
            // Keep the Top surface mapped across fullscreen, preserving stack order.
            visible: Config.ready && !GlobalStates.screenLocked
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            WlrLayershell.namespace: "hadalis:abyss-perimeter"
            WlrLayershell.layer: GlobalStates.settingsNativeDialogOpen ? WlrLayer.Bottom : PolkitService.active ? WlrLayer.Top : (window.editorOpen || wallpaperBody.open || (keyboardBody.open && (Config.options?.osk?.keepOnTop ?? false)) || utility.open || liquid.popupsOpen || toastBody.open || dialogBody.open || talkCloud.editing || settings.open || dashboardBody.open || controls.open || (window.fullscreenCovered && window.presented)) ? WlrLayer.Overlay : WlrLayer.Top
            WlrLayershell.keyboardFocus: !window.presented || !field.ready || GlobalStates.regionSelectorOpen || GlobalStates.settingsNativeDialogOpen || PolkitService.active || window.overviewDragging || companionCuriosity.owned
                ? WlrKeyboardFocus.None
                : (talkCloud.editing || window.editorOpen || (utility.presented && utility.ready) || liquid.popupExclusiveFocus || (popup.presented && (popup.contentItem.item?.keyboardFocus ?? false)) || (dialogBody.presented && dialogBody.ready) || (aux.presented && aux.ready) || (wallpaperBody.presented && wallpaperBody.ready) || (clipboardBody.presented && clipboardBody.ready) || (settings.presented && settings.ready) || (dashboardBody.presented && dashboardBody.ready) || (controls.presented && controls.ready)) ? WlrKeyboardFocus.Exclusive
                : (talkCloud.editing || liquid.popupOnDemandFocus || (leftPanel.presented && leftPanel.ready) || (rightPanel.presented && rightPanel.ready) || (popup.presented && popup.ready) || (notification.presented && notification.ready && notification.contentKind === "center"))
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
                Region {
                    x: utility.inputBounds.x; y: utility.inputBounds.y
                    width: window.presented && field.ready ? utility.inputBounds.width : 0
                    height: utility.inputBounds.height
                }
                Region { regions: [window.companionInputMask] }
                Region { regions: [window.companionRimInputMask] }
            }
            readonly property Region companionInputMask: Region { item: WullHostPolicy.acceptsInput(window.companionHostActive, companion.interactive, companion.visible && companion.inputReady) ? companion : emptyInput }
            readonly property bool companionRimInputActive: window.presented && field.ready
                && WullHostPolicy.acceptsInput(window.companionHostActive,companion.interactive,companion.visible && companion.inputReady)
            readonly property real companionRimThickness: Math.min(AbyssStyle.perimeterThickness,window.width/2,window.height/2)
            // Observe Wull's surrounding water on all four painted rims. The
            // interior desktop retains its existing pass-through/input owners.
            readonly property Region companionRimInputMask: Region {
                Region { x:0; y:0; width:window.companionRimInputActive ? window.width : 0; height:window.companionRimThickness }
                Region { x:0; y:window.height-window.companionRimThickness; width:window.companionRimInputActive ? window.width : 0; height:window.companionRimThickness }
                Region { x:0; y:0; width:window.companionRimInputActive ? window.companionRimThickness : 0; height:window.height }
                Region { x:window.width-window.companionRimThickness; y:0; width:window.companionRimInputActive ? window.companionRimThickness : 0; height:window.height }
            }
            readonly property Region nativeInputMask: Region {
                Region { regions: window.presented && field.ready && bar.visible ? bar.inputRegions : [] }
                Region { regions: [window.companionInputMask] }
                Region { regions: [window.companionRimInputMask] }
                Region { regions: window.presented && field.ready && editor.visible ? editor.regions : [] }
                Region { item: window.presented && revealTrigger.visible ? revealTrigger : emptyInput }
                Region { item: window.presented && dockTrigger.visible ? dockTrigger : emptyInput }
                Region { x: widgetEditorBody.inputBounds.x; y: widgetEditorBody.inputBounds.y; width: window.presented && field.ready ? widgetEditorBody.inputBounds.width : 0; height: widgetEditorBody.inputBounds.height }
                Region { x: leftReveal.x; y: leftReveal.y; width: leftReveal.available ? leftReveal.width : 0; height: leftReveal.height }
                Region { x: rightReveal.x; y: rightReveal.y; width: rightReveal.available ? rightReveal.width : 0; height: rightReveal.height }
                Region { x: leftPanel.inputBounds.x; y: leftPanel.inputBounds.y; width: window.presented && field.ready ? leftPanel.inputBounds.width : 0; height: leftPanel.inputBounds.height }
                Region { x: rightPanel.inputBounds.x; y: rightPanel.inputBounds.y; width: window.presented && field.ready ? rightPanel.inputBounds.width : 0; height: rightPanel.inputBounds.height }
                Region { x: liquid.popupInputBounds[0]?.x ?? 0; y: liquid.popupInputBounds[0]?.y ?? 0; width: window.presented && field.ready ? (liquid.popupInputBounds[0]?.width ?? 0) : 0; height: liquid.popupInputBounds[0]?.height ?? 0 }
                Region { x: liquid.popupInputBounds[1]?.x ?? 0; y: liquid.popupInputBounds[1]?.y ?? 0; width: window.presented && field.ready ? (liquid.popupInputBounds[1]?.width ?? 0) : 0; height: liquid.popupInputBounds[1]?.height ?? 0 }
                Region { x: liquid.popupInputBounds[2]?.x ?? 0; y: liquid.popupInputBounds[2]?.y ?? 0; width: window.presented && field.ready ? (liquid.popupInputBounds[2]?.width ?? 0) : 0; height: liquid.popupInputBounds[2]?.height ?? 0 }
                Region { x: liquid.popupInputBounds[3]?.x ?? 0; y: liquid.popupInputBounds[3]?.y ?? 0; width: window.presented && field.ready ? (liquid.popupInputBounds[3]?.width ?? 0) : 0; height: liquid.popupInputBounds[3]?.height ?? 0 }
                Region { x: popup.inputBounds.x; y: popup.inputBounds.y; width: window.presented && field.ready ? popup.inputBounds.width : 0; height: popup.inputBounds.height }
                Region { x: dock.inputBounds.x; y: dock.inputBounds.y; width: window.presented && field.ready ? dock.inputBounds.width : 0; height: dock.inputBounds.height }
                Region { item:talkCloud.visible ? talkCloud : emptyInput }
                Region { item:cloudActions.visible ? cloudActions.obsidianTarget : emptyInput }
                Region { item:cloudActions.visible ? cloudActions.aiTarget : emptyInput }
                Region { item:corners.notesAvailable ? corners.notesAnchor : emptyInput }
                Region { item:corners.centerAvailable ? corners.centerAnchor : emptyInput }
                Region { regions:corners.sidebarRegions }
                Region { x: notification.inputBounds.x; y: notification.inputBounds.y; width: window.presented && field.ready ? notification.inputBounds.width : 0; height: notification.inputBounds.height }
                Region { x: toastBody.inputBounds.x; y: toastBody.inputBounds.y; width: window.presented && field.ready ? toastBody.inputBounds.width : 0; height: toastBody.inputBounds.height }
                Region { x: osd.inputBounds.x; y: osd.inputBounds.y; width: window.presented && field.ready ? osd.inputBounds.width : 0; height: osd.inputBounds.height }
                Region { x: dashboardBody.inputBounds.x; y: dashboardBody.inputBounds.y; width: window.presented && field.ready ? dashboardBody.inputBounds.width : 0; height: dashboardBody.inputBounds.height }
                Region { x: controls.inputBounds.x; y: controls.inputBounds.y; width: window.presented && field.ready ? controls.inputBounds.width : 0; height: controls.inputBounds.height }
                Region { x: settings.inputBounds.x; y: settings.inputBounds.y; width: window.presented && field.ready && !GlobalStates.settingsNativeDialogOpen ? settings.inputBounds.width : 0; height: settings.inputBounds.height }
                Region { x: aux.inputBounds.x; y: aux.inputBounds.y; width: window.presented && field.ready ? aux.inputBounds.width : 0; height: aux.inputBounds.height }
                Region {x:keyboardBody.inputBounds.x;y:keyboardBody.inputBounds.y;width:window.presented && field.ready ? keyboardBody.inputBounds.width : 0;height:keyboardBody.inputBounds.height}
                Region { x:wallpaperBody.inputBounds.x;y:wallpaperBody.inputBounds.y;width:window.presented && field.ready ? wallpaperBody.inputBounds.width : 0;height:wallpaperBody.inputBounds.height }
                Region { x: clipboardBody.inputBounds.x; y: clipboardBody.inputBounds.y; width: window.presented && field.ready ? clipboardBody.inputBounds.width : 0; height: clipboardBody.inputBounds.height }
            }
            function closeGenericPopup(expectedKind = ""): void {
                const expected = String(expectedKind ?? "")

                // Hover-owned generic surfaces (Wi-Fi/Bluetooth/Utilities/etc.)
                // must never dismiss a newer mature StyledPopup. A stale idle
                // timer may only close the generic popup it originally owned.
                const current = String(GlobalStates.abyssPopupKind ?? "")
                if (expected && current !== expected)
                    return
                if (current === "dockAppMenu") {
                    GlobalStates.abyssDockMenuModel = []
                    GlobalStates.abyssDockMenuOwnerId = ""
                    GlobalStates.abyssDockMenuTriggerHovered = false
                }
                GlobalStates.abyssPopupKind = ""
            }
            function closePopup(): void {
                // Semantic "close all" remains reserved for Escape/backdrop
                // and explicit global transitions.
                liquid.dismissPopups()
                window.closeGenericPopup()
            }
            Item {
                anchors.fill: parent
                focus: aux.presented || clipboardBody.presented || leftPanel.presented || rightPanel.presented || popup.presented
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
                edgeInsets: window.nativeInsets
            }
            property string transientPopupHoverKind: ""
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
                    companionCuriosity.yieldToUser()
                    const same = GlobalStates.abyssPopupKind === kind
                        && GlobalStates.abyssPopupTargetOutput === window.outputName
                    // Utilities is hover-owned. A click while it is already open
                    // is an idempotent keep-open action, not a surprising toggle-close.
                    if (kind === "utilities" && same)
                        return
                    window.closeGenericPopup()
                    if (!same) {
                        GlobalStates.abyssPopupTargetOutput = window.outputName
                        GlobalStates.abyssPopupAlong = along
                        GlobalStates.abyssPopupEdge = edge
                        GlobalStates.abyssPopupKind = kind
                    }
                }
                onPopupHoveredRequested: (kind,edge,along) => {
                    companionCuriosity.yieldToUser()
                    const same = GlobalStates.abyssPopupKind === kind
                        && GlobalStates.abyssPopupTargetOutput === window.outputName
                    if (same)
                        return
                    window.closeGenericPopup()
                    GlobalStates.abyssPopupTargetOutput = window.outputName
                    GlobalStates.abyssPopupAlong = along
                    GlobalStates.abyssPopupEdge = edge
                    GlobalStates.abyssPopupKind = kind
                }
                onPopupHoverStateChanged: (kind,edge,along,hovered) => {
                    if (!["wifi","bluetooth","utilities"].includes(kind))
                        return
                    if (hovered) {
                        window.transientPopupHoverKind = kind
                        return
                    }
                    if (window.transientPopupHoverKind === kind)
                        window.transientPopupHoverKind = ""
                }
            }
            WullPortals {presence:companionPresence;z:23}
            Loader {
                id:waterImmersion
                active:window.companionHostActive && field.ready && companion.visible && companion.leaving
                    && ["sink","pulled"].includes(companion.hideClip) && companion.presentation<.999
                z:24
                x:companionPresence.position().x-48*root.companionScale
                y:companionPresence.position().y-100*root.companionScale
                width:208*root.companionScale;height:298*root.companionScale
                sourceComponent:field.immersionComponent
                Binding {target:waterImmersion.item;property:"bodyItem";value:companion;when:waterImmersion.active && !!waterImmersion.item}
                Binding {target:waterImmersion.item;property:"renderRect";value:Qt.vector4d(waterImmersion.x,waterImmersion.y,waterImmersion.width,waterImmersion.height);when:waterImmersion.active && !!waterImmersion.item}
                Binding {target:waterImmersion.item;property:"renderScale";value:window.modelData?.devicePixelRatio ?? 1;when:waterImmersion.active && !!waterImmersion.item}
            }
            AbyssCompanion {
                id: companion
                character:root.companionCharacter
                z: 24
                opacity: companionBridge.ready ? 1 : 0
                edge: companionPresence.emergenceEdge
                scale: root.companionScale
                interactive: root.companionInteractive && window.companionHostActive && !companionPresence.retreating
                // Drag is allowed, but release never leaves Wull parked in open
                // space. A fast release becomes a bounded throw to a verified
                // grounded destination; a slow release settles back to support.
                dragEnabled: interactive
                motionEnabled: root.companionPreferences.animationsEnabled && AbyssStyle.motionEnabled
                effectsEnabled: root.companionPreferences.effectsEnabled && Appearance.effectsEnabled
                    && AbyssStyle.quality!=="performance"
                motionScale: WullPreferences.motionScale(root.companionPreferences.personality)
                renderQuality: AbyssRenderPolicy.wullQuality
                translucency: root.companionPreferences.translucency
                travelEnabled: companionPresence.traveling && !companionPresence.portalActive
                portalReveal:companionPresence.portalReveal
                travelMode: companionPresence.mode
                surfaceSupported: companionPresence.grounded
                travelDuration: companionPresence.duration
                travelArc: companionPresence.arc
                travelDirection: companionPresence.directionX/Math.max(1,Math.hypot(companionPresence.directionX,companionPresence.directionY))
                travelDirectionY: companionPresence.directionY/Math.max(1,Math.hypot(companionPresence.directionX,companionPresence.directionY))
                managedPlacement: true
                emergenceEdge: companionPresence.emergenceEdge
                upright: true
                standingAngle: companionPresence.standingAngle
                appearClip: companionPresence.appearClip
                appearanceOffsetX: companionPresence.appearanceOffsetX
                appearanceOffsetY: companionPresence.appearanceOffsetY
                hideClip: companionPresence.hideClip
                travelNormalX: companionPresence.normalX
                travelNormalY: companionPresence.normalY
                connectedWater: true
                curvedImmersion:waterImmersion.active && !!waterImmersion.item && waterImmersion.item.status!==ShaderEffect.Error
                reveal: companionPresence.renderedReveal
                pointerFresh: window.companionPointerFresh
                    && Math.hypot(window.companionPointerX-(x+width/2),window.companionPointerY-(y+height/2))<companionPresence.pointerNoticeRadius
                pointerX: (window.companionPointerX-(x+width/2))/(140*scale)
                pointerY: (window.companionPointerY-(y+height/2))/(140*scale)
                gazeX: companionBridge.gazeX
                gazeY: companionBridge.gazeY
                energy: companionBridge.energy
                bodySquash: companionBridge.squash
                bodyStretch: companionBridge.stretch
                bodyLean: companionBridge.lean
                bodyTip: companionBridge.tip
                ripple: companionBridge.ripple
                eyeOpen: companionBridge.eyeOpen
                mouthCurve: companionBridge.mouthCurve
                pulse: companionBridge.pulse
                expression: companionBridge.expression
                mood: companionBridge.mood
                activity: companionBridge.activity
                targetX: companionPresence.targetX+(root.companionScale-1)*implicitWidth/2
                targetY: companionPresence.targetY+(root.companionScale-1)*implicitHeight/2
                onTravelCompleted: companionPresence.arrived()
                onDragStarted: companionPresence.beginDrag()
                onDragPositionRequested: (px,py)=>companionPresence.dragTo(
                    px-(root.companionScale-1)*implicitWidth/2,
                    py-(root.companionScale-1)*implicitHeight/2)
                onDragEnded: companionPresence.endDrag()
                onActivated: {companionWater.tap();companionBridge.sendEvent("click")}
                onChatRequested: {companionCuriosity.interrupt();WullMind.openChat()}
                onSettingsRequested: GlobalStates.openSettingsSection(37,"Overview")
            }
            WullTalkCloud {
                id:talkCloud;actor:companion
                outputWidth:window.width;outputHeight:window.height
                allowed:window.companionHostActive && root.companionInteractive
                onControlsVisibleChanged: if (controlsVisible) companionCuriosity.interrupt()
            }
            WullCloudActions {
                id:cloudActions;actor:companion
                outputWidth:window.width;outputHeight:window.height
                allowed:window.companionHostActive && root.companionInteractive
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
                // Hover state is transient; popup ownership has its own leases.
                // Clearing revealedBars while a popup is open lets the lease
                // release hide the Bar immediately after the popup retracts,
                // instead of leaving the Bar stuck open until another hover.
                onTriggered: if (!barHover.hovered && !revealHover.hovered)
                    root.setBarRevealed(window.outputName,false)
            }
            property real barProgress: root.barOnOutput(window.outputName) ? 1 : 0
            Behavior on barProgress {
                enabled: AbyssStyle.motionEnabled
                NumberAnimation { duration: AbyssStyle.motionNormal; easing.type: Easing.OutCubic }
            }
            readonly property var nativeInsets: {
                const result = ModuleLayout.edgeInsetsForModules([],bar.layoutOptions,Appearance.fontSizeScale,AbyssStyle.perimeterThickness,AbyssStyle.barThickness,false)
                return bar.visible ? ModuleLayout.edgeInsetsForModules(bar.placements,bar.layoutOptions,Appearance.fontSizeScale,
                    AbyssStyle.perimeterThickness,AbyssStyle.barThickness,false) : result
            }
            AbyssSurfaceController {
                id: liquid
                outputName: window.outputName
                outputWidth: window.width
                outputHeight: window.height
                presented: window.presented
                presentationItem: field
                dialogHost: dialogBody
                edgeInsets: window.nativeInsets
                moduleRecords: bar.visible ? bar.deformations : []
            }
            readonly property var sideObstacles: {
                // Keep the filter phase before either selected record read.
                const leftVisible = leftPanel.progress > 0.001
                const rightVisible = rightPanel.progress > 0.001
                const result = []
                if (leftVisible) result.push(leftPanel.record)
                if (rightVisible) result.push(rightPanel.record)
                return result
            }
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
                && !controls.open && !aux.open && !clipboardBody.open && !dialogBody.open && !GlobalStates.settingsNativeDialogOpen
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
                transientOpen: GlobalStates.sidebarLeftTransient
                bodyItem: leftPanel.contentParent
                onRevealRequested: GlobalStates.openSidebarLeft(window.outputName, true)
                onHideRequested: if (GlobalStates.sidebarLeftPresentationOutput===window.outputName) GlobalStates.closeSidebarLeft()
            }
            SidebarReveal {
                id: rightReveal
                x: window.width-width
                available: window.sidebarRevealAvailable && (Config.options?.enabledPanels ?? []).includes("abyssSidebarRight")
                open: rightPanel.open
                transientOpen: GlobalStates.sidebarRightTransient
                bodyItem: rightPanel.contentParent
                onRevealRequested: GlobalStates.openSidebarRight(window.outputName, true)
                onHideRequested: if (GlobalStates.sidebarRightPresentationOutput===window.outputName) GlobalStates.closeSidebarRight()
            }
            AbyssCorners {
                id:corners;anchors.fill:parent;controller:liquid;outputName:window.outputName
                attachmentThickness:window.nativeInsets.bottom
                quickNotesEditorOutput: root.quickNotesEditorOutput
                presentationEnabled:window.presented && field.ready && !window.editorOpen
                blocked:settings.open || dashboardBody.open || utility.open || controls.open || aux.open || clipboardBody.open
                    || GlobalStates.settingsNativeDialogOpen || PolkitService.active || GlobalStates.regionSelectorOpen
                onQuickNotesEditorLeaseChanged:(outputName,focused)=>
                    root.setQuickNotesEditorOutput(outputName,focused)
            }
            AbyssBodyHost {
                id: widgetEditorBody
                identity: "widgetEditor"
                controller: liquid
                anchors.fill: parent
                outputName: window.outputName
                embeddedItem: GlobalStates.desktopWidgetEditors[window.outputName] ?? null
                readonly property var editorWorkArea: ({
                    left:window.nativeInsets.left, top:window.nativeInsets.top,
                    right:window.width-window.nativeInsets.right,
                    bottom:window.height-window.nativeInsets.bottom})
                readonly property var editorPlacement: embeddedItem?.placement ?? {edge:"bottom",along:0,span:900,depth:64}
                edge: editorPlacement.edge
                along: editorPlacement.along
                span: editorPlacement.span
                depth: editorPlacement.depth
                padding: 6
                edgeInsets: window.bodyInsets(edge,along,span)
                placementPriority: 1
                placementCanResize: false
                placementCanStackInward: false
                animatePlacementChanges: false
                stableContentSize: true
                open: window.presented && field.ready && embeddedItem !== null && GlobalStates.widgetEditMode
                Binding {
                    target: widgetEditorBody.embeddedItem
                    property: "abyssHost"
                    value: widgetEditorBody
                    when: widgetEditorBody.embeddedItem !== null
                    restoreMode: Binding.RestoreBindingOrValue
                }
            }
            AbyssBodyHost {
                id: leftPanel
                identity: "leftPanel"
                controller: liquid
                anchors.fill: parent
                edge: window.positionEdge(identity,ShellLayoutController.sidebarAssignments().featureSidebar)
                outputName: window.outputName
                vacancyRole: "featureSidebar"
                open: window.presented && field.ready && (Config.options?.enabledPanels ?? []).includes("abyssSidebarLeft")
                    && GlobalStates.sidebarLeftOpen && GlobalStates.sidebarLeftPresentationOutput === window.outputName

                edgeInsets: window.bodyInsets(edge,along,span)
                along: window.positionAlong(identity,edge,span,Geometry.horizontal(edge) ? (window.width-span)/2 : (window.height-span)/2)
                readonly property var sizeState:ShellLayoutController.currentState("featureSidebar",window.outputName)
                readonly property real bodyWidth:Math.min(window.width*.8,(sizeState.width ?? 460)+(GlobalStates.sidebarLeftExpanded ? 190 : 0))
                readonly property real bodyHeight:Math.min(window.height-window.nativeInsets.top-window.nativeInsets.bottom-72,
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
                vacancyRole: "systemSidebar"
                open: window.presented && field.ready && (Config.options?.enabledPanels ?? []).includes("abyssSidebarRight")
                    && GlobalStates.sidebarRightOpen && GlobalStates.sidebarRightPresentationOutput === window.outputName

                edgeInsets: window.bodyInsets(edge,along,span)
                along: window.positionAlong(identity,edge,span,Geometry.horizontal(edge) ? (window.width-span)/2 : (window.height-span)/2)
                readonly property var sizeState:ShellLayoutController.currentState("systemSidebar",window.outputName)
                readonly property real bodyWidth:Math.min(window.width*.8,sizeState.width ?? 460)
                readonly property real bodyHeight:Math.min(window.height-window.nativeInsets.top-window.nativeInsets.bottom-72,
                    sizeState.sizeMode === "custom" ? sizeState.customHeight : Math.max(420,contentItem.item?.preferredContentHeight ?? window.height*.7))
                span:Geometry.horizontal(edge) ? bodyWidth : bodyHeight
                depth:Geometry.horizontal(edge) ? bodyHeight : bodyWidth
                source: "content/AbyssRightContent.qml"
                onCloseRequested: GlobalStates.closeSidebarRight()
            }
            AbyssGenericPopupPresenter {
                id: popup
                anchors.fill: parent
                controller: liquid
                outputName: window.outputName
                outputWidth: window.width
                outputHeight: window.height
                positions: Config.options?.abyss?.positions ?? []
                presentationInsets: window.nativeInsets
                obstacles: window.sideObstacles

                requestedKind: GlobalStates.abyssPopupKind
                requestedOpen: window.presented && field.ready
                    && (Config.options?.enabledPanels ?? []).includes("abyssPopup")
                    && requestedKind.length > 0
                    && GlobalStates.resolveOutputName(
                        GlobalStates.abyssPopupTargetOutput,[]) === window.outputName
                requestedFallbackEdge:
                    GlobalStates.abyssPopupEdge || root.barEdge
                requestedAlongCenter: GlobalStates.abyssPopupAlong
                hoverKind: window.transientPopupHoverKind
                companionVisitActive: companionCuriosity.owned
                    && companionCuriosity.feature?.kind==="utilities"
                    && window.ownsCompanionFeature(companionCuriosity.feature)
                bodyInsetsResolver: (edge,along,span) =>
                    window.bodyInsets(edge,along,span)

                onCloseRequested: kind => window.closeGenericPopup(kind)
            }
            // Stable slots avoid destroying/recreating a mature popup's visual
            // content when another popup opens. The controller owns slot
            // assignment; every host remains an ordinary Abyss participant so
            // anchor-preserving composition, input masks and focus arbitration
            // apply to all simultaneous popups.
            Repeater {
                id: styledPopupHosts
                model: liquid.popupCapacity

                delegate: AbyssBodyHost {
                    id: styledPopupHost
                    required property int index
                    readonly property var popupEntry: liquid.popupSlots[index] ?? null
                    readonly property var hostedPopup: popupEntry?.popup ?? null
                    readonly property string presentationKind: {
                        const explicitKind = String(
                            hostedPopup?.liquidPresentationKind ?? "")
                        return explicitKind.length > 0
                            ? explicitKind
                            : (hostedPopup?._liquidAnchor?.kind ?? "popup")
                    }

                    identity: "styledPopup" + index
                    stackPolicy: "pyramid"
                    semanticOpenOverride:
                        hostedPopup?.liquidSemanticVisible ?? false
                    readonly property var configuredPresentation:
                        window.presentation(presentationKind)
                    readonly property string configuredJoinedEdge:
                        Presentation.joinedEdge(presentationKind,
                            configuredPresentation,edge,along,span,
                            window.width,window.height)
                    joinedEdge: configuredJoinedEdge.length > 0
                        ? configuredJoinedEdge
                        : (hostedPopup?._liquidAnchor?.popupJoinedEdge ?? "")
                    controller: liquid
                    anchors.fill: parent
                    edge: window.positionEdge(presentationKind,
                        hostedPopup?._attachmentEdge ?? root.barEdge)
                    outputName: window.outputName
                    vacancyRole: presentationKind === "quickNotes"
                        ? "quickNotes"
                        : (presentationKind === "notificationCenter"
                            ? "notificationCenter" : "")
                    open: window.presented && field.ready
                        && (hostedPopup?.presentationActive ?? false)
                        && ((hostedPopup?.requestedVisible ?? false)
                            || ((hostedPopup?.hoverActivates ?? false)
                                && (hostedPopup?._lingerVisible ?? false)))
                    animatePresentation: true
                    externalProgress: hostedPopup?.revealProgress ?? 0
                    embeddedItem: hostedPopup?.contentItem ?? null
                    edgeInsets: window.bodyInsets(edge,along,span)
                    padding: 14
                    span: (Geometry.horizontal(edge)
                        ? (embeddedItem?.implicitWidth ?? 1)
                        : (embeddedItem?.implicitHeight ?? 1))+padding*2
                    depth: (Geometry.horizontal(edge)
                        ? (embeddedItem?.implicitHeight ?? 1)
                        : (embeddedItem?.implicitWidth ?? 1))+padding*2
                    largeSurface: depth
                        > (Geometry.horizontal(edge) ? window.height : window.width)*.42
                    readonly property rect anchorBounds:
                        hostedPopup?._anchorRect(window.width,window.height)
                            ?? Qt.rect(0,0,0,0)
                    along: window.positionAlong(presentationKind,edge,span,
                        (Geometry.horizontal(edge)
                            ? anchorBounds.x+anchorBounds.width/2
                            : anchorBounds.y+anchorBounds.height/2)-span/2)
                    obstacles: window.sideObstacles

                    onPopupEntryChanged: {
                        retainedPlacement = null
                        resetPyramidMotion()
                    }
                    onCloseRequested: hostedPopup?.dismissPresentation()
                    Component.onCompleted:
                        liquid.registerPopupHost(index,styledPopupHost)
                    Component.onDestruction:
                        liquid.unregisterPopupHost(index,styledPopupHost)

                    HoverHandler {
                        parent: styledPopupHost.contentParent
                        enabled: styledPopupHost.open
                        onHoveredChanged: {
                            if (styledPopupHost.hostedPopup)
                                styledPopupHost.hostedPopup._contentHovered = hovered
                        }
                    }
                }
            }
            property bool dockHovered: false
            // Retain the source/arrival water during a visit and its final dive.
            // This reads semantic placement and the actor's presentation, not
            // the derived scene/permission, so Dock geometry cannot bind back
            // into its own open decision. Policy reset removes the hold at once.
            readonly property bool companionDockHeld: companionBridge.ready && companion.visible
                && (companionPresence.placement.key==="dock"
                    || companionPresence.placement.support?.key==="dock"
                    || (companionPresence.traveling && companionPresence.destination.key==="dock"))
            readonly property string dockEdge: ["top","bottom","left","right"].includes(Config.options?.dock?.position) ? Config.options.dock.position : "bottom"
            AbyssBodyHost {
                id: dock
                stableContentSize: true
                residentContent: true
                property real cachedSpan: 220
                readonly property real measuredSpan: contentItem.item?.desiredSpan ?? cachedSpan
                readonly property bool attachedPopupHold:
                    liquid.hasPopupAnchoredTo(dock)
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
                    && !aux.open && !clipboardBody.open && !utility.open
                    && (GlobalStates.abyssPopupKind === "dockAppMenu"
                        || attachedPopupHold
                        || !liquid.participantOverlapsRect("popup", requestedRecord.surface, 10))
                    && (GlobalStates.abyssPopupKind === "dockAppMenu"
                        || attachedPopupHold
                        || !liquid.hasPopupOverlapRect(requestedRecord.surface, 10))
                    && (((Config.options?.dock?.pinnedOnStartup ?? false) && !(Config.options?.dock?.hoverToReveal ?? false)) || window.dockHovered
                        || window.companionDockHeld
                        || attachedPopupHold
                        || (contentItem.item?.requestDockShow ?? false)
                        || ((Config.options?.dock?.showOnDesktop ?? true) && !ToplevelManager.activeToplevel?.activated))
                edgeInsets: window.bodyInsets(edge,along,span)
                span: Math.min((Geometry.horizontal(edge) ? window.width : window.height)-80,
                    Math.max(140,measuredSpan))
                along: (Geometry.horizontal(edge) ? window.width : window.height)/2-span/2
                depth: AbyssStyle.dockThickness
                padding: 12
                obstacles: {
                    // Keep the first concat's evaluation/copy phase intact.
                    const result = window.sideObstacles.concat(notification.progress > 0.001 ? [notification.record] : [])
                    if (popup.progress > 0.001) result.push(popup.record)
                    return result
                }
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
                id:keyboardBody;identity:"keyboard"
                controller:liquid;anchors.fill:parent;outputName:window.outputName
                z:(Config.options?.osk?.keepOnTop ?? false) ? 10000 : 0
                property string draftEdge:""
                property real draftAlong:NaN
                property real dragOriginX:0
                property real dragOriginY:0
                property bool dragActive:false
                edge:draftEdge || (["top","bottom"].includes(window.positionEdge(identity,"bottom")) ? window.positionEdge(identity,"bottom") : "bottom")
                open:window.presented && field.ready && GlobalStates.oskOpen
                    && (Config.options?.enabledPanels ?? []).includes("iiOnScreenKeyboard")
                    && GlobalStates.resolveOutputName(GlobalStates.oskTargetMonitor,[])===window.outputName
                edgeInsets:window.bodyInsets(edge,along,span)
                span:Math.min(1010,window.width*.94);depth:Math.min(440,window.height*.72)
                placementCanResize:false
                along:Number.isFinite(draftAlong) ? draftAlong : window.positionAlong(identity,edge,span,window.width/2-span/2)
                source:"../onScreenKeyboard/AbyssKeyboardContent.qml"
                function beginKeyboardDrag():void {
                    dragActive=true;animatePlacementChanges=false
                    dragOriginX=inputBounds.x+inputBounds.width/2
                    dragOriginY=inputBounds.y+inputBounds.height/2
                }
                function moveKeyboardDrag(dx,dy):void {
                    if(!dragActive)return
                    draftEdge=dragOriginY+dy<window.height/2 ? "top" : "bottom"
                    draftAlong=Math.max(window.nativeInsets.left,Math.min(window.width-window.nativeInsets.right-span,dragOriginX+dx-span/2))
                }
                function finishKeyboardDrag():void {
                    if(!dragActive)return
                    dragActive=false;animatePlacementChanges=true
                    const start=window.nativeInsets.left,end=Math.max(start,window.width-window.nativeInsets.right-span)
                    Config.setNestedValue("abyss.positions",Presentation.save(Config.options?.abyss?.positions,identity,outputName,
                        {edge:edge,alignment:"custom",position:end>start ? Math.max(0,Math.min(1,(along-start)/(end-start))) : .5}))
                    draftEdge="";draftAlong=NaN
                }
                onOpenChanged:if(!open){dragActive=false;draftEdge="";draftAlong=NaN;animatePlacementChanges=true}
                onCloseRequested:GlobalStates.oskOpen=false
            }
            AbyssBodyHost {
                id:wallpaperBody;identity:"wallpaper"
                controller:liquid;anchors.fill:parent;outputName:window.outputName
                edge:window.positionEdge(identity,"bottom")
                open:window.presented && field.ready && GlobalStates.wallpaperLauncherOpen
                    && (Config.options?.enabledPanels ?? []).includes("iiWallpaperSelector")
                    && GlobalStates.resolveOutputName(GlobalStates.wallpaperSelectorTargetMonitor,[])===window.outputName
                edgeInsets:window.bodyInsets(edge,along,span)
                readonly property real contentWidth:Math.min(1080,window.width*.9)
                readonly property real contentHeight:Math.min(320,window.height*.65)
                span:Geometry.horizontal(edge) ? contentWidth : contentHeight
                depth:Geometry.horizontal(edge) ? contentHeight : contentWidth
                along:window.positionAlong(identity,edge,span,(Geometry.horizontal(edge) ? window.width : window.height)/2-span/2)
                minimumSpan:Math.min(span,420);minimumDepth:Math.min(depth,280)
                source:"../wallpaperLauncher/WallpaperLauncherContent.qml"
                onReadyChanged:if(ready && contentItem.item)contentItem.item.embedded=true
                onCloseRequested:GlobalStates.wallpaperLauncherOpen=false
            }
            // Distinct hosts retain their own content until retraction ends.
            // Switching the aux Loader to Overview on clipboard close briefly
            // rendered Dashboard inside the still-visible Clipboard silhouette.
            AbyssBodyHost {
                id: clipboardBody
                identity: "clipboard"
                controller: liquid
                anchors.fill: parent
                edge: window.positionEdge(identity,"bottom")
                outputName: window.outputName
                open: window.presented && field.ready && GlobalStates.clipboardOpen
                    && (Config.options?.enabledPanels ?? []).includes("abyssClipboard")
                    && GlobalStates.resolveOutputName(GlobalStates.abyssClipboardTargetOutput,[]) === window.outputName
                edgeInsets: window.bodyInsets(edge,along,span)
                readonly property real contentWidth: 640
                readonly property real contentHeight: window.height*.42
                span: Geometry.horizontal(edge) ? contentWidth : contentHeight
                along: window.positionAlong(identity,edge,span,(Geometry.horizontal(edge) ? window.width : window.height)/2-span/2)
                depth: Geometry.horizontal(edge) ? contentHeight : contentWidth
                obstacles: window.sideObstacles
                source: "content/AbyssClipboardContent.qml"
                onCloseRequested: GlobalStates.clipboardOpen = false
            }
            AbyssBodyHost {
                id: aux
                stableContentSize: true
                identity: "aux"
                controller: liquid
                anchors.fill: parent
                readonly property string presentationKind: "overview"
                edge: window.positionEdge(presentationKind,"bottom")
                outputName: window.outputName
                open: window.presented && field.ready && GlobalStates.overviewOpen
                    && (Config.options?.enabledPanels ?? []).includes("abyssOverview")
                    && GlobalStates.overviewPresentationOutput === window.outputName
                edgeInsets: window.bodyInsets(edge,along,span)
                largeSurface: true
                readonly property real contentWidth: GlobalStates.overviewMode === "taskview" ? window.width*.9 : window.width*(Config.options?.dashboard?.widthRatio ?? .72)+40
                readonly property real contentHeight: (contentItem.item?.desiredHeight ?? window.height*.72)+padding*2
                span: Geometry.horizontal(edge) ? contentWidth : contentHeight
                along: window.positionAlong(presentationKind,edge,span,(Geometry.horizontal(edge) ? window.width : window.height)/2-span/2)
                depth: Geometry.horizontal(edge) ? contentHeight : contentWidth
                source: "content/AbyssOverviewContent.qml"
                onCloseRequested: GlobalStates.overviewOpen = false
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
                edgeInsets: window.bodyInsets(edge,along,span)
                span: Geometry.horizontal(edge) ? Math.min(1600,Math.max(900,window.width*.9)) : Math.min(1080,Math.max(720,window.height*.92))
                along: window.positionAlong(identity,edge,span,((Geometry.horizontal(edge) ? window.width : window.height)-span)/2)
                depth: Geometry.horizontal(edge) ? Math.min(1080,Math.max(720,window.height*.92)) : Math.min(1600,Math.max(900,window.width*.9))
                source: "content/AbyssSettingsContent.qml"
                onCloseRequested: GlobalStates.settingsOverlayOpen = false
            }
            AbyssBodyHost {
                id: dashboardBody
                stableContentSize: true
                identity: "dashboard"
                controller: liquid
                anchors.fill: parent
                edge: window.positionEdge(identity,"bottom")
                outputName: window.outputName
                open: window.presented && field.ready && GlobalStates.dashboardOpen
                    && root.largeTargetOutput === window.outputName && (Config.options?.enabledPanels ?? []).includes("iiDashboard")
                largeSurface: true
                edgeInsets: window.bodyInsets(edge,along,span)
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
                edgeInsets: window.bodyInsets(edge,along,span)
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
                joinedEdge: window.presentation(presentationKind).joinCorner===true
                    ? ModuleLayout.adjacentEdge({edge:edge,along:along,span:span},window.width,window.height) : ""
                outputName: window.outputName
                open: window.presented && field.ready && (!GlobalStates.notificationCenterOpen && !Notifications.popupInhibited && Notifications.popupList.length > 0
                        && (Config.options?.enabledPanels ?? []).includes("abyssNotificationPopup")
                        && Geometry.targets(window.outputName,Config.options?.notifications?.screenList ?? [],Quickshell.screens.map(s => s.name)))
                edgeInsets: window.bodyInsets(edge,along,span)
                readonly property real contentWidth: centerOnOutput ? 390 : (contentItem.item?.desiredWidth ?? Appearance.sizes.notificationPopupWidth)+padding*2
                readonly property real contentHeight: centerOnOutput ? window.height-window.nativeInsets.top-window.nativeInsets.bottom-72 : Math.min(window.height*.42,Math.max(100,(contentItem.item?.desiredHeight ?? 130)+padding*2))
                span: Geometry.horizontal(edge) ? contentWidth : contentHeight
                along: window.positionAlong(presentationKind,edge,span,centerOnOutput ? (Geometry.horizontal(edge) ? (window.width-span)/2 : window.nativeInsets.top+36) : position.endsWith("Left") ? 40 : (Geometry.horizontal(edge) ? window.width : window.height)-span-40)
                depth: Geometry.horizontal(edge) ? contentHeight : contentWidth
                obstacles: centerOnOutput ? [] : window.sideObstacles.concat(popup.open ? [popup.record] : [])
                contentKind: centerOnOutput ? "center" : "popup"
                source: "content/AbyssNotificationsContent.qml"
                onCloseRequested: GlobalStates.closeNotificationCenter()
            }
            // Reload/system toasts reuse the same output-owned Abyss field.
            // ToastManager remains the single queue/timer owner; the legacy
            // independent PanelWindow is never loaded while Abyss is active.
            AbyssBodyHost {
                id: toastBody
                identity: "toast"
                controller: liquid
                anchors.fill: parent
                edge: "top"
                joinedEdge: "right"
                outputName: window.outputName
                open: window.presented && field.ready
                    && (GlobalStates.toastManager?.useAbyssPresentation ?? false)
                    && !(GlobalStates.toastManager?.suppressOnScreenToasts ?? false)
                    && (GlobalStates.toastManager?.toasts?.length ?? 0) > 0
                    && GlobalStates.toastManager?.presentationOutputName === window.outputName
                animatePresentation: false
                externalProgress: GlobalStates.toastManager?.surfaceRevealProgress ?? 0
                placementPriority: 1
                edgeInsets: window.bodyInsets(edge,along,span)
                padding: 8
                span: (contentItem.item?.desiredWidth ?? 180)+padding*2
                depth: (contentItem.item?.desiredHeight ?? 54)+padding*2
                along: Math.max(window.nativeInsets.left,
                    window.width-window.nativeInsets.right-span)
                source: "content/AbyssToastContent.qml"
            }
            AbyssBodyHost {
                id: osd
                identity: "osd"
                controller: liquid
                anchors.fill: parent
                readonly property string presentationKind: GlobalStates.abyssOsdKind === "media" ? "mediaOsd" : GlobalStates.abyssOsdKind
                edge: window.positionEdge(presentationKind,root.barEdge)
                joinedEdge: window.presentation(presentationKind).joinCorner===true
                    ? ModuleLayout.adjacentEdge({edge:edge,along:along,span:span},window.width,window.height) : ""
                outputName: window.outputName
                open: window.presented && field.ready && (Config.options?.enabledPanels ?? []).includes("abyssOnScreenDisplay")
                    && (GlobalStates.osdVolumeOpen || GlobalStates.osdBrightnessOpen || GlobalStates.osdMicOpen || GlobalStates.osdMediaOpen || GlobalStates.osdKeyboardLayoutOpen)
                    && Geometry.targets(window.outputName,Config.options?.osd?.screenList ?? [],Quickshell.screens.map(s => s.name))
                edgeInsets: window.bodyInsets(edge,along,span)
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
                edgeInsets: window.bodyInsets(edge,along,span)
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
                vacancyRole: String(
                    liquid.activeDialog?.liquidVacancyRole ?? "")
                open: window.presented && field.ready && liquid.activeDialog !== null
                embeddedItem: liquid.activeDialog
                span: (Geometry.horizontal(edge) ? (liquid.activeDialog?.liquidWidth ?? 350) : (liquid.activeDialog?.liquidHeight ?? 450))+padding*2
                depth: (Geometry.horizontal(edge) ? (liquid.activeDialog?.liquidHeight ?? 450) : (liquid.activeDialog?.liquidWidth ?? 350))+padding*2
                along: window.positionAlong(identity,edge,span,((Geometry.horizontal(edge) ? window.width : window.height)-span)/2)
                edgeInsets: window.bodyInsets(edge,along,span)
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
                waterLink: companionWater
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
