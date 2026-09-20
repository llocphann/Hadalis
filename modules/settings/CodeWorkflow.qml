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
    readonly property var selectedIrEdge:
        CodeWorkflowIr.edgeFor(
            CodeWorkflowSession.subflowTargetId,
            CodeWorkflowSession.selectedEdgeId)
    readonly property var reviewedConnectTargetsForSelection:
        CodeWorkflowIr.connectTargetsFor(
            CodeWorkflowSession.subflowTargetId).filter(target =>
                target.parentNodeId === CodeWorkflowSession.selectedNodeId)
    readonly property var selectedConnectTarget:
        CodeWorkflowIr.connectTargetFor(
            CodeWorkflowSession.subflowTargetId,
            CodeWorkflowSession.selectedConnectTargetId)
    readonly property var previewableInboundEdge:
        (root.graph?.edges ?? []).find(edge =>
            edge.previewable === true
            && edge.to === CodeWorkflowSession.selectedNodeId) ?? null
    readonly property string sourcePath:
        root.selectedConnectTarget?.sourcePath
            ?? root.selectedIrNode?.sourcePath
            ?? root.descriptor?.sourcePath
            ?? ""
    readonly property string sourceNeedle:
        root.selectedConnectTarget?.parentObjectNeedle
            ?? root.selectedIrNode?.sourceNeedle
            ?? ""
    readonly property string storedSemanticAnchor:
        CodeWorkflowSession.selectedConnectTargetId.length > 0
            ? ""
            : CodeWorkflowSession.semanticAnchorNodeId
                === CodeWorkflowSession.selectedNodeId
                ? CodeWorkflowSession.semanticAnchor
                : ""
    readonly property bool live:
        root.snapshot.records?.some(item => item.state === "resident") ?? false
    readonly property bool pickerAvailable: CodeWorkflowPicker.canBegin
    readonly property bool analyzerMatchesSource:
        CodeWorkflowAnalyzer.sourcePath === root.sourcePath
    readonly property bool analyzerMatchesAnchor:
        root.analyzerMatchesSource
        && CodeWorkflowAnalyzer.sourceNeedle === root.sourceNeedle
        && CodeWorkflowAnalyzer.semanticAnchor === root.storedSemanticAnchor
    readonly property var sourceAnchorEvidence:
        root.analyzerMatchesAnchor
            ? CodeWorkflowAnalyzer.reviewedAnchor
            : ({ status: "idle" })
    readonly property string sourceRangeText: {
        const evidence = root.sourceAnchorEvidence
        if (evidence?.status === "resolved") {
            const range = evidence.needleRange ?? []
            let label = range.length === 2
                ? "bytes " + range[0] + "–" + range[1]
                : "resolved"
            if (String(evidence.cstKind ?? "").length > 0)
                label += " · CST " + evidence.cstKind
            if (String(evidence.semanticKind ?? "").length > 0)
                label += " · " + evidence.semanticKind
            return label
        }
        if (evidence?.status === "ambiguous")
            return "AMBIGUOUS · " + Number(evidence.occurrences ?? 0)
                + " occurrences"
        if (evidence?.status === "missing")
            return "MISSING"
        if (evidence?.status === "unavailable")
            return "UNAVAILABLE"
        if (evidence?.status === "error")
            return "ERROR"
        if (evidence?.status === "analyzing")
            return "ANALYZING"
        return "—"
    }
    readonly property var semanticRebindEvidence:
        root.analyzerMatchesAnchor
            ? CodeWorkflowAnalyzer.semanticRebind
            : ({ status: "idle" })
    readonly property string semanticRebindText: {
        const evidence = root.semanticRebindEvidence
        if (evidence?.status === "resolved")
            return "RESOLVED · "
                + String(evidence.kind ?? "node")
                + (String(evidence.name ?? "").length > 0
                    ? " · " + evidence.name
                    : "")
        if (evidence?.status === "ambiguous")
            return "AMBIGUOUS · "
                + Number(evidence.occurrences ?? 0)
                + " matches"
        if (evidence?.status === "missing")
            return "MISSING"
        if (evidence?.status === "unavailable")
            return "UNAVAILABLE"
        if (evidence?.status === "error")
            return "ERROR"
        if (evidence?.status === "analyzing")
            return "ANALYZING"
        return root.storedSemanticAnchor.length > 0
            ? "PENDING"
            : "—"
    }
    readonly property var literalValueKinds: [
        "true", "false", "number", "string"
    ]
    readonly property var directBindingValueKinds: [
        "identifier", "member_expression"
    ]
    readonly property bool literalPreviewEligible:
        root.analyzerMatchesAnchor
        && CodeWorkflowAnalyzer.status === "ready"
        && root.sourceAnchorEvidence?.status === "resolved"
        && root.sourceAnchorEvidence?.semanticAnchorUnique === true
        && root.sourceAnchorEvidence?.semanticKind === "property"
        && root.literalValueKinds.includes(
            String(root.sourceAnchorEvidence?.semanticValueKind ?? ""))
        && root.storedSemanticAnchor.length > 0
    readonly property bool bindingPreviewEligible:
        root.analyzerMatchesAnchor
        && CodeWorkflowAnalyzer.status === "ready"
        && root.sourceAnchorEvidence?.status === "resolved"
        && root.sourceAnchorEvidence?.semanticAnchorUnique === true
        && root.sourceAnchorEvidence?.semanticKind === "binding"
        && root.directBindingValueKinds.includes(
            String(root.sourceAnchorEvidence?.semanticValueKind ?? ""))
        && root.storedSemanticAnchor.length > 0
    readonly property bool connectPreviewEligible:
        root.selectedConnectTarget !== null
        && root.selectedConnectTarget?.previewable === false
        && root.selectedConnectTarget?.editable === false
        && root.selectedConnectTarget?.typeCompatibility
            === "unknown-unresolved"
        && root.selectedConnectTarget?.cycleStatus
            === "unknown-incomplete-projection"
        && String(root.selectedConnectTarget?.sourcePath ?? "").length > 0
    readonly property string currentLiteralText:
        root.literalPreviewEligible
            ? String(root.sourceAnchorEvidence?.semanticValueText ?? "")
            : ""
    readonly property string currentBindingText:
        root.bindingPreviewEligible
            ? String(root.sourceAnchorEvidence?.semanticValueText ?? "")
            : ""
    readonly property bool transactionMatchesSelection: {
        const command = CodeWorkflowTransaction.activeCommand
        if (!command)
            return false
        if (String(command.kind ?? "") === "connect-binding") {
            return root.selectedConnectTarget !== null
                && String(command.targetId ?? "")
                    === CodeWorkflowSession.subflowTargetId
                && String(command.connectTargetId ?? "")
                    === CodeWorkflowSession.selectedConnectTargetId
                && String(command.sourcePath ?? "") === root.sourcePath
        }
        return CodeWorkflowTransaction.sourcePath === root.sourcePath
            && CodeWorkflowTransaction.semanticAnchor
                === root.storedSemanticAnchor
    }
    readonly property string analyzerStatusText: {
        if (!root.analyzerMatchesAnchor)
            return "IDLE"
        if (CodeWorkflowAnalyzer.status === "analyzing")
            return "ANALYZING"
        if (CodeWorkflowAnalyzer.status === "ready")
            return CodeWorkflowAnalyzer.diagnostics.length > 0
                ? "READY · " + CodeWorkflowAnalyzer.diagnostics.length + " diagnostics"
                : "READY · " + CodeWorkflowAnalyzer.entryCount + " semantic entries"
        if (CodeWorkflowAnalyzer.status === "unavailable")
            return "UNAVAILABLE"
        if (CodeWorkflowAnalyzer.status === "error")
            return "ERROR"
        return "IDLE"
    }

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

    function requestAnalysis(force: bool): void {
        if (root.sourcePath.length === 0)
            return
        CodeWorkflowAnalyzer.request(
            root.sourcePath,
            root.sourceNeedle,
            root.storedSemanticAnchor,
            force)
    }

    function captureSemanticAnchor(): void {
        if (CodeWorkflowSession.selectedConnectTargetId.length > 0)
            return
        if (!root.analyzerMatchesAnchor
                || CodeWorkflowAnalyzer.status !== "ready")
            return
        const evidence = CodeWorkflowAnalyzer.reviewedAnchor
        if (evidence?.status !== "resolved"
                || evidence?.semanticAnchorUnique !== true)
            return
        const anchor = String(evidence.semanticAnchor ?? "")
        if (anchor.length === 0)
            return
        CodeWorkflowSession.bindSemanticAnchor(
            CodeWorkflowSession.selectedNodeId,
            anchor)
    }

    function previewLiteral(nextValue: string): void {
        if (!root.literalPreviewEligible)
            return
        const baseSha = String(
            CodeWorkflowAnalyzer.result?.sourceSha256 ?? "")
        if (baseSha.length === 0)
            return
        CodeWorkflowTransaction.previewLiteral(
            root.sourcePath,
            baseSha,
            root.storedSemanticAnchor,
            String(nextValue ?? ""))
    }

    function previewBinding(nextValue: string): void {
        if (!root.bindingPreviewEligible)
            return
        const baseSha = String(
            CodeWorkflowAnalyzer.result?.sourceSha256 ?? "")
        if (baseSha.length === 0)
            return
        CodeWorkflowTransaction.previewBinding(
            root.sourcePath,
            baseSha,
            root.storedSemanticAnchor,
            String(nextValue ?? ""))
    }

    function previewSelectedConnectTarget(): void {
        if (!root.connectPreviewEligible)
            return
        CodeWorkflowTransaction.previewConnectBinding(
            CodeWorkflowSession.subflowTargetId,
            CodeWorkflowSession.selectedConnectTargetId)
    }

    function previewSelectedEdgeDisconnect(): void {
        if (!root.selectedIrEdge
                || !root.bindingPreviewEligible
                || root.selectedIrEdge.previewable !== true)
            return
        const expected = String(
            root.selectedIrEdge.sourceExpression ?? "")
        const current = String(
            root.sourceAnchorEvidence?.semanticValueText ?? "")
        if (expected.length === 0 || current !== expected)
            return
        const baseSha = String(
            CodeWorkflowAnalyzer.result?.sourceSha256 ?? "")
        if (baseSha.length === 0)
            return
        CodeWorkflowTransaction.previewDisconnectBinding(
            root.sourcePath,
            baseSha,
            root.storedSemanticAnchor,
            expected)
    }

    function evaluatePreApplyGate(): void {
        const analyzerReady = root.analyzerMatchesAnchor
            && CodeWorkflowAnalyzer.status === "ready"
        const currentSha = analyzerReady
            ? String(CodeWorkflowAnalyzer.result?.sourceSha256 ?? "")
            : ""
        const rebindResolved = analyzerReady
            && root.semanticRebindEvidence?.status === "resolved"
        const diagnosticsCount = analyzerReady
            ? CodeWorkflowAnalyzer.diagnostics.length
            : -1
        CodeWorkflowTransaction.evaluatePreApply(
            root.sourcePath,
            currentSha,
            root.storedSemanticAnchor,
            analyzerReady,
            rebindResolved,
            diagnosticsCount)
    }

    function regenerateTransaction(): void {
        if (!root.transactionMatchesSelection)
            return
        if (CodeWorkflowTransaction.activeCommand?.kind
                === "connect-binding") {
            CodeWorkflowTransaction.regenerate("")
            return
        }
        if (CodeWorkflowAnalyzer.status !== "ready")
            return
        const currentSha = String(
            CodeWorkflowAnalyzer.result?.sourceSha256 ?? "")
        if (currentSha.length === 0)
            return
        CodeWorkflowTransaction.regenerate(currentSha)
    }

    function focusSourceAnchor(): void {
        if (root.sourceNeedle.length === 0 || root.sourceText.length === 0)
            return
        const start = root.sourceText.indexOf(root.sourceNeedle)
        if (start < 0)
            return
        const duplicate = root.sourceText.indexOf(
            root.sourceNeedle,
            start + Math.max(1, root.sourceNeedle.length))
        if (duplicate >= 0)
            return
        sourcePreviewText.select(start, start + root.sourceNeedle.length)
        sourcePreviewText.cursorPosition = start
    }

    onSourcePathChanged: {
        Qt.callLater(root.reloadSource)
        Qt.callLater(() => root.requestAnalysis(false))
        Qt.callLater(root.evaluatePreApplyGate)
    }
    onSourceNeedleChanged: {
        Qt.callLater(root.focusSourceAnchor)
        Qt.callLater(() => root.requestAnalysis(false))
    }
    onStoredSemanticAnchorChanged: {
        Qt.callLater(() => root.requestAnalysis(false))
        Qt.callLater(root.evaluatePreApplyGate)
    }

    Connections {
        target: CodeWorkflowAnalyzer
        function onStatusChanged(): void {
            if (CodeWorkflowAnalyzer.status === "ready")
                Qt.callLater(root.captureSemanticAnchor)
            Qt.callLater(root.evaluatePreApplyGate)
        }
    }

    Connections {
        target: CodeWorkflowTransaction
        function onStatusChanged(): void {
            Qt.callLater(root.evaluatePreApplyGate)
        }
        function onHistoryIndexChanged(): void {
            Qt.callLater(root.evaluatePreApplyGate)
        }
    }

    Component.onCompleted: {
        const outputs = root.snapshot.outputs ?? []
        if (CodeWorkflowSession.outputName.length === 0 && outputs.length > 0)
            CodeWorkflowSession.setOutputName(outputs[0])
        Qt.callLater(root.reloadSource)
        Qt.callLater(() => root.requestAnalysis(false))
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
        onFileChanged: {
            CodeWorkflowTransaction.markSourceChanged(root.sourcePath)
            sourceReader.reload()
            root.requestAnalysis(true)
        }
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
                        text: "Phase 2 · "
                            + (root.graph?.title ?? "Workflow")
                            + " · guarded literal writes + binding preview"
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colSubtext
                    }
                }

                Pill { label: "LITERAL APPLY"; accent: Appearance.colors.colPrimary }
                Pill {
                    visible: CodeWorkflowTransaction.dirty
                    label: CodeWorkflowTransaction.status === "preview"
                        ? "PATCH PREVIEW"
                        : String(CodeWorkflowTransaction.status).toUpperCase()
                    accent: CodeWorkflowTransaction.status === "conflict"
                        ? Appearance.colors.colError
                        : Appearance.colors.colTertiary
                }
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
                    StyledText {
                        visible: root.selectedIrEdge !== null
                        text: "Connection"
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        Layout.fillWidth: true
                        visible: root.selectedIrEdge !== null
                        text: root.selectedIrEdge
                            ? String(root.selectedIrEdge.label ?? root.selectedIrEdge.id)
                                + " · "
                                + String(root.selectedIrEdge.sourceExpression ?? "")
                            : ""
                        color: Appearance.colors.colPrimary
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        wrapMode: Text.WrapAnywhere
                    }
                    RippleButtonWithIcon {
                        visible: root.selectedIrEdge === null
                            && root.previewableInboundEdge !== null
                        Layout.fillWidth: true
                        materialIcon: "conversion_path"
                        mainText: root.previewableInboundEdge
                            ? "Select connection · "
                                + String(root.previewableInboundEdge.label ?? "")
                            : "Select connection"
                        onClicked: {
                            if (root.previewableInboundEdge)
                                CodeWorkflowSession.selectEdge(
                                    root.previewableInboundEdge.id)
                        }
                    }
                    Repeater {
                        model: root.reviewedConnectTargetsForSelection

                        delegate: RippleButtonWithIcon {
                            required property var modelData
                            Layout.fillWidth: true
                            materialIcon: "add_link"
                            mainText: CodeWorkflowSession.selectedConnectTargetId
                                    === String(modelData.id ?? "")
                                ? "Connect target · "
                                    + String(modelData.label ?? modelData.id)
                                : "Select Connect target · "
                                    + String(modelData.label ?? modelData.id)
                            onClicked: CodeWorkflowSession.selectConnectTarget(
                                String(modelData.id ?? ""))
                        }
                    }
                    StyledText {
                        visible: root.selectedConnectTarget !== null
                        text: "Reviewed Connect"
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        Layout.fillWidth: true
                        visible: root.selectedConnectTarget !== null
                        text: root.selectedConnectTarget
                            ? String(root.selectedConnectTarget.bindingName ?? "")
                                + " ← "
                                + String(root.selectedConnectTarget
                                    .sourceExpression ?? "")
                            : ""
                        color: Appearance.colors.colPrimary
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        wrapMode: Text.WrapAnywhere
                    }
                    StyledText {
                        Layout.fillWidth: true
                        visible: root.selectedConnectTarget !== null
                        text: "TYPE UNKNOWN · CYCLE UNKNOWN · PREVIEW ONLY"
                        color: Appearance.colors.colTertiary
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.weight: Font.Medium
                        wrapMode: Text.WordWrap
                    }
                    RippleButtonWithIcon {
                        visible: root.selectedConnectTarget !== null
                        Layout.fillWidth: true
                        materialIcon: "add_link"
                        mainText: "Preview Connect"
                        enabled: root.connectPreviewEligible
                            && !CodeWorkflowTransaction.previewBusy
                        onClicked: root.previewSelectedConnectTarget()
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
                            : "No reviewed source anchor"
                        color: Appearance.colors.colOnLayer1
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        wrapMode: Text.WrapAnywhere
                    }
                    StyledText { text: "Semantic ID"; color: Appearance.colors.colSubtext }
                    StyledText {
                        Layout.fillWidth: true
                        text: root.storedSemanticAnchor.length > 0
                            ? root.storedSemanticAnchor
                            : "Not bound"
                        color: root.storedSemanticAnchor.length > 0
                            ? Appearance.colors.colPrimary
                            : Appearance.colors.colSubtext
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        wrapMode: Text.WrapAnywhere
                    }
                    StyledText { text: "Semantic rebind"; color: Appearance.colors.colSubtext }
                    StyledText {
                        Layout.fillWidth: true
                        text: root.semanticRebindText
                        color: root.semanticRebindEvidence?.status === "resolved"
                            ? Appearance.colors.colPrimary
                            : Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        wrapMode: Text.WordWrap
                    }
                    StyledText { text: "Parser"; color: Appearance.colors.colSubtext }
                    StyledText {
                        Layout.fillWidth: true
                        text: root.analyzerStatusText
                        color: CodeWorkflowAnalyzer.status === "ready"
                            ? Appearance.colors.colPrimary
                            : CodeWorkflowAnalyzer.status === "error"
                                ? Appearance.colors.colError
                                : Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        wrapMode: Text.WordWrap
                    }
                    StyledText { text: "CST evidence"; color: Appearance.colors.colSubtext }
                    StyledText {
                        Layout.fillWidth: true
                        text: root.sourceRangeText
                        color: root.sourceAnchorEvidence?.status === "resolved"
                            ? Appearance.colors.colPrimary
                            : Appearance.colors.colSubtext
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        wrapMode: Text.WrapAnywhere
                    }
                    StyledText {
                        visible: root.literalPreviewEligible
                            || root.bindingPreviewEligible
                            || root.connectPreviewEligible
                            || root.transactionMatchesSelection
                        text: root.selectedConnectTarget !== null
                            ? "Phase 2 Connect · preview + guarded artifact preparation"
                            : root.selectedIrEdge !== null
                                ? "Phase 2 edge retarget · preview only"
                                : root.bindingPreviewEligible
                                    ? "Phase 2 direct binding · preview only"
                                    : "Phase 2 literal edit · guarded Apply"
                        color: Appearance.colors.colSubtext
                    }
                    ToolbarTextField {
                        id: transactionPreviewField
                        visible: root.literalPreviewEligible
                            || root.bindingPreviewEligible
                        Layout.fillWidth: true
                        Layout.fillHeight: false
                        Layout.preferredHeight: 34
                        text: root.bindingPreviewEligible
                            ? root.currentBindingText
                            : root.currentLiteralText
                        placeholderText: root.bindingPreviewEligible
                            ? "QML identifier or member expression"
                            : "QML literal"
                        onAccepted: {
                            if (root.bindingPreviewEligible)
                                root.previewBinding(text)
                            else
                                root.previewLiteral(text)
                        }
                    }
                    RippleButtonWithIcon {
                        visible: root.literalPreviewEligible
                            || root.bindingPreviewEligible
                        Layout.fillWidth: true
                        materialIcon: "difference"
                        mainText: root.bindingPreviewEligible
                            ? "Preview binding patch"
                            : "Preview literal patch"
                        onClicked: {
                            if (root.bindingPreviewEligible)
                                root.previewBinding(transactionPreviewField.text)
                            else
                                root.previewLiteral(transactionPreviewField.text)
                        }
                    }
                    RippleButtonWithIcon {
                        visible: root.selectedIrEdge !== null
                            && root.bindingPreviewEligible
                        Layout.fillWidth: true
                        materialIcon: "link_off"
                        mainText: "Preview Disconnect"
                        enabled: String(
                            root.sourceAnchorEvidence?.semanticValueText ?? "")
                            === String(
                                root.selectedIrEdge?.sourceExpression ?? "")
                        onClicked: root.previewSelectedEdgeDisconnect()
                    }
                    StyledText {
                        Layout.fillWidth: true
                        visible: root.transactionMatchesSelection
                            && CodeWorkflowTransaction.status !== "clean"
                        text: "Transaction: "
                            + String(CodeWorkflowTransaction.status).toUpperCase()
                            + (CodeWorkflowTransaction.error.length > 0
                                ? " · " + CodeWorkflowTransaction.error
                                : "")
                        color: CodeWorkflowTransaction.status === "conflict"
                            ? Appearance.colors.colError
                            : Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        wrapMode: Text.WordWrap
                    }
                    StyledText {
                        Layout.fillWidth: true
                        visible: root.analyzerMatchesAnchor
                            && CodeWorkflowAnalyzer.error.length > 0
                        text: CodeWorkflowAnalyzer.error
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        wrapMode: Text.WordWrap
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
                        text: "Only qualified literal-property commands may Apply. Direct bindings and Disconnect are preview-only. Connect may prepare and explicitly authorize one exact state-artifact handoff, but user-facing source Apply remains unavailable."
                        color: Appearance.colors.colTertiary
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: CodeWorkflowTransaction.dirty
                ? (CodeWorkflowTransaction.activeCommand?.kind
                        === "connect-binding" ? 316 : 118)
                : 0
            visible: CodeWorkflowTransaction.dirty
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer1
            border.width: 1
            border.color: CodeWorkflowTransaction.status === "conflict"
                ? Appearance.colors.colError
                : Appearance.colors.colOutlineVariant
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 5

                RowLayout {
                    Layout.fillWidth: true
                    MaterialSymbol {
                        text: "difference"
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colTertiary
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: CodeWorkflowTransaction.activeCommand?.kind
                                === "connect-binding"
                            ? "Connect Preview · "
                                + String(CodeWorkflowTransaction.status)
                                    .toUpperCase()
                            : CodeWorkflowTransaction.activeCommand?.kind
                                === "disconnect-binding"
                                ? "Disconnect Preview · "
                                    + String(CodeWorkflowTransaction.status)
                                        .toUpperCase()
                                : CodeWorkflowTransaction.activeCommand?.kind
                                    === "direct-binding"
                                    ? "Binding Preview · "
                                        + String(CodeWorkflowTransaction.status)
                                            .toUpperCase()
                                    : "Literal Transaction · "
                                        + String(CodeWorkflowTransaction.status)
                                            .toUpperCase()
                        color: Appearance.colors.colOnLayer1
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                    }
                    Pill {
                        label: CodeWorkflowTransaction.historyLabel
                        accent: Appearance.colors.colSubtext
                    }
                    Pill {
                        label: CodeWorkflowTransaction.activeCommand?.kind
                                === "connect-binding"
                            ? CodeWorkflowTransaction.connectAuthorizationReady
                                ? "CONNECT AUTHORIZED · APPLY BLOCKED"
                                : CodeWorkflowTransaction.connectArtifactsReady
                                    ? "CONNECT READY · AUTHORIZATION REQUIRED"
                                    : CodeWorkflowTransaction.connectPreparationBusy
                                        ? "CONNECT CHECKING"
                                        : "PREVIEW ONLY"
                            : [
                                "direct-binding",
                                "disconnect-binding"
                            ].includes(
                                    CodeWorkflowTransaction.activeCommand?.kind)
                                ? "PREVIEW ONLY"
                                : CodeWorkflowTransaction.applyEnabled
                                    && root.transactionMatchesSelection
                                ? "APPLY READY"
                                : CodeWorkflowTransaction.applyArtifactsReady
                                    ? "ARTIFACTS READY"
                                    : CodeWorkflowTransaction.preApplyReady
                                        ? "PRE-APPLY READY"
                                        : "PRE-APPLY BLOCKED"
                        accent: CodeWorkflowTransaction.activeCommand?.kind
                                === "connect-binding"
                                && (CodeWorkflowTransaction.connectArtifactsReady
                                    || CodeWorkflowTransaction
                                        .connectAuthorizationReady)
                            ? Appearance.colors.colPrimary
                            : [
                                "direct-binding",
                                "disconnect-binding",
                                "connect-binding"
                            ].includes(
                                    CodeWorkflowTransaction.activeCommand?.kind)
                                ? Appearance.colors.colTertiary
                                : CodeWorkflowTransaction.applyEnabled
                                    && root.transactionMatchesSelection
                                ? Appearance.colors.colPrimary
                                : CodeWorkflowTransaction.applyArtifactsReady
                                    ? Appearance.colors.colPrimary
                                    : CodeWorkflowTransaction.preApplyReady
                                        ? Appearance.colors.colPrimary
                                        : Appearance.colors.colTertiary
                    }
                    RippleButtonWithIcon {
                        visible: CodeWorkflowTransaction.activeCommand?.kind
                            === "connect-binding"
                            && root.transactionMatchesSelection
                        materialIcon: "inventory_2"
                        mainText: CodeWorkflowTransaction.connectArtifactsReady
                            ? "Connect artifacts prepared"
                            : "Prepare Connect artifacts"
                        enabled: CodeWorkflowTransaction.connectPrepareEnabled
                            && root.transactionMatchesSelection
                        onClicked:
                            CodeWorkflowTransaction.prepareConnectArtifacts()
                    }
                    RippleButtonWithIcon {
                        visible: CodeWorkflowTransaction.activeCommand?.kind
                            === "connect-binding"
                            && CodeWorkflowTransaction.connectArtifactsReady
                            && root.transactionMatchesSelection
                        materialIcon: "verified_user"
                        mainText: CodeWorkflowTransaction.connectAuthorizationReady
                            ? "Connect write authorized"
                            : "Authorize Connect write"
                        enabled: CodeWorkflowTransaction.connectAuthorizeEnabled
                            && root.transactionMatchesSelection
                        onClicked:
                            CodeWorkflowTransaction.authorizeConnectWrite()
                    }
                    RippleButtonWithIcon {
                        visible: CodeWorkflowTransaction.activeCommand?.kind
                            === "connect-binding"
                            && CodeWorkflowTransaction.connectAuthorizationReady
                            && root.transactionMatchesSelection
                        materialIcon: "gpp_bad"
                        mainText: "Revoke authorization"
                        enabled: !CodeWorkflowTransaction.connectLifecycleBusy
                        onClicked:
                            CodeWorkflowTransaction.revokeConnectAuthorization(
                                "user-revoked")
                    }
                    RippleButtonWithIcon {
                        visible: CodeWorkflowTransaction.preApplyReady
                            && !CodeWorkflowTransaction.applyArtifactsReady
                        materialIcon: "inventory_2"
                        mainText: "Prepare Apply"
                        enabled: CodeWorkflowTransaction.prepareApplyEnabled
                        onClicked:
                            CodeWorkflowTransaction.prepareApplyArtifacts()
                    }
                    RippleButtonWithIcon {
                        visible: CodeWorkflowTransaction.applyArtifactsReady
                            && root.transactionMatchesSelection
                        materialIcon: "save"
                        mainText: "Apply"
                        enabled: CodeWorkflowTransaction.applyEnabled
                            && root.transactionMatchesSelection
                        onClicked:
                            CodeWorkflowTransaction.beginApplyLifecycle()
                    }
                    RippleButtonWithIcon {
                        materialIcon: "undo"
                        mainText: "Undo"
                        enabled: CodeWorkflowTransaction.canUndo
                        onClicked: CodeWorkflowTransaction.undoPreview()
                    }
                    RippleButtonWithIcon {
                        materialIcon: "redo"
                        mainText: "Redo"
                        enabled: CodeWorkflowTransaction.canRedo
                        onClicked: CodeWorkflowTransaction.redoPreview()
                    }
                    RippleButtonWithIcon {
                        visible: CodeWorkflowTransaction.status === "conflict"
                        materialIcon: "refresh"
                        mainText: "Regenerate"
                        enabled: root.transactionMatchesSelection
                            && !CodeWorkflowTransaction.connectPreparationBusy
                            && (CodeWorkflowTransaction.activeCommand?.kind
                                    === "connect-binding"
                                || CodeWorkflowAnalyzer.status === "ready")
                        onClicked: root.regenerateTransaction()
                    }
                    RippleButtonWithIcon {
                        materialIcon: "close"
                        mainText: "Clear"
                        enabled: CodeWorkflowTransaction.status !== "previewing"
                            && !CodeWorkflowTransaction.applyLifecycleBusy
                            && !CodeWorkflowTransaction.connectPreparationBusy
                        onClicked: CodeWorkflowTransaction.clear()
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: CodeWorkflowTransaction.activeCommand?.kind
                        === "connect-binding"
                    text: CodeWorkflowTransaction.connectPreparationCapability
                            ?.ready === true
                        ? "Connect preparation capability: READY · native parser + qmllint + writable source available"
                        : "Connect preparation capability: "
                            + String(
                                CodeWorkflowTransaction
                                    .connectPreparationCapability
                                    ?.reason ?? "checking")
                    color: CodeWorkflowTransaction.connectPreparationCapability
                            ?.ready === true
                        ? Appearance.colors.colPrimary
                        : Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: CodeWorkflowTransaction.connectArtifactsReady
                    text: "Connect artifacts prepared · exact rollback snapshot + candidate + manifest are stored in shell state · tracked source QML is unchanged · authorization is separate from source Apply"
                    color: Appearance.colors.colPrimary
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: CodeWorkflowTransaction.connectArtifactsReady
                    text: "Authorization target · "
                        + String(
                            CodeWorkflowTransaction.activeCommand
                                ?.connectTargetId ?? "")
                        + " · "
                        + String(
                            CodeWorkflowTransaction.activeCommand
                                ?.result?.bindingName ?? "")
                        + " ← "
                        + String(
                            CodeWorkflowTransaction.activeCommand
                                ?.replacement ?? "")
                    color: Appearance.colors.colOnLayer1
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: CodeWorkflowTransaction.connectArtifactsReady
                    text: "Proof evidence · freshness "
                        + String(
                            CodeWorkflowTransaction.activeConnectSafety
                                ?.freshness ?? "unknown")
                            .toUpperCase()
                        + " · qmllint type proof retained · source-backed cycle proof retained · production TYPE/CYCLE remain UNKNOWN"
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: CodeWorkflowTransaction.connectArtifactsReady
                    text: "Source identity · "
                        + String(
                            CodeWorkflowTransaction.activeCommand
                                ?.sourcePath ?? "")
                        + " · base "
                        + String(
                            CodeWorkflowTransaction.activeCommand
                                ?.baseSha256 ?? "")
                        + " → candidate "
                        + String(
                            CodeWorkflowTransaction.activeCommand
                                ?.candidateSha256 ?? "")
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    wrapMode: Text.WrapAnywhere
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: CodeWorkflowTransaction.connectArtifactsReady
                    text: "Dependency identity · "
                        + String(
                            CodeWorkflowTransaction.activeConnectPreparation
                                ?.externalSourcePath ?? "")
                        + " · "
                        + String(
                            CodeWorkflowTransaction.activeConnectPreparation
                                ?.externalSourceSha256 ?? "")
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    wrapMode: Text.WrapAnywhere
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: CodeWorkflowTransaction.connectArtifactsReady
                    text: CodeWorkflowTransaction.connectAuthorizationReady
                        ? "Authorization ACTIVE · bound to this exact prepared manifest/history command · automatic exact-snapshot rollback is qualified · source Apply control is still unavailable"
                        : "Authorization REQUIRED · deliberate authorization will bind only this exact prepared manifest/history command · any Clock/Config/history change expires it · source Apply control is still unavailable"
                    color: CodeWorkflowTransaction.connectAuthorizationReady
                        ? Appearance.colors.colPrimary
                        : Appearance.colors.colTertiary
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.weight: Font.Medium
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: CodeWorkflowTransaction.connectPreparationError
                        .length > 0
                    text: "Prepare Connect artifacts: "
                        + CodeWorkflowTransaction.connectPreparationError
                    color: Appearance.colors.colError
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: CodeWorkflowTransaction.applyArtifactsReady
                    text: "Apply artifacts ready · rollback snapshot + "
                        + "candidate + manifest are stored in shell state · "
                        + "source QML is still unchanged until Apply"
                    color: Appearance.colors.colPrimary
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: CodeWorkflowTransaction.applyPreparationError
                        .length > 0
                    text: "Prepare Apply: "
                        + CodeWorkflowTransaction.applyPreparationError
                    color: Appearance.colors.colError
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: !CodeWorkflowTransaction.applyArtifactsReady
                        && CodeWorkflowTransaction.preApplyDiagnostics
                            ?.status !== "not-evaluated"
                    text: CodeWorkflowTransaction.preApplyReady
                        ? "Pre-Apply diagnostics: READY · source writable · "
                            + "current/candidate parser evidence valid · "
                            + "prepare exact artifacts before Apply is enabled"
                        : "Pre-Apply blockers: "
                            + (CodeWorkflowTransaction.preApplyDiagnostics
                                ?.blockers ?? []).join(", ")
                    color: CodeWorkflowTransaction.preApplyReady
                        ? Appearance.colors.colPrimary
                        : Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    text: CodeWorkflowTransaction.previewText.length > 0
                        ? CodeWorkflowTransaction.previewText
                            + (CodeWorkflowTransaction.status === "conflict"
                                ? "\n\nSTALE: "
                                    + CodeWorkflowTransaction.error
                                : "")
                        : CodeWorkflowTransaction.error
                    color: Appearance.colors.colOnLayer1
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    wrapMode: Text.WrapAnywhere
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
                        contentHeight: Math.max(height, sourcePreviewText.implicitHeight)
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
