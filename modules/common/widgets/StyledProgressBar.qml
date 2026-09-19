pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls


/**
 * Material 3 progress bar. See https://m3.material.io/components/progress-indicators/overview
 */
ProgressBar {
    id: root
    property real valueBarWidth: 120
    property real valueBarHeight: 4
    property real valueBarGap: 4
    property color highlightColor: Appearance.colors.colPrimary
    property color trackColor: Appearance.colors.colSecondaryContainer
    property bool wavy: false // If true, the progress bar will have a wavy fill effect
    property bool animateWave: true
    property real waveAmplitudeMultiplier: wavy ? 0.5 : 0
    property real waveFrequency: 6

    Behavior on waveAmplitudeMultiplier {
        enabled: Appearance.animationsEnabled
        animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }

    Behavior on value {
        enabled: Appearance.animationsEnabled
        animation: NumberAnimation { duration: Appearance.animation.elementMoveEnter.duration; easing.type: Appearance.animation.elementMoveEnter.type; easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve }
    }
    
    background: Item {
        implicitHeight: valueBarHeight
        implicitWidth: valueBarWidth
    }

    contentItem: Item {
        id: contentItem
        anchors.fill: parent

        Loader {
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
            }
            width: Math.max(0, contentItem.width * root.visualPosition)
            height: contentItem.height * (1 + 2 * Math.max(0.5, Math.abs(root.waveAmplitudeMultiplier)))
            active: root.wavy || root.waveAmplitudeMultiplier > 0
            sourceComponent: WavyLine {
                anchors.fill: parent
                frequency: root.waveFrequency
                color: root.highlightColor
                amplitudeMultiplier: root.waveAmplitudeMultiplier
                animate: root.animateWave && root.wavy
                lineWidth: contentItem.height
                fullLength: root.width
            }
        }

        Loader {
            active: !root.wavy && root.waveAmplitudeMultiplier <= 0
            sourceComponent: Rectangle {
                anchors.left: parent.left
                width: contentItem.width * root.visualPosition
                height: contentItem.height
                radius: height / 2
                color: root.highlightColor
            }
        }

        Rectangle { // Right remaining part fill
            visible: true
            anchors.right: parent.right
            width: Math.max(0, (1 - root.visualPosition) * parent.width - valueBarGap)
            height: parent.height
            radius: height / 2
            color: root.trackColor
        }

        Rectangle { // Stop point
            visible: true
            anchors.right: parent.right
            width: valueBarGap
            height: valueBarGap
            radius: height / 2
            color: root.highlightColor
        }
    }
}
