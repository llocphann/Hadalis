// Inert private test underlay for REAL nested-Niri compositor pointer routing.
// Its own layer is below the unmodified production AbyssPerimeter layer.
// This fixture does not enable Wull, move a pointer, or touch the live desktop.
import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
    PanelWindow {
        id: underlay
        visible: true
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        WlrLayershell.namespace: "hadalis:wull-pointer-underlay"
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // Independent full-output input witness; production mask is never
        // replaced or overridden. Every test click must be output-scoped.
        mask: Region { item: witness }

        Rectangle {
            id: witness
            anchors.fill: parent
            color: "#172e34"
            Text {
                anchors.centerIn: parent
                text: "PRIVATE NESTED WULL POINTER TEST"
                color: "#bddde6"
            }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                onPressed: mouse => {
                    // Counts and positions are PRIVATE diagnostics, not report
                    // contents. A child runner may publish aggregate counters.
                    console.log("WULL_POINTER_UNDERLAY_PRESS " +
                        JSON.stringify({
                            x: Math.round(mouse.x),
                            y: Math.round(mouse.y),
                            button: mouse.button
                        }))
                }
            }
        }
        Component.onCompleted: console.log("WULL_POINTER_UNDERLAY_QML_READY")
    }
}
