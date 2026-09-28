pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.bar
import qs.modules.bar.weather
import qs.modules.mediaControls
import qs.modules.abyss.looks

// Rehost the mature popup contents, including Events, ThinkFan and Equalizer.
Item {
    id: root
    property string kind: "media"
    property string outputName: ""
    property var participant: null
    signal closeRequested()
    readonly property var feature: content.item
    readonly property var featureContent: feature?.contentItem ?? feature
    readonly property real desiredWidth: featureContent?.implicitWidth || 390
    readonly property real desiredHeight: featureContent?.implicitHeight || 300
    readonly property bool keyboardFocus: kind === "clock" && (feature?.keyboardFocus ?? false)
    Loader {
        id: content
        anchors.fill: parent
        sourceComponent: root.kind === "clock" ? calendar : root.kind === "battery" ? battery
            : root.kind === "resources" ? resources : root.kind === "weather" ? weather
            : ["wifi","bluetooth"].includes(root.kind) ? network
            : root.kind === "audio" ? audio : media
    }
    Component { id: calendar; ClockCalendarPopup { embeddedHost: root } }
    Component { id: battery; BatteryPopup { embeddedHost: root } }
    Component { id: resources; ResourcesPopup { embeddedHost: root } }
    Component { id: weather; WeatherPopupContent { compact: (root.participant?.width ?? 1920)<compactBreakpoint } }
    Component { id: media; BarMediaPopup { onCloseRequested: root.closeRequested() } }
    Component { id: network; AbyssNetworkPopup { kind: root.kind; onCloseRequested: root.closeRequested() } }
    Component {
        id: audio
        ColumnLayout {
            implicitWidth: 350
            AbyssLabel { text: "Volume" }
            AbyssSlider { Layout.fillWidth: true;value:Audio.value;onMoved:Audio.setSinkVolume(value) }
            AbyssButton { text:"Mute";onClicked:Audio.toggleMute() }
        }
    }
}
