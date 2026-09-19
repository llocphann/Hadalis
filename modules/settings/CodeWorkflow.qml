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
    readonly property var graph:
        CodeWorkflowIr.graphFor(CodeWorkflowSession.subflowTargetId)
    readonly property var selectedIrNode:
        CodeWorkflowIr.nodeFor(
            CodeWorkflowSession.subflowTargetId,
            CodeWorkflowSession.selectedNodeId)
    readonly property string sourcePath:
        root.selectedIrNode?.sourcePath
            ?? root.descriptor?.sourcePath
            ?? ""
    readonly property string sourceNeedle:
        root.selectedIrNode?.sourceNeedle ?? ""
    readonly property bool live:
        root.snapshot.records?.some(item => item.state === "resident") ?? false
    readonly property bool pickerAvailable: CodeWorkflowPicker.canBegin

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

    function stateLabel(item): string {    function stateLabel(item): string {
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

    function focusSourceAnchor(): void {
        if (root.sourceNeedle.length === 0 || root.sourceText.length === 0)
            return
        const start = root.sourceText.indexOf(root.sourceNeedle)
        if (start < 0)
            return
        sourcePreviewText.select(start, start + root.sourceNeedle.length)
        sourcePreviewText.cursorPosition = start
    }

    onSourcePathChanged: Qt.callLater(root.reloadSource)
    onSourceNeedleChanged: Qt.callLater(root.focusSourceAnchor)

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
        onLoaded: {
            root.sourceText = String(sourceReader.text() ?? "")
            Qt.callLater(root.focusSourceAnchor)
        }
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

    ColumnLayout {
        anchors.fill: parent    ColumnLayout {
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
                        text: "Phase 1 · "
                            + (root.graph?.title ?? "Workflow")
                            + " · graph is the editor"
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
                    visible: CodeWorkflowSession.subflowTargetId !== "bar"
                    materialIcon: "arrow_back"
                    mainText: "Bar"
                    onClicked: CodeWorkflowSession.openSubflow("bar")
                }

                RippleButtonWithIcon {
                    materialIcon: "ads_click"
                    mainText: CodeWorkflowPicker.phase === "idle"
                        ? "Pick component" : "Picking…"
                    enabled: root.pickerAvailable
                    onClicked: CodeWorkflowPicker.begin()
                    StyledToolTip {
                        text: root.pickerAvailable
                            ? "Hide Settings and select a live ii Bar component"
                            : (root.live
                                ? "Picker is available from overlay Settings only"
                                : "No live ii Bar targets in this Settings process")
                    }
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

            CodeWorkflowIrCanvas {
                id: canvas
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 360
            }

            Rectangle {
                Layout.preferredWidth: 250            Rectangle {
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
                        text: root.selectedIrNode?.title
                            ?? root.descriptor?.label
                            ?? "Target"
                        color: Appearance.colors.colPrimary
                        font.pixelSize: Appearance.font.pixelSize.large
                        font.weight: Font.DemiBold
                    }
                    Pill {
                        label: String(root.selectedIrNode?.kind ?? "component").toUpperCase()
                        accent: Appearance.colors.colPrimary
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: root.selectedIrNode?.description ?? ""
                        visible: text.length > 0
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        wrapMode: Text.WordWrap
                    }
                    StyledText { text: "Runtime"; color: Appearance.colors.colSubtext }
                    StyledText {
                        Layout.fillWidth: true
                        text: root.stateLabel(root.record)
                        color: root.record?.state === "resident"
                            ? Appearance.colors.colPrimary
                            : Appearance.colors.colSubtext
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
                    StyledText { text: "Source anchor"; color: Appearance.colors.colSubtext }
                    StyledText {
                        Layout.fillWidth: true
                        text: root.sourceNeedle.length > 0
                            ? root.sourceNeedle
                            : "Parser range not attached yet"
                        color: Appearance.colors.colOnLayer1
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.smallest
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
                        contentWidth: Math.max(width, sourcePreviewText.implicitWidth)
                        contentHeight: Math.max(height, sourceText.implicitHeight)
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        TextEdit {
                            id: sourcePreviewText
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
