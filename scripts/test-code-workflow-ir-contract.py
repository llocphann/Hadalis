#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "defaults/code-workflow-ir.json"

def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")

def fail(message: str) -> None:
    raise SystemExit("FAIL: " + message)

NODE_WIDTH = 190.0
NODE_HEIGHT = 88.0
ROUTE_PADDING = 8.0
DETOUR_OFFSETS = (
    120.0, -120.0, 180.0, -180.0, 240.0, -240.0,
    320.0, -320.0, 420.0, -420.0, 520.0, -520.0,
)

def cubic(p0: float, p1: float, p2: float, p3: float, t: float) -> float:
    inv = 1.0 - t
    return (
        inv * inv * inv * p0
        + 3.0 * inv * inv * t * p1
        + 3.0 * inv * t * t * p2
        + t * t * t * p3
    )

def base_route(from_node: dict, to_node: dict) -> dict:
    from_x = float(from_node.get("x") or 0)
    from_y = float(from_node.get("y") or 0)
    to_x = float(to_node.get("x") or 0)
    to_y = float(to_node.get("y") or 0)
    from_right = from_x + NODE_WIDTH
    to_right = to_x + NODE_WIDTH
    separated_right = to_x >= from_right
    separated_left = to_right <= from_x
    vertical = not separated_right and not separated_left

    if vertical:
        downward = (
            to_y + NODE_HEIGHT / 2.0
            >= from_y + NODE_HEIGHT / 2.0
        )
        direction = 1.0 if downward else -1.0
        x0 = from_x + NODE_WIDTH / 2.0
        y0 = from_y + (NODE_HEIGHT if downward else 0.0)
        x3 = to_x + NODE_WIDTH / 2.0
        y3 = to_y + (0.0 if downward else NODE_HEIGHT)
        bend = max(48.0, abs(y3 - y0) / 2.0)
        return {
            "vertical": True, "direction": direction, "bend": bend,
            "x0": x0, "y0": y0,
            "x1": x0, "y1": y0 + direction * bend,
            "x2": x3, "y2": y3 - direction * bend,
            "x3": x3, "y3": y3,
        }

    rightward = separated_right
    direction = 1.0 if rightward else -1.0
    x0 = from_x + (NODE_WIDTH if rightward else 0.0)
    y0 = from_y + NODE_HEIGHT / 2.0
    x3 = to_x + (0.0 if rightward else NODE_WIDTH)
    y3 = to_y + NODE_HEIGHT / 2.0
    bend = max(48.0, abs(x3 - x0) / 2.0)
    return {
        "vertical": False, "direction": direction, "bend": bend,
        "x0": x0, "y0": y0,
        "x1": x0 + direction * bend, "y1": y0,
        "x2": x3 - direction * bend, "y2": y3,
        "x3": x3, "y3": y3,
    }

def detour_route(route: dict, offset: float) -> dict:
    candidate = dict(route)
    if candidate["vertical"]:
        candidate["x1"] = candidate["x0"] + offset
        candidate["y1"] = candidate["y0"]
        candidate["x2"] = candidate["x3"] + offset
        candidate["y2"] = candidate["y3"]
    else:
        candidate["x1"] = candidate["x0"]
        candidate["y1"] = candidate["y0"] + offset
        candidate["x2"] = candidate["x3"]
        candidate["y2"] = candidate["y3"] + offset
    return candidate

def route_intersects_node(route: dict, node: dict) -> bool:
    left = float(node.get("x") or 0) - ROUTE_PADDING
    top = float(node.get("y") or 0) - ROUTE_PADDING
    right = float(node.get("x") or 0) + NODE_WIDTH + ROUTE_PADDING
    bottom = float(node.get("y") or 0) + NODE_HEIGHT + ROUTE_PADDING

    route_left = min(route[f"x{i}"] for i in range(4))
    route_top = min(route[f"y{i}"] for i in range(4))
    route_right = max(route[f"x{i}"] for i in range(4))
    route_bottom = max(route[f"y{i}"] for i in range(4))
    if (
        route_right < left or route_left > right
        or route_bottom < top or route_top > bottom
    ):
        return False

    for step in range(1, 32):
        t = step / 32.0
        x = cubic(route["x0"], route["x1"], route["x2"], route["x3"], t)
        y = cubic(route["y0"], route["y1"], route["y2"], route["y3"], t)
        if left <= x <= right and top <= y <= bottom:
            return True
    return False

def route_collision_count(route: dict, edge: dict, nodes: list[dict]) -> int:
    return sum(
        1
        for node in nodes
        if node.get("id") not in {edge.get("from"), edge.get("to")}
        and route_intersects_node(route, node)
    )

def resolved_route(edge: dict, node_by_id: dict, nodes: list[dict]) -> dict:
    route = base_route(
        node_by_id[edge.get("from")],
        node_by_id[edge.get("to")],
    )
    best = route
    best_count = route_collision_count(route, edge, nodes)
    if best_count == 0:
        return route

    for offset in DETOUR_OFFSETS:
        candidate = detour_route(route, offset)
        count = route_collision_count(candidate, edge, nodes)
        if count < best_count:
            best = candidate
            best_count = count
        if count == 0:
            return candidate
    return best

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
seen_backward_edge = False
seen_same_column_edge = False

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
    node_by_id = {node.get("id"): node for node in nodes}
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
        from_node = node_by_id[edge.get("from")]
        to_node = node_by_id[edge.get("to")]
        from_x = float(from_node.get("x") or 0)
        to_x = float(to_node.get("x") or 0)
        if from_x > to_x:
            seen_backward_edge = True
        if from_x == to_x:
            seen_same_column_edge = True

        route = resolved_route(edge, node_by_id, nodes)
        collisions = route_collision_count(route, edge, nodes)
        if collisions != 0:
            fail(
                f"{graph_id}/{edge.get('id')}: routed edge still intersects "
                f"{collisions} unrelated node(s)"
            )

if not required_kinds.issubset(seen_kinds):
    fail("IR node-kind coverage missing: " + ", ".join(sorted(required_kinds - seen_kinds)))
if not {"data", "event", "action", "lifecycle", "structure"}.issubset(seen_edges):
    fail("IR edge-kind coverage is incomplete")
if not seen_backward_edge:
    fail("IR fixture must cover a backward edge for direction-aware routing")
if not seen_same_column_edge:
    fail("IR fixture must cover a same-column edge for vertical routing")

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
    "function routeIntersectsNode(route, node, padding: real): bool",
    "function routeCollisionCount(route, edge): int",
    "function detourRoute(route, offset: real): var",
    "function edgeRoute(edge): var",
    "const detourOffsets = [",
    "const separatedRight = toX >= fromRight",
    "const separatedLeft = toRight <= fromX",
    "const vertical = !separatedRight && !separatedLeft",
    "if (vertical)",
    "readonly property var edgeRouteCache: root.buildEdgeRouteCache()",
    "function buildEdgeRouteCache(): var",
    "function routeForEdge(edge): var",
    "cache[edgeId] = root.edgeRoute(edge)",
    "const route = root.routeForEdge(edge)",
    "root.routeForEdge(edgeShape.modelData)",
    "root.routeForEdge(modelData)",
    "arrowPath.route?.vertical",
    "id: nodeContent",
    "clip: true",
    "id: edgeLabel",
    "function revealNode(nodeId: string): void",
    "function graphBounds(): var",
    "function fitGraph(): void",
    "const bounds = root.graphBounds()",
    "availableWidth / Math.max(1, bounds.width)",
    "availableHeight / Math.max(1, bounds.height)",
    "function edgeAt(screenX: real, screenY: real): string",
    "const edgeId = root.edgeAt(",
    "function edgeInk(kind: string, emphasized: bool): color",
    "id: arrowPath",
    "root.hoveredEdgeId === modelData.id",
    "root.edgeInk(modelData.kind, false)",
    "root.edgeInk(",
    "ShapePath.RoundCap",
    "Appearance.colors.colLayer0",
    "function onSelectedNodeIdChanged(): void",
    "root.cubicCoordinate(",
    "Layout.maximumWidth: node.width - 20",
    "CodeWorkflowSession.selectNode",
    "CodeWorkflowSession.openSubflow",
):
    if token not in canvas:
        fail("IR canvas missing " + token)

if canvas.count("function edgeRoute(edge): var") != 1:
    fail("IR canvas must keep one authoritative edgeRoute geometry function")

for token in (
    "CodeWorkflowIrCanvas {",
    "root.selectedIrNode?.sourcePath",
    "root.selectedIrNode?.sourceNeedle",
    "focusSourceAnchor",
):
    if token not in page:
        fail("Code Workflow page missing IR integration " + token)

for token in (
    "Inspection and mutation eligibility are separate concerns.",
    "if (edge.previewable === true && target.kind !== \"binding\")",
    "root.selectedEdgeId = edge.id",
):
    if token not in session:
        fail("session missing read-only edge inspection contract " + token)

if "function selectableEdgeAt(" in canvas or "function previewableEdgeAt(" in canvas:
    fail("canvas must not restrict inspect hit-testing to mutation-eligible edges")

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
