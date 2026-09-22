#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def fail(message: str) -> None:
    raise SystemExit("FAIL: " + message)


session = read("services/CodeWorkflowSession.qml")
persistent = read("modules/common/Persistent.qml")
canvas = read("modules/settings/CodeWorkflowIrCanvas.qml")
page = read("modules/settings/CodeWorkflow.qml")
phase2 = read("docs/CODE_WORKFLOW_PHASE2.md")

# The old 2K-B contract expected mutation-only hit testing against a cubic
# previewableEdgeAt surface. The reviewed smooth-step graph now makes every
# source-backed edge inspectable; only the transaction path is preview-gated.
for token in (
    'property string selectedEdgeId: ""',
    "function selectEdge(edgeId: string): bool",
    "CodeWorkflowIr.edgeFor(",
    "if (edge.previewable === true && target.kind !== \"binding\")",
    "root.selectedEdgeId = edge.id",
    "root.selectedNodeId = target.id",
    'root.selectedEdgeId = ""',
    "onSelectedEdgeIdChanged: root.persist()",
):
    if token not in session:
        fail("edge session identity or mutation boundary missing " + token)

if 'property string codeWorkflowEdgeId: ""' not in persistent:
    fail("persistent workflow state must include primitive edge id")
if "state.codeWorkflowEdgeId = root.selectedEdgeId" not in session:
    fail("edge id must persist through workflow session state")
if 'state.codeWorkflowEdgeId ?? ""' not in session:
    fail("edge id must restore through workflow session state")

for token in (
    "function pointSegmentDistance(",
    "function edgeDistance(edge, px: real, py: real): real",
    "const route = root.routeForEdge(edge)",
    "function nodeAtWorld(px: real, py: real): bool",
    "function viewportContains(screenX: real, screenY: real): bool",
    "function edgeAt(screenX: real, screenY: real): string",
    "if (!root.viewportContains(screenX, screenY))",
    "if (root.nodeAtWorld(worldX, worldY))",
    "const tolerance = 8 / zoom",
    "for (const edge of root.edges)",
    "CodeWorkflowSession.selectUnifiedEdge(edge)",
    "CodeWorkflowSession.selectedEdgeId === modelData.id",
):
    if token not in canvas:
        fail("all-edge route-backed hit test/selection missing " + token)

edge_hit_test = canvas.split(
    "function edgeAt(screenX: real, screenY: real): string", 1)[1].split(
    "function accentForKind(", 1)[0]
if "edge.previewable" in edge_hit_test:
    fail("read-only edges must remain selectable, not mutation-filtered")
if "function previewableEdgeAt(" in canvas:
    fail("retired mutation-only edge hit-test API must not return")
if "function cubicCoordinate(" in canvas:
    fail("retired cubic hit-test must not diverge from routed edge geometry")

edge_delegate_start = canvas.index("model: root.edges")
node_delegate_start = canvas.index("model: root.nodes", edge_delegate_start)
if edge_delegate_start < 0 or node_delegate_start < 0:
    fail("unable to isolate edge renderer delegate")
edge_delegate = canvas[edge_delegate_start:node_delegate_start]
if "MouseArea {" in edge_delegate or "TapHandler {" in edge_delegate:
    fail("edge renderer delegate must not own a wide/invisible input surface")

for token in (
    "readonly property var selectedIrEdge:",
    "readonly property var previewableInboundEdge:",
    '"Select connection · "',
    "CodeWorkflowSession.selectEdge(",
    '"Phase 2 edge retarget · preview only"',
):
    if token not in page:
        fail("edge inspector/keyboard path missing " + token)

for token in (
    "Milestone 2K-B — edge selection and retarget context",
    "9 / zoom",
    "No wide invisible stroke",
    "edge ID remains UI/session identity only",
    "Keyboard users can select",
):
    if token not in phase2:
        fail("Phase 2 2K-B documentation missing " + token)

print("ok - Code Workflow 2K-B edge selection/retarget context contract")
