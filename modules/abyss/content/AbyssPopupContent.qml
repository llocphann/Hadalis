pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.abyss.looks

Flickable {
    id: root
    property string kind: "media"
    property string outputName: ""
    signal closeRequested()
    contentHeight: column.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ColumnLayout {
        id: column
        width: root.width
        spacing: AbyssStyle.sectionSpacing
        RowLayout {
            Layout.fillWidth: true
            AbyssLabel { text: root.kind === "media" ? "Now Playing" : root.kind.charAt(0).toUpperCase()+root.kind.slice(1); font.bold: true; Layout.fillWidth: true }
            AbyssButton { glyph: "close"; description: "Close popup"; onClicked: root.closeRequested() }
        }
        AbyssSeparator { Layout.fillWidth: true }
        Loader { Layout.fillWidth: true; active: root.kind === "media"; source: "AbyssMediaSection.qml" }
        AbyssLabel { visible: root.kind === "resources"; Layout.fillWidth: true; text: "CPU   " + Math.round(ResourceUsage.cpuUsage*100) + "%\nRAM   " + Math.round(ResourceUsage.memoryUsedPercentage*100) + "%\nGPU   " + Math.round(ResourceUsage.gpuUsage*100) + "%\nStorage   " + Math.round(ResourceUsage.diskUsedPercentage*100) + "%" }
        AbyssLabel { visible: root.kind === "weather"; Layout.fillWidth: true; text: (Weather.showVisibleCity ? Weather.visibleCity+"\n" : "") + Weather.data.temp+" · "+Weather.data.description+"\nFeels like "+Weather.data.tempFeelsLike+"\nWind "+Weather.data.wind+"\nHumidity "+Weather.data.humidity }
        AbyssLabel { visible: root.kind === "battery"; text: Battery.available ? Math.round(Battery.percentage*100)+"% · "+(Battery.isCharging ? "Charging" : "Battery power") : "No battery" }
        Loader { active: root.kind === "clock"; Layout.fillWidth: true; source: "AbyssCalendar.qml" }
        AbyssLabel { visible: root.kind === "audio"; text: "Volume · " + Math.round(Audio.value*100)+"%" }
        AbyssSlider { visible: root.kind === "audio"; Layout.fillWidth: true; value: Audio.value; onMoved: Audio.setSinkVolume(value) }
        AbyssButton { visible: root.kind === "audio"; glyph: "volume_off"; text: "Mute"; onClicked: Audio.toggleMute() }
        AbyssButton { text: "Related settings"; glyph: "settings"; onClicked: GlobalStates.openSettingsPage(root.kind === "battery" || root.kind === "audio" ? 1 : 2) }
    }
    property bool resourceLease: false
    function syncLease(): void {
        const wanted = kind === "resources"
        if (wanted === resourceLease) return
        if (wanted) ResourceUsage.keepAlive(false,false)
        else ResourceUsage.releaseKeepAlive(false,false)
        resourceLease = wanted
    }
    Component.onCompleted: syncLease()
    onKindChanged: syncLease()
    Component.onDestruction: if (resourceLease) ResourceUsage.releaseKeepAlive(false,false)
}
