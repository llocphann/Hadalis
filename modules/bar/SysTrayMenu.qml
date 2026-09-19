import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Item {
    id: root

    required property QsMenuHandle trayItemMenuHandle
    required property Item anchorItem
    property bool anchorHovered: false
    property bool keyboardMode: false
    property bool closing: false
    property bool menuRequestedOpen: false
    property bool _openedSignaled: false

    signal menuClosed
    signal menuOpened(qsWindow: var)

    function open() {
        root.closing = false
        root.menuRequestedOpen = true
        root._openedSignaled = false
    }

    function finalizeClose() {
        root.menuRequestedOpen = false
        root.closing = false
        while (stackView.depth > 1)
            stackView.pop()
        root._openedSignaled = false
        root.menuClosed()
    }

    function close() {
        if (root.closing || !root.menuRequestedOpen)
            return
        root.closing = true
        root.menuRequestedOpen = false
        if (!Appearance.animationsEnabled) {
            root.finalizeClose()
            return
        }
        closeAnimTimer.restart()
    }

    Timer {
        id: closeTimer
        interval: 450
        running: root.menuRequestedOpen && !root.keyboardMode
            && !connectedPopup.popupHovered && !root.anchorHovered
        onTriggered: root.close()
    }

    Timer {
        id: closeAnimTimer
        interval: Math.max(
            Appearance.animation.elementMoveEnter.duration + 16,
            Appearance.animation.elementMoveExit.duration)
        onTriggered: root.finalizeClose()
    }

    StyledPopup {
        id: connectedPopup

        hoverTarget: root.anchorItem
        hoverActivates: false
        alternativeVisibleCondition: root.menuRequestedOpen
        closeOnOutsideClick: true
        keyboardFocus: root.keyboardMode
        popupBackgroundMargin: 0
        onRequestClose: root.close()

        onPresentationWindowChanged: {
            if (presentationWindow !== null
                    && root.menuRequestedOpen
                    && !root._openedSignaled) {
                root._openedSignaled = true
                root.menuOpened(presentationWindow)
            }
        }

        Item {
            id: menuContent

            readonly property real padding: 3
            implicitWidth: Math.max(1, stackView.implicitWidth + padding * 2)
            implicitHeight: Math.max(1, stackView.implicitHeight + padding * 2)

            StackView {
                id: stackView
                anchors.fill: parent
                anchors.margins: menuContent.padding
                focus: root.keyboardMode
                pushEnter: NoAnim {}
                pushExit: NoAnim {}
                popEnter: NoAnim {}
                popExit: NoAnim {}

                implicitWidth: currentItem?.implicitWidth ?? 0
                implicitHeight: currentItem?.implicitHeight ?? 0

                Keys.onPressed: event => {
                    if (event.key !== Qt.Key_Escape)
                        return
                    event.accepted = true
                    if (stackView.depth > 1)
                        stackView.pop()
                    else
                        root.close()
                }

                initialItem: SubMenu {
                    handle: root.trayItemMenuHandle
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.BackButton | Qt.RightButton
                onPressed: event => {
                    if ((event.button === Qt.BackButton
                            || event.button === Qt.RightButton)
                            && stackView.depth > 1) {
                        stackView.pop()
                        event.accepted = true
                    }
                }
            }
        }
    }

    component NoAnim: Transition {
        NumberAnimation {
            duration: 0
        }
    }

    component SubMenu: ColumnLayout {
        id: submenu

        required property QsMenuHandle handle
        property bool isSubMenu: false
        property bool shown: false

        opacity: shown ? 1 : 0
        spacing: 0

        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            animation: NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        Component.onCompleted: shown = true
        StackView.onActivating: shown = true
        StackView.onDeactivating: shown = false
        StackView.onRemoved: destroy()

        QsMenuOpener {
            id: menuOpener
            menu: submenu.handle
        }

        Loader {
            Layout.fillWidth: true
            visible: submenu.isSubMenu
            active: visible

            sourceComponent: RippleButton {
                id: backButton

                buttonRadius: Math.max(0,
                    Appearance.rounding.large - menuContent.padding)
                horizontalPadding: 12
                implicitWidth: contentItem.implicitWidth + horizontalPadding * 2
                implicitHeight: 36
                Accessible.name: Translation.tr("Back")

                onClicked: stackView.pop()

                contentItem: RowLayout {
                    anchors {
                        verticalCenter: parent.verticalCenter
                        left: parent.left
                        right: parent.right
                        leftMargin: backButton.horizontalPadding
                        rightMargin: backButton.horizontalPadding
                    }
                    spacing: 8

                    MaterialSymbol {
                        iconSize: 20
                        text: "chevron_left"
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Back")
                    }
                }
            }
        }

        Repeater {
            id: menuEntriesRepeater

            property bool iconColumnNeeded: {
                for (let i = 0; i < menuOpener.children.values.length; i++) {
                    if (menuOpener.children.values[i].icon.length > 0)
                        return true
                }
                return false
            }
            property bool specialInteractionColumnNeeded: {
                for (let i = 0; i < menuOpener.children.values.length; i++) {
                    if (menuOpener.children.values[i].buttonType !== QsMenuButtonType.None)
                        return true
                }
                return false
            }

            model: menuOpener.children

            delegate: SysTrayMenuEntry {
                required property QsMenuEntry modelData

                forceIconColumn: menuEntriesRepeater.iconColumnNeeded
                forceSpecialInteractionColumn:
                    menuEntriesRepeater.specialInteractionColumnNeeded
                menuEntry: modelData
                buttonRadius: Math.max(0,
                    Appearance.rounding.large - menuContent.padding)

                onDismiss: root.close()
                onOpenSubmenu: handle => {
                    stackView.push(subMenuComponent.createObject(null, {
                        handle: handle,
                        isSubMenu: true
                    }))
                }
            }
        }
    }

    Component {
        id: subMenuComponent
        SubMenu {}
    }
}
