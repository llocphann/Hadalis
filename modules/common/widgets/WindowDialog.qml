import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

Rectangle {
    id: root

    property bool show: false
    // Embedded mode keeps the dialog's form/state/buttons but removes the
    // centered modal scrim/chrome so owners can place it inside an existing
    // connected surface (for example Calendar's expanding bottom editor).
    property bool embeddedPresentation: false
    // Embedded owners can lower dialog density without changing modal dialogs.
    property real contentSpacing: 16
    property color embeddedBackgroundColor: "transparent"
    default property alias contentData: contentColumn.data
    // Negative means content-sized. Fixed-height consumers keep assigning an
    // explicit value; compact dialogs follow their measured content instead of
    // freezing whatever height happened to exist during Component completion.
    property real backgroundHeight: -1
    property real backgroundWidth: 350
    property real backgroundAnimationMovementDistance: 60
    property string zzzLabel: "DIALOG"
    property string zzzIndex: "UI"
    property string zzzGhostText: "DIALOG"
    property color zzzAccentColor: Appearance.zzz.secondary
    property bool zzzShowBurst: true
    property bool zzzShowTicks: false
    property bool zzzDecorationsEnabled: true
    
    signal dismiss()
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            root.dismiss();
            event.accepted = true;
        }
    }

    color: root.embeddedPresentation
        ? root.embeddedBackgroundColor
        : (root.show ? Appearance.colors.colScrim
            : ColorUtils.transparentize(Appearance.colors.colScrim))
    Behavior on color {
        animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }
    visible: root.embeddedPresentation
        ? root.show
        : (root.show || dialogBackground.implicitHeight > 0 || contentColumn.opacity > 0)

    onShowChanged: dialogBackgroundHeightAnimation.easing.bezierCurve = show
        ? Appearance.animationCurves.emphasizedDecel
        : Appearance.animationCurves.emphasizedAccel

    radius: Appearance.rounding.screenRounding - Appearance.sizes.surfaceGap + 1

    MouseArea { // Clicking outside the dialog should dismiss
        anchors.fill: parent
        enabled: root.show && !root.embeddedPresentation
        acceptedButtons: Qt.AllButtons
        hoverEnabled: true
        onPressed: root.dismiss()
    }

    GlassBackground {
        id: dialogBackground
        visible: !root.embeddedPresentation
        // Keep the animated chrome on whole-pixel geometry. Dialog content uses
        // NativeRendering, which Qt documents as unsuitable under transforms;
        // centering on a half pixel makes the softened result persist after open.
        x: Math.round((root.width - implicitWidth) / 2)
        radius: Appearance.rounding.large
        Behavior on radius {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        fallbackColor: Appearance.colors.colSurfaceContainerHigh
        border.width: 0
        border.color: "transparent"

        readonly property real measuredContentHeight: contentColumn.implicitHeight
            + dialogBackground.contentPad * 2
        readonly property real resolvedHeight: Math.round(root.backgroundHeight >= 0
            ? root.backgroundHeight : measuredContentHeight)
        property real targetY: Math.round(root.height / 2 - resolvedHeight / 2)
        y: root.show ? targetY : (targetY - root.backgroundAnimationMovementDistance)
        implicitWidth: Math.round(root.backgroundWidth)
        readonly property real contentPad: Math.max(radius, Appearance.sizes.spacingLarge)
        implicitHeight: root.show ? resolvedHeight : 0
        Behavior on implicitHeight {
            NumberAnimation {
                id: dialogBackgroundHeightAnimation
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.emphasizedDecel
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: dialogBackgroundHeightAnimation.duration
                easing.type: dialogBackgroundHeightAnimation.easing.type
                easing.bezierCurve: dialogBackgroundHeightAnimation.easing.bezierCurve
            }
        }

        MouseArea { // So clicking inside the dialog won't dismiss
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            hoverEnabled: true
        }

    }

    // Keep text and icons at their final pixel-aligned position while the chrome
    // performs its reveal motion. Native-rendered glyphs stay crisp because they
    // are no longer children of the translated/resized background item.
    ColumnLayout {
        id: contentColumn
        x: root.embeddedPresentation
            ? 0 : dialogBackground.x + dialogBackground.contentPad
        y: root.embeddedPresentation
            ? 0 : dialogBackground.targetY + dialogBackground.contentPad
        width: root.embeddedPresentation
            ? root.width
            : Math.max(0, dialogBackground.implicitWidth
                - dialogBackground.contentPad * 2)
        height: root.embeddedPresentation
            ? root.height
            : Math.max(0, dialogBackground.resolvedHeight
                - dialogBackground.contentPad * 2)
        spacing: root.contentSpacing
        opacity: root.show ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
    }
}
