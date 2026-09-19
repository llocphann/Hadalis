pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property int settingsPageIndex: 30
    property string settingsPageName: Translation.tr("Code Workflow")
    property string sourceText: ""

    readonly property int runtimeRevision: CodeWorkflowRuntime.revision
    readonly property var snapshot: {
        const dependency = root.runtimeRevision
        if (dependency < 0)
            return ({ outputs: [], records: [] })
        return CodeWorkflowRuntime.snapshot()
    }
    readonly property var descriptor:
        CodeWorkflowRuntime.descriptor(CodeWorkflowSession.selectedTargetId)
            ?? CodeWorkflowRuntime.catalog[0]
    readonly property var record: root.recordFor(CodeWorkflowSession.selectedTargetId)
    readonly property string sourcePath: root.descriptor?.sourcePath ?? ""
    readonly property bool live:
        root.snapshot.records?.some(item => item.state === "resident") ?? false

    function recordFor(targetId: string): var {
        const records = root.snapshot.records ?? []
        const exact = records.find(item =>
            item.targetId === targetId
            && item.instanceId === CodeWorkflowSession.selectedInstanceId)
        if (exact)
            return exact

        if (CodeWorkflowSession.outputName.length > 0) {
            const sameOutput = records.find(item =>
                item.targetId === targetId
                && item.output === CodeWorkflowSession.outputName)
            if (sameOutput)
                return sameOutput
        }

        return records.find(item =>
            item.targetId === targetId && item.state === "resident")
            ?? records.find(item => item.targetId === targetId)
            ?? null
    }

    function selectTarget(targetId: string): void {
        const next = root.recordFor(targetId)
        CodeWorkflowSession.selectTarget(targetId, next?.instanceId ?? "")
    }

    function cycleOutput(): void {
        const outputs = root.snapshot.outputs ?? []
        if (outputs.length === 0)
            return
        const current = outputs.indexOf(CodeWorkflowSession.outputName)
        CodeWorkflowSession.setOutputName(
            outputs[(current + 1 + outputs.length) % outputs.length])
    }

    function zoomAt(x: real, y: real, nextZoom: real): void {
        const oldZoom = CodeWorkflowSession.zoom
        const zoom = Math.max(0.35, Math.min(2.5, nextZoom))
        const graphX = (x - CodeWorkflowSession.panX) / oldZoom
        const graphY = (y - CodeWorkflowSession.panY) / oldZoom
        CodeWorkflowSession.setViewport(
            x - graphX * zoom, y - graphY * zoom, zoom)
    }

    function stateLabel(item): string {
        return item?.state === "resident" ? "LIVE" : "STATIC"
    }

    function n(value): string {
        const number = Number(value)
        return Number.isFinite(number) ? number.toFixed(0) : "—"
    }

    function geometryText(rect): string {
        if (!rect)
            return "—"
        return root.n(rect.x) + ", " + root.n(rect.y)
            + " · " + root.n(rect.width) + "×" + root.n(rect.height)
    }

    function reloadSource(): void {
        root.sourceText = ""
        if (sourceReader.path)
            sourceReader.reload()
    }

    onSourcePathChanged: Qt.callLater(root.reloadSource)

    Component.onCompleted: {
        const outputs = root.snapshot.outputs ?? []
        if (CodeWorkflowSession.outputName.length === 0 && outputs.length > 0)
            CodeWorkflowSession.setOutputName(outputs[0])
        Qt.callLater(root.reloadSource)
    }

    FileView {
        id: sourceReader
        path: root.sourcePath.length > 0 ? Quickshell.shellPath(root.sourcePath) : ""
        watchChanges: true
        printErrors: false
        onLoaded: root.sourceText = String(sourceReader.text() ?? "")
        onFileChanged: sourceReader.reload()
        onLoadFailed: root.sourceText = ""
    }

    component Pill: Rectangle {
        required property string label
        property color accent: Appearance.colors.colPrimary
        implicitWidth: pillText.implicitWidth + 14
        implicitHeight: pillText.implicitHeight + 6
        radius: implicitHeight / 2
        color: ColorUtils.transparentize(accent, 0.84)
        border.width: 1
        border.color: ColorUtils.transparentize(accent, 0.5)

        StyledText {
            id: pillText
            anchors.centerIn: parent
            text: parent.label
            color: parent.accent
            font.pixelSize: Appearance.font.pixelSize.smallest
            font.weight: Font.DemiBold
        }
    }

    component Node: Rectangle {
        id: node
        required property string targetId
        required property string title
        required property string icon
        required property real nodeX
        required property real nodeY

        readonly property var runtimeRecord: root.recordFor(node.targetId)
        readonly property bool selected:
            CodeWorkflowSession.selectedTargetId === node.targetId

        x: nodeX
        y: nodeY
        width: 188
        height: 88
        radius: Appearance.rounding.normal
        color: selected ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer1
        border.width: selected ? 2 : 1
        border.color: selected ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant
        activeFocusOnTab: true

        Accessible.role: Accessible.Button
        Accessible.name: node.title + " workflow node"
        Accessible.description: "Read-only workflow target"

        TapHandler {
            onTapped: {
                root.selectTarget(node.targetId)
                node.forceActiveFocus()
            }
        }
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                    || event.key === Qt.Key_Space) {
                root.selectTarget(node.targetId)
                event.accepted = true
            } else {
                event.accepted = false
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 11
            spacing: 3

            RowLayout {
                Layout.fillWidth: true
                spacing: 7
                MaterialSymbol {
                    text: node.icon
                    iconSize: Appearance.font.pixelSize.large
                    color: node.selected ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                }
                StyledText {
                    Layout.fillWidth: true
                    text: node.title
                    color: Appearance.colors.colOnLayer1
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Pill {
                    label: root.stateLabel(node.runtimeRecord)
                    accent: node.runtimeRecord?.state === "resident"
                        ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: node.runtimeRecord?.output?.length > 0 ? node.runtimeRecord.output : "source only"
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                elide: Text.ElideRight
            }
            StyledText {
                Layout.fillWidth: true
                text: CodeWorkflowRuntime.descriptor(node.targetId)?.sourcePath ?? ""
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smallest
                font.family: Appearance.font.family.monospace
                elide: Text.ElideMiddle
            }
        }

        Rectangle {
            x: -4
            anchors.verticalCenter: parent.verticalCenter
            width: 8; height: 8; radius: 4
            color: Appearance.colors.colPrimary
        }
        Rectangle {
            x: parent.width - 4
            anchors.verticalCenter: parent.verticalCenter
            width: 8; height: 8; radius: 4
            color: Appearance.colors.colPrimary
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer1
            border.width: 1
            border.color: Appearance.colors.colOutlineVariant

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 8
                spacing: 8

                MaterialSymbol {
                    text: "account_tree"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colPrimary
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    StyledText {
                        Layout.fillWidth: true
                        text: "Code Workflow"
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer1
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: "Phase 1 · horizontal ii Bar · graph is the editor"
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colSubtext
                    }
                }

                Pill { label: "READ ONLY"; accent: Appearance.colors.colTertiary }
                Pill {
                    label: root.live ? "LIVE RUNTIME" : "STATIC SOURCE"
                    accent: root.live ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                }

                RippleButtonWithIcon {
                    materialIcon: "monitor"
                    mainText: CodeWorkflowSession.outputName.length > 0
                        ? CodeWorkflowSession.outputName : "Output"
                    enabled: (root.snapshot.outputs?.length ?? 0) > 0
                    onClicked: root.cycleOutput()
                }
                RippleButtonWithIcon {
                    materialIcon: "filter_center_focus"
                    mainText: "Reset view"
                    onClicked: CodeWorkflowSession.resetViewport()
                }
                RippleButtonWithIcon {
                    materialIcon: "code"
                    mainText: CodeWorkflowSession.sourcePreviewVisible ? "Hide source" : "Show source"
                    onClicked: CodeWorkflowSession.sourcePreviewVisible =
                        !CodeWorkflowSession.sourcePreviewVisible
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 224
                Layout.fillHeight: true
                radius: Appearance.rounding.normal
                color: Appearance.colors.colLayer1
                border.width: 1
                border.color: Appearance.colors.colOutlineVariant

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 9
                    spacing: 7

                    StyledText {
                        text: "Targets"
                        color: Appearance.colors.colOnLayer1
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.DemiBold
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: "Semantic allowlist · no QObject tree walking"
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        wrapMode: Text.WordWrap
                    }

                    ListView {
                        id: targetList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 5
                        clip: true
                        model: CodeWorkflowRuntime.catalog

                        delegate: Rectangle {
                            id: targetRow
                            required property int index
                            required property var modelData
                            readonly property var rowRecord: root.recordFor(modelData.targetId)

                            width: targetList.width
                            height: 54
                            radius: Appearance.rounding.small
                            color: CodeWorkflowSession.selectedTargetId === modelData.targetId
                                ? Appearance.colors.colPrimaryContainer : "transparent"
                            border.width: CodeWorkflowSession.selectedTargetId === modelData.targetId ? 1 : 0
                            border.color: Appearance.colors.colPrimary

                            TapHandler { onTapped: root.selectTarget(targetRow.modelData.targetId) }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 7
                                MaterialSymbol {
                                    text: targetRow.modelData.icon
                                    iconSize: Appearance.font.pixelSize.normal
                                    color: Appearance.colors.colOnLayer1
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: targetRow.modelData.label
                                        color: Appearance.colors.colOnLayer1
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        font.weight: Font.Medium
                                        elide: Text.ElideRight
                                    }
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: targetRow.rowRecord?.state === "resident"
                                            ? targetRow.rowRecord.output + " · live" : "source only"
                                        color: Appearance.colors.colSubtext
                                        font.pixelSize: Appearance.font.pixelSize.smallest
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: canvas
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 360
                radius: Appearance.rounding.normal
                color: Appearance.colors.colLayer0
                border.width: 1
                border.color: Appearance.colors.colOutlineVariant
                clip: true

                DragHandler {
                    id: pan
                    target: null
                    acceptedButtons: Qt.MiddleButton
                    property real baseX: 0
                    property real baseY: 0
                    onActiveChanged: {
                        if (active) {
                            baseX = CodeWorkflowSession.panX
                            baseY = CodeWorkflowSession.panY
                        }
                    }
                    onActiveTranslationChanged: {
                        if (active)
                            CodeWorkflowSession.setViewport(
                                baseX + activeTranslation.x,
                                baseY + activeTranslation.y,
                                CodeWorkflowSession.zoom)
                    }
                }

                WheelHandler {
                    target: null
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        const delta = event.pixelDelta.y !== 0
                            ? event.pixelDelta.y * 3 : event.angleDelta.y
                        root.zoomAt(event.x, event.y,
                            CodeWorkflowSession.zoom * Math.pow(1.0015, delta))
                        event.accepted = true
                    }
                }

                Item {
                    id: world
                    width: 820
                    height: 500
                    x: CodeWorkflowSession.panX
                    y: CodeWorkflowSession.panY
                    scale: CodeWorkflowSession.zoom
                    transformOrigin: Item.TopLeft

                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.GeometryRenderer
                        asynchronous: false

                        ShapePath {
                            strokeColor: CodeWorkflowSession.selectedTargetId === "bar/media"
                                ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant
                            strokeWidth: 2
                            fillColor: "transparent"
                            startX: 228; startY: 214
                            PathCubic { x: 420; y: 94; control1X: 310; control1Y: 214; control2X: 338; control2Y: 94 }
                        }
                        ShapePath {
                            strokeColor: CodeWorkflowSession.selectedTargetId === "bar/clock"
                                ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant
                            strokeWidth: 2
                            fillColor: "transparent"
                            startX: 228; startY: 214
                            PathCubic { x: 420; y: 214; control1X: 306; control1Y: 214; control2X: 342; control2Y: 214 }
                        }
                        ShapePath {
                            strokeColor: CodeWorkflowSession.selectedTargetId === "bar/resources"
                                ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant
                            strokeWidth: 2
                            fillColor: "transparent"
                            startX: 228; startY: 214
                            PathCubic { x: 420; y: 334; control1X: 310; control1Y: 214; control2X: 338; control2Y: 334 }
                        }
                    }

                    Node { targetId: "bar"; title: "Bar"; icon: "toolbar"; nodeX: 40; nodeY: 170 }
                    Node { targetId: "bar/media"; title: "Media"; icon: "music_note"; nodeX: 420; nodeY: 50 }
                    Node { targetId: "bar/clock"; title: "Clock"; icon: "schedule"; nodeX: 420; nodeY: 170 }
                    Node { targetId: "bar/resources"; title: "Resources"; icon: "memory"; nodeX: 420; nodeY: 290 }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: 10
                    implicitWidth: hint.implicitWidth + 14
                    implicitHeight: hint.implicitHeight + 8
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colLayer2
                    StyledText {
                        id: hint
                        anchors.centerIn: parent
                        text: "Middle drag to pan · Wheel to zoom · "
                            + Math.round(CodeWorkflowSession.zoom * 100) + "%"
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smallest
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 250
                Layout.fillHeight: true
                radius: Appearance.rounding.normal
                color: Appearance.colors.colLayer1
                border.width: 1
                border.color: Appearance.colors.colOutlineVariant

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    StyledText {
                        text: "Inspector"
                        color: Appearance.colors.colOnLayer1
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.DemiBold
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: root.descriptor?.label ?? "Target"
                        color: Appearance.colors.colPrimary
                        font.pixelSize: Appearance.font.pixelSize.large
                        font.weight: Font.DemiBold
                    }
                    Pill {
                        label: root.stateLabel(root.record)
                        accent: root.record?.state === "resident"
                            ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                    }
                    StyledText { text: "Output"; color: Appearance.colors.colSubtext }
                    StyledText {
                        Layout.fillWidth: true
                        text: root.record?.output || "—"
                        color: Appearance.colors.colOnLayer1
                        elide: Text.ElideRight
                    }
                    StyledText { text: "Geometry"; color: Appearance.colors.colSubtext }
                    StyledText {
                        Layout.fillWidth: true
                        text: root.geometryText(root.record?.rect)
                        color: Appearance.colors.colOnLayer1
                        elide: Text.ElideRight
                    }
                    StyledText { text: "Source"; color: Appearance.colors.colSubtext }
                    StyledText {
                        Layout.fillWidth: true
                        text: root.sourcePath
                        color: Appearance.colors.colOnLayer1
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        wrapMode: Text.WrapAnywhere
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: "Runtime values are allowlisted. Unloaded targets remain available as static source."
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        wrapMode: Text.WordWrap
                    }
                    Item { Layout.fillHeight: true }
                    StyledText {
                        Layout.fillWidth: true
                        text: "Picker and source transforms are intentionally deferred to later Phase 1/2 milestones."
                        color: Appearance.colors.colTertiary
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: CodeWorkflowSession.sourcePreviewVisible ? 190 : 0
            visible: CodeWorkflowSession.sourcePreviewVisible
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer1
            border.width: 1
            border.color: Appearance.colors.colOutlineVariant
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 5

                RowLayout {
                    Layout.fillWidth: true
                    MaterialSymbol {
                        text: "code"
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colPrimary
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: "Source Preview · " + root.sourcePath
                        color: Appearance.colors.colOnLayer1
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                        elide: Text.ElideMiddle
                    }
                    Pill { label: "READ ONLY"; accent: Appearance.colors.colTertiary }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colLayer0
                    clip: true

                    Flickable {
                        anchors.fill: parent
                        anchors.margins: 7
                        contentWidth: Math.max(width, sourceText.implicitWidth)
                        contentHeight: Math.max(height, sourceText.implicitHeight)
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        TextEdit {
                            id: sourceText
                            width: Math.max(parent.width, implicitWidth)
                            text: root.sourceText
                            readOnly: true
                            selectByMouse: true
                            wrapMode: TextEdit.NoWrap
                            color: Appearance.colors.colOnLayer1
                            selectionColor: Appearance.colors.colPrimaryContainer
                            selectedTextColor: Appearance.colors.colOnPrimaryContainer
                            font.family: Appearance.font.family.monospace
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                    }
                }
            }
        }
    }
}
