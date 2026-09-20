#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
manifest = json.loads(
    (ROOT / "defaults/code-workflow-ir.json").read_text(encoding="utf-8")
)
service = (ROOT / "services/CodeWorkflowIr.qml").read_text(encoding="utf-8")
phase2 = (ROOT / "docs/CODE_WORKFLOW_PHASE2.md").read_text(encoding="utf-8")


def fail(message: str) -> None:
    raise SystemExit("FAIL: " + message)


expected = {
    "clock.data.time": "DateTime.timeDisplay",
    "clock.data.date": "DateTime.date",
    "resources.data.memory": "ResourceUsage.memoryUsedPercentage",
    "resources.data.cpu": "ResourceUsage.cpuUsage",
}
seen = {}

for graph_id, graph in (manifest.get("graphs") or {}).items():
    nodes = {node.get("id"): node for node in graph.get("nodes") or []}
    for edge in graph.get("edges") or []:
        if edge.get("previewable") is not True:
            continue
        edge_id = edge.get("id")
        seen[edge_id] = edge.get("sourceExpression")
        if edge.get("kind") != "data":
            fail(f"{graph_id}/{edge_id}: previewable edge must be data")
        if edge.get("previewTransform") != "direct-binding-retarget":
            fail(f"{graph_id}/{edge_id}: unsupported preview transform")
        if edge.get("editable") is not False:
            fail(f"{graph_id}/{edge_id}: previewable must not mean editable")
        target = nodes.get(edge.get("to"))
        if not target or target.get("kind") != "binding":
            fail(f"{graph_id}/{edge_id}: target must be reviewed binding node")
        expression = str(edge.get("sourceExpression") or "")
        needle = str(target.get("sourceNeedle") or "")
        if not expression or expression not in needle:
            fail(f"{graph_id}/{edge_id}: source expression lacks target evidence")
        if edge.get("reviewedSemanticKind") != "binding":
            fail(f"{graph_id}/{edge_id}: semantic kind evidence drifted")
        if edge.get("reviewedValueKind") != "member_expression":
            fail(f"{graph_id}/{edge_id}: value kind evidence drifted")

if seen != expected:
    fail("2K-A previewable edge allowlist drifted: " + repr(seen))

for graph in (manifest.get("graphs") or {}).values():
    for edge in graph.get("edges") or []:
        if edge.get("id") in {
            "media.data.component",
            "clock.data.timeComponent",
            "clock.data.dateComponent",
            "resources.data.memoryComponent",
            "resources.data.cpuComponent",
        } and edge.get("previewable") is True:
            fail("visual propagation edge must never become mutation candidate")

for token in (
    "function edgeFor(targetId: string, edgeId: string): var",
    "function previewableDataEdgesFor(targetId: string): var",
    'edge.previewTransform === "direct-binding-retarget"',
):
    if token not in service:
        fail("IR edge lookup/eligibility service missing " + token)

for forbidden in (
    "setText(",
    "writeAdapter(",
    "atomicWrites",
):
    if forbidden in service:
        fail("IR edge gate must remain non-writing: " + forbidden)

for token in (
    "Gate 2K-A — source-backed data-edge eligibility",
    "an edge ID alone is",
    "visual propagation edges",
    "Disconnect remains blocked",
    "absence of a reviewed path is not proof",
):
    if token not in phase2:
        fail("Phase 2 edge gate documentation missing " + token)

print("ok - Code Workflow 2K-A source-backed edge eligibility contract")
