pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

Item {
    id: root

    property int settingsPageIndex: 30
    property string settingsPageName: Translation.tr("Code Workflow")
    property string sourceText: ""
    property string sourceDraft: ""
    property string sourceEditorPath: ""
    property string sourceEditorBaseText: ""
    property bool sourceEditorConflict: false
    property bool sourceEditorSaving: false
    property bool sourceEditorStagePending: false
    property string sourceEditorStatus: ""
    property var sourceEditorBuffers: ({})
    property bool sourceEditorUseNvim: false
    readonly property bool sourceEditorDirty:
        root.sourceDraft !== root.sourceEditorBaseText
    readonly property bool sourceEditorCanSave:
        root.sourcePath.length > 0
        && root.sourceEditorDirty
        && !root.sourceEditorConflict
        && !root.sourceEditorSaving
        && !CodeWorkflowTransaction.dirty
    readonly property string sourceEditorShellRoot:
        FileUtils.trimFileProtocol(Quickshell.shellPath("."))
    readonly property string sourceEditorTargetPath:
        root.sourcePath.length > 0
            ? FileUtils.trimFileProtocol(Quickshell.shellPath(root.sourcePath))
            : ""
    readonly property string sourceEditorTempPath:
        "/tmp/hadalis-code-workflow-editor-"
            + String(Quickshell.processId) + ".tmp"
    readonly property var embeddedNvimView:
        embeddedNvimLoader.item ?? null
    readonly property string embeddedNvimPath:
        String(root.embeddedNvimView?.nvimPath ?? "")
    readonly property bool embeddedNvimBufferModified:
        root.embeddedNvimView?.bufferModified === true
    readonly property string embeddedNvimMode:
        String(root.embeddedNvimView?.nvimMode ?? "normal")
    readonly property bool embeddedNvimReady:
        root.embeddedNvimView?.nvimReady === true
    readonly property string sourceEditorNvimDisplayPath: {
        const activePath = root.embeddedNvimPath
        if (activePath.length === 0)
            return root.sourcePath
        const prefix = root.sourceEditorShellRoot.endsWith("/")
            ? root.sourceEditorShellRoot
            : root.sourceEditorShellRoot + "/"
        return activePath.startsWith(prefix)
            ? activePath.slice(prefix.length)
            : activePath
    }
    readonly property bool compactHeader: root.width < 1080
    readonly property string sourceHighlightDefinition: {
        const path = String(root.sourcePath ?? "").toLowerCase()
        if (path.endsWith(".qml"))
            return "QML"
        if (path.endsWith(".js") || path.endsWith(".mjs"))
            return "JavaScript"
        if (path.endsWith(".json"))
            return "JSON"
        if (path.endsWith(".py"))
            return "Python"
        if (path.endsWith(".sh"))
            return "Bash"
        return "plaintext"
    }

    readonly property int runtimeRevision: CodeWorkflowRuntime.revision
    readonly property var snapshot: {
        const dependency = root.runtimeRevision
        if (dependency < 0)
            return ({ outputs: [], records: [] })
        return CodeWorkflowRuntime.snapshot()
    }
    readonly property var descriptor:
        CodeWorkflowRuntime.descriptor(CodeWorkflowSession.selectedTargetId)
            ?? CodeWorkflowRuntime.activeCatalog[0]
            ?? null
    readonly property var record: root.recordFor(CodeWorkflowSession.selectedTargetId)
    readonly property var graph:
        CodeWorkflowIr.graphFor(CodeWorkflowSession.subflowTargetId)
    readonly property string inspectedSemanticAnchor:
        CodeWorkflowSession.selectedSemanticAnchor
    property string inspectFilter: ""
    property bool inspectShowInternals: false
    property bool inspectSelectionFromTargets: false
    readonly property bool captureHarnessEnabled:
        Quickshell.env("QS_CODE_WORKFLOW_CAPTURE") === "1"
    property var captureHarnessBaseline: null
    readonly property var parsedSemanticEntries:
        root.analyzerMatchesSource
            && CodeWorkflowAnalyzer.status === "ready"
            ? (CodeWorkflowAnalyzer.result?.entries ?? [])
            : []
    readonly property var inspectedSemanticEntry:
        root.parsedSemanticEntries.find(entry =>
            String(entry.anchor ?? "") === root.inspectedSemanticAnchor)
            ?? null
    readonly property string inspectedSemanticRangeText: {
        const range = root.inspectedSemanticEntry?.range ?? []
        if (range.length !== 2)
            return "—"
        return "bytes " + Number(range[0]) + "–" + Number(range[1])
    }
    readonly property var inspectTargets: {
        const items = []
        const runtimeItems = []
        const graphItems = []
        const edgeItems = []
        const connectItems = []
        const semanticItems = []
        const query = root.inspectFilter.trim().toLowerCase()

        const append = (bucket, item) => {
            const haystack = (
                String(item.label ?? "") + " "
                + String(item.detail ?? "") + " "
                + String(item.id ?? "")
            ).toLowerCase()
            if (query.length === 0 || haystack.includes(query))
                bucket.push(item)
        }

        const appendSection = (id, label, icon, detail, bucket) => {
            if (bucket.length === 0)
                return
            items.push({
                category: "section",
                id: "section/" + id,
                label: label,
                detail: String(bucket.length) + " " + detail,
                icon: icon,
                depth: 0
            })
            for (const item of bucket)
                items.push(item)
        }

        for (const target of CodeWorkflowRuntime.activeCatalog) {
            const rowRecord = root.recordFor(target.targetId)
            append(runtimeItems, {
                category: "runtime",
                id: target.targetId,
                label: target.label,
                detail: {
                    const state = String(
                        rowRecord?.state ?? target?.state ?? "inactive")
                    if (state === "resident")
                        return String(rowRecord?.output ?? "") + " · live"
                    if (state === "loaded")
                        return "loaded"
                    if (state === "loaded-hidden")
                        return "loaded · hidden"
                    if (state === "loading")
                        return "loading"
                    if (state === "disabled")
                        return "disabled · source"
                    return "inactive · source"
                },
                icon: target.icon,
                depth: Math.min(5, Math.max(
                    0, Number(target.depth ?? 0)))
            })
        }

        for (const node of (root.graph?.nodes ?? [])) {
            append(graphItems, {
                category: "graph",
                id: String(node.id ?? ""),
                label: String(node.title ?? node.id ?? "Node"),
                detail: "graph · " + String(node.kind ?? "node"),
                icon: root.inspectIconForKind(String(node.kind ?? "")),
                depth: String(node.id ?? "") === String(
                        root.graph?.rootNodeId ?? "")
                    ? 0 : 1
            })
        }

        for (const edge of (root.graph?.edges ?? [])) {
            append(edgeItems, {
                category: "edge",
                id: String(edge.id ?? ""),
                label: String(edge.label ?? edge.id ?? "Connection"),
                detail: String(edge.kind ?? "connection")
                    + " · " + String(edge.from ?? "—")
                    + " → " + String(edge.to ?? "—")
                    + (edge.previewable === true
                        || CodeWorkflowIr.reviewedSignalActionTargetForEdge(
                            CodeWorkflowSession.subflowTargetId,
                            String(edge.id ?? "")) !== null
                        ? " · reviewed"
                        : " · read only"),
                icon: "conversion_path",
                depth: 0
            })
        }

        for (const target of CodeWorkflowIr.connectTargetsFor(
                CodeWorkflowSession.subflowTargetId)) {
            append(connectItems, {
                category: "connect",
                id: String(target.id ?? ""),
                label: String(target.label ?? target.id
                    ?? "Connect candidate"),
                detail: "candidate · "
                    + String(target.bindingName ?? "binding")
                    + " · TYPE "
                    + String(target.typeCompatibility
                        ?? "unknown").toUpperCase()
                    + " · CYCLE "
                    + String(target.cycleStatus
                        ?? "unknown").toUpperCase(),
                icon: "add_link",
                depth: 0
            })
        }

        for (const entry of root.parsedSemanticEntries) {
            if (!root.semanticEntryVisible(
                    entry,
                    root.inspectShowInternals || query.length > 0))
                continue

            const kind = String(entry.kind ?? "")
            const scope = entry.scope ?? []
            const objectType = String(entry.object_type ?? "")
            const qmlId = String(entry.qml_id ?? "")
            const name = String(entry.name ?? "")
            let label = ""
            if (qmlId.length > 0)
                label = (objectType.length > 0 ? objectType : "Object")
                    + "#" + qmlId
            else if (name.length > 0)
                label = name
            else if (objectType.length > 0)
                label = objectType
            else
                label = kind

            append(semanticItems, {
                category: "semantic",
                id: String(entry.anchor ?? ""),
                label: label,
                detail: "qml · " + kind
                    + (scope.length > 0
                        ? " · " + root.scopeLeaf(
                            String(scope[scope.length - 1]))
                        : ""),
                icon: root.inspectIconForKind(kind),
                depth: root.semanticEntryDepth(entry)
            })
        }

        appendSection(
            "runtime", "Runtime", "memory", "targets", runtimeItems)
        appendSection(
            "graph", "Workflow graph", "account_tree", "nodes", graphItems)
        appendSection(
            "edges", "Connections", "conversion_path", "edges", edgeItems)
        appendSection(
            "connect", "Connect candidates", "add_link",
            "candidates", connectItems)
        appendSection(
            "semantic", "Parsed QML", "code", "elements", semanticItems)
        return items
    }
    function captureHarnessStatus(): var {
        return {
            enabled: root.captureHarnessEnabled,
            targetId: CodeWorkflowSession.selectedTargetId,
            instanceId: CodeWorkflowSession.selectedInstanceId,
            outputName: CodeWorkflowSession.outputName,
            subflowTargetId: CodeWorkflowSession.subflowTargetId,
            nodeId: CodeWorkflowSession.selectedNodeId,
            nodeLayoutOffset: CodeWorkflowSession.nodeLayoutOffset(
                CodeWorkflowSession.subflowTargetId,
                CodeWorkflowSession.selectedNodeId),
            graphLayoutRevision: CodeWorkflowSession.graphLayoutRevision,
            edgeId: CodeWorkflowSession.selectedEdgeId,
            connectTargetId: CodeWorkflowSession.selectedConnectTargetId,
            semanticAnchor: CodeWorkflowSession.selectedSemanticAnchor,
            filter: root.inspectFilter,
            showInternals: root.inspectShowInternals,
            sourcePreviewVisible: CodeWorkflowSession.sourcePreviewVisible,
            analyzerStatus: CodeWorkflowAnalyzer.status,
            analyzerError: CodeWorkflowAnalyzer.error,
            sourcePath: root.sourcePath,
            runtimeState: String(root.record?.state ?? "missing"),
            selectedLive: root.selectedLive,
            inspectTargetCount: root.inspectTargets.length,
            parserEntryCount: root.parsedSemanticEntries.length,
            pageWidth: root.width,
            pageHeight: root.height,
            canvasWidth: canvas.width,
            canvasHeight: canvas.height,
            targetsPaneWidth: CodeWorkflowSession.targetsPaneWidth,
            inspectorPaneWidth: CodeWorkflowSession.inspectorPaneWidth,
            targetsPaneCollapsed: CodeWorkflowSession.targetsPaneCollapsed,
            inspectorPaneCollapsed: CodeWorkflowSession.inspectorPaneCollapsed,
            sourcePreviewHeight: CodeWorkflowSession.sourcePreviewHeight,
            actualTargetsPaneWidth: targetsPane.width,
            actualInspectorPaneWidth: inspectorPane.width,
            actualSourcePreviewHeight: sourcePane.visible
                ? sourcePane.height : 0,
            routeDiagnostics: canvas.routeDiagnostics(),
            panX: CodeWorkflowSession.panX,
            panY: CodeWorkflowSession.panY,
            zoom: CodeWorkflowSession.zoom
        }
    }

    function captureHarnessBegin(): string {
        if (!root.captureHarnessEnabled)
            return JSON.stringify({ ok: false, error: "capture-harness-disabled" })
        root.captureHarnessBaseline = {
            selectedTargetId: CodeWorkflowSession.selectedTargetId,
            selectedInstanceId: CodeWorkflowSession.selectedInstanceId,
            outputName: CodeWorkflowSession.outputName,
            subflowTargetId: CodeWorkflowSession.subflowTargetId,
            selectedNodeId: CodeWorkflowSession.selectedNodeId,
            selectedEdgeId: CodeWorkflowSession.selectedEdgeId,
            selectedConnectTargetId: CodeWorkflowSession.selectedConnectTargetId,
            selectedSemanticAnchor: CodeWorkflowSession.selectedSemanticAnchor,
            semanticAnchor: CodeWorkflowSession.semanticAnchor,
            semanticAnchorNodeId: CodeWorkflowSession.semanticAnchorNodeId,
            panX: CodeWorkflowSession.panX,
            panY: CodeWorkflowSession.panY,
            zoom: CodeWorkflowSession.zoom,
            sourcePreviewVisible: CodeWorkflowSession.sourcePreviewVisible,
            targetsPaneWidth: CodeWorkflowSession.targetsPaneWidth,
            inspectorPaneWidth: CodeWorkflowSession.inspectorPaneWidth,
            targetsPaneCollapsed: CodeWorkflowSession.targetsPaneCollapsed,
            inspectorPaneCollapsed: CodeWorkflowSession.inspectorPaneCollapsed,
            sourcePreviewHeight: CodeWorkflowSession.sourcePreviewHeight,
            graphNodeLayoutOffsets: JSON.parse(JSON.stringify(
                CodeWorkflowSession.graphNodeLayoutOffsets ?? ({})))
        }
        return JSON.stringify({ ok: true, status: root.captureHarnessStatus() })
    }

    function captureHarnessRestore(): string {
        const baseline = root.captureHarnessBaseline
        if (!root.captureHarnessEnabled || baseline === null)
            return JSON.stringify({ ok: false, error: "capture-baseline-missing" })

        CodeWorkflowSession.selectedTargetId =
            String(baseline.selectedTargetId ?? "bar")
        CodeWorkflowSession.selectedInstanceId =
            String(baseline.selectedInstanceId ?? "")
        CodeWorkflowSession.outputName =
            String(baseline.outputName ?? "")
        CodeWorkflowSession.subflowTargetId =
            String(baseline.subflowTargetId ?? "bar")
        CodeWorkflowSession.selectedNodeId =
            String(baseline.selectedNodeId ?? "")
        CodeWorkflowSession.selectedEdgeId =
            String(baseline.selectedEdgeId ?? "")
        CodeWorkflowSession.selectedConnectTargetId =
            String(baseline.selectedConnectTargetId ?? "")
        CodeWorkflowSession.selectedSemanticAnchor =
            String(baseline.selectedSemanticAnchor ?? "")
        CodeWorkflowSession.semanticAnchor =
            String(baseline.semanticAnchor ?? "")
        CodeWorkflowSession.semanticAnchorNodeId =
            String(baseline.semanticAnchorNodeId ?? "")
        CodeWorkflowSession.setViewport(
            Number(baseline.panX ?? 32),
            Number(baseline.panY ?? 28),
            Number(baseline.zoom ?? 1))
        CodeWorkflowSession.sourcePreviewVisible =
            baseline.sourcePreviewVisible !== false
        CodeWorkflowSession.targetsPaneWidth =
            Number(baseline.targetsPaneWidth ?? 224)
        CodeWorkflowSession.inspectorPaneWidth =
            Number(baseline.inspectorPaneWidth ?? 280)
        CodeWorkflowSession.targetsPaneCollapsed =
            baseline.targetsPaneCollapsed === true
        CodeWorkflowSession.inspectorPaneCollapsed =
            baseline.inspectorPaneCollapsed === true
        CodeWorkflowSession.sourcePreviewHeight =
            Number(baseline.sourcePreviewHeight ?? 190)
        CodeWorkflowSession.graphNodeLayoutOffsets = JSON.parse(
            JSON.stringify(baseline.graphNodeLayoutOffsets ?? ({})))
        CodeWorkflowSession.graphLayoutRevision += 1
        CodeWorkflowSession.persist()
        root.inspectFilter = ""
        root.inspectShowInternals = false
        root.captureHarnessBaseline = null
        return JSON.stringify({ ok: true, status: root.captureHarnessStatus() })
    }

    function captureHarnessScenario(name: string): string {
        if (!root.captureHarnessEnabled)
            return JSON.stringify({ ok: false, error: "capture-harness-disabled" })

        const scenario = String(name ?? "")
        root.inspectFilter = ""
        root.inspectShowInternals = false
        CodeWorkflowSession.sourcePreviewVisible = false

        if (scenario === "overview") {
            root.selectTarget("bar")
            Qt.callLater(canvas.fitGraph)
        } else if (scenario === "filter-input") {
            root.selectTarget("bar")
            Qt.callLater(() => targetFilter.forceActiveFocus())
        } else if (scenario === "filter-sidebar") {
            root.selectTarget("bar")
            root.inspectFilter = "sidebar"
            Qt.callLater(root.revealSelectedInspectTarget)
        } else if (scenario === "edge-detour") {
            root.selectTarget("bar/resources")
            CodeWorkflowSession.selectEdge("resources.action.keepAlive")
            Qt.callLater(canvas.revealPrimarySelection)
        } else if (scenario === "edge-readonly-binding") {
            root.selectTarget("bar/media")
            CodeWorkflowSession.selectEdge("media.data.player")
            Qt.callLater(canvas.revealPrimarySelection)
        } else if (scenario === "connect-candidate") {
            root.selectTarget("bar/clock")
            CodeWorkflowSession.selectConnectTarget("clock.connect.rootVisible")
            Qt.callLater(canvas.revealPrimarySelection)
        } else if (scenario === "pane-resize") {
            root.selectTarget("bar")
            CodeWorkflowSession.targetsPaneWidth = 300
            CodeWorkflowSession.inspectorPaneWidth = 380
            CodeWorkflowSession.sourcePreviewHeight = 260
            CodeWorkflowSession.sourcePreviewVisible = true
            Qt.callLater(canvas.fitGraph)
        } else if (scenario === "node-layout") {
            root.selectTarget("bar/clock")
            CodeWorkflowSession.setNodeLayoutOffset(
                "bar/clock", "clock.hover", -120, 90)
            CodeWorkflowSession.selectNode("clock.hover")
            Qt.callLater(canvas.fitGraph)
        } else if (scenario === "viewport-boundary") {
            root.selectTarget("bar")
            Qt.callLater(() => {
                const bounds = canvas.rawNodeBounds()
                const zoom = Math.max(
                    CodeWorkflowSession.minimumZoom,
                    Math.min(1.0, CodeWorkflowSession.maximumZoom))
                const graphWidth = Math.max(
                    1, bounds.maxX - bounds.minX)
                const panX =
                    (canvas.width - graphWidth * zoom) / 2
                    - bounds.minX * zoom
                const panY = -bounds.minY * zoom - 34
                CodeWorkflowSession.setViewport(panX, panY, zoom)
            })
        } else if (scenario === "semantic-source") {
            root.selectTarget("bar")
            root.inspectShowInternals = true
            CodeWorkflowSession.sourcePreviewVisible = true
            if (CodeWorkflowAnalyzer.status !== "ready") {
                root.requestAnalysis(true)
                return JSON.stringify({
                    ok: true,
                    pending: true,
                    status: root.captureHarnessStatus()
                })
            }
            const entries = root.parsedSemanticEntries
            const entry = entries.find(item =>
                    String(item?.kind ?? "") === "opaque")
                ?? entries.find(item =>
                    String(item?.kind ?? "") === "pragma")
                ?? entries.find(item =>
                    String(item?.kind ?? "") === "binding")
                ?? entries[0]
                ?? null
            if (entry !== null) {
                CodeWorkflowSession.selectSemantic(
                    String(entry.anchor ?? ""))
                Qt.callLater(root.focusSourceAnchor)
            }
        } else {
            return JSON.stringify({
                ok: false,
                error: "unknown-scenario",
                scenario: scenario
            })
        }

        return JSON.stringify({
            ok: true,
            scenario: scenario,
            status: root.captureHarnessStatus()
        })
    }

    readonly property var selectedIrNode:
        CodeWorkflowIr.nodeFor(
            CodeWorkflowSession.subflowTargetId,
            CodeWorkflowSession.selectedNodeId)
    readonly property var selectedIrEdge:
        CodeWorkflowIr.edgeFor(
            CodeWorkflowSession.subflowTargetId,
            CodeWorkflowSession.selectedEdgeId)
    readonly property var selectedSignalActionTarget:
        CodeWorkflowIr.reviewedSignalActionTargetForEdge(
            CodeWorkflowSession.subflowTargetId,
            CodeWorkflowSession.selectedEdgeId)
    readonly property bool selectedEdgeMutationReviewed:
        root.selectedIrEdge !== null
        && (root.selectedIrEdge?.previewable === true
            || root.selectedSignalActionTarget !== null)
    readonly property bool selectedEdgeReadOnly:
        root.selectedIrEdge !== null
        && !root.selectedEdgeMutationReviewed
    readonly property var reviewedSignalActionTargetForSelection:
        CodeWorkflowIr.reviewedSignalActionTargetForNode(
            CodeWorkflowSession.subflowTargetId,
            CodeWorkflowSession.selectedNodeId)
    readonly property var reviewedSignalActionEdgeForSelection:
        root.reviewedSignalActionTargetForSelection === null
            ? null
            : (root.graph?.edges ?? []).find(edge =>
                String(edge.signalActionTargetId ?? "")
                    === String(
                        root.reviewedSignalActionTargetForSelection.id ?? ""))
                ?? null
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
        root.selectedSignalActionTarget?.sourcePath
            ?? root.selectedConnectTarget?.sourcePath
            ?? root.selectedIrNode?.sourcePath
            ?? root.descriptor?.sourcePath
            ?? ""
    function syncEmbeddedNvimView(): void {
        const item = embeddedNvimLoader.item
        if (!item)
            return
        item.sourcePath = root.sourceEditorTargetPath
        item.active = root.sourceEditorUseNvim
        if (item.active && item.sourcePath.length > 0)
            item.ensureSession()
    }

    function saveEmbeddedNvim(): bool {
        const item = embeddedNvimLoader.item
        return item ? item.saveBuffer() : false
    }

    function syncSourceSyntaxHighlighter(): void {
        const item = sourceSyntaxLoader.item
        if (!item)
            return
        item.targetTextEdit = sourcePreviewText
        item.definitionName = root.sourceHighlightDefinition
    }

    onSourcePathChanged: {
        root.stashSourceEditorBuffer()
        root.sourceEditorStatus = ""
        CodeWorkflowSession.selectSemantic("")
        Qt.callLater(root.reloadSource)
        Qt.callLater(() => root.requestAnalysis(false))
        Qt.callLater(root.evaluatePreApplyGate)
        if (root.sourceEditorUseNvim)
            Qt.callLater(root.syncEmbeddedNvimView)
        Qt.callLater(root.syncSourceSyntaxHighlighter)
    }

    function stashSourceEditorBuffer(): void {
        const path = String(root.sourceEditorPath ?? "")
        if (path.length === 0)
            return
        const next = Object.assign({}, root.sourceEditorBuffers)
        next[path] = {
            draft: root.sourceDraft,
            base: root.sourceEditorBaseText,
            conflict: root.sourceEditorConflict
        }
        root.sourceEditorBuffers = next
    }

    function activateSourceEditorBuffer(path: string, diskText: string): void {
        const source = String(path ?? "")
        root.stashSourceEditorBuffer()
        root.sourceEditorPath = source
        const stored = root.sourceEditorBuffers[source] ?? null
        if (stored) {
            root.sourceDraft = String(stored.draft ?? "")
            root.sourceEditorBaseText = String(stored.base ?? "")
            root.sourceEditorConflict = stored.conflict === true
                || diskText !== root.sourceEditorBaseText
            if (root.sourceEditorConflict)
                root.sourceEditorStatus = "Source changed outside this editor"
            return
        }
        root.sourceDraft = diskText
        root.sourceEditorBaseText = diskText
        root.sourceEditorConflict = false
        root.sourceEditorStatus = ""
    }

    function syncSourceEditorFromDisk(force: bool): void {
        const diskText = String(root.sourceText ?? "")
        if (root.sourceEditorPath !== root.sourcePath) {
            root.activateSourceEditorBuffer(root.sourcePath, diskText)
            return
        }
        if (root.sourceEditorSaving)
            return
        if (force || !root.sourceEditorDirty) {
            root.sourceDraft = diskText
            root.sourceEditorBaseText = diskText
            root.sourceEditorConflict = false
            root.sourceEditorStatus = force ? "Reverted to disk" : ""
            root.stashSourceEditorBuffer()
            return
        }
        if (diskText !== root.sourceEditorBaseText) {
            root.sourceEditorConflict = true
            root.sourceEditorStatus = "Source changed outside this editor"
            root.stashSourceEditorBuffer()
        }
    }

    function revertSourceEditor(): void {
        root.syncSourceEditorFromDisk(true)
        Qt.callLater(root.focusSourceAnchor)
    }

    function saveSourceEditor(): bool {
        if (!root.sourceEditorCanSave)
            return false
        root.sourceEditorSaving = true
        root.sourceEditorStagePending = true
        root.sourceEditorStatus = "Staging source draft"
        sourceDraftWriter.setText(root.sourceDraft)
        return true
    }

    function openSourceInNeovim(): bool {
        const target = root.sourceEditorTargetPath
        if (target.length === 0)
            return false
        const configured = String(
            AppLauncher.commandFor("terminal") ?? "kitty").trim()
        const terminal = configured.length > 0
            ? configured.split(/\\s+/)[0] : "kitty"
        const terminalName = terminal.split("/").pop()
        const command = terminalName === "wezterm"
            ? [terminal, "start", "--always-new-process", "--", "nvim", target]
            : [terminal, "-e", "nvim", target]
        ShellExec.execDetachedArgs(
            command, "Open Code Workflow source in Neovim",
            root.sourceEditorShellRoot)
        return true
    }

    readonly property string sourceNeedle:
        root.selectedSignalActionTarget?.parentObjectNeedle
            ?? root.selectedConnectTarget?.parentObjectNeedle
            ?? root.selectedIrNode?.sourceNeedle
            ?? ""
    readonly property string storedSemanticAnchor:
        CodeWorkflowSession.selectedConnectTargetId.length > 0
                || root.selectedSignalActionTarget !== null
            ? ""
            : CodeWorkflowSession.semanticAnchorNodeId
                === CodeWorkflowSession.selectedNodeId
                ? CodeWorkflowSession.semanticAnchor
                : ""
    readonly property bool live:
        root.snapshot.records?.some(item =>
            ["resident", "loaded", "loaded-hidden"].includes(
                String(item?.state ?? ""))) ?? false
    readonly property bool selectedLive:
        ["resident", "loaded", "loaded-hidden"].includes(
            String(root.record?.state ?? ""))
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
                + (CodeWorkflowAnalyzer.error.length > 0
                    ? " · " + CodeWorkflowAnalyzer.error
                    : "")
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
                + (CodeWorkflowAnalyzer.error.length > 0
                    ? " · " + CodeWorkflowAnalyzer.error
                    : "")
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
    readonly property bool directMutationSelectionEligible:
        root.selectedIrEdge === null
        || root.selectedIrEdge?.previewable === true
    readonly property bool literalPreviewEligible:
        root.directMutationSelectionEligible
        && root.analyzerMatchesAnchor
        && CodeWorkflowAnalyzer.status === "ready"
        && root.sourceAnchorEvidence?.status === "resolved"
        && root.sourceAnchorEvidence?.semanticAnchorUnique === true
        && root.sourceAnchorEvidence?.semanticKind === "property"
        && root.literalValueKinds.includes(
            String(root.sourceAnchorEvidence?.semanticValueKind ?? ""))
        && root.storedSemanticAnchor.length > 0
    readonly property bool bindingPreviewEligible:
        root.directMutationSelectionEligible
        && root.analyzerMatchesAnchor
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
    readonly property bool transactionSelectionMismatch:
        CodeWorkflowTransaction.dirty
        && CodeWorkflowTransaction.activeCommand !== null
        && !root.transactionMatchesSelection

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
        if (String(command.kind ?? "") === "signal-action") {
            return root.selectedSignalActionTarget !== null
                && String(command.targetId ?? "")
                    === CodeWorkflowSession.subflowTargetId
                && String(command.signalActionTargetId ?? "")
                    === String(root.selectedSignalActionTarget?.id ?? "")
                && String(command.sourcePath ?? "") === root.sourcePath
        }
        if (String(command.kind ?? "") === "direct-binding") {
            return root.directMutationSelectionEligible
                && String(command.targetId ?? "")
                    === CodeWorkflowSession.subflowTargetId
                && String(command.sourcePath ?? "") === root.sourcePath
                && String(command.semanticAnchor ?? "")
                    === root.storedSemanticAnchor
        }
        if (String(command.kind ?? "") === "disconnect-binding") {
            return root.selectedIrEdge !== null
                && String(command.targetId ?? "")
                    === CodeWorkflowSession.subflowTargetId
                && String(command.reviewedEdgeId ?? "")
                    === String(root.selectedIrEdge?.id ?? "")
                && String(command.sourcePath ?? "") === root.sourcePath
                && String(command.semanticAnchor ?? "")
                    === root.storedSemanticAnchor
        }
        if (String(command.kind ?? "") !== "literal-property")
            return false
        return root.selectedIrEdge === null
            && root.selectedConnectTarget === null
            && CodeWorkflowTransaction.sourcePath === root.sourcePath
            && CodeWorkflowTransaction.semanticAnchor
                === root.storedSemanticAnchor
    }
    readonly property string connectLifecyclePhaseText: {
        const phase = String(
            CodeWorkflowTransaction.pendingConnectPhase ?? "idle")
        switch (phase) {
        case "write-issued":
            return "WRITING SOURCE"
        case "waiting-reload":
            return "WAITING FOR RELOAD"
        case "candidate-verify-issued":
            return "VERIFYING CANDIDATE"
        case "rebinding":
            return "REBINDING SEMANTIC ANCHOR"
        case "rollback-pending":
            return "ROLLBACK PENDING"
        case "rollback-issued":
            return "RESTORING SNAPSHOT"
        case "rollback-waiting-reload":
            return "WAITING FOR ROLLBACK RELOAD"
        case "rollback-verify-issued":
            return "VERIFYING ROLLBACK"
        case "connect-commit-conflict":
            return "COMMIT CONFLICT"
        case "connect-commit-failed":
            return "COMMIT FAILED"
        case "connect-rollback-conflict":
            return "ROLLBACK CONFLICT"
        case "connect-rollback-failed":
            return "ROLLBACK FAILED"
        default:
            return phase.toUpperCase()
        }
    }

    readonly property string bindingLifecyclePhaseText: {
        const phase = String(
            CodeWorkflowTransaction.pendingBindingPhase ?? "idle")
        switch (phase) {
        case "write-issued":
            return "WRITING SOURCE"
        case "waiting-reload":
            return "WAITING FOR RELOAD"
        case "candidate-verify-issued":
            return "VERIFYING CANDIDATE"
        case "postcondition-checking":
            return "VERIFYING EXACT REBIND"
        case "rollback-pending":
            return "ROLLBACK PENDING"
        case "rollback-issued":
            return "RESTORING SNAPSHOT"
        case "rollback-waiting-reload":
            return "WAITING FOR ROLLBACK RELOAD"
        case "rollback-verify-issued":
            return "VERIFYING ROLLBACK"
        case "binding-commit-conflict":
            return "COMMIT CONFLICT"
        case "binding-commit-failed":
            return "COMMIT FAILED"
        case "binding-rollback-conflict":
            return "ROLLBACK CONFLICT"
        case "binding-rollback-failed":
            return "ROLLBACK FAILED"
        default:
            return phase.toUpperCase()
        }
    }

    readonly property string disconnectLifecyclePhaseText: {
        const phase = String(
            CodeWorkflowTransaction.pendingDisconnectPhase ?? "idle")
        switch (phase) {
        case "write-issued":
            return "WRITING SOURCE"
        case "waiting-reload":
            return "WAITING FOR RELOAD"
        case "candidate-verify-issued":
            return "VERIFYING CANDIDATE"
        case "postcondition-checking":
            return "VERIFYING BINDING ABSENCE"
        case "rollback-pending":
            return "ROLLBACK PENDING"
        case "rollback-issued":
            return "RESTORING SNAPSHOT"
        case "rollback-waiting-reload":
            return "WAITING FOR ROLLBACK RELOAD"
        case "rollback-verify-issued":
            return "VERIFYING ROLLBACK"
        case "disconnect-commit-conflict":
            return "COMMIT CONFLICT"
        case "disconnect-commit-failed":
            return "COMMIT FAILED"
        case "disconnect-rollback-conflict":
            return "ROLLBACK CONFLICT"
        case "disconnect-rollback-failed":
            return "ROLLBACK FAILED"
        default:
            return phase.toUpperCase()
        }
    }

    readonly property string signalActionLifecyclePhaseText: {
        const phase = String(
            CodeWorkflowTransaction.pendingSignalActionPhase ?? "idle")
        switch (phase) {
        case "write-issued":
            return "WRITING SOURCE"
        case "waiting-reload":
            return "WAITING FOR RELOAD"
        case "candidate-verify-issued":
            return "VERIFYING CANDIDATE"
        case "postcondition-checking":
            return "VERIFYING EXACT HANDLER"
        case "rollback-pending":
            return "ROLLBACK PENDING"
        case "rollback-issued":
            return "RESTORING SNAPSHOT"
        case "rollback-waiting-reload":
            return "WAITING FOR ROLLBACK RELOAD"
        case "rollback-verify-issued":
            return "VERIFYING ROLLBACK"
        case "signal-action-commit-conflict":
            return "COMMIT CONFLICT"
        case "signal-action-commit-failed":
            return "COMMIT FAILED"
        case "signal-action-rollback-conflict":
            return "ROLLBACK CONFLICT"
        case "signal-action-rollback-failed":
            return "ROLLBACK FAILED"
        default:
            return phase.toUpperCase()
        }
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
                + (CodeWorkflowAnalyzer.error.length > 0
                    ? " · " + CodeWorkflowAnalyzer.error
                    : "")
        if (CodeWorkflowAnalyzer.status === "error")
            return "ERROR"
                + (CodeWorkflowAnalyzer.error.length > 0
                    ? " · " + CodeWorkflowAnalyzer.error
                    : "")
        return "IDLE"
    }

    function scopeLeaf(value: string): string {
        const text = String(value ?? "")
        const bracket = text.lastIndexOf("[")
        return bracket > 0 && text.endsWith("]")
            ? text.slice(0, bracket)
            : text
    }

    function semanticEntryDepth(entry): int {
        const kind = String(entry?.kind ?? "")
        const scope = entry?.scope ?? []
        const ownsScope = kind === "object"
            || kind === "component"
            || kind === "inline-component"
            || kind === "lifecycle"
            || kind === "connections"
            || kind === "explicit-binding"
        return Math.min(5, Math.max(
            0, scope.length - (ownsScope ? 1 : 0)))
    }

    function semanticEntryVisible(entry, discloseInternals: bool): bool {
        const kind = String(entry?.kind ?? "")
        const visibleKinds = [
            "object", "component", "inline-component", "lifecycle",
            "connections", "property", "binding", "explicit-binding",
            "signal", "function", "handler-candidate", "id", "required",
            "pragma", "opaque"
        ]
        if (!visibleKinds.includes(kind))
            return false
        if (discloseInternals)
            return true

        if (kind === "component"
                || kind === "inline-component"
                || kind === "lifecycle"
                || kind === "connections"
                || kind === "explicit-binding")
            return true

        const qmlId = String(entry?.qml_id ?? "")
        if (qmlId.length > 0)
            return true

        if (kind !== "object")
            return false

        const objectType = String(entry?.object_type ?? entry?.name ?? "")
        const shortType = objectType.split(".").pop()
        const genericTypes = [
            "Item", "Rectangle", "Text", "Row", "Column", "Grid", "Flow",
            "RowLayout", "ColumnLayout", "GridLayout", "MouseArea",
            "TapHandler", "HoverHandler", "WheelHandler", "DragHandler",
            "PinchHandler", "Shape", "ShapePath", "Repeater", "ListView",
            "Flickable", "StyledText"
        ]
        return !genericTypes.includes(shortType)
    }

    function inspectIconForKind(kind: string): string {
        if (kind === "service")
            return "dns"
        if (kind === "event" || kind === "signal"
                || kind === "handler-candidate")
            return "bolt"
        if (kind === "action" || kind === "function")
            return "play_arrow"
        if (kind === "binding" || kind === "explicit-binding"
                || kind === "property" || kind === "required")
            return "link"
        if (kind === "lifecycle")
            return "hourglass"
        if (kind === "component" || kind === "inline-component")
            return "widgets"
        if (kind === "object")
            return "deployed_code"
        if (kind === "connections")
            return "conversion_path"
        if (kind === "id")
            return "tag"
        if (kind === "pragma")
            return "tune"
        if (kind === "opaque")
            return "warning"
        return "account_tree"
    }

    function inspectTargetSelected(item): bool {
        const category = String(item?.category ?? "")
        const id = String(item?.id ?? "")
        if (category === "runtime") {
            const targetGraph = CodeWorkflowIr.graphFor(id)
            return CodeWorkflowSession.selectedTargetId === id
                && CodeWorkflowSession.subflowTargetId === id
                && CodeWorkflowSession.selectedNodeId
                    === String(targetGraph?.rootNodeId ?? "")
                && root.inspectedSemanticAnchor.length === 0
                && CodeWorkflowSession.selectedEdgeId.length === 0
                && CodeWorkflowSession.selectedConnectTargetId.length === 0
        }
        if (category === "graph") {
            const rootNodeId = String(root.graph?.rootNodeId ?? "")
            const runtimeOwnsRoot = id === rootNodeId
                && CodeWorkflowSession.selectedTargetId
                    === CodeWorkflowSession.subflowTargetId
            return CodeWorkflowSession.selectedNodeId === id
                && !runtimeOwnsRoot
                && root.inspectedSemanticAnchor.length === 0
                && CodeWorkflowSession.selectedEdgeId.length === 0
                && CodeWorkflowSession.selectedConnectTargetId.length === 0
        }
        if (category === "edge")
            return CodeWorkflowSession.selectedEdgeId === id
                && root.inspectedSemanticAnchor.length === 0
        if (category === "connect")
            return CodeWorkflowSession.selectedConnectTargetId === id
                && root.inspectedSemanticAnchor.length === 0
        if (category === "semantic")
            return root.inspectedSemanticAnchor === id
        return false
    }

    function inspectTarget(item): void {
        const category = String(item?.category ?? "")
        const id = String(item?.id ?? "")
        if (id.length === 0)
            return

        root.inspectSelectionFromTargets = true
        try {
            if (category === "runtime") {
                root.selectTarget(id)
                return
            }
            if (category === "graph") {
                CodeWorkflowSession.selectNode(id)
                return
            }
            if (category === "edge") {
                CodeWorkflowSession.selectEdge(id)
                return
            }
            if (category === "connect") {
                CodeWorkflowSession.selectConnectTarget(id)
                return
            }
            if (category === "semantic") {
                root.inspectShowInternals = true
                CodeWorkflowSession.selectSemantic(id)
                Qt.callLater(root.revealSelectedInspectTarget)
                return
            }
        } finally {
            root.inspectSelectionFromTargets = false
        }
    }

    function prepareSelectedSemanticInspectTarget(): void {
        if (root.inspectedSemanticAnchor.length === 0)
            return

        if (!root.inspectSelectionFromTargets)
            root.inspectFilter = ""
        const entry = root.inspectedSemanticEntry
        if (entry !== null
                && !root.semanticEntryVisible(
                    entry, root.inspectShowInternals))
            root.inspectShowInternals = true
    }

    function revealSelectedInspectTarget(): void {
        const index = root.inspectTargets.findIndex(
            item => root.inspectTargetSelected(item))
        if (index < 0)
            return
        targetList.positionViewAtIndex(index, ListView.Contain)
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
        if (!item)
            return "RUNTIME TARGET NOT DISCOVERED"
        if (item.state === "resident")
            return "LIVE · RESIDENT"
        if (item.state === "loaded")
            return "LIVE · LOADED"
        if (item.state === "loaded-hidden")
            return "LOADED · HIDDEN"
        if (item.state === "loading")
            return "LOADING"
        if (item.state === "inactive")
            return "INACTIVE · SOURCE"
        if (item.state === "disabled")
            return "DISABLED · SOURCE"
        return String(item.state ?? "unknown").toUpperCase()
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
        if (CodeWorkflowSession.selectedConnectTargetId.length > 0
                || root.selectedSignalActionTarget !== null)
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

    function reconcileSemanticInspectSelection(): void {
        const selectedAnchor = CodeWorkflowSession.selectedSemanticAnchor
        if (selectedAnchor.length === 0
                || !root.analyzerMatchesSource
                || CodeWorkflowAnalyzer.status !== "ready")
            return
        const stillExists = root.parsedSemanticEntries.some(entry =>
            String(entry.anchor ?? "") === selectedAnchor)
        if (!stillExists)
            CodeWorkflowSession.selectSemantic("")
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
            String(nextValue ?? ""),
            CodeWorkflowSession.subflowTargetId)
    }

    function previewSelectedConnectTarget(): void {
        if (!root.connectPreviewEligible)
            return
        CodeWorkflowTransaction.previewConnectBinding(
            CodeWorkflowSession.subflowTargetId,
            CodeWorkflowSession.selectedConnectTargetId)
    }

    function previewSelectedSignalAction(): void {
        if (root.selectedSignalActionTarget === null
                || String(root.selectedSignalActionTarget?.id ?? "")
                    !== "media.signal.doubleClickToggle"
                || CodeWorkflowSession.subflowTargetId !== "bar/media")
            return
        CodeWorkflowTransaction.previewSignalAction(
            CodeWorkflowSession.subflowTargetId,
            String(root.selectedSignalActionTarget.id))
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
            expected,
            CodeWorkflowSession.subflowTargetId,
            String(root.selectedIrEdge?.id ?? ""))
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
                === "connect-binding"
                || CodeWorkflowTransaction.activeCommand?.kind
                    === "signal-action") {
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

    function textIndexForUtf8ByteOffset(byteOffset: int): int {
        const target = Math.max(0, Number(byteOffset))
        let bytes = 0
        let index = 0
        while (index < root.sourceText.length && bytes < target) {
            const first = root.sourceText.charCodeAt(index)
            if (first <= 0x7f) {
                bytes += 1
                index += 1
            } else if (first <= 0x7ff) {
                bytes += 2
                index += 1
            } else if (first >= 0xd800 && first <= 0xdbff
                    && index + 1 < root.sourceText.length) {
                const second = root.sourceText.charCodeAt(index + 1)
                if (second >= 0xdc00 && second <= 0xdfff) {
                    bytes += 4
                    index += 2
                } else {
                    bytes += 3
                    index += 1
                }
            } else {
                bytes += 3
                index += 1
            }
        }
        return index
    }

    function revealSourceSelection(start: int, end: int): void {
        if (start < 0 || end < start || root.sourceText.length === 0)
            return
        const safeStart = Math.min(start, root.sourceText.length)
        const safeEnd = Math.min(end, root.sourceText.length)
        sourcePreviewText.select(safeStart, safeEnd)
        Qt.callLater(() => {
            const rect = sourcePreviewText.positionToRectangle(safeStart)
            const margin = 18
            sourcePreviewFlick.contentX = Math.max(
                0,
                Math.min(
                    Math.max(0,
                        sourcePreviewFlick.contentWidth
                            - sourcePreviewFlick.width),
                    rect.x - margin))
            sourcePreviewFlick.contentY = Math.max(
                0,
                Math.min(
                    Math.max(0,
                        sourcePreviewFlick.contentHeight
                            - sourcePreviewFlick.height),
                    rect.y - sourcePreviewFlick.height / 3))
        })
    }

    function focusSourceAnchor(): void {
        sourcePreviewText.deselect()
        if (root.sourceText.length === 0)
            return

        const semanticRange = root.inspectedSemanticEntry?.range ?? []
        if (semanticRange.length === 2) {
            const start = root.textIndexForUtf8ByteOffset(
                Number(semanticRange[0]))
            const end = root.textIndexForUtf8ByteOffset(
                Number(semanticRange[1]))
            root.revealSourceSelection(start, end)
            return
        }

        if (root.sourceNeedle.length === 0)
            return
        const start = root.sourceText.indexOf(root.sourceNeedle)
        if (start < 0)
            return
        const duplicate = root.sourceText.indexOf(
            root.sourceNeedle,
            start + Math.max(1, root.sourceNeedle.length))
        if (duplicate >= 0)
            return
        root.revealSourceSelection(
            start, start + root.sourceNeedle.length)
    }

    onInspectedSemanticAnchorChanged:
        Qt.callLater(root.focusSourceAnchor)

    onSourceNeedleChanged: {
        Qt.callLater(root.focusSourceAnchor)
        Qt.callLater(() => root.requestAnalysis(false))
    }
    onStoredSemanticAnchorChanged: {
        Qt.callLater(() => root.requestAnalysis(false))
        Qt.callLater(root.evaluatePreApplyGate)
    }

    Loader {
        active: root.captureHarnessEnabled
        sourceComponent: IpcHandler {
            target: "codeWorkflowCapture"
            function begin(): string {
                return root.captureHarnessBegin()
            }
            function status(): string {
                return JSON.stringify(root.captureHarnessStatus())
            }
            function scenario(name: string): string {
                return root.captureHarnessScenario(name)
            }
            function restore(): string {
                return root.captureHarnessRestore()
            }
        }
    }

    Connections {
        target: CodeWorkflowSession

        function onSelectedTargetIdChanged(): void {
            if (!root.inspectSelectionFromTargets)
                root.inspectFilter = ""
            Qt.callLater(root.revealSelectedInspectTarget)
        }

        function onSelectedNodeIdChanged(): void {
            if (!root.inspectSelectionFromTargets
                    && CodeWorkflowSession.selectedSemanticAnchor.length === 0)
                root.inspectFilter = ""
            Qt.callLater(root.revealSelectedInspectTarget)
        }

        function onSelectedEdgeIdChanged(): void {
            if (!root.inspectSelectionFromTargets
                    && CodeWorkflowSession.selectedEdgeId.length > 0)
                root.inspectFilter = ""
            Qt.callLater(root.revealSelectedInspectTarget)
        }

        function onSelectedConnectTargetIdChanged(): void {
            if (!root.inspectSelectionFromTargets
                    && CodeWorkflowSession.selectedConnectTargetId.length > 0)
                root.inspectFilter = ""
            Qt.callLater(root.revealSelectedInspectTarget)
        }

        function onSelectedSemanticAnchorChanged(): void {
            root.prepareSelectedSemanticInspectTarget()
            Qt.callLater(root.revealSelectedInspectTarget)
        }
    }

    Connections {
        target: CodeWorkflowAnalyzer
        function onStatusChanged(): void {
            if (CodeWorkflowAnalyzer.status === "ready") {
                Qt.callLater(root.reconcileSemanticInspectSelection)
                Qt.callLater(root.captureSemanticAnchor)
                Qt.callLater(() => {
                    root.prepareSelectedSemanticInspectTarget()
                    root.revealSelectedInspectTarget()
                })
            } else if ((CodeWorkflowAnalyzer.status === "unavailable"
                        || CodeWorkflowAnalyzer.status === "error")
                    && CodeWorkflowSession.selectedSemanticAnchor.length > 0) {
                CodeWorkflowSession.selectSemantic("")
            }
            Qt.callLater(root.evaluatePreApplyGate)
        }
    }

    Connections {
        target: CodeWorkflowTransaction
        function onStatusChanged(): void {
            Qt.callLater(root.evaluatePreApplyGate)
        }
        function onHistoryIndexChanged(): void {
            transactionScroll.contentY = 0
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
            root.syncSourceEditorFromDisk(false)
            Qt.callLater(root.focusSourceAnchor)
        }
        onFileChanged: {
            CodeWorkflowTransaction.markSourceChanged(root.sourcePath)
            sourceReader.reload()
            root.requestAnalysis(true)
        }
        onLoadFailed: {
            root.sourceText = ""
            if (root.sourceEditorPath === root.sourcePath
                    && !root.sourceEditorDirty)
                root.syncSourceEditorFromDisk(true)
            root.sourceEditorStatus = "Source unavailable"
        }
    }

    FileView {
        id: sourceDraftWriter
        path: root.sourceEditorTempPath
        printErrors: false

        onLoaded: {
            if (!root.sourceEditorStagePending)
                return
            root.sourceEditorStagePending = false
            sourceEditorCommitProcess.command = [
                "/usr/bin/python3",
                Quickshell.shellPath("scripts/code-workflow-editor-save.py"),
                root.sourceEditorShellRoot,
                root.sourceEditorTargetPath,
                String(Qt.md5(root.sourceEditorBaseText)),
                root.sourceEditorTempPath
            ]
            sourceEditorCommitProcess.running = true
        }

        onLoadFailed: {
            if (!root.sourceEditorStagePending)
                return
            root.sourceEditorStagePending = false
            root.sourceEditorSaving = false
            root.sourceEditorStatus = "Failed to stage source draft"
        }
    }

    Process {
        id: sourceEditorCommitProcess
        running: false
        property bool startObserved: false

        onStarted: sourceEditorCommitProcess.startObserved = true
        onRunningChanged: {
            if (running) {
                sourceEditorCommitProcess.startObserved = false
                return
            }
            if (!sourceEditorCommitProcess.startObserved
                    && root.sourceEditorSaving) {
                root.sourceEditorSaving = false
                root.sourceEditorStatus = "Source save process failed to start"
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.sourceEditorBaseText = root.sourceDraft
                root.sourceText = root.sourceDraft
                root.sourceEditorConflict = false
                root.sourceEditorSaving = false
                root.sourceEditorStatus = "Saved"
                root.stashSourceEditorBuffer()
                sourceReader.reload()
                root.requestAnalysis(true)
                return
            }
            root.sourceEditorSaving = false
            if (exitCode === 3) {
                root.sourceEditorConflict = true
                root.sourceEditorStatus =
                    "Conflict: source changed before save"
                root.stashSourceEditorBuffer()
                sourceReader.reload()
                return
            }
            root.sourceEditorStatus =
                "Save failed · exit " + String(exitCode)
        }
    }

    component Pill: Rectangle {
        id: pill
        required property string label
        property color accent: Appearance.colors.colPrimary
        readonly property color ink: ColorUtils.readableAccentInk(
            accent,
            Appearance.colors.colLayer2,
            4.5,
            Appearance.colors.colOnLayer1)
        implicitWidth: Math.min(implicitContentWidth, 180)
        readonly property real implicitContentWidth:
            pillText.implicitWidth + 14
        implicitHeight: pillText.implicitHeight + 6
        radius: implicitHeight / 2
        color: Appearance.colors.colLayer2
        border.width: 1
        border.color: ColorUtils.applyAlpha(ink, 0.6)
        clip: true
        readonly property bool hovered: pillHover.hovered

        HoverHandler {
            id: pillHover
            target: pill
        }

        StyledText {
            id: pillText
            anchors.fill: parent
            anchors.leftMargin: 7
            anchors.rightMargin: 7
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            text: parent.label
            color: parent.ink
            font.pixelSize: Appearance.font.pixelSize.smallest
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        StyledToolTip {
            text: pill.label
        }
    }


    component WorkflowSplitHandle: Rectangle {
        id: splitHandle
        implicitWidth: 6
        implicitHeight: 6
        color: "transparent"
        readonly property bool handleHovered: SplitHandle.hovered
        readonly property bool handlePressed: SplitHandle.pressed
        readonly property bool horizontalRule: width > height

        // Keep the visual divider compact while providing a forgiving 18px
        // drag target on either side of the pane edge.
        containmentMask: Item {
            x: splitHandle.horizontalRule
                ? 0 : (splitHandle.width - width) / 2
            y: splitHandle.horizontalRule
                ? (splitHandle.height - height) / 2 : 0
            width: splitHandle.horizontalRule
                ? splitHandle.width : 18
            height: splitHandle.horizontalRule
                ? 18 : splitHandle.height
        }

        HoverHandler {
            cursorShape: splitHandle.horizontalRule
                ? Qt.SizeVerCursor : Qt.SizeHorCursor
        }

        Rectangle {
            anchors.centerIn: parent
            width: splitHandle.horizontalRule
                ? Math.min(48, Math.max(12, splitHandle.width - 8))
                : 2
            height: splitHandle.horizontalRule
                ? 2
                : Math.min(48, Math.max(12, splitHandle.height - 8))
            radius: 1
            color: splitHandle.handlePressed
                ? Appearance.colors.colPrimary
                : splitHandle.handleHovered
                    ? Appearance.colors.colOutline
                    : ColorUtils.applyAlpha(
                        Appearance.colors.colOutlineVariant, 0.65)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer1
            border.width: 1
            border.color: Appearance.colors.colOutlineVariant

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 8
                spacing: 6

                MaterialSymbol {
                    text: "account_tree"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colPrimary
                    StyledToolTip {
                        text: "Code Workflow · inspect, trace, and guarded source editing"
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: "Code Workflow · "
                        + String(root.graph?.title ?? "Workflow")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer1
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

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
                    label: root.record?.state === "loaded-hidden"
                        ? "HIDDEN"
                        : root.selectedLive ? "LIVE" : "SOURCE"
                    accent: root.selectedLive
                        ? Appearance.colors.colPrimary
                        : Appearance.colors.colSubtext
                    StyledToolTip {
                        text: root.record?.state === "loaded-hidden"
                            ? "Selected target is loaded but currently hidden"
                            : root.selectedLive
                                ? "Selected target is loaded in the running shell"
                                : "Selected target is available from runtime source metadata"
                    }
                }

                RippleButtonWithIcon {
                    materialIcon: "monitor"
                    buttonText: "Output · "
                        + (CodeWorkflowSession.outputName.length > 0
                            ? CodeWorkflowSession.outputName : "none")
                    mainText: ""
                    enabled: (root.snapshot.outputs?.length ?? 0) > 0
                    onClicked: root.cycleOutput()
                    StyledToolTip {
                        text: "Output · "
                            + (CodeWorkflowSession.outputName.length > 0
                                ? CodeWorkflowSession.outputName : "none")
                    }
                }
                RippleButtonWithIcon {
                    visible: CodeWorkflowSession.subflowTargetId !== "bar"
                    materialIcon: "arrow_back"
                    buttonText: "Back to Bar workflow"
                    mainText: ""
                    onClicked: CodeWorkflowSession.openSubflow("bar")
                    StyledToolTip { text: "Back to Bar workflow" }
                }
                RippleButtonWithIcon {
                    materialIcon: "ads_click"
                    buttonText: CodeWorkflowPicker.phase === "idle"
                        ? "Pick component" : "Picking component"
                    mainText: ""
                    enabled: root.pickerAvailable
                    onClicked: CodeWorkflowPicker.begin()
                    StyledToolTip {
                        text: root.pickerAvailable
                            ? "Pick a live component from the shell"
                            : (root.live
                                ? "Picker is available from overlay Settings only"
                                : "No live inspect target is available")
                    }
                }
                RippleButtonWithIcon {
                    materialIcon: "filter_center_focus"
                    buttonText: "Fit graph"
                    mainText: ""
                    onClicked: canvas.fitGraph()
                    StyledToolTip { text: "Fit graph to viewport" }
                }
                RippleButtonWithIcon {
                    materialIcon: "restart_alt"
                    buttonText: "Reset graph layout"
                    mainText: ""
                    enabled: CodeWorkflowSession.graphLayoutRevision >= 0
                        && CodeWorkflowSession.hasGraphLayout(
                            CodeWorkflowSession.subflowTargetId)
                    onClicked: {
                        CodeWorkflowSession.resetGraphLayout(
                            CodeWorkflowSession.subflowTargetId)
                        Qt.callLater(canvas.fitGraph)
                    }
                    StyledToolTip {
                        text: enabled
                            ? "Reset moved components to reviewed layout"
                            : "Graph layout already matches reviewed positions"
                    }
                }
                RippleButtonWithIcon {
                    materialIcon: "code"
                    buttonText: CodeWorkflowSession.sourcePreviewVisible
                        ? "Hide source preview" : "Show source preview"
                    mainText: ""
                    onClicked: CodeWorkflowSession.sourcePreviewVisible =
                        !CodeWorkflowSession.sourcePreviewVisible
                    StyledToolTip {
                        text: CodeWorkflowSession.sourcePreviewVisible
                            ? "Hide source editor" : "Show source editor"
                    }
                }
            }
        }

        SplitView {
            id: workflowVerticalSplit
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: Qt.Vertical
            handle: WorkflowSplitHandle {}

            SplitView {
                id: workflowHorizontalSplit
                SplitView.fillHeight: true
                SplitView.minimumHeight: 280
                orientation: Qt.Horizontal
                handle: WorkflowSplitHandle {}

                onResizingChanged: {
                    if (resizing)
                        return
                    if (!CodeWorkflowSession.targetsPaneCollapsed)
                        CodeWorkflowSession.targetsPaneWidth = targetsPane.width
                    if (!CodeWorkflowSession.inspectorPaneCollapsed)
                        CodeWorkflowSession.inspectorPaneWidth = inspectorPane.width
                }

            Rectangle {
                id: targetsPane
                SplitView.preferredWidth: CodeWorkflowSession.targetsPaneCollapsed
                    ? 42 : CodeWorkflowSession.targetsPaneWidth
                SplitView.minimumWidth: CodeWorkflowSession.targetsPaneCollapsed
                    ? 42 : 180
                SplitView.maximumWidth: CodeWorkflowSession.targetsPaneCollapsed
                    ? 42 : 420
                radius: Appearance.rounding.normal
                color: Appearance.colors.colLayer1
                border.width: 1
                border.color: Appearance.colors.colOutlineVariant

                RippleButtonWithIcon {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 5
                    z: 5
                    materialIcon: CodeWorkflowSession.targetsPaneCollapsed
                        ? "chevron_right" : "chevron_left"
                    buttonText: CodeWorkflowSession.targetsPaneCollapsed
                        ? "Expand Targets" : "Collapse Targets"
                    mainText: ""
                    onClicked: CodeWorkflowSession.setTargetsPaneCollapsed(
                        !CodeWorkflowSession.targetsPaneCollapsed)
                    StyledToolTip {
                        text: CodeWorkflowSession.targetsPaneCollapsed
                            ? "Expand Targets" : "Collapse Targets"
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 9
                    visible: !CodeWorkflowSession.targetsPaneCollapsed
                    spacing: 7

                    StyledText {
                        Layout.rightMargin: 30
                        text: "Targets"
                        color: Appearance.colors.colOnLayer1
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.DemiBold
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: "Runtime · graph · connections · connect · parsed QML"
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        wrapMode: Text.WordWrap
                    }

                    ToolbarTextField {
                        id: targetFilter
                        Layout.fillWidth: true
                        Layout.fillHeight: false
                        Layout.preferredHeight: 34
                        colBackground: Appearance.colors.colLayer2
                        text: root.inspectFilter
                        placeholderText: "Filter targets"
                        Accessible.name: "Filter inspect targets"
                        Accessible.description:
                            "Search runtime, graph, connection, connect candidate, and parsed QML targets"
                        onTextChanged: root.inspectFilter = text
                    }

                    RippleButtonWithIcon {
                        Layout.fillWidth: true
                        materialIcon: root.inspectShowInternals
                            ? "visibility_off" : "account_tree"
                        mainText: root.inspectShowInternals
                            ? "Hide internals" : "Show internals"
                        onClicked: root.inspectShowInternals =
                            !root.inspectShowInternals
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: root.inspectTargets.length === 0
                        text: root.inspectFilter.trim().length > 0
                            ? "No targets match the current filter"
                            : "No inspect targets available"
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }

                    ListView {
                        id: targetList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 3
                        clip: true
                        model: root.inspectTargets

                        delegate: Rectangle {
                            id: targetRow
                            required property int index
                            required property var modelData
                            readonly property bool selected:
                                root.inspectTargetSelected(modelData)
                            readonly property bool section:
                                modelData.category === "section"

                            function activateRow(): void {
                                if (targetRow.section)
                                    return
                                root.inspectTarget(targetRow.modelData)
                            }

                            width: targetList.width
                            height: section
                                ? 44
                                : modelData.category === "runtime" ? 54 : 48
                            radius: Appearance.rounding.small
                            color: selected
                                ? Appearance.colors.colPrimaryContainer
                                : section
                                    ? Appearance.colors.colLayer2
                                    : "transparent"
                            border.width: selected
                                ? 1
                                : activeFocus && !section ? 1 : 0
                            border.color: Appearance.colors.colPrimary
                            clip: true
                            activeFocusOnTab: !section

                            Accessible.role: section
                                ? Accessible.StaticText
                                : Accessible.Button
                            Accessible.name: String(modelData.label ?? "")
                            Accessible.description:
                                String(modelData.detail ?? "")
                            Accessible.focusable: !section
                            Accessible.onPressAction: targetRow.activateRow()

                            TapHandler {
                                enabled: !targetRow.section
                                onTapped: {
                                    targetRow.activateRow()
                                    targetRow.forceActiveFocus()
                                }
                            }

                            Keys.onPressed: event => {
                                if (targetRow.section
                                        || (event.key !== Qt.Key_Return
                                            && event.key !== Qt.Key_Enter
                                            && event.key !== Qt.Key_Space)) {
                                    event.accepted = false
                                    return
                                }
                                targetRow.activateRow()
                                event.accepted = true
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                    + (targetRow.section
                                        ? 0
                                        : Number(
                                            targetRow.modelData.depth ?? 0)
                                            * 12)
                                anchors.rightMargin: 8
                                spacing: 7
                                MaterialSymbol {
                                    text: targetRow.modelData.icon
                                    iconSize: Appearance.font.pixelSize.normal
                                    color: targetRow.selected
                                        ? Appearance.colors.colOnPrimaryContainer
                                        : targetRow.section
                                            ? Appearance.colors.colSubtext
                                            : Appearance.colors.colOnLayer1
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    StyledText {
                                        Layout.fillWidth: true
                                        Layout.maximumWidth: Math.max(0,
                                            targetRow.width - 44
                                                - Number(
                                                    targetRow.modelData.depth
                                                        ?? 0) * 12)
                                        text: targetRow.modelData.label
                                        color: targetRow.selected
                                            ? Appearance.colors.colOnPrimaryContainer
                                            : Appearance.colors.colOnLayer1
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        font.weight: targetRow.section
                                            ? Font.DemiBold
                                            : Font.Medium
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }
                                    StyledText {
                                        Layout.fillWidth: true
                                        Layout.maximumWidth: Math.max(0,
                                            targetRow.width - 44
                                                - Number(
                                                    targetRow.modelData.depth
                                                        ?? 0) * 12)
                                        text: targetRow.modelData.detail
                                        color: targetRow.selected
                                            ? ColorUtils.ensureReadable(
                                                Appearance.colors.colSubtext,
                                                Appearance.colors.colPrimaryContainer,
                                                4.5)
                                            : Appearance.colors.colSubtext
                                        font.pixelSize: Appearance.font.pixelSize.smallest
                                        elide: Text.ElideMiddle
                                        maximumLineCount: 1
                                    }
                                }
                            }
                        }
                    }
                }
            }

            CodeWorkflowIrCanvas {
                id: canvas
                SplitView.fillWidth: true
                SplitView.minimumWidth: 360
            }

            Rectangle {
                id: inspectorPane
                SplitView.preferredWidth: CodeWorkflowSession.inspectorPaneCollapsed
                    ? 42 : CodeWorkflowSession.inspectorPaneWidth
                SplitView.minimumWidth: CodeWorkflowSession.inspectorPaneCollapsed
                    ? 42 : 240
                SplitView.maximumWidth: CodeWorkflowSession.inspectorPaneCollapsed
                    ? 42 : 520
                radius: Appearance.rounding.normal
                color: Appearance.colors.colLayer1
                border.width: 1
                border.color: Appearance.colors.colOutlineVariant
                clip: true

                RippleButtonWithIcon {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 5
                    z: 5
                    materialIcon: CodeWorkflowSession.inspectorPaneCollapsed
                        ? "chevron_left" : "chevron_right"
                    buttonText: CodeWorkflowSession.inspectorPaneCollapsed
                        ? "Expand Inspector" : "Collapse Inspector"
                    mainText: ""
                    onClicked: CodeWorkflowSession.setInspectorPaneCollapsed(
                        !CodeWorkflowSession.inspectorPaneCollapsed)
                    StyledToolTip {
                        text: CodeWorkflowSession.inspectorPaneCollapsed
                            ? "Expand Inspector" : "Collapse Inspector"
                    }
                }

                StyledFlickable {
                    id: inspectorScroll
                    visible: !CodeWorkflowSession.inspectorPaneCollapsed
                    anchors.fill: parent
                    anchors.margins: 4
                    contentWidth: width
                    contentHeight: inspectorColumn.implicitHeight + 12
                    clip: true

                    ColumnLayout {
                        id: inspectorColumn
                        x: 6
                        y: 6
                        width: Math.max(0, inspectorScroll.width - 18)
                        spacing: 8

                    StyledText {
                        Layout.rightMargin: 30
                        text: "Inspector"
                        color: Appearance.colors.colOnLayer1
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.DemiBold
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: root.inspectedSemanticEntry
                            ? (String(root.inspectedSemanticEntry.qml_id ?? "").length > 0
                                ? String(root.inspectedSemanticEntry.object_type
                                    ?? root.inspectedSemanticEntry.name ?? "Element")
                                    + "#" + String(root.inspectedSemanticEntry.qml_id)
                                : String(root.inspectedSemanticEntry.name
                                    ?? root.inspectedSemanticEntry.kind
                                    ?? "Element"))
                            : root.selectedConnectTarget !== null
                                ? String(root.selectedConnectTarget.label
                                    ?? root.selectedConnectTarget.id
                                    ?? "Connect candidate")
                                : root.selectedIrEdge !== null
                                    ? String(root.selectedIrEdge.label
                                        ?? root.selectedIrEdge.id
                                        ?? "Connection")
                                    : root.selectedIrNode?.title
                                        ?? root.descriptor?.label
                                        ?? "Target"
                        color: Appearance.colors.colPrimary
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        font.pixelSize: Appearance.font.pixelSize.large
                        font.weight: Font.DemiBold
                    }
                    Pill {
                        label: String(root.inspectedSemanticEntry?.kind
                            ?? (root.selectedConnectTarget !== null
                                ? "connect" : null)
                            ?? root.selectedIrEdge?.kind
                            ?? root.selectedIrNode?.kind
                            ?? "component").toUpperCase()
                        accent: Appearance.colors.colPrimary
                    }
                    StyledText {
                        Layout.fillWidth: true
                        visible: root.inspectedSemanticEntry !== null
                        text: root.inspectedSemanticEntry
                            ? "Parsed QML element · "
                                + String(root.inspectedSemanticEntry.anchor ?? "")
                            : ""
                        color: Appearance.colors.colSubtext
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        elide: Text.ElideMiddle
                        maximumLineCount: 1
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: root.inspectedSemanticEntry
                            ? "Read-only parser element · "
                                + root.inspectedSemanticRangeText
                            : root.selectedConnectTarget !== null
                                ? "Reviewed connect candidate · TYPE/CYCLE proof pending"
                                : root.selectedIrNode?.description ?? ""
                        visible: text.length > 0
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        wrapMode: Text.WordWrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }
                    StyledText {
                        visible: root.inspectedSemanticEntry === null
                        text: "Runtime"
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        Layout.fillWidth: true
                        visible: root.inspectedSemanticEntry === null
                        text: root.stateLabel(root.record)
                        color: root.record?.state === "resident"
                            ? Appearance.colors.colPrimary
                            : Appearance.colors.colSubtext
                    }
                    StyledText {
                        visible: root.inspectedSemanticEntry === null
                        text: "Output"
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        Layout.fillWidth: true
                        visible: root.inspectedSemanticEntry === null
                        text: root.record?.output || "—"
                        color: Appearance.colors.colOnLayer1
                        elide: Text.ElideRight
                    }
                    StyledText {
                        visible: root.inspectedSemanticEntry === null
                        text: "Geometry"
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        Layout.fillWidth: true
                        visible: root.inspectedSemanticEntry === null
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
                            ? String(root.selectedIrEdge.label
                                ?? root.selectedIrEdge.id)
                                + (String(root.selectedIrEdge.sourceExpression
                                        ?? "").length > 0
                                    ? " · "
                                        + String(
                                            root.selectedIrEdge
                                                .sourceExpression)
                                    : "")
                            : ""
                        color: Appearance.colors.colPrimary
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        wrapMode: Text.WrapAnywhere
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }
                    StyledText {
                        Layout.fillWidth: true
                        visible: root.selectedIrEdge !== null
                        text: root.selectedIrEdge
                            ? String(root.selectedIrEdge.kind
                                ?? "connection").toUpperCase()
                                + " · "
                                + String(root.selectedIrEdge.from ?? "—")
                                + " → "
                                + String(root.selectedIrEdge.to ?? "—")
                                + (root.selectedEdgeReadOnly
                                    ? " · READ ONLY"
                                    : " · REVIEWED")
                            : ""
                        color: root.selectedEdgeReadOnly
                            ? Appearance.colors.colSubtext
                            : Appearance.colors.colTertiary
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        elide: Text.ElideMiddle
                        maximumLineCount: 1
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
                    RippleButtonWithIcon {
                        visible: root.selectedIrEdge === null
                            && root.reviewedSignalActionTargetForSelection
                                !== null
                            && root.reviewedSignalActionEdgeForSelection
                                !== null
                        Layout.fillWidth: true
                        materialIcon: "conversion_path"
                        mainText: root.reviewedSignalActionTargetForSelection
                            ? "Select Signal/Action · "
                                + String(
                                    root.reviewedSignalActionTargetForSelection
                                        .label ?? "")
                            : "Select Signal/Action"
                        onClicked: {
                            if (root.reviewedSignalActionEdgeForSelection)
                                CodeWorkflowSession.selectEdge(
                                    root.reviewedSignalActionEdgeForSelection.id)
                        }
                    }
                    StyledText {
                        visible: root.selectedSignalActionTarget !== null
                        text: "Reviewed Signal/Action"
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        Layout.fillWidth: true
                        visible: root.selectedSignalActionTarget !== null
                        text: root.selectedSignalActionTarget
                            ? String(
                                root.selectedSignalActionTarget.handlerName ?? "")
                                + " → "
                                + String(
                                    root.selectedSignalActionTarget
                                        .actionExpression ?? "")
                            : ""
                        color: Appearance.colors.colPrimary
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        wrapMode: Text.WrapAnywhere
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }
                    StyledText {
                        Layout.fillWidth: true
                        visible: root.selectedSignalActionTarget !== null
                        text: "EXACT REVIEWED TARGET · one handler + one existing action · no TYPE/CYCLE proof"
                        color: Appearance.colors.colTertiary
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.weight: Font.Medium
                        wrapMode: Text.WordWrap
                    }
                    RippleButtonWithIcon {
                        visible: root.selectedSignalActionTarget !== null
                        Layout.fillWidth: true
                        materialIcon: "bolt"
                        mainText: "Preview Signal/Action"
                        enabled: !CodeWorkflowTransaction.previewBusy
                            && root.selectedSignalActionTarget?.id
                                === "media.signal.doubleClickToggle"
                        onClicked: root.previewSelectedSignalAction()
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
                        elide: Text.ElideMiddle
                        maximumLineCount: 1
                    }
                    StyledText { text: "Source anchor"; color: Appearance.colors.colSubtext }
                    StyledText {
                        Layout.fillWidth: true
                        text: root.inspectedSemanticEntry
                            ? root.inspectedSemanticRangeText
                            : root.sourceNeedle.length > 0
                                ? root.sourceNeedle
                                : "No reviewed source anchor"
                        color: Appearance.colors.colOnLayer1
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        wrapMode: Text.WrapAnywhere
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }
                    StyledText { text: "Semantic ID"; color: Appearance.colors.colSubtext }
                    StyledText {
                        Layout.fillWidth: true
                        text: root.inspectedSemanticEntry
                            ? String(root.inspectedSemanticEntry.anchor ?? "")
                            : root.storedSemanticAnchor.length > 0
                                ? root.storedSemanticAnchor
                                : "Not bound"
                        color: root.inspectedSemanticEntry !== null
                                || root.storedSemanticAnchor.length > 0
                            ? Appearance.colors.colPrimary
                            : Appearance.colors.colSubtext
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        elide: Text.ElideMiddle
                        maximumLineCount: 1
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
                        text: root.inspectedSemanticEntry
                            ? "PARSED · " + root.inspectedSemanticRangeText
                            : root.sourceRangeText
                        color: root.inspectedSemanticEntry !== null
                                || root.sourceAnchorEvidence?.status === "resolved"
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
                                ? String(root.selectedIrEdge?.id ?? "")
                                        === "clock.data.time"
                                    ? "Phase 2 Disconnect · reviewed transactional Apply"
                                    : "Phase 2 edge retarget · preview only"
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
                        visible: root.selectedIrEdge?.previewable === true
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
                    StyledText {
                        Layout.fillWidth: true
                        text: "Literal-property Apply remains independently qualified. Direct-binding Apply is restricted to reviewed clock.text.time-to-date and requires exact replacement artifacts + explicit authorization. Connect Apply requires its exact prepared + authorized handoff. Disconnect Apply is restricted to reviewed clock.data.time and requires exact deletion artifacts + explicit authorization."
                        color: Appearance.colors.colTertiary
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        wrapMode: Text.WordWrap
                    }
                }
            }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: CodeWorkflowTransaction.dirty
                ? Math.min(
                    420,
                    Math.max(118, transactionColumn.implicitHeight + 16))
                : 0
            visible: CodeWorkflowTransaction.dirty
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer1
            border.width: 1
            border.color: CodeWorkflowTransaction.status === "conflict"
                ? Appearance.colors.colError
                : Appearance.colors.colOutlineVariant
            clip: true

            StyledFlickable {
                id: transactionScroll
                anchors.fill: parent
                anchors.margins: 4
                contentWidth: width
                contentHeight: transactionColumn.implicitHeight + 8
                clip: true

                ColumnLayout {
                    id: transactionColumn
                    x: 4
                    y: 4
                    width: Math.max(0, transactionScroll.width - 8)
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
                                    === "signal-action"
                                    ? "Signal/Action Preview · "
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
                        label: root.transactionSelectionMismatch
                            ? "OTHER SELECTION"
                            : CodeWorkflowTransaction.activeCommand?.kind
                                === "connect-binding"
                            ? CodeWorkflowTransaction.connectLifecycleBusy
                                ? "CONNECT APPLY · "
                                    + root.connectLifecyclePhaseText
                                : CodeWorkflowTransaction.status
                                        === "connect-applied"
                                    ? "CONNECT APPLIED"
                                    : CodeWorkflowTransaction.status
                                            === "connect-rollback-complete"
                                        ? "CONNECT ROLLED BACK"
                                        : CodeWorkflowTransaction.connectApplyEnabled
                                            ? "CONNECT APPLY READY"
                                            : CodeWorkflowTransaction.connectAuthorizationReady
                                                ? "CONNECT AUTHORIZED"
                                                : CodeWorkflowTransaction.connectArtifactsReady
                                                    ? "CONNECT READY · AUTHORIZATION REQUIRED"
                                                    : CodeWorkflowTransaction.connectPreparationBusy
                                                        ? "CONNECT CHECKING"
                                                        : "PREVIEW ONLY"
                            : CodeWorkflowTransaction.activeCommand?.kind
                                    === "disconnect-binding"
                                ? CodeWorkflowTransaction.disconnectLifecycleBusy
                                    ? "DISCONNECT APPLY · "
                                        + root.disconnectLifecyclePhaseText
                                    : CodeWorkflowTransaction.status
                                            === "disconnect-applied"
                                        ? "DISCONNECT APPLIED"
                                        : CodeWorkflowTransaction.status
                                                === "disconnect-rollback-complete"
                                            ? "DISCONNECT ROLLED BACK"
                                            : CodeWorkflowTransaction.disconnectApplyEnabled
                                                ? "DISCONNECT APPLY READY"
                                                : CodeWorkflowTransaction.disconnectAuthorizationReady
                                                    ? "DISCONNECT AUTHORIZED"
                                                    : CodeWorkflowTransaction.disconnectArtifactsReady
                                                        ? "DISCONNECT READY · AUTHORIZATION REQUIRED"
                                                        : CodeWorkflowTransaction.disconnectPreparationBusy
                                                            ? "DISCONNECT PREPARING"
                                                            : "PREVIEW ONLY"
                                : CodeWorkflowTransaction.activeCommand?.kind
                                        === "signal-action"
                                    ? CodeWorkflowTransaction.signalActionLifecycleBusy
                                        ? "SIGNAL/ACTION APPLY · "
                                            + root.signalActionLifecyclePhaseText
                                        : CodeWorkflowTransaction.status
                                                === "signal-action-applied"
                                            ? "SIGNAL/ACTION APPLIED"
                                            : CodeWorkflowTransaction.status
                                                    === "signal-action-rollback-complete"
                                                ? "SIGNAL/ACTION ROLLED BACK"
                                                : CodeWorkflowTransaction.signalActionApplyEnabled
                                                    ? "SIGNAL/ACTION APPLY READY"
                                                    : CodeWorkflowTransaction.signalActionAuthorizationReady
                                                        ? "SIGNAL/ACTION AUTHORIZED"
                                                        : CodeWorkflowTransaction.signalActionArtifactsReady
                                                            ? "SIGNAL/ACTION READY · AUTHORIZATION REQUIRED"
                                                            : CodeWorkflowTransaction.signalActionPreparationBusy
                                                                ? "SIGNAL/ACTION PREPARING"
                                                                : "PREVIEW ONLY"
                                : CodeWorkflowTransaction.activeCommand?.kind
                                        === "direct-binding"
                                    ? CodeWorkflowTransaction.bindingLifecycleBusy
                                        ? "BINDING APPLY · "
                                            + root.bindingLifecyclePhaseText
                                        : CodeWorkflowTransaction.status
                                                === "binding-applied"
                                            ? "BINDING APPLIED"
                                            : CodeWorkflowTransaction.status
                                                    === "binding-rollback-complete"
                                                ? "BINDING ROLLED BACK"
                                                : CodeWorkflowTransaction.bindingApplyEnabled
                                                    ? "BINDING APPLY READY"
                                                    : CodeWorkflowTransaction.bindingAuthorizationReady
                                                        ? "BINDING AUTHORIZED"
                                                        : CodeWorkflowTransaction.bindingArtifactsReady
                                                            ? "BINDING READY · AUTHORIZATION REQUIRED"
                                                            : CodeWorkflowTransaction.bindingPreparationBusy
                                                                ? "BINDING PREPARING"
                                                                : "PREVIEW ONLY"
                                    : CodeWorkflowTransaction.applyEnabled
                                    && root.transactionMatchesSelection
                                ? "APPLY READY"
                                : CodeWorkflowTransaction.applyArtifactsReady
                                    ? "ARTIFACTS READY"
                                    : CodeWorkflowTransaction.preApplyReady
                                        ? "PRE-APPLY READY"
                                        : "PRE-APPLY BLOCKED"
                        accent: root.transactionSelectionMismatch
                            ? Appearance.colors.colTertiary
                            : CodeWorkflowTransaction.activeCommand?.kind
                                === "connect-binding"
                                && (CodeWorkflowTransaction.connectArtifactsReady
                                    || CodeWorkflowTransaction
                                        .connectAuthorizationReady)
                            ? Appearance.colors.colPrimary
                            : CodeWorkflowTransaction.activeCommand?.kind
                                    === "signal-action"
                                && (CodeWorkflowTransaction.signalActionArtifactsReady
                                    || CodeWorkflowTransaction
                                        .signalActionAuthorizationReady)
                            ? Appearance.colors.colPrimary
                            : CodeWorkflowTransaction.activeCommand?.kind
                                    === "direct-binding"
                                && (CodeWorkflowTransaction.bindingArtifactsReady
                                    || CodeWorkflowTransaction
                                        .bindingAuthorizationReady)
                            ? Appearance.colors.colPrimary
                            : CodeWorkflowTransaction.activeCommand?.kind
                                    === "disconnect-binding"
                                && (CodeWorkflowTransaction.disconnectArtifactsReady
                                    || CodeWorkflowTransaction
                                        .disconnectAuthorizationReady)
                            ? Appearance.colors.colPrimary
                            : [
                                "direct-binding",
                                "disconnect-binding",
                                "connect-binding",
                                "signal-action"
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
                    StyledText {
                        Layout.fillWidth: true
                        visible: root.transactionSelectionMismatch
                        text: "Preview belongs to another inspect selection. "
                            + "Re-select its target, connection, or candidate "
                            + "to resume guarded transaction controls."
                        color: Appearance.colors.colTertiary
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        wrapMode: Text.WordWrap
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
                            && !CodeWorkflowTransaction.connectLifecycleBusy
                            && root.transactionMatchesSelection
                        materialIcon: "save"
                        mainText: "Apply Connect"
                        enabled: CodeWorkflowTransaction.connectApplyEnabled
                            && root.transactionMatchesSelection
                        onClicked:
                            CodeWorkflowTransaction.beginAuthorizedConnectApply()
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
                        visible: CodeWorkflowTransaction.activeCommand?.kind
                            === "signal-action"
                            && root.transactionMatchesSelection
                        materialIcon: "inventory_2"
                        mainText: CodeWorkflowTransaction.signalActionArtifactsReady
                            ? "Signal/Action artifacts prepared"
                            : "Prepare Signal/Action artifacts"
                        enabled: CodeWorkflowTransaction.signalActionPrepareEnabled
                            && root.transactionMatchesSelection
                        onClicked:
                            CodeWorkflowTransaction.prepareSignalActionArtifacts()
                    }
                    RippleButtonWithIcon {
                        visible: CodeWorkflowTransaction.activeCommand?.kind
                            === "signal-action"
                            && CodeWorkflowTransaction.signalActionArtifactsReady
                            && root.transactionMatchesSelection
                        materialIcon: "verified_user"
                        mainText: CodeWorkflowTransaction.signalActionAuthorizationReady
                            ? "Signal/Action write authorized"
                            : "Authorize Signal/Action write"
                        enabled: CodeWorkflowTransaction.signalActionAuthorizeEnabled
                            && root.transactionMatchesSelection
                        onClicked:
                            CodeWorkflowTransaction.authorizeSignalActionWrite()
                    }
                    RippleButtonWithIcon {
                        visible: CodeWorkflowTransaction.activeCommand?.kind
                            === "signal-action"
                            && CodeWorkflowTransaction.signalActionAuthorizationReady
                            && !CodeWorkflowTransaction.signalActionLifecycleBusy
                            && root.transactionMatchesSelection
                        materialIcon: "bolt"
                        mainText: "Apply Signal/Action"
                        enabled: CodeWorkflowTransaction.signalActionApplyEnabled
                            && root.transactionMatchesSelection
                        onClicked:
                            CodeWorkflowTransaction.beginAuthorizedSignalActionApply()
                    }
                    RippleButtonWithIcon {
                        visible: CodeWorkflowTransaction.activeCommand?.kind
                            === "signal-action"
                            && CodeWorkflowTransaction.signalActionAuthorizationReady
                            && root.transactionMatchesSelection
                        materialIcon: "gpp_bad"
                        mainText: "Revoke Signal/Action authorization"
                        enabled: !CodeWorkflowTransaction.signalActionLifecycleBusy
                        onClicked:
                            CodeWorkflowTransaction.revokeSignalActionAuthorization(
                                "user-revoked")
                    }
                    RippleButtonWithIcon {
                        visible: CodeWorkflowTransaction.activeCommand?.kind
                            === "direct-binding"
                            && String(
                                CodeWorkflowTransaction.activeCommand
                                    ?.reviewedReplacementId ?? "")
                                === "clock.text.time-to-date"
                            && root.transactionMatchesSelection
                        materialIcon: "inventory_2"
                        mainText: CodeWorkflowTransaction.bindingArtifactsReady
                            ? "Binding artifacts prepared"
                            : "Prepare Binding artifacts"
                        enabled: CodeWorkflowTransaction.bindingPrepareEnabled
                            && root.transactionMatchesSelection
                        onClicked:
                            CodeWorkflowTransaction.prepareBindingArtifacts()
                    }
                    RippleButtonWithIcon {
                        visible: CodeWorkflowTransaction.activeCommand?.kind
                            === "direct-binding"
                            && CodeWorkflowTransaction.bindingArtifactsReady
                            && root.transactionMatchesSelection
                        materialIcon: "verified_user"
                        mainText: CodeWorkflowTransaction.bindingAuthorizationReady
                            ? "Binding write authorized"
                            : "Authorize Binding write"
                        enabled: CodeWorkflowTransaction.bindingAuthorizeEnabled
                            && root.transactionMatchesSelection
                        onClicked:
                            CodeWorkflowTransaction.authorizeBindingWrite()
                    }
                    RippleButtonWithIcon {
                        visible: CodeWorkflowTransaction.activeCommand?.kind
                            === "direct-binding"
                            && CodeWorkflowTransaction.bindingAuthorizationReady
                            && !CodeWorkflowTransaction.bindingLifecycleBusy
                            && root.transactionMatchesSelection
                        materialIcon: "swap_horiz"
                        mainText: "Apply Binding replacement"
                        enabled: CodeWorkflowTransaction.bindingApplyEnabled
                            && root.transactionMatchesSelection
                        onClicked:
                            CodeWorkflowTransaction.beginAuthorizedBindingApply()
                    }
                    RippleButtonWithIcon {
                        visible: CodeWorkflowTransaction.activeCommand?.kind
                            === "direct-binding"
                            && CodeWorkflowTransaction.bindingAuthorizationReady
                            && root.transactionMatchesSelection
                        materialIcon: "gpp_bad"
                        mainText: "Revoke Binding authorization"
                        enabled: !CodeWorkflowTransaction.bindingLifecycleBusy
                        onClicked:
                            CodeWorkflowTransaction.revokeBindingAuthorization(
                                "user-revoked")
                    }
                    RippleButtonWithIcon {
                        visible: CodeWorkflowTransaction.activeCommand?.kind
                            === "disconnect-binding"
                            && root.transactionMatchesSelection
                        materialIcon: "inventory_2"
                        mainText: CodeWorkflowTransaction.disconnectArtifactsReady
                            ? "Disconnect artifacts prepared"
                            : "Prepare Disconnect artifacts"
                        enabled: CodeWorkflowTransaction.disconnectPrepareEnabled
                            && root.transactionMatchesSelection
                        onClicked:
                            CodeWorkflowTransaction.prepareDisconnectArtifacts()
                    }
                    RippleButtonWithIcon {
                        visible: CodeWorkflowTransaction.activeCommand?.kind
                            === "disconnect-binding"
                            && CodeWorkflowTransaction.disconnectArtifactsReady
                            && root.transactionMatchesSelection
                        materialIcon: "verified_user"
                        mainText: CodeWorkflowTransaction.disconnectAuthorizationReady
                            ? "Disconnect write authorized"
                            : "Authorize Disconnect write"
                        enabled: CodeWorkflowTransaction.disconnectAuthorizeEnabled
                            && root.transactionMatchesSelection
                        onClicked:
                            CodeWorkflowTransaction.authorizeDisconnectWrite()
                    }
                    RippleButtonWithIcon {
                        visible: CodeWorkflowTransaction.activeCommand?.kind
                            === "disconnect-binding"
                            && CodeWorkflowTransaction.disconnectAuthorizationReady
                            && !CodeWorkflowTransaction.disconnectLifecycleBusy
                            && root.transactionMatchesSelection
                        materialIcon: "link_off"
                        mainText: "Apply Disconnect"
                        enabled: CodeWorkflowTransaction.disconnectApplyEnabled
                            && root.transactionMatchesSelection
                        onClicked:
                            CodeWorkflowTransaction.beginAuthorizedDisconnectApply()
                    }
                    RippleButtonWithIcon {
                        visible: CodeWorkflowTransaction.activeCommand?.kind
                            === "disconnect-binding"
                            && CodeWorkflowTransaction.disconnectAuthorizationReady
                            && root.transactionMatchesSelection
                        materialIcon: "gpp_bad"
                        mainText: "Revoke Disconnect authorization"
                        enabled: !CodeWorkflowTransaction.disconnectLifecycleBusy
                        onClicked:
                            CodeWorkflowTransaction.revokeDisconnectAuthorization(
                                "user-revoked")
                    }
                    RippleButtonWithIcon {
                        visible: CodeWorkflowTransaction.activeCommand?.kind
                                === "literal-property"
                            && CodeWorkflowTransaction.preApplyReady
                            && !CodeWorkflowTransaction.applyArtifactsReady
                            && root.transactionMatchesSelection
                        materialIcon: "inventory_2"
                        mainText: "Prepare Apply"
                        enabled: CodeWorkflowTransaction.prepareApplyEnabled
                            && root.transactionMatchesSelection
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
                            && !CodeWorkflowTransaction.connectLifecycleBusy
                            && !CodeWorkflowTransaction.bindingPreparationBusy
                            && !CodeWorkflowTransaction.bindingLifecycleBusy
                            && !CodeWorkflowTransaction.disconnectPreparationBusy
                            && !CodeWorkflowTransaction.disconnectLifecycleBusy
                            && !CodeWorkflowTransaction.signalActionPreparationBusy
                            && !CodeWorkflowTransaction.signalActionLifecycleBusy
                            && !CodeWorkflowTransaction.bindingPreparationBusy
                            && !CodeWorkflowTransaction.bindingLifecycleBusy
                            && !CodeWorkflowTransaction.disconnectPreparationBusy
                            && !CodeWorkflowTransaction.disconnectLifecycleBusy
                            && (CodeWorkflowTransaction.activeCommand?.kind
                                    === "connect-binding"
                                || CodeWorkflowTransaction.activeCommand?.kind
                                        === "disconnect-binding"
                                || CodeWorkflowTransaction.activeCommand?.kind
                                        === "signal-action"
                                || CodeWorkflowAnalyzer.status === "ready")
                        onClicked: root.regenerateTransaction()
                    }
                    RippleButtonWithIcon {
                        materialIcon: "close"
                        mainText: "Clear"
                        enabled: CodeWorkflowTransaction.status !== "previewing"
                            && !CodeWorkflowTransaction.applyLifecycleBusy
                            && !CodeWorkflowTransaction.connectPreparationBusy
                            && !CodeWorkflowTransaction.connectLifecycleBusy
                            && !CodeWorkflowTransaction.bindingPreparationBusy
                            && !CodeWorkflowTransaction.bindingLifecycleBusy
                            && !CodeWorkflowTransaction.disconnectPreparationBusy
                            && !CodeWorkflowTransaction.disconnectLifecycleBusy
                            && !CodeWorkflowTransaction.signalActionPreparationBusy
                            && !CodeWorkflowTransaction.signalActionLifecycleBusy
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
                        ? "Authorization ACTIVE · bound to this exact prepared manifest/history command · Apply Connect may consume it once · automatic exact-snapshot rollback is qualified"
                        : "Authorization REQUIRED · deliberate authorization will bind only this exact prepared manifest/history command · any Clock/Config/history change expires it · Apply Connect stays disabled"
                    color: CodeWorkflowTransaction.connectAuthorizationReady
                        ? Appearance.colors.colPrimary
                        : Appearance.colors.colTertiary
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.weight: Font.Medium
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: CodeWorkflowTransaction.activeCommand?.kind
                            === "connect-binding"
                        && (CodeWorkflowTransaction.connectLifecycleBusy
                            || CodeWorkflowTransaction.connectLifecycleError
                                .length > 0
                            || Object.keys(
                                CodeWorkflowTransaction
                                    .connectLifecycleResult ?? {}
                            ).length > 0)
                    text: CodeWorkflowTransaction.connectLifecycleBusy
                        ? "Connect Apply lifecycle · "
                            + root.connectLifecyclePhaseText
                            + " · mutation/history/preparation controls are locked"
                        : CodeWorkflowTransaction.status === "connect-applied"
                            ? "Connect Apply complete · candidate verified and inserted semantic anchor rebound · authorization consumed · regenerate before another write"
                            : CodeWorkflowTransaction.status
                                    === "connect-rollback-complete"
                                ? "Connect Apply rolled back · exact base snapshot verified · "
                                    + String(
                                        CodeWorkflowTransaction
                                            .connectLifecycleError ?? "")
                                : "Connect Apply stopped · "
                                    + root.connectLifecyclePhaseText
                                    + " · "
                                    + String(
                                        CodeWorkflowTransaction
                                            .connectLifecycleError ?? "")
                    color: CodeWorkflowTransaction.status === "connect-applied"
                        ? Appearance.colors.colPrimary
                        : CodeWorkflowTransaction.connectLifecycleBusy
                            ? Appearance.colors.colTertiary
                            : Appearance.colors.colError
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
                    visible: CodeWorkflowTransaction.signalActionArtifactsReady
                    text: "Signal/Action artifacts prepared · exact rollback snapshot + candidate + manifest are stored in shell state · tracked Media.qml is unchanged"
                    color: Appearance.colors.colPrimary
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: CodeWorkflowTransaction.signalActionArtifactsReady
                    text: "Signal/Action identity · "
                        + String(
                            CodeWorkflowTransaction.activeCommand
                                ?.signalActionTargetId ?? "")
                        + " · "
                        + String(
                            CodeWorkflowTransaction.activeCommand
                                ?.handlerName ?? "")
                        + ": "
                        + String(
                            CodeWorkflowTransaction.activeCommand
                                ?.actionExpression ?? "")
                        + " · postcondition EXACT INSERTED HANDLER"
                    color: Appearance.colors.colOnLayer1
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: CodeWorkflowTransaction.signalActionArtifactsReady
                    text: "Signal/Action safety · exact parent + existing-action + inserted-handler semantic identity + exact candidate SHA + inserted-handler-rebound-exact-action · no TYPE/CYCLE proof is used for Signal/Action"
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: CodeWorkflowTransaction.signalActionArtifactsReady
                    text: CodeWorkflowTransaction.signalActionAuthorizationReady
                        ? "Signal/Action authorization ACTIVE · bound to this exact manifest SHA/history command · Apply Signal/Action may consume it once · exact-snapshot rollback is qualified"
                        : "Signal/Action authorization REQUIRED · source/history drift expires it · Apply Signal/Action stays disabled until explicit authorization"
                    color: CodeWorkflowTransaction.signalActionAuthorizationReady
                        ? Appearance.colors.colPrimary
                        : Appearance.colors.colTertiary
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.weight: Font.Medium
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: CodeWorkflowTransaction.activeCommand?.kind
                            === "signal-action"
                        && (CodeWorkflowTransaction.signalActionLifecycleBusy
                            || CodeWorkflowTransaction.signalActionLifecycleError
                                .length > 0
                            || Object.keys(
                                CodeWorkflowTransaction
                                    .signalActionLifecycleResult ?? {}
                            ).length > 0)
                    text: CodeWorkflowTransaction.signalActionLifecycleBusy
                        ? "Signal/Action Apply lifecycle · "
                            + root.signalActionLifecyclePhaseText
                            + " · mutation/history/preparation controls are locked"
                        : CodeWorkflowTransaction.status
                                === "signal-action-applied"
                            ? "Signal/Action Apply complete · candidate verified and exact inserted handler rebound to root.toggleExpanded() · authorization consumed · regenerate before another write"
                            : CodeWorkflowTransaction.status
                                    === "signal-action-rollback-complete"
                                ? "Signal/Action Apply rolled back · exact base snapshot verified · "
                                    + String(
                                        CodeWorkflowTransaction
                                            .signalActionLifecycleError ?? "")
                                : "Signal/Action Apply stopped · "
                                    + root.signalActionLifecyclePhaseText
                                    + " · "
                                    + String(
                                        CodeWorkflowTransaction
                                            .signalActionLifecycleError ?? "")
                    color: CodeWorkflowTransaction.status
                            === "signal-action-applied"
                        ? Appearance.colors.colPrimary
                        : CodeWorkflowTransaction.signalActionLifecycleBusy
                            ? Appearance.colors.colTertiary
                            : Appearance.colors.colError
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.weight: Font.Medium
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: CodeWorkflowTransaction.signalActionPreparationError
                        .length > 0
                    text: "Prepare Signal/Action artifacts: "
                        + CodeWorkflowTransaction.signalActionPreparationError
                    color: Appearance.colors.colError
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: CodeWorkflowTransaction.bindingArtifactsReady
                    text: "Binding artifacts prepared · exact rollback snapshot + replacement candidate + manifest are stored in shell state · tracked source QML is unchanged"
                    color: Appearance.colors.colPrimary
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: CodeWorkflowTransaction.bindingArtifactsReady
                    text: "Binding identity · "
                        + String(
                            CodeWorkflowTransaction.activeCommand
                                ?.reviewedReplacementId ?? "")
                        + " · text: "
                        + String(
                            CodeWorkflowTransaction.activeCommand
                                ?.expectedCurrent ?? "")
                        + " → "
                        + String(
                            CodeWorkflowTransaction.activeCommand
                                ?.replacement ?? "")
                        + " · postcondition SAME ANCHOR + EXACT EXPRESSION"
                    color: Appearance.colors.colOnLayer1
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: CodeWorkflowTransaction.bindingArtifactsReady
                    text: "Replacement safety · exact binding/property/old+new expression identity + exact candidate SHA + semantic-anchor-rebound-exact-expression · no TYPE/CYCLE proof is used for Binding replacement"
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: CodeWorkflowTransaction.bindingArtifactsReady
                    text: CodeWorkflowTransaction.bindingAuthorizationReady
                        ? "Binding authorization ACTIVE · bound to this exact manifest SHA/history command · Apply Binding replacement may consume it once · exact-snapshot rollback is qualified"
                        : "Binding authorization REQUIRED · source/history drift expires it · Apply Binding replacement stays disabled until explicit authorization"
                    color: CodeWorkflowTransaction.bindingAuthorizationReady
                        ? Appearance.colors.colPrimary
                        : Appearance.colors.colTertiary
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.weight: Font.Medium
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: CodeWorkflowTransaction.activeCommand?.kind
                            === "direct-binding"
                        && (CodeWorkflowTransaction.bindingLifecycleBusy
                            || CodeWorkflowTransaction.bindingLifecycleError
                                .length > 0
                            || Object.keys(
                                CodeWorkflowTransaction
                                    .bindingLifecycleResult ?? {}
                            ).length > 0)
                    text: CodeWorkflowTransaction.bindingLifecycleBusy
                        ? "Binding Apply lifecycle · "
                            + root.bindingLifecyclePhaseText
                            + " · mutation/history/preparation controls are locked"
                        : CodeWorkflowTransaction.status === "binding-applied"
                            ? "Binding Apply complete · candidate verified and same semantic anchor rebound to exact DateTime.date · authorization consumed · regenerate before another write"
                            : CodeWorkflowTransaction.status
                                    === "binding-rollback-complete"
                                ? "Binding Apply rolled back · exact base snapshot verified · "
                                    + String(
                                        CodeWorkflowTransaction
                                            .bindingLifecycleError ?? "")
                                : "Binding Apply stopped · "
                                    + root.bindingLifecyclePhaseText
                                    + " · "
                                    + String(
                                        CodeWorkflowTransaction
                                            .bindingLifecycleError ?? "")
                    color: CodeWorkflowTransaction.status
                            === "binding-applied"
                        ? Appearance.colors.colPrimary
                        : CodeWorkflowTransaction.bindingLifecycleBusy
                            ? Appearance.colors.colTertiary
                            : Appearance.colors.colError
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.weight: Font.Medium
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: CodeWorkflowTransaction.bindingPreparationError
                        .length > 0
                    text: "Prepare Binding artifacts: "
                        + CodeWorkflowTransaction.bindingPreparationError
                    color: Appearance.colors.colError
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: CodeWorkflowTransaction.disconnectArtifactsReady
                    text: "Disconnect artifacts prepared · exact rollback snapshot + deletion candidate + manifest are stored in shell state · tracked source QML is unchanged"
                    color: Appearance.colors.colPrimary
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: CodeWorkflowTransaction.disconnectArtifactsReady
                    text: "Disconnect identity · "
                        + String(
                            CodeWorkflowTransaction.activeCommand
                                ?.reviewedEdgeId ?? "")
                        + " · text ← "
                        + String(
                            CodeWorkflowTransaction.activeCommand
                                ?.expectedCurrent ?? "")
                        + " · postcondition OLD ANCHOR MISSING"
                    color: Appearance.colors.colOnLayer1
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: CodeWorkflowTransaction.disconnectArtifactsReady
                    text: "Deletion safety · exact binding/property/expression identity + exact candidate SHA + semantic-anchor-missing · no TYPE/CYCLE proof is used for Disconnect"
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: CodeWorkflowTransaction.disconnectArtifactsReady
                    text: CodeWorkflowTransaction.disconnectAuthorizationReady
                        ? "Disconnect authorization ACTIVE · bound to this exact manifest SHA/history command · Apply Disconnect may consume it once · exact-snapshot rollback is qualified"
                        : "Disconnect authorization REQUIRED · source/history drift expires it · Apply Disconnect stays disabled until explicit authorization"
                    color: CodeWorkflowTransaction.disconnectAuthorizationReady
                        ? Appearance.colors.colPrimary
                        : Appearance.colors.colTertiary
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.weight: Font.Medium
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: CodeWorkflowTransaction.activeCommand?.kind
                            === "disconnect-binding"
                        && (CodeWorkflowTransaction.disconnectLifecycleBusy
                            || CodeWorkflowTransaction.disconnectLifecycleError
                                .length > 0
                            || Object.keys(
                                CodeWorkflowTransaction
                                    .disconnectLifecycleResult ?? {}
                            ).length > 0)
                    text: CodeWorkflowTransaction.disconnectLifecycleBusy
                        ? "Disconnect Apply lifecycle · "
                            + root.disconnectLifecyclePhaseText
                            + " · mutation/history/preparation controls are locked"
                        : CodeWorkflowTransaction.status === "disconnect-applied"
                            ? "Disconnect Apply complete · candidate verified and old semantic anchor is absent · authorization consumed · regenerate before another write"
                            : CodeWorkflowTransaction.status
                                    === "disconnect-rollback-complete"
                                ? "Disconnect Apply rolled back · exact base snapshot verified · "
                                    + String(
                                        CodeWorkflowTransaction
                                            .disconnectLifecycleError ?? "")
                                : "Disconnect Apply stopped · "
                                    + root.disconnectLifecyclePhaseText
                                    + " · "
                                    + String(
                                        CodeWorkflowTransaction
                                            .disconnectLifecycleError ?? "")
                    color: CodeWorkflowTransaction.status
                            === "disconnect-applied"
                        ? Appearance.colors.colPrimary
                        : CodeWorkflowTransaction.disconnectLifecycleBusy
                            ? Appearance.colors.colTertiary
                            : Appearance.colors.colError
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.weight: Font.Medium
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: CodeWorkflowTransaction.disconnectPreparationError
                        .length > 0
                    text: "Prepare Disconnect artifacts: "
                        + CodeWorkflowTransaction.disconnectPreparationError
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
            }

            Rectangle {
                id: sourcePane
                SplitView.preferredHeight: CodeWorkflowSession.sourcePreviewHeight
                SplitView.minimumHeight: 120
                SplitView.maximumHeight: 420
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
                        text: root.sourceEditorUseNvim
                            ? "Neovim · " + root.sourceEditorNvimDisplayPath
                            : "Source Editor · " + root.sourcePath
                        color: Appearance.colors.colOnLayer1
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                        elide: Text.ElideMiddle
                    }
                    Pill {
                        label: root.sourceEditorUseNvim
                            ? (root.embeddedNvimBufferModified
                                ? "NVIM · MODIFIED"
                                : "NVIM · " + root.embeddedNvimMode.toUpperCase())
                            : root.sourceEditorConflict
                                ? "CONFLICT"
                                : root.sourceEditorSaving
                                    ? "SAVING"
                                    : root.sourceEditorDirty
                                        ? "MODIFIED" : "SYNCED"
                        accent: root.sourceEditorUseNvim
                            ? (root.embeddedNvimBufferModified
                                ? Appearance.colors.colTertiary
                                : Appearance.colors.colPrimary)
                            : root.sourceEditorConflict
                                ? Appearance.colors.colError
                                : root.sourceEditorDirty
                                    ? Appearance.colors.colTertiary
                                    : Appearance.colors.colPrimary
                    }
                    RippleButtonWithIcon {
                        buttonText: root.sourceEditorUseNvim
                            ? "Use inline source editor"
                            : "Use embedded Neovim"
                        mainText: ""
                        materialIcon: root.sourceEditorUseNvim
                            ? "edit_note" : "terminal"
                        enabled: root.sourcePath.length > 0
                            && !root.sourceEditorDirty
                            && !root.sourceEditorConflict
                            && !root.sourceEditorSaving
                            && !CodeWorkflowTransaction.dirty
                        onClicked: {
                            root.sourceEditorUseNvim =
                                !root.sourceEditorUseNvim
                            if (root.sourceEditorUseNvim)
                                Qt.callLater(root.syncEmbeddedNvimView)
                        }
                        StyledToolTip {
                            text: root.sourceEditorUseNvim
                                ? "Return to the inline guarded editor"
                                : CodeWorkflowTransaction.dirty
                                    ? "Finish or discard the active Code Workflow transaction first"
                                    : root.sourceEditorDirty
                                        ? "Save or revert the inline draft before starting Neovim"
                                        : "Run Neovim --embed inside Source Editor"
                        }
                    }
                    RippleButtonWithIcon {
                        buttonText: "Revert source editor"
                        visible: !root.sourceEditorUseNvim
                        mainText: ""
                        materialIcon: "restart_alt"
                        enabled: (root.sourceEditorDirty
                                || root.sourceEditorConflict)
                            && !root.sourceEditorSaving
                        onClicked: root.revertSourceEditor()
                        StyledToolTip { text: "Discard draft and reload from disk" }
                    }
                    RippleButtonWithIcon {
                        buttonText: root.sourceEditorUseNvim
                            ? "Save Neovim buffer"
                            : "Save source editor"
                        mainText: ""
                        materialIcon: "save"
                        enabled: root.sourceEditorUseNvim
                            ? root.embeddedNvimReady
                                && root.embeddedNvimBufferModified
                            : root.sourceEditorCanSave
                        onClicked: {
                            if (root.sourceEditorUseNvim)
                                root.saveEmbeddedNvim()
                            else
                                root.saveSourceEditor()
                        }
                        StyledToolTip {
                            text: root.sourceEditorUseNvim
                                ? "Write the active Neovim buffer"
                                : CodeWorkflowTransaction.dirty
                                    ? "Finish or discard the active Code Workflow transaction first"
                                    : root.sourceEditorConflict
                                        ? "Reload or reconcile the external change before saving"
                                        : "Save source · Ctrl+S"
                        }
                    }
                    RippleButtonWithIcon {
                        buttonText: "Open source in Neovim"
                        mainText: ""
                        materialIcon: "terminal"
                        enabled: root.sourcePath.length > 0
                        onClicked: root.openSourceInNeovim()
                        StyledToolTip { text: "Open this source in Neovim" }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: !root.sourceEditorUseNvim
                        && root.sourceEditorStatus.length > 0
                    text: root.sourceEditorStatus
                    color: root.sourceEditorConflict
                        || root.sourceEditorStatus.startsWith("Save failed")
                        || root.sourceEditorStatus.includes("failed")
                            ? Appearance.colors.colError
                            : Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colLayer0
                    clip: true

                    Loader {
                        id: embeddedNvimLoader
                        anchors.fill: parent
                        active: root.sourceEditorUseNvim
                        visible: active
                        source: active ? "CodeWorkflowNvimView.qml" : ""
                        asynchronous: true

                        onLoaded: Qt.callLater(root.syncEmbeddedNvimView)

                        onStatusChanged: {
                            if (status !== Loader.Error)
                                return
                            root.sourceEditorUseNvim = false
                            root.sourceEditorStatus =
                                "Embedded Neovim failed to load · using inline editor"
                        }
                    }

                    Flickable {
                        id: sourcePreviewFlick
                        visible: !root.sourceEditorUseNvim
                        anchors.fill: parent
                        anchors.margins: 7
                        contentWidth: Math.max(width, sourcePreviewText.implicitWidth)
                        contentHeight: Math.max(height, sourcePreviewText.implicitHeight)
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        TextEdit {
                            id: sourcePreviewText
                            width: Math.max(parent.width, implicitWidth)
                            text: root.sourceDraft
                            readOnly: false
                            selectByMouse: true
                            activeFocusOnTab: true
                            Accessible.name: "Source editor"
                            Accessible.description:
                                "Editable source draft for the current inspect selection"
                            onTextChanged: {
                                if (root.sourceDraft !== text) {
                                    root.sourceDraft = text
                                    if (!root.sourceEditorSaving
                                            && !root.sourceEditorConflict)
                                        root.sourceEditorStatus = ""
                                }
                            }
                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_S
                                        && (event.modifiers
                                            & Qt.ControlModifier)) {
                                    root.saveSourceEditor()
                                    event.accepted = true
                                }
                            }
                            wrapMode: TextEdit.NoWrap
                            renderType: Text.QtRendering
                            color: Appearance.colors.colOnLayer1
                            selectionColor: Appearance.colors.colPrimaryContainer
                            selectedTextColor: Appearance.colors.colOnPrimaryContainer
                            font.family: Appearance.font.family.monospace
                            font.pixelSize: Appearance.font.pixelSize.small
                        }

                        Loader {
                            id: sourceSyntaxLoader
                            active: !root.sourceEditorUseNvim
                            source: active
                                ? "CodeWorkflowSyntaxHighlighter.qml" : ""
                            asynchronous: true
                            visible: false

                            onLoaded:
                                Qt.callLater(root.syncSourceSyntaxHighlighter)

                            onStatusChanged: {
                                if (status !== Loader.Error)
                                    return
                                root.sourceEditorStatus =
                                    "Syntax highlighting unavailable · plain editor active"
                            }
                        }
                    }
                }
            }
            }

            onResizingChanged: {
                if (!resizing && sourcePane.visible)
                    CodeWorkflowSession.sourcePreviewHeight = sourcePane.height
            }
        }
    }
}
