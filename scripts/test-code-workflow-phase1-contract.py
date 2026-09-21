#!/usr/bin/env python3
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
require(page, "CodeWorkflowIrCanvas {", "page must host the semantic IR canvas")
require(page, "property string inspectedSemanticAnchor:", "inspect mode must track parsed QML element selection")
require(page, "CodeWorkflowAnalyzer.result?.entries", "inspect mode must expose parser semantic entries")
require(page, "model: root.inspectTargets", "Targets must include runtime, graph and parsed QML elements")
require(page, "Appearance.colors.colOnPrimaryContainer", "selected inspect targets need contrast-safe foreground")
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
require(page, "enabled: !targetRow.section",
        "Target section headers must be non-interactive")
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
require(page, "function revealSelectedInspectTarget(): void",
        "Targets must reveal the unified selected item")
require(page, "function reconcileSemanticInspectSelection(): void",
        "semantic inspect selection must clear after parser anchor drift")
require(page, "Qt.callLater(root.reconcileSemanticInspectSelection)",
        "analyzer READY must reconcile semantic inspect selection")
require(page, "target: CodeWorkflowSession",
        "Targets must react to shared session selection changes")
require(page, "targetList.positionViewAtIndex(index, ListView.Contain)",
        "Targets must scroll the selected item into view")
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
require(page, "readonly property bool selectedEdgeReadOnly:",
        "Inspector must distinguish read-only edge inspection")
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
