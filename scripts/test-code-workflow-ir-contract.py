#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "defaults/code-workflow-ir.json"

def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")

def fail(message: str) -> None:
    raise SystemExit("FAIL: " + message)

data = json.loads(MANIFEST.read_text(encoding="utf-8"))
if data.get("schema") != 1:
    fail("IR schema must be 1")
if data.get("mode") != "reviewed-source-projection":
    fail("IR must identify the reviewed source projection boundary")
if data.get("editable") is not False:
    fail("Phase 1 IR must remain globally read-only")
if data.get("sourceAnchorMode") != "reviewed-source-needle":
    fail("IR manifest must keep reviewed needles; CST ranges are runtime evidence")

graphs = data.get("graphs")
if set(graphs or {}) != {"bar", "bar/media", "bar/clock", "bar/resources"}:
    fail("IR graph scope must remain the reviewed horizontal ii Bar set")

required_kinds = {"component", "service", "binding", "event", "action", "lifecycle"}
seen_kinds = set()
seen_edges = set()

expected_bar_inspect_nodes = {
    "bar.workspaces", "bar.activeWindow", "bar.tray", "bar.battery",
    "bar.weather", "bar.utilButtons", "bar.shellUpdate", "bar.leftSidebar",
    "bar.rightSidebar", "bar.timer", "bar.background", "bar.edgeCell",
    "bar.separator", "bar.cava",
}
bar_node_ids = {node.get("id") for node in graphs["bar"].get("nodes", [])}
if not expected_bar_inspect_nodes.issubset(bar_node_ids):
    fail("Bar inspect projection is missing reviewed component-level targets")

for graph_id, graph in graphs.items():
    nodes = graph.get("nodes") or []
    edges = graph.get("edges") or []
    ids = [node.get("id") for node in nodes]
    if len(ids) != len(set(ids)):
        fail(f"{graph_id}: duplicate node IDs")
    if graph.get("rootNodeId") not in set(ids):
        fail(f"{graph_id}: rootNodeId does not resolve")

    node_ids = set(ids)
    for node in nodes:
        seen_kinds.add(node.get("kind"))
        if node.get("editable") is not False:
            fail(f"{graph_id}/{node.get('id')}: node must be read-only")
        path = node.get("sourcePath")
        needle = node.get("sourceNeedle")
        if not path or not needle:
            fail(f"{graph_id}/{node.get('id')}: missing source evidence")
        source_path = ROOT / path
        if not source_path.is_file():
            fail(f"{graph_id}/{node.get('id')}: missing source path {path}")
        source_text = source_path.read_text(encoding="utf-8")
        occurrence_count = source_text.count(needle)
        if occurrence_count == 0:
            fail(f"{graph_id}/{node.get('id')}: source anchor drift: {needle!r}")
        if occurrence_count != 1:
            fail(
                f"{graph_id}/{node.get('id')}: source anchor must be unique, "
                f"found {occurrence_count}: {needle!r}"
            )
        if "sourceRange" in node or "range" in node:
            fail(f"{graph_id}/{node.get('id')}: reviewed projection must not claim CST ranges")

    edge_ids = [edge.get("id") for edge in edges]
    if len(edge_ids) != len(set(edge_ids)):
        fail(f"{graph_id}: duplicate edge IDs")
    for edge in edges:
        seen_edges.add(edge.get("kind"))
        if edge.get("editable") is not False:
            fail(f"{graph_id}/{edge.get('id')}: edge must be read-only")
        if edge.get("from") not in node_ids or edge.get("to") not in node_ids:
            fail(f"{graph_id}/{edge.get('id')}: unresolved edge endpoint")

if not required_kinds.issubset(seen_kinds):
    fail("IR node-kind coverage missing: " + ", ".join(sorted(required_kinds - seen_kinds)))
if not {"data", "event", "action", "lifecycle", "structure"}.issubset(seen_edges):
    fail("IR edge-kind coverage is incomplete")

ir_service = read("services/CodeWorkflowIr.qml")
canvas = read("modules/settings/CodeWorkflowIrCanvas.qml")
page = read("modules/settings/CodeWorkflow.qml")
session = read("services/CodeWorkflowSession.qml")
persistent = read("modules/common/Persistent.qml")

for token in (
    "defaults/code-workflow-ir.json",
    'parsed?.mode !== "reviewed-source-projection"',
    "function graphFor(targetId: string): var",
    "function nodeFor(targetId: string, nodeId: string): var",
):
    if token not in ir_service:
        fail("IR service missing " + token)

if "RegExp" in ir_service or ".match(" in ir_service:
    fail("IR service must not regex-parse QML as a source model")

for token in (
    "CodeWorkflowIr.graphFor(CodeWorkflowSession.subflowTargetId)",
    "Shape.GeometryRenderer",
    "id: edgePath",
    'root.graphExtent("x", 1050)',
    'root.graphExtent("y", 570)',
    "x: edgePath.endNodeX",
    "control1X: edgePath.startNodeX",
    "id: nodeContent",
    "clip: true",
    "id: edgeLabel",
    "root.cubicCoordinate(",
    "Layout.maximumWidth: node.width - 20",
    "CodeWorkflowSession.selectNode",
    "CodeWorkflowSession.openSubflow",
):
    if token not in canvas:
        fail("IR canvas missing " + token)

for token in (
    "CodeWorkflowIrCanvas {",
    "root.selectedIrNode?.sourcePath",
    "root.selectedIrNode?.sourceNeedle",
    "focusSourceAnchor",
):
    if token not in page:
        fail("Code Workflow page missing IR integration " + token)

for token in (
    'property string subflowTargetId: "bar"',
    'property string selectedNodeId: "bar.component"',
    "function selectNode(nodeId: string): void",
    "function openSubflow(targetId: string): bool",
    "if (!Persistent.ready || !CodeWorkflowIr.ready)",
    "target: CodeWorkflowIr",
):
    if token not in session:
        fail("session missing " + token)

for token in ("codeWorkflowSubflowTargetId", "codeWorkflowNodeId"):
    if token not in persistent:
        fail("persistent state missing " + token)

if 'Node { targetId: "bar/media"' in page:
    fail("page still contains the old fixed component projection")
if "setText(" in page or "setText(" in ir_service:
    fail("read-only IR milestone must not write source")

print("ok - Code Workflow source-backed semantic IR contract")
