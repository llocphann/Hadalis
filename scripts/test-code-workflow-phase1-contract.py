#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def read(path):
    return (ROOT / path).read_text(encoding="utf-8")

def require(text, token, message):
    if token not in text:
        raise SystemExit("FAIL: " + message)

registry = read("modules/settings/SettingsPageRegistryData.qml")
arrangement = read("modules/settings/SettingsArrangement.qml")
persistent = read("modules/common/Persistent.qml")
qmldir = read("services/qmldir")
page = read("modules/settings/CodeWorkflow.qml")
canvas = read("modules/settings/CodeWorkflowIrCanvas.qml")
runtime = read("services/CodeWorkflowRuntime.qml")
target = read("services/CodeWorkflowRuntimeTarget.qml")
session = read("services/CodeWorkflowSession.qml")
ripple_button = read("modules/common/widgets/RippleButton.qml")
ir = json.loads(read("defaults/code-workflow-ir.json"))

require(registry, 'key: "code-workflow"', "registry missing Code Workflow")
require(registry, 'pages: [30, 9, 13]', "Reference ordering must be Code Workflow, Shortcuts, About")
require(arrangement, "layoutSchemaVersion: 6", "saved layouts need v6 migration")
require(arrangement, "codeWorkflowPageIndex: 30", "Code Workflow must keep appended index 30")

for token in ("codeWorkflowTargetId", "codeWorkflowInstanceId", "codeWorkflowOutputName",
              "codeWorkflowPanX", "codeWorkflowPanY", "codeWorkflowZoom"):
    require(persistent, token, "missing primitive workspace state " + token)

for token in ("singleton CodeWorkflowRuntime 1.0 CodeWorkflowRuntime.qml",
              "singleton CodeWorkflowSession 1.0 CodeWorkflowSession.qml",
              "CodeWorkflowRuntimeTarget 1.0 CodeWorkflowRuntimeTarget.qml"):
    require(qmldir, token, "services/qmldir missing " + token)

for token in ('targetId: "bar"', 'targetId: "bar/media"',
              'targetId: "bar/clock"', 'targetId: "bar/resources"'):
    require(runtime, token, "runtime catalog missing " + token)

require(target, "horizontal ii Bar", "runtime geometry scope must remain explicit")
require(target, "Explicit allowlist", "runtime values must stay allowlisted")
require(session, "import Quickshell", "Singleton session must import Quickshell for staged-runtime startup")
require(session, "Persistent.states", "session must survive Settings page eviction")
require(session, "const changedSubflow = root.subflowTargetId !== targetId",
        "reselecting the current runtime target must preserve graph viewport")
require(session, "if (changedSubflow)\n                root.resetViewport()",
        "viewport reset must occur only when runtime selection changes subflow")
require(session, "readonly property real minimumZoom: 0.20",
        "session must allow low enough overview zoom for Fit graph")
require(session, "readonly property real maximumZoom: 2.5",
        "session must centralize the graph zoom ceiling")
require(canvas, "CodeWorkflowSession.minimumZoom",
        "canvas fit/wheel/pinch must share the session zoom floor")
require(canvas, "CodeWorkflowSession.maximumZoom",
        "canvas manual zoom must share the session zoom ceiling")
if "Math.max(0.35" in session or "Math.max(0.35" in canvas:
    raise SystemExit("FAIL: Code Workflow must not reintroduce the old 0.35 zoom floor")
require(page, "CodeWorkflowIrCanvas {", "page must host the semantic IR canvas")
require(page, "property string inspectedSemanticAnchor:", "inspect mode must track parsed QML element selection")
require(page, "CodeWorkflowAnalyzer.result?.entries", "inspect mode must expose parser semantic entries")
require(page, "model: root.inspectTargets", "Targets must include runtime, graph and parsed QML elements")
require(page, "Appearance.colors.colOnPrimaryContainer", "selected inspect targets need contrast-safe foreground")
require(page, "readonly property bool compactHeader:",
        "Code Workflow header must expose a narrow-layout mode")
require(page, "mainText: root.compactHeader",
        "toolbar buttons must collapse to icon-only in compact mode")
require(ripple_button,
        "Accessible.name: root.buttonText.length > 0 ? root.buttonText : root.text",
        "compact icon buttons must derive accessibility names from buttonText")
require(page, 'buttonText: "Fit graph"',
        "compact graph control must retain an accessibility label")
require(page, 'buttonText: "Back to Bar workflow"',
        "compact subflow navigation must retain an accessibility label")
require(page, 'text: "Fit graph to viewport"',
        "compact graph controls must retain discoverable tooltips")
require(page, "StyledFlickable {", "Inspector must scroll instead of overflowing its panel")
require(page, "contentHeight: inspectorColumn.implicitHeight + 12", "Inspector scroll extent must follow content")
require(page, "inspectedSemanticRangeText", "parsed QML targets must expose source range evidence")
require(session, 'property string selectedSemanticAnchor: ""',
        "semantic inspect selection must live in the session singleton")
require(session, "function selectSemantic(anchor: string): bool",
        "session must own semantic inspect selection")
require(page, "CodeWorkflowSession.selectedSemanticAnchor",
        "page must consume the shared semantic selection")
require(page, 'placeholderText: "Filter targets"',
        "Targets must expose a search/filter control")
require(page, 'category: "section"',
        "Targets must group runtime, graph and parsed QML sources")
require(page, "appendSection(",
        "Targets must preserve source grouping after filtering")
require(page, 'category: "edge"',
        "Targets must expose graph connections as first-class inspect rows")
require(page, '"edges", "Connections", "conversion_path", "edges", edgeItems',
        "Targets must group graph connections separately from nodes")
require(page, 'if (category === "edge")',
        "Target activation must route connection rows through session selection")
require(page, "function onSelectedEdgeIdChanged(): void",
        "Targets must reveal graph-driven edge selection")
require(page, 'category: "connect"',
        "Targets must expose reviewed connect candidates as inspect rows")
require(page, '"connect", "Connect candidates", "add_link"',
        "Targets must group connect candidates separately from graph edges")
require(page, 'if (category === "connect")',
        "Target activation must route connect candidates through session selection")
require(page, "function onSelectedConnectTargetIdChanged(): void",
        "Targets must reveal selected connect candidates")
require(page, "root.selectedConnectTarget !== null",
        "Inspector header must prioritize selected connect candidates")
require(page, "enabled: !targetRow.section",
        "Target section headers must be non-interactive")
require(page, "function activateRow(): void",
        "Target rows must expose one activation path for pointer, keyboard and AT")
require(page, "activeFocusOnTab: !section",
        "Inspect targets must be keyboard-focusable while headers stay static")
require(page, "Accessible.focusable: !section",
        "Inspect targets must expose focusability to assistive technology")
require(page, "Keys.onPressed: event =>",
        "Inspect targets must support Enter/Space activation")
require(page, '"No targets match the current filter"',
        "Targets filter must expose an explicit empty state")
require(page, "property bool inspectShowInternals: false",
        "Targets must use progressive disclosure for parser internals")
require(page, "function semanticEntryVisible(entry, discloseInternals: bool): bool",
        "Targets must suppress anonymous parser noise by default")
require(page, '"pragma", "opaque"',
        "Show internals/search must expose parser-known unsupported entries")
require(page, "function semanticEntryDepth(entry): int",
        "Targets must derive parser hierarchy depth")
require(page, "function textIndexForUtf8ByteOffset(byteOffset: int): int",
        "Source Preview must map parser byte ranges to text positions")
require(page, "function revealSourceSelection(start: int, end: int): void",
        "Source Preview must reveal selected parser evidence")
require(page, "const safeStart = Math.min(start, root.sourceText.length)",
        "Source Preview must clamp parser ranges before selection")
if "sourcePreviewText.cursorPosition = start" in page:
    raise SystemExit("FAIL: Source Preview must not collapse selected evidence range")
require(page, "function revealSelectedInspectTarget(): void",
        "Targets must reveal the unified selected item")
require(page, "function reconcileSemanticInspectSelection(): void",
        "semantic inspect selection must clear after parser anchor drift")
require(page, "function prepareSelectedSemanticInspectTarget(): void",
        "restored semantic selection must become revealable after analyzer readiness")
require(page, "root.prepareSelectedSemanticInspectTarget()",
        "semantic selection and analyzer readiness must prepare Targets disclosure")
require(page, "Qt.callLater(root.reconcileSemanticInspectSelection)",
        "analyzer READY must reconcile semantic inspect selection")
require(page, 'CodeWorkflowAnalyzer.status === "unavailable"',
        "parser unavailability must drop stale semantic inspect selection")
require(page, 'CodeWorkflowAnalyzer.status === "error"',
        "parser error must drop stale semantic inspect selection")
require(page, 'CodeWorkflowSession.selectSemantic("")',
        "parser failure must restore graph-level inspect context")
require(page, "target: CodeWorkflowSession",
        "Targets must react to shared session selection changes")
require(page, "targetList.positionViewAtIndex(index, ListView.Contain)",
        "Targets must scroll the selected item into view")
require(page, "const targetGraph = CodeWorkflowIr.graphFor(id)",
        "runtime target selection must resolve its graph root explicitly")
require(page, "const runtimeOwnsRoot = id === rootNodeId",
        "graph root and runtime row must not both claim primary selection")
require(page, "&& !runtimeOwnsRoot",
        "child graph selection must remain uniquely revealable in Targets")
require(page, 'mainText: "Fit graph"',
        "graph fit control must describe its actual behavior")
require(page, "onClicked: canvas.fitGraph()",
        "Fit graph control must use actual graph extents")
require(canvas, "function onSubflowTargetIdChanged(): void",
        "subflow navigation must refit the graph")
require(page, "ColorUtils.readableAccentInk(",
        "Code Workflow chips must derive readable foreground ink")
require(page, '"UNLOADED · STATIC SOURCE"',
        "Inspector must distinguish unloaded runtime from live residency")
require(page, "readonly property bool selectedLive:",
        "Header runtime badge must reflect the selected target")
require(page, '" · " + CodeWorkflowAnalyzer.error',
        "Inspector must expose parser unavailability/error reason")
read_only_binding_edges = []
for graph_id, graph in (ir.get("graphs") or {}).items():
    nodes = {node.get("id"): node for node in (graph.get("nodes") or [])}
    for edge in graph.get("edges") or []:
        target_node = nodes.get(edge.get("to")) or {}
        if target_node.get("kind") == "binding" and edge.get("previewable") is not True:
            read_only_binding_edges.append((graph_id, edge.get("id")))
if not read_only_binding_edges:
    raise SystemExit(
        "FAIL: fixture must cover read-only edges targeting binding nodes")

require(page, "readonly property bool directMutationSelectionEligible:",
        "read-only edge inspection must gate destination-node edits")
require(page, "root.selectedIrEdge === null",
        "direct node edits must remain available when no edge is selected")
require(page, "root.selectedIrEdge?.previewable === true",
        "only reviewed previewable edges may expose edge mutation controls")
require(page, "readonly property bool selectedEdgeReadOnly:",
        "Inspector must distinguish read-only edge inspection")
require(page, "return root.directMutationSelectionEligible",
        "direct-binding transaction matching must honor the inspect mutation gate")
require(page, 'String(command.kind ?? "") !== "literal-property"',
        "transaction matching must reject unknown/non-literal fallback commands")
require(page, "return root.selectedIrEdge === null",
        "literal transaction controls must not follow edge inspection")
require(page, '=== "literal-property"\n                            && CodeWorkflowTransaction.preApplyReady',
        "generic Prepare Apply must stay scoped to literal-property transactions")
require(page, "&& root.transactionMatchesSelection",
        "transaction mutation controls must remain selection-bound")
require(page, "readonly property bool transactionSelectionMismatch:",
        "transaction panel must detect when preview belongs to another selection")
require(page, '"OTHER SELECTION"',
        "transaction panel must label selection mismatch explicitly")
require(page, '"Preview belongs to another inspect selection. "',
        "transaction panel must explain how to resume guarded controls")
require(page, "Math.max(118, transactionColumn.implicitHeight + 16)",
        "transaction panel height must follow visible content")
require(page, "id: transactionScroll",
        "transaction panel must scroll instead of clipping long evidence")
require(page, "contentHeight: transactionColumn.implicitHeight + 8",
        "transaction scroll extent must follow transaction content")
require(page, "transactionScroll.contentY = 0",
        "transaction history navigation must reveal the next command from the top")
require(page, "Math.min(\n                    420,",
        "transaction panel must cap growth before scrolling")
require(page, "root.selectedIrEdge !== null",
        "Inspector header must treat selected edges as primary inspect objects")
require(page, "?? root.selectedIrEdge?.kind",
        "Inspector kind pill must follow edge selection")
require(page, '" · READ ONLY"',
        "Inspector must label mutation-ineligible edges explicitly")
require(page, "visible: root.selectedIrEdge?.previewable === true",
        "Disconnect affordance must stay gated to reviewed previewable edges")
require(canvas, "CodeWorkflowSession.selectedSemanticAnchor.length === 0",
        "graph highlight must yield to finer semantic selection")
require(canvas, "CodeWorkflowSession.selectedEdgeId.length === 0",
        "node/incident highlight must yield to selected edge inspection")
require(canvas, "id: subflowAction",
        "graph subflow drill-down must expose a dedicated interactive target")
require(canvas, "activeFocusOnTab: parent.visible",
        "graph subflow drill-down must be keyboard-focusable")
require(canvas, 'Accessible.name: "Open "',
        "graph subflow drill-down must expose an accessibility label")
require(canvas, "preferredRendererType: Shape.GeometryRenderer", "IR canvas must use qualified Geometry renderer")
require(page, "readOnly: true", "Source Preview must be read-only")
require(page, "FileView {", "Source Preview must read selected source")
require(page, "contentHeight: Math.max(height, sourcePreviewText.implicitHeight)",
        "Source Preview scroll extent must follow its TextEdit")
if page.count("function stateLabel(item): string {") != 1:
    raise SystemExit("FAIL: Code Workflow page has duplicate stateLabel declarations")
if "setText(" in page or "setText(" in canvas:
    raise SystemExit("FAIL: read-only Phase 1 UI must not write source")

hooks = {
    "modules/bar/BarContent.qml": 'targetId: "bar"',
    "modules/bar/Media.qml": 'targetId: "bar/media"',
    "modules/bar/ClockWidget.qml": 'targetId: "bar/clock"',
    "modules/bar/Resources.qml": 'targetId: "bar/resources"',
}
for path, target_id in hooks.items():
    source = read(path)
    require(source, "CodeWorkflowRuntimeTarget {", path + " missing runtime registration")
    require(source, target_id, path + " has wrong semantic target ID")

print("ok - Code Workflow Phase 1 production foundation contract")
