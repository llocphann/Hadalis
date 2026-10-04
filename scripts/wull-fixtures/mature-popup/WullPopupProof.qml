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
    property var retained: null
    property var borrower: QtObject {}
    Item {
        id: scene
        anchors.fill: parent
        AbyssBarModule {
            id: module
            x: 390; y: 12; width: 220; height: 32
            kind: "clock"; outputName: root.screen.name
            liquidController: controller
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
            check(popup.acquireCompanion(root.borrower),"mature clock refused lease")
            wait(400)
            check(controller.activePopups.length===1 && controller.activePopup===popup,"curiosity created another popup")
            check(!popup.active && popup.presentationWindow===root,"curiosity created a native window")
            root.retained=popup.contentItem
            const slot=controller._popupSlot(popup), parent=popup.contentItem.parent
            // Send a real Qt hover to the mature control after its owning
            // window is exposed; await delivery rather than a fixed sleep.
            mouseMove(popup.hoverTarget,popup.hoverTarget.width/2,popup.hoverTarget.height/2)
            tryVerify(()=>popup.humanVisibleRequest && popup.companionLease===null,1500)
            check(popup.humanVisibleRequest && popup.companionLease===null,"hover did not hand off ownership")
            check(controller.activePopups.length===1 && controller._popupSlot(popup)===slot,"hover stacked a duplicate host")
            check(popup.contentItem===root.retained && popup.contentItem.parent===parent,"hover replaced mature content")
            popup.releaseCompanion(root.borrower);wait(150)
            check(popup.presentationActive && popup.requestedVisible,"Wull departure closed human popup")
            mouseMove(scene,900,700);wait(500)
            check(controller.activePopups.length===0,"hover leave did not retract mature popup")
            check(popup.acquireCompanion(root.borrower),"second lease failed")
            wait(100);popup.releaseCompanion(root.borrower);wait(500)
            check(!popup.presentationActive && controller.activePopups.length===0,"owned close retained popup")
            console.log("WULL_POPUP=PASS oneMatureContent stableSlot realHover handoff ownedClose noNativeDuplicate")
            root.done=true
        }
    }
    Timer {interval:200;running:Config.ready;repeat:false;onTriggered:input.exercisePopup()}
    Timer {interval:100;running:root.done;onTriggered:Qt.quit()}
    Timer {interval:12000;running:true;onTriggered:{console.error("WULL_POPUP=FAIL timeout");Qt.quit()}}
}
