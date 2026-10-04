pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Quickshell
import qs
import qs.modules.common
import qs.modules.bar
import qs.modules.abyss
import qs.modules.abyss.bar

FloatingWindow {
    id: root
    visible: true
    implicitWidth: 1100; implicitHeight: 780
    property bool done: false
    property string testPhase: "initialize"
    property var retained: null
    property var borrower: QtObject {}
    property bool utilitiesOpen: false
    property bool utilitiesVisit: false
    Item {
        id: scene
        anchors.fill: parent
        AbyssBarModule {
            id: module
            x: 390; y: 12; width: 220; height: 32
            kind: "clock"; outputName: root.screen.name
            liquidController: controller
        }
        AbyssGenericPopupPresenter {
            id: utilities;anchors.fill:parent;controller:controller
            outputName:root.screen.name;outputWidth:scene.width;outputHeight:scene.height
            requestedKind:"utilities";requestedOpen:root.utilitiesOpen
            requestedAlongCenter:700;presentationInsets:controller.edgeInsets
            companionVisitActive:root.utilitiesVisit
            onCloseRequested:root.utilitiesOpen=false
        }
        Repeater {
            model: controller.popupCapacity
            delegate: AbyssBodyHost {
                id: host
                required property int index
                readonly property var popup: controller.popupSlots[index]?.popup ?? null
                identity: "styledPopup"+index; anchors.fill: parent; controller: controller
                open: popup?.presentationActive ?? false
                semanticOpenOverride: popup?.liquidSemanticVisible ?? false
                externalProgress: popup?.revealProgress ?? 0
                edge: "top"; along: 220; span: 520; depth: 490
                embeddedItem: popup?.contentItem ?? null
                edgeInsets: controller.edgeInsets
                Component.onCompleted: controller.registerPopupHost(index,host)
                Component.onDestruction: controller.unregisterPopupHost(index,host)
            }
        }
    }
    AbyssSurfaceController {
        id: controller
        presentationItem: scene; outputWidth: scene.width; outputHeight: scene.height
        edgeInsets: ({left:16,right:16,top:16,bottom:16})
    }
    TestCase {
        id: input;name: "WullMaturePopup"; when: false
        function check(value,message): void {if(!value) {console.error("WULL_POPUP=FAIL "+message);Qt.quit();throw new Error(message)}}
        function exercisePopup(): void {
            tryCompare(Config,"ready",true,4000)
            check(Config.ready,"config not ready")
            tryCompare(root,"backingWindowVisible",true,4000)
            check(root.backingWindowVisible,"owned window not exposed")
            mouseMove(scene,900,700);wait(120)
            tryVerify(()=>module.companionPopup && module.companionPopup._anchorReady,4000)
            check(module.companionPopup && module.companionPopup._anchorReady,"mature anchor not ready")
            const popup=module.companionPopup
            root.testPhase="borrow"
            check(popup.acquireCompanion(root.borrower),"mature clock refused lease")
            wait(400)
            check(controller.activePopups.length===1 && controller.activePopup===popup,"curiosity created another popup")
            check(!popup.active && popup.presentationWindow===root,"curiosity created a native window")
            root.retained=popup.contentItem
            const slot=controller._popupSlot(popup), parent=popup.contentItem.parent
            // Send a real Qt hover to the mature control after its owning
            // window is exposed; await delivery rather than a fixed sleep.
            mouseMove(popup.hoverTarget,popup.hoverTarget.width/2,popup.hoverTarget.height/2)
            root.testPhase="handoff"
            tryVerify(()=>popup.humanVisibleRequest && popup.companionLease===null,1500)
            check(popup.humanVisibleRequest && popup.companionLease===null,"hover did not hand off ownership")
            check(controller.activePopups.length===1 && controller._popupSlot(popup)===slot,"hover stacked a duplicate host")
            check(popup.contentItem===root.retained && popup.contentItem.parent===parent,"hover replaced mature content")
            check(popup.requestedVisible,"human hover was not semantically visible")
            popup.releaseCompanion(root.borrower)
            check(popup.presentationActive && popup.requestedVisible,"Wull departure closed human popup")
            // Qt's synthetic hover does not move the compositor's physical
            // cursor. Refresh the owned input before testing ongoing hover.
            mouseMove(popup.hoverTarget,popup.hoverTarget.width/2+1,popup.hoverTarget.height/2)
            tryVerify(()=>popup.humanVisibleRequest && popup.presentationActive,1500)
            check(popup.humanVisibleRequest && popup.presentationActive,"human hover lost the mature popup")
            mouseMove(scene,900,700)
            root.testPhase="hover leave"
            tryVerify(()=>controller.activePopups.length===0,2500)
            check(controller.activePopups.length===0,"hover leave did not retract mature popup")
            check(popup.acquireCompanion(root.borrower),"second lease failed")
            root.testPhase="second release"
            wait(100);popup.releaseCompanion(root.borrower)
            tryVerify(()=>!popup.presentationActive && controller.activePopups.length===0,2500)
            check(!popup.presentationActive && controller.activePopups.length===0,"owned close retained popup")
            GlobalStates.deferredPanelsReady=true
            root.utilitiesVisit=true;root.utilitiesOpen=true
            root.testPhase="utilities ready"
            tryCompare(utilities,"ready",true,3500)
            check(utilities.ready,"owned utilities did not construct")
            wait(1000)
            check(root.utilitiesOpen && utilities.open,"idle timer closed utilities during companion visit")
            root.utilitiesVisit=false
            root.testPhase="utilities release"
            tryCompare(root,"utilitiesOpen",false,2500)
            check(!root.utilitiesOpen,"released utilities retained idle popup")
            console.log("WULL_POPUP=PASS oneMatureContent stableSlot realHover handoff ownedClose noNativeDuplicate utilitiesVisitHold releasedIdleClose")
            root.done=true
        }
    }
    Timer {interval:200;running:Config.ready;repeat:false;onTriggered:input.exercisePopup()}
    Timer {interval:100;running:root.done;onTriggered:Qt.quit()}
    Timer {interval:16000;running:true;onTriggered:{console.error("WULL_POPUP=FAIL timeout "+JSON.stringify({phase:root.testPhase,
        utilitiesOpen:root.utilitiesOpen,utilitiesReady:utilities.ready,utilitiesResident:utilities.open,
        utilityKind:utilities.activeKind,popupHovered:module.companionPopup?.humanVisibleRequest,
        popupRequested:module.companionPopup?.requestedVisible,popups:controller.activePopups.length}));Qt.quit()}}
}
