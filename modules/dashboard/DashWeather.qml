import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.bar.weather

DashCard {
    id: root
    property date now: new Date()
    readonly property bool hasData: Weather.enabled
        && (Weather.data?.temp ?? "").length > 0
        && !(Weather.data?.temp ?? "--").startsWith("--")

    Timer {
        interval: 30000
        repeat: true
        running: root.visible
        onTriggered: root.now = new Date()
    }

    ColumnLayout {
        visible: !root.hasData
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 6

        MascotImage {
            id: weatherMascot
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            Layout.preferredWidth: 96
            Layout.preferredHeight: 96
            surface: "dashboard"
            pose: "weather-umbrella"
        }

        MaterialShapeWrappedMaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            visible: !weatherMascot.active
            text: "partly_cloudy_day"
            shape: MaterialShape.Shape.Puffy
            padding: 10
            iconSize: 32
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: Weather.enabled
                ? Translation.tr("Waiting for weather data…")
                : Translation.tr("Enable weather in Settings › Bar")
            font.pixelSize: Appearance.font.pixelSize.small
            color: root.colSubtext
            wrapMode: Text.WordWrap
        }
    }

    OrbitalWeather {
        visible: root.hasData
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 180
        now: root.now
    }
}
