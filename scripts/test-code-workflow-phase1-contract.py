#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def read(path):
    return (ROOT / path).read_text(encoding="utf-8")

def require(text, token, message):
    if token not in text:
        raise SystemExit("FAIL: " + message)

def utf16_index_for_utf8_byte_offset(text, byte_offset):
    target = max(0, int(byte_offset))
    consumed = 0
    utf16_index = 0
    for char in text:
        if consumed >= target:
            break
        consumed += len(char.encode("utf-8"))
        utf16_index += 2 if ord(char) > 0xFFFF else 1
    return utf16_index

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
capture_script = read("scripts/capture-code-workflow-ui.sh")
ir = json.loads(read("defaults/code-workflow-ir.json"))

require(registry, 'key: "code-workflow"', "registry missing Code Workflow")
require(registry, 'pages: [30, 9, 13]', "Reference ordering must be Code Workflow, Shortcuts, About")
require(arrangement, "layoutSchemaVersion: 6", "saved layouts need v6 migration")
require(arrangement, "codeWorkflowPageIndex: 30", "Code Workflow must keep appended index 30")

for token in ("codeWorkflowTargetId", "codeWorkflowInstanceId", "codeWorkflowOutputName",
              "codeWorkflowPanX", "codeWorkflowPanY", "codeWorkflowZoom",
              "codeWorkflowTargetsPaneWidth", "codeWorkflowInspectorPaneWidth",
              "codeWorkflowSourcePreviewHeight"):
    require(persistent, token, "missing primitive workspace state " + token)

for token in ("singleton CodeWorkflowRuntime 1.0 CodeWorkflowRuntime.qml",
              "singleton CodeWorkflowSession 1.0 CodeWorkflowSession.qml",
              "CodeWorkflowRuntimeTarget 1.0 CodeWorkflowRuntimeTarget.qml"):
    require(qmldir, token, "services/qmldir missing " + token)

for token in ('targetId: "bar"', 'targetId: "bar/media"',
              'targetId: "bar/clock"', 'targetId: "bar/resources"'):
    require(runtime, token, "runtime catalog missing " + token)

require(page, 'Quickshell.env("QS_CODE_WORKFLOW_CAPTURE") === "1"',
        "capture harness must be opt-in through an explicit environment gate")
require(page, "active: root.captureHarnessEnabled",
        "capture IPC must not load outside capture mode")
require(page, 'target: "codeWorkflowCapture"',
        "capture mode must expose one dedicated standalone Settings IPC target")
require(page, "function captureHarnessBegin(): string",
        "capture harness must snapshot pre-capture session state")
require(page, "function captureHarnessRestore(): string",
        "capture harness must restore pre-capture session state")
for scenario in (
    "overview",
    "filter-input",
    "filter-sidebar",
    "edge-detour",
    "edge-readonly-binding",
    "connect-candidate",
    "pane-resize",
    "viewport-boundary",
    "semantic-source",
):
    require(page, f'scenario === "{scenario}"',
            "capture harness missing scenario " + scenario)

capture_start = page.index("function captureHarnessStatus(): var")
capture_end = page.index("readonly property var selectedIrNode:", capture_start)
capture_block = page[capture_start:capture_end]
for forbidden in (
    "CodeWorkflowTransaction.",
    "previewLiteral(",
    "previewBinding(",
    "beginAuthorized",
    "prepareApplyArtifacts(",
):
    if forbidden in capture_block:
        raise SystemExit(
            "FAIL: capture harness must remain read-only; found " + forbidden
        )

for token in (
    'QS_SETTINGS_PAGE=30',
    'QS_CODE_WORKFLOW_CAPTURE=1',
    'niri msg action focus-window --id "$WINDOW_ID"',
    'niri msg action fullscreen-window --id "$WINDOW_ID"',
    'grim -o "$OUTPUT_NAME" "$png_file"',
    'ipc restore >"$BUNDLE_DIR/state/99-restored.txt"',
    'capture_step "05" "edge-detour" "edge-detour"',
    'capture_step "06" "edge-readonly-binding" "edge-readonly-binding"',
    'capture_step "07" "connect-candidate" "connect-candidate"',
    'capture_step "08" "pane-resize" "pane-resize"',
    'capture_step "09" "viewport-boundary" "viewport-boundary"',
    'capture_step "10" "semantic-source"',
    'tar -C "$OUT_PARENT" -czf "$ARCHIVE" "$BUNDLE_NAME"',
):
    require(capture_script, token,
            "Code Workflow capture runner missing contract token: " + token)

require(capture_script, '"$WTYPE_BIN" "sidebar"',
        "capture runner must exercise the real target filter input path when wtype is available")
require(capture_script, "for cmd in jq niri grim tar git sha256sum python3; do",
        "capture runner must preflight Python before generating runtime diagnostics")
require(capture_script, 'meta/parser-capability.json',
        "capture runner must record parser capability for semantic-source review")
require(capture_script, 'meta/code-workflow-runtime-warnings.txt',
        "capture runner must summarize Code Workflow runtime warnings")
require(capture_script, '"actualTargetsPaneWidth": latest.get("actualTargetsPaneWidth")',
        "capture diagnostics must distinguish requested and actual Targets width")
require(capture_script, '"actualInspectorPaneWidth": latest.get("actualInspectorPaneWidth")',
        "capture diagnostics must distinguish requested and actual Inspector width")
require(capture_script, '"actualSourcePreviewHeight": latest.get("actualSourcePreviewHeight")',
        "capture diagnostics must distinguish requested and actual Source Preview height")
require(capture_script, '"Cannot assign to non-existent property" in line',
        "capture warning summary must catch typed Persistent schema failures")
require(capture_script, 'meta/route-diagnostics.json',
        "capture runner must summarize smart-route metrics for every screenshot state")
require(capture_script, '"routeDiagnostics": latest.get("routeDiagnostics", {})',
        "capture route summary must preserve renderer diagnostics")
for token in (
    '"canvasWidth": latest.get("canvasWidth")',
    '"canvasHeight": latest.get("canvasHeight")',
    '"panX": latest.get("panX")',
    '"panY": latest.get("panY")',
):
    require(capture_script, token,
            "capture route summary missing viewport evidence " + token)
require(capture_script, 'settings_window_json >"$BUNDLE_DIR/meta/niri-settings-window.json"',
        "capture runner must retain only the selected Settings window geometry record")

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
canvas_root_start = canvas.index("Item {\n    id: root")
canvas_root_prefix = canvas[canvas_root_start:canvas_root_start + 320]
require(canvas_root_prefix, "clip: true",
        "graph canvas root must hard-clip transformed content to its viewport")
require(canvas, "function viewportContains(screenX: real, screenY: real): bool",
        "graph hit testing must expose an explicit viewport guard")
require(canvas, "if (!root.viewportContains(screenX, screenY))\n            return \"\"",
        "edge hit testing must reject pointer coordinates outside the canvas")
require(canvas, "function itemPointInsideViewport(",
        "transformed graph children must map pointer coordinates back to the canvas")
for token in (
    "edgeLabelHover.point.position.x",
    "eventPoint.position.x",
    "subflowAction,",
    "mouse.x, mouse.y",
):
    require(canvas, token,
            "graph child pointer containment missing token " + token)
if "Math.max(0.35" in session or "Math.max(0.35" in canvas:
    raise SystemExit("FAIL: Code Workflow must not reintroduce the old 0.35 zoom floor")
require(page, "CodeWorkflowIrCanvas {", "page must host the semantic IR canvas")
require(page, "property string inspectedSemanticAnchor:", "inspect mode must track parsed QML element selection")
require(page, "CodeWorkflowAnalyzer.result?.entries", "inspect mode must expose parser semantic entries")
require(page, "model: root.inspectTargets", "Targets must include runtime, graph and parsed QML elements")
require(page, "Appearance.colors.colOnPrimaryContainer", "selected inspect targets need contrast-safe foreground")
require(page, "id: pill",
        "inline Pill must own a local id for tooltip/hover bindings")
require(page, "target: pill",
        "Pill hover handler must bind to the inline Pill, not the page root")
require(page, "text: pill.label",
        "Pill tooltip must read the inline Pill label without undefined QString warnings")
require(page, "readonly property bool hovered: pillHover.hovered",
        "elided status pills must expose a stable hover surface")
require(page, "id: pillHover",
        "status pills must reveal full labels through hover")
require(page, "text: root.label",
        "status pill tooltip must use the complete unelided label")
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
require(page, "import QtQuick.Controls",
        "resizable Code Workflow panes must use Qt Quick Controls SplitView")
require(page, "component WorkflowSplitHandle: Rectangle",
        "Code Workflow must expose a visible edge resize handle")
require(page, "containmentMask: Item {",
        "pane divider must provide a larger invisible drag target")
require(page, "width: splitHandle.horizontalRule\n                ? splitHandle.width : 18",
        "vertical pane divider must expose an 18px edge hit target")
require(page, "height: splitHandle.horizontalRule\n                ? 18 : splitHandle.height",
        "horizontal pane divider must expose an 18px edge hit target")
require(page, "Qt.SizeVerCursor : Qt.SizeHorCursor",
        "pane divider hover must advertise the correct resize cursor")
require(page, "routeDiagnostics: canvas.routeDiagnostics()",
        "capture status must expose route quality metrics")
for token in (
    "canvasWidth: canvas.width",
    "canvasHeight: canvas.height",
    "actualTargetsPaneWidth: targetsPane.width",
    "actualInspectorPaneWidth: inspectorPane.width",
    "actualSourcePreviewHeight: sourcePane.visible",
):
    require(page, token, "capture status missing canvas/split geometry " + token)
require(page, "id: workflowHorizontalSplit",
        "Targets, graph and Inspector must share a horizontal SplitView")
require(page, "id: workflowVerticalSplit",
        "graph workspace and Source Preview must share a vertical SplitView")
require(page, "SplitView.preferredWidth: CodeWorkflowSession.targetsPaneWidth",
        "Targets width must restore from session state")
require(page, "SplitView.preferredWidth: CodeWorkflowSession.inspectorPaneWidth",
        "Inspector width must restore from session state")
require(page, "SplitView.preferredHeight: CodeWorkflowSession.sourcePreviewHeight",
        "Source Preview height must restore from session state")
for token in (
    'property real codeWorkflowTargetsPaneWidth: 224',
    'property real codeWorkflowInspectorPaneWidth: 280',
    'property real codeWorkflowSourcePreviewHeight: 190',
):
    require(persistent, token,
            "Persistent.settings missing resizable pane schema " + token)

for token in (
    'property real targetsPaneWidth: 224',
    'property real inspectorPaneWidth: 280',
    'property real sourcePreviewHeight: 190',
    'state.codeWorkflowTargetsPaneWidth = root.targetsPaneWidth',
    'state.codeWorkflowInspectorPaneWidth = root.inspectorPaneWidth',
    'state.codeWorkflowSourcePreviewHeight = root.sourcePreviewHeight',
    'onTargetsPaneWidthChanged: root.persist()',
    'onInspectorPaneWidthChanged: root.persist()',
    'onSourcePreviewHeightChanged: root.persist()',
):
    require(session, token, "resizable pane state missing " + token)
require(page, "inspectedSemanticRangeText", "parsed QML targets must expose source range evidence")
require(session, 'property string selectedSemanticAnchor: ""',
        "semantic inspect selection must live in the session singleton")
require(session, "function selectSemantic(anchor: string): bool",
        "session must own semantic inspect selection")
require(page, "CodeWorkflowSession.selectedSemanticAnchor",
        "page must consume the shared semantic selection")
require(page, 'import qs.modules.common.functions',
        "Code Workflow page must import ColorUtils helpers used by pills and target contrast")
require(page, 'placeholderText: "Filter targets"',
        "Targets must expose a search/filter control")
target_filter_start = page.index("id: targetFilter")
target_filter_end = page.index("onTextChanged: root.inspectFilter = text",
                               target_filter_start)
target_filter_block = page[target_filter_start:target_filter_end]
require(target_filter_block, "Layout.fillHeight: false",
        "Targets filter must not consume the flexible height reserved for the inspect list")
require(target_filter_block, "Layout.preferredHeight: 34",
        "Targets filter must keep its compact toolbar height")
require(target_filter_block, "colBackground: Appearance.colors.colLayer2",
        "Targets filter must remain visually distinct from the Targets panel")
require(page, "property bool inspectSelectionFromTargets: false",
        "Targets must distinguish list-originated selection from external selection")
require(page, "root.inspectSelectionFromTargets = true",
        "Targets activation must mark its selection origin")
require(page, "finally {\n            root.inspectSelectionFromTargets = false",
        "Targets activation must always clear its selection-origin guard")
require(page, "if (!root.inspectSelectionFromTargets)",
        "external selection may clear filters while list selection preserves them")
require(page, 'Accessible.name: "Filter inspect targets"',
        "Targets filter must expose an explicit accessibility label")
require(page, 'Accessible.name: "Source preview"',
        "Source Preview must expose an explicit accessibility label")
require(page, "activeFocusOnTab: true",
        "read-only Source Preview must remain keyboard-focusable")
source_preview_start = page.index("id: sourcePreviewText")
source_preview_end = page.index("font.pixelSize: Appearance.font.pixelSize.small",
                                source_preview_start)
source_preview_block = page[source_preview_start:source_preview_end]
require(source_preview_block, "renderType: Text.QtRendering",
        "Source Preview must use Qt text rendering for clean monospace antialiasing")
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
for token in (
    "first >= 0xd800 && first <= 0xdbff",
    "second >= 0xdc00 && second <= 0xdfff",
    "bytes += 4",
    "index += 2",
):
    require(page, token,
            "UTF-8 byte mapper must preserve surrogate-pair handling: " + token)

unicode_sample = "Aé中😀Z"
unicode_boundaries = {
    0: 0,
    1: 1,
    3: 2,
    6: 3,
    10: 5,
    11: 6,
}
for byte_offset, expected_utf16_index in unicode_boundaries.items():
    actual = utf16_index_for_utf8_byte_offset(unicode_sample, byte_offset)
    if actual != expected_utf16_index:
        raise SystemExit(
            "FAIL: UTF-8/UTF-16 source-range fixture drift at byte "
            + str(byte_offset)
            + ": expected " + str(expected_utf16_index)
            + ", got " + str(actual)
        )
require(page, "function revealSourceSelection(start: int, end: int): void",
        "Source Preview must reveal selected parser evidence")
require(page, "sourcePreviewText.deselect()",
        "Source Preview must clear stale evidence before resolving a new anchor")
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
require(session, "restoredEdge.previewable === true",
        "session restore must re-check previewable edge mutation invariants")
require(session, 'edgeTarget.kind !== "binding"',
        "restored previewable edges must still target reviewed binding nodes")
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
