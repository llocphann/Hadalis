pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common

// In-page Settings search for Window, Rail and Focus. A query replaces the
// page canvas rather than opening a popup that obscures the controls beneath.
Item {
    id: root

    property string query: ""
    property var results: []
    property Item searchField: null
    property var iconForPage: (index) => "search"
    signal activated(var entry)
    signal closeRequested()

    readonly property bool searching: query.trim().length > 0
    visible: searching
    enabled: searching

    function focusResults(): void {
        if (resultsList.count <= 0) return
        if (resultsList.currentIndex < 0
                || resultsList.currentIndex >= resultsList.count)
            resultsList.currentIndex = 0
        resultsList.forceActiveFocus()
    }

    function activateCurrent(): void {
        if (resultsList.count <= 0) return
        const index = resultsList.currentIndex >= 0
            && resultsList.currentIndex < resultsList.count
                ? resultsList.currentIndex : 0
        root.activated(root.results[index])
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 16
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer1
        border.width: 1
        border.color: Appearance.m3colors.m3outlineVariant
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                MaterialSymbol {
                    text: "manage_search"
                    iconSize: 20
                    color: Appearance.colors.colPrimary
                    Layout.alignment: Qt.AlignVCenter
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Search results")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer1
                }

                StyledText {
                    text: root.results.length.toString()
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Appearance.m3colors.m3outlineVariant
                opacity: 0.6
            }

            ListView {
                id: resultsList
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.results.length > 0
                model: root.results
                clip: true
                spacing: 4
                boundsBehavior: Flickable.StopAtBounds
                currentIndex: -1
                onCountChanged: currentIndex = count > 0 ? 0 : -1

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Up) {
                        if (currentIndex > 0) currentIndex--
                        else if (root.searchField) root.searchField.forceActiveFocus()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Down) {
                        if (currentIndex < count - 1) currentIndex++
                        event.accepted = true
                    } else if (event.key === Qt.Key_Return
                            || event.key === Qt.Key_Enter) {
                        root.activateCurrent()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Escape) {
                        root.closeRequested()
                        if (root.searchField) root.searchField.forceActiveFocus()
                        event.accepted = true
                    }
                }

                delegate: RippleButton {
                    id: resultRow
                    required property var modelData
                    required property int index

                    width: resultsList.width
                    implicitHeight: 60
                    buttonRadius: Appearance.rounding.small
                    colBackground: resultRow.ListView.isCurrentItem
                        ? Appearance.colors.colLayer2 : "transparent"
                    colBackgroundHover: Appearance.colors.colLayer2
                    Keys.forwardTo: [resultsList]
                    onClicked: root.activated(modelData)

                    contentItem: RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

                        Rectangle {
                            Layout.preferredWidth: 3
                            Layout.preferredHeight: 25
                            radius: 1.5
                            color: Appearance.colors.colPrimary
                            opacity: resultRow.ListView.isCurrentItem ? 1 : 0.35
                        }

                        MaterialSymbol {
                            text: root.iconForPage(resultRow.modelData.pageIndex)
                            iconSize: 19
                            color: Appearance.colors.colPrimary
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            spacing: 3

                            Text {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                text: resultRow.modelData.labelHighlighted
                                    || resultRow.modelData.label
                                    || resultRow.modelData.pageName || ""
                                textFormat: Text.StyledText
                                font.family: Appearance.font.family.main
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Medium
                                color: Appearance.colors.colOnLayer1
                                elide: Text.ElideRight
                                wrapMode: Text.NoWrap
                            }

                            StyledText {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                readonly property string pageName:
                                    resultRow.modelData.pageName || ""
                                readonly property string sectionName: {
                                    const section = String(resultRow.modelData.section || "")
                                    const pieces = section.split(/\s*[·›]\s*/).filter(part => part.length > 0)
                                    if (pieces.length > 1 && pieces[0] === pageName) pieces.shift()
                                    return pieces.join(" › ")
                                }
                                text: sectionName && sectionName !== pageName
                                    ? pageName + " › " + sectionName : pageName
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colSubtext
                                elide: Text.ElideRight
                                wrapMode: Text.NoWrap
                            }
                        }

                        MaterialSymbol {
                            text: "arrow_forward"
                            iconSize: 17
                            color: Appearance.colors.colSubtext
                            opacity: resultRow.hovered
                                || resultRow.ListView.isCurrentItem ? 1 : 0.5
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.results.length === 0

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 10

                    MaterialSymbol {
                        text: "search_off"
                        iconSize: 21
                        color: Appearance.colors.colSubtext
                    }

                    StyledText {
                        text: Translation.tr("No results found")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                    }
                }
            }
        }
    }
}
