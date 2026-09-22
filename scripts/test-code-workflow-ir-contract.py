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
ROUTE_PADDING = 10.0

def raw_node_bounds(nodes: list[dict]) -> dict:
    return {
        "minX": min(float(node.get("x") or 0) for node in nodes),
        "minY": min(float(node.get("y") or 0) for node in nodes),
        "maxX": max(float(node.get("x") or 0) + NODE_WIDTH for node in nodes),
        "maxY": max(float(node.get("y") or 0) + NODE_HEIGHT for node in nodes),
    }

def normalize_points(points: list[dict]) -> list[dict]:
    compact = []
    for point in points:
        next_point = {"x": float(point["x"]), "y": float(point["y"])}
        if compact and all(
            abs(compact[-1][axis] - next_point[axis]) < 0.001
            for axis in ("x", "y")
        ):
            continue
        compact.append(next_point)

    changed = True
    while changed and len(compact) > 2:
        changed = False
        for index in range(1, len(compact) - 1):
            before, point, after = (
                compact[index - 1],
                compact[index],
                compact[index + 1],
            )
            same_x = (
                abs(before["x"] - point["x"]) < 0.001
                and abs(point["x"] - after["x"]) < 0.001
            )
            same_y = (
                abs(before["y"] - point["y"]) < 0.001
                and abs(point["y"] - after["y"]) < 0.001
            )
            if same_x or same_y:
                compact.pop(index)
                changed = True
                break
    return compact

def make_route(points: list[dict], vertical: bool, direction: float) -> dict:
    return {
        "points": normalize_points(points),
        "vertical": vertical,
        "direction": direction,
    }

def segment_intersects_rect(
    start: dict,
    end: dict,
    left: float,
    top: float,
    right: float,
    bottom: float,
) -> bool:
    if abs(start["x"] - end["x"]) < 0.001:
        low, high = sorted((start["y"], end["y"]))
        return left <= start["x"] <= right and high >= top and low <= bottom
    if abs(start["y"] - end["y"]) < 0.001:
        low, high = sorted((start["x"], end["x"]))
        return top <= start["y"] <= bottom and high >= left and low <= right
    return False

def route_intersects_node(route: dict, node: dict) -> bool:
    left = float(node.get("x") or 0) - ROUTE_PADDING
    top = float(node.get("y") or 0) - ROUTE_PADDING
    right = float(node.get("x") or 0) + NODE_WIDTH + ROUTE_PADDING
    bottom = float(node.get("y") or 0) + NODE_HEIGHT + ROUTE_PADDING
    points = route["points"]
    return any(
        segment_intersects_rect(
            points[index - 1], points[index],
            left, top, right, bottom,
        )
        for index in range(1, len(points))
    )

def route_collision_count(route: dict, edge: dict, nodes: list[dict]) -> int:
    return sum(
        1
        for node in nodes
        if node.get("id") not in {edge.get("from"), edge.get("to")}
        and route_intersects_node(route, node)
    )

def route_length(route: dict) -> float:
    points = route["points"]
    return sum(
        abs(points[index]["x"] - points[index - 1]["x"])
        + abs(points[index]["y"] - points[index - 1]["y"])
        for index in range(1, len(points))
    )

def edge_lane_offset(
    edge: dict,
    edges: list[dict],
    node_by_id: dict,
    vertical: bool,
    direction: float,
) -> float:
    siblings = [
        candidate for candidate in edges
        if candidate.get("from") == edge.get("from")
    ]
    if len(siblings) <= 1:
        return 0.0
    axis = "x" if vertical else "y"
    siblings.sort(key=lambda candidate: (
        float(node_by_id[candidate.get("to")].get(axis) or 0),
        str(candidate.get("id") or ""),
    ))
    index = next(
        (
            index for index, candidate in enumerate(siblings)
            if candidate.get("id") == edge.get("id")
        ),
        -1,
    )
    if index < 0:
        return 0.0
    middle = (len(siblings) - 1) / 2.0
    lane_spacing = 12.0 if len(siblings) >= 8 else (
        10.0 if len(siblings) >= 4 else 8.0
    )
    return max(-64.0, min(
        64.0, (middle - index) * lane_spacing * direction))

def segments_cross(
    first_a: dict,
    first_b: dict,
    second_a: dict,
    second_b: dict,
) -> bool:
    first_vertical = abs(first_a["x"] - first_b["x"]) < 0.001
    second_vertical = abs(second_a["x"] - second_b["x"]) < 0.001
    if first_vertical == second_vertical:
        return False
    vertical_a, vertical_b = (
        (first_a, first_b)
        if first_vertical else (second_a, second_b)
    )
    horizontal_a, horizontal_b = (
        (second_a, second_b)
        if first_vertical else (first_a, first_b)
    )
    x = vertical_a["x"]
    y = horizontal_a["y"]
    epsilon = 0.001
    return (
        x > min(horizontal_a["x"], horizontal_b["x"]) + epsilon
        and x < max(horizontal_a["x"], horizontal_b["x"]) - epsilon
        and y > min(vertical_a["y"], vertical_b["y"]) + epsilon
        and y < max(vertical_a["y"], vertical_b["y"]) - epsilon
    )

def route_crossing_count(route: dict, occupied_routes: list[dict]) -> int:
    crossings = 0
    points = route["points"]
    for occupied in occupied_routes:
        other = occupied["points"]
        for first in range(1, len(points)):
            for second in range(1, len(other)):
                if segments_cross(
                    points[first - 1], points[first],
                    other[second - 1], other[second],
                ):
                    crossings += 1
    return crossings

def segment_overlap_length(
    first_a: dict,
    first_b: dict,
    second_a: dict,
    second_b: dict,
) -> float:
    first_vertical = abs(first_a["x"] - first_b["x"]) < 0.001
    second_vertical = abs(second_a["x"] - second_b["x"]) < 0.001
    if first_vertical != second_vertical:
        return 0.0

    if first_vertical:
        if abs(first_a["x"] - second_a["x"]) >= 0.001:
            return 0.0
        start = max(
            min(first_a["y"], first_b["y"]),
            min(second_a["y"], second_b["y"]),
        )
        end = min(
            max(first_a["y"], first_b["y"]),
            max(second_a["y"], second_b["y"]),
        )
        return max(0.0, end - start)

    if abs(first_a["y"] - second_a["y"]) >= 0.001:
        return 0.0
    start = max(
        min(first_a["x"], first_b["x"]),
        min(second_a["x"], second_b["x"]),
    )
    end = min(
        max(first_a["x"], first_b["x"]),
        max(second_a["x"], second_b["x"]),
    )
    return max(0.0, end - start)

def route_overlap_length(
    route: dict,
    edge: dict,
    occupied_routes: list[dict],
) -> float:
    overlap = 0.0
    points = route["points"]
    current_from = str(edge.get("from") or "")
    current_to = str(edge.get("to") or "")
    for occupied in occupied_routes:
        other = occupied["points"]
        occupied_from = str(occupied.get("fromId") or "")
        occupied_to = str(occupied.get("toId") or "")
        for first in range(1, len(points)):
            for second in range(1, len(other)):
                length = segment_overlap_length(
                    points[first - 1], points[first],
                    other[second - 1], other[second],
                )
                if length <= 0.0:
                    continue

                current_at_source = first == 1
                current_at_target = first == len(points) - 1
                occupied_at_source = second == 1
                occupied_at_target = second == len(other) - 1
                shared_endpoint = (
                    current_at_source
                    and occupied_at_source
                    and current_from == occupied_from
                ) or (
                    current_at_source
                    and occupied_at_target
                    and current_from == occupied_to
                ) or (
                    current_at_target
                    and occupied_at_source
                    and current_to == occupied_from
                ) or (
                    current_at_target
                    and occupied_at_target
                    and current_to == occupied_to
                )
                if not shared_endpoint:
                    overlap += length
    return overlap

def resolved_route(
    edge: dict,
    node_by_id: dict,
    nodes: list[dict],
    edges: list[dict],
    occupied_routes: list[dict],
) -> dict:
    from_node = node_by_id[edge.get("from")]
    to_node = node_by_id[edge.get("to")]
    from_x = float(from_node.get("x") or 0)
    from_y = float(from_node.get("y") or 0)
    to_x = float(to_node.get("x") or 0)
    to_y = float(to_node.get("y") or 0)
    from_right = from_x + NODE_WIDTH
    to_right = to_x + NODE_WIDTH
    from_center_x = from_x + NODE_WIDTH / 2.0
    from_center_y = from_y + NODE_HEIGHT / 2.0
    to_center_x = to_x + NODE_WIDTH / 2.0
    to_center_y = to_y + NODE_HEIGHT / 2.0
    separated_right = to_x >= from_right
    separated_left = to_right <= from_x
    vertical = not separated_right and not separated_left
    primary_direction = (
        1.0 if (
            (to_center_y >= from_center_y)
            if vertical else separated_right
        ) else -1.0
    )
    lane_offset = edge_lane_offset(
        edge, edges, node_by_id, vertical, primary_direction)
    bounds = raw_node_bounds(nodes)
    candidates = []

    if not vertical:
        rightward = separated_right
        direction = 1.0 if rightward else -1.0
        x0 = from_x + (NODE_WIDTH if rightward else 0.0)
        y0 = from_center_y
        x3 = to_x + (0.0 if rightward else NODE_WIDTH)
        y3 = to_center_y
        target_label_run = min(
            84.0, max(60.0, abs(x3 - x0) * 0.45))
        base_corridor = (
            x3 - direction * target_label_run + lane_offset * 0.5)
        for offset in (0, 32, -32, 64, -64, 120, -120):
            corridor = base_corridor + offset
            candidates.append(make_route([
                {"x": x0, "y": y0},
                {"x": corridor, "y": y0},
                {"x": corridor, "y": y3},
                {"x": x3, "y": y3},
            ], False, direction))

        stub = 36.0
        from_stub = x0 + direction * stub
        to_stub = x3 - direction * stub
        middle_y = (y0 + y3) / 2.0
        for lane_y in (
            bounds["minY"] - 52 - abs(lane_offset) * 0.25,
            bounds["maxY"] + 52 + abs(lane_offset) * 0.25,
            middle_y + 120, middle_y - 120,
            middle_y + 220, middle_y - 220,
        ):
            candidates.append(make_route([
                {"x": x0, "y": y0},
                {"x": from_stub, "y": y0},
                {"x": from_stub, "y": lane_y},
                {"x": to_stub, "y": lane_y},
                {"x": to_stub, "y": y3},
                {"x": x3, "y": y3},
            ], False, direction))

        for source_y, target_y, lane_y in (
            (
                from_y,
                to_y,
                bounds["minY"] - 52 - abs(lane_offset) * 0.25,
            ),
            (
                from_y + NODE_HEIGHT,
                to_y + NODE_HEIGHT,
                bounds["maxY"] + 52 + abs(lane_offset) * 0.25,
            ),
        ):
            candidates.append(make_route([
                {"x": from_center_x, "y": source_y},
                {"x": from_center_x, "y": lane_y},
                {"x": to_center_x, "y": lane_y},
                {"x": to_center_x, "y": target_y},
            ], False, direction))

        outer_x = (
            bounds["maxX"] + 52
            if rightward else bounds["minX"] - 52
        )
        target_outer_x = to_right if rightward else to_x
        for source_y, lane_y in (
            (from_y, bounds["minY"] - 52),
            (from_y + NODE_HEIGHT, bounds["maxY"] + 52),
        ):
            candidates.append(make_route([
                {"x": from_center_x, "y": source_y},
                {"x": from_center_x, "y": lane_y},
                {"x": outer_x, "y": lane_y},
                {"x": outer_x, "y": to_center_y},
                {"x": target_outer_x, "y": to_center_y},
            ], False, direction))
    else:
        downward = to_center_y >= from_center_y
        direction = 1.0 if downward else -1.0
        x0 = from_center_x
        y0 = from_y + (NODE_HEIGHT if downward else 0.0)
        x3 = to_center_x
        y3 = to_y + (0.0 if downward else NODE_HEIGHT)
        base_corridor = (y0 + y3) / 2.0 + lane_offset
        for offset in (0, 48, -48, 96, -96, 160, -160):
            corridor = base_corridor + offset
            candidates.append(make_route([
                {"x": x0, "y": y0},
                {"x": x0, "y": corridor},
                {"x": x3, "y": corridor},
                {"x": x3, "y": y3},
            ], True, direction))

        stub = 36.0
        from_stub = y0 + direction * stub
        to_stub = y3 - direction * stub
        middle_x = (x0 + x3) / 2.0
        for lane_x in (
            bounds["minX"] - 52 - abs(lane_offset) * 0.25,
            bounds["maxX"] + 52 + abs(lane_offset) * 0.25,
            middle_x + 120, middle_x - 120,
            middle_x + 220, middle_x - 220,
        ):
            candidates.append(make_route([
                {"x": x0, "y": y0},
                {"x": x0, "y": from_stub},
                {"x": lane_x, "y": from_stub},
                {"x": lane_x, "y": to_stub},
                {"x": x3, "y": to_stub},
                {"x": x3, "y": y3},
            ], True, direction))

        for source_x, target_x, lane_x in (
            (
                from_x,
                to_x,
                bounds["minX"] - 52 - abs(lane_offset) * 0.25,
            ),
            (
                from_right,
                to_right,
                bounds["maxX"] + 52 + abs(lane_offset) * 0.25,
            ),
        ):
            candidates.append(make_route([
                {"x": source_x, "y": from_center_y},
                {"x": lane_x, "y": from_center_y},
                {"x": lane_x, "y": to_center_y},
                {"x": target_x, "y": to_center_y},
            ], True, direction))

    best = min(
        candidates,
        key=lambda route: (
            route_collision_count(route, edge, nodes) * 1_000_000_000
            + route_crossing_count(route, occupied_routes) * 1_000_000
            + route_overlap_length(route, edge, occupied_routes) * 1_000
            + route_length(route)
            + max(0, len(route["points"]) - 2) * 18,
            route_length(route),
        ),
    )
    best["edgeId"] = str(edge.get("id") or "")
    best["fromId"] = str(edge.get("from") or "")
    best["toId"] = str(edge.get("to") or "")
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
    occupied_routes = []
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

        route = resolved_route(
            edge, node_by_id, nodes, edges, occupied_routes)
        collisions = route_collision_count(route, edge, nodes)
        if collisions != 0:
            fail(
                f"{graph_id}/{edge.get('id')}: routed edge still intersects "
                f"{collisions} unrelated node(s)"
            )
        crossings = route_crossing_count(route, occupied_routes)
        if crossings != 0:
            fail(
                f"{graph_id}/{edge.get('id')}: routed edge still crosses "
                f"{crossings} previously routed segment(s)"
            )
        overlap = route_overlap_length(route, edge, occupied_routes)
        if overlap != 0:
            fail(
                f"{graph_id}/{edge.get('id')}: routed edge still overlaps "
                f"{overlap:.1f}px away from a shared endpoint"
            )
        occupied_routes.append(route)

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

if "import qs.modules.common.functions" not in canvas:
    fail("IR canvas must import ColorUtils helpers used by graph contrast")
if "component GraphText: StyledText {" not in canvas:
    fail("IR canvas must route transformed graph text through GraphText")
if "renderType: Text.QtRendering" not in canvas:
    fail("IR canvas GraphText must use Qt rendering under fractional zoom")
world_start = canvas.index("    Item {\n        id: world")
world_end = canvas.index("\n    Rectangle {\n        id: edgeLabelTooltip", world_start)
world_block = canvas[world_start:world_end]
if "StyledText {" in world_block:
    fail("transformed graph world must not use Native-rendered StyledText directly")
if "textRenderType: Text.QtRendering" not in world_block:
    fail("graph MaterialSymbol text must use Qt rendering under world transforms")
if "id: edgeLabelTooltip" in world_block:
    fail("edge-label tooltip HUD must stay outside the transformed graph world")

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
    "CodeWorkflowSession.graphLayoutRevision",
    "function nodeLayoutOffset(node): var",
    "function nodeX(node): real",
    "function nodeY(node): real",
    "id: canvasPanArea",
    "z: 2",
    "enabled: root.activeNodeDragHandler === null",
    "acceptedButtons: Qt.LeftButton | Qt.MiddleButton",
    "preventStealing: true",
    "hoverEnabled: false",
    "root.nodeAtScreen(mouse.x, mouse.y)",
    "mouse.accepted = false",
    "id: nodeDrag",
    "dragThreshold: 3",
    "centroid.scenePosition.x - startSceneX",
    "centroid.scenePosition.y - startSceneY",
    "CodeWorkflowSession.setNodeLayoutOffset(",
    "z: nodeDrag.active ? 1.4 : 1",
    "Behavior on scale {",
    "function autoPanStep(position: real, extent: real): real",
    "function autoPanDraggedNode(): void",
    "root.mapFromItem(",
    "null, root.activeNodeDragSceneX, root.activeNodeDragSceneY",
    "CodeWorkflowSession.setViewportTransient(",
    "handler.updateLayout()",
    "id: viewportCommitTimer",
    "onReleased: CodeWorkflowSession.commitViewport()",
    "function updateLayout(): void",
    "root.activeNodeDragOffsetX = nextX - baseX",
    "root.activeNodeDragOffsetY = nextY - baseY",
    "root.dragRoutesDirty = true",
    "id: dragFrameTimer",
    "root.rebuildDragEdgeRouteCache()",
    "CodeWorkflowSession.panX - startPanX",
    "CodeWorkflowSession.panY - startPanY",
    "Shape.CurveRenderer",
    "antialiasing: true",
    "z: selectedEdge ? 0.4 : hoveredEdge ? 0.3 : 0",
    "function edgeStrokeWidth(selected: bool, highlighted: bool): real",
    "return screenWidth / zoom",
    "id: edgePath",
    'root.graphExtent("x", 1050)',
    'root.graphExtent("y", 570)',
    "function normalizeRoutePoints(points): var",
    "function smoothStepSvg(points): string",
    "function routeFromPoints(points, vertical: bool, direction: real): var",
    "function segmentIntersectsRect(",
    "function routeIntersectsNode(route, node, padding: real): bool",
    "function routeCollisionCount(route, edge): int",
    "function edgeLaneOffset(",
    "const laneSpacing = siblings.length >= 8",
    "function segmentsCross(firstA, firstB, secondA, secondB): bool",
    "function routeCrossingCount(route, occupiedRoutes): int",
    "function segmentOverlapLength(firstA, firstB, secondA, secondB): real",
    "function routeOverlapLength(route, edge, occupiedRoutes): real",
    "function routeScore(route, edge, occupiedRoutes): real",
    "+ crossings * 1000000",
    "+ overlap * 1000",
    "function edgeRoute(edge, occupiedRoutes = []): var",
    "const targetLabelRun = Math.min(",
    "const corridorOffsets = [0, 32, -32, 64, -64, 120, -120]",
    "let foundTargetHorizontal = false",
    "const horizontalPortLanes = [",
    "const perimeterPortLanes = [",
    "const verticalPortLanes = [",
    "property var edgeRouteCache: ({})",
    "property var dragEdgeRouteCache: ({})",
    "function buildEdgeRouteCache(): var",
    "function rebuildEdgeRouteCache(): void",
    "root.edgeRouteCache = root.buildEdgeRouteCache()",
    "function edgeTouchesNode(edge, nodeId: string): bool",
    "function rebuildDragEdgeRouteCache(): void",
    "root.dragEdgeRouteCache = cache",
    "function routeForEdge(edge): var",
    "function routeDiagnostics(): var",
    'style: "smooth-step-lane-v2"',
    "overlapLength: Math.round(overlapLength)",
    "const occupiedRoutes = []",
    "const route = root.edgeRoute(edge, occupiedRoutes)",
    "occupiedRoutes.push(route)",
    "const route = root.routeForEdge(edge)",
    "root.routeForEdge(edgeShape.modelData)",
    "root.routeForEdge(modelData)",
    "PathSvg {",
    "path: edgePath.route?.svg ?? \"\"",
    "readonly property var previousPoint:",
    "readonly property real tangentX:",
    "readonly property real tangentY:",
    "readonly property real tangentLength:",
    "readonly property real unitX:",
    "readonly property real unitY:",
    "readonly property real worldArrowHalfWidth:",
    "x: arrowPath.backX - arrowPath.unitY * arrowPath.worldArrowHalfWidth",
    "id: nodeContent",
    "clip: true",
    "id: edgeLabel",
    "readonly property real labelWidthLimit:",
    "readonly property bool hovered:",
    "edgeLabelHover.hovered",
    "id: edgeLabelHover",
    "id: edgeLabelTooltip",
    "function revealNode(nodeId: string): void",
    "function revealEdge(edgeId: string): void",
    "function revealPrimarySelection(): void",
    "Qt.callLater(root.revealPrimarySelection)",
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
    "Layout.maximumWidth: node.width - 20",
    "CodeWorkflowSession.selectNode",
    "CodeWorkflowSession.openSubflow",
):
    if token not in canvas:
        fail("IR canvas missing " + token)

if canvas.count("function edgeRoute(edge, occupiedRoutes = []): var") != 1:
    fail("IR canvas must keep one authoritative edgeRoute geometry function")

for token in (
    "CodeWorkflowIrCanvas {",
    "root.selectedIrNode?.sourcePath",
    "root.selectedIrNode?.sourceNeedle",
    "focusSourceAnchor",
    'buttonText: "Reset graph layout"',
    "CodeWorkflowSession.hasGraphLayout(",
    "CodeWorkflowSession.resetGraphLayout(",
    "readonly property string sourceHighlightDefinition:",
    "id: sourceSyntaxLoader",
    "function syncSourceSyntaxHighlighter(): void",
    '"CodeWorkflowSyntaxHighlighter.qml"',
    "property string sourceDraft:",
    "readonly property bool sourceEditorDirty:",
    "readonly property bool sourceEditorCanSave:",
    "function syncSourceEditorFromDisk(force: bool): void",
    "function saveSourceEditor(): bool",
    "function openSourceInNeovim(): bool",
    'AppLauncher.commandFor("terminal")',
    '"nvim", target',
    'text: "Source Editor · " + root.sourcePath',
    'buttonText: "Save source editor"',
    'buttonText: "Open source in Neovim"',
    "text: root.sourceDraft",
    "readOnly: false",
    "Keys.onPressed: event =>",
    "property bool sourceEditorUseNvim: false",
    'buttonText: root.sourceEditorUseNvim',
    '"Use embedded Neovim"',
    "readonly property var embeddedNvimView:",
    "readonly property bool embeddedNvimBufferModified:",
    "readonly property string embeddedNvimMode:",
    "readonly property bool embeddedNvimReady:",
    "function syncEmbeddedNvimView(): void",
    "function saveEmbeddedNvim(): bool",
    "id: embeddedNvimLoader",
    '"CodeWorkflowNvimView.qml"',
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
if "acceptedButtons: Qt.MiddleButton\n" in canvas:
    fail("empty-space pan must not regress to middle-button-only interaction")
if "id: canvasPanArea\n        anchors.fill: parent\n        z: -1" in canvas:
    fail("empty-space pan surface must stay above the transformed graph world")
if "Qt.OpenHandCursor" in canvas:
    fail("Code Workflow cursor must stay normal until a drag is actually active")

drag_update_start = canvas.index("function updateLayout(): void")
drag_update_end = canvas.index("onActiveChanged:", drag_update_start)
drag_update_block = canvas[drag_update_start:drag_update_end]
if "CodeWorkflowSession.setNodeLayoutOffset(" in drag_update_block:
    fail("node drag update must remain transient; commit layout only after drag ends")
if "root.activeNodeDragOffsetX = nextX - baseX" not in drag_update_block \
        or "root.dragRoutesDirty = true" not in drag_update_block:
    fail("node drag update must move local preview state and schedule coalesced routing")

for token in (
    'property string subflowTargetId: "bar"',
    'property string selectedNodeId: "bar.component"',
    "function selectNode(nodeId: string): void",
    "function openSubflow(targetId: string): bool",
    "if (!Persistent.ready || !CodeWorkflowIr.ready)",
    "target: CodeWorkflowIr",
    "property var graphNodeLayoutOffsets: ({})",
    "property int graphLayoutRevision: 0",
    "function nodeLayoutOffset(graphId: string, nodeId: string): var",
    "function setNodeLayoutOffset(",
    "function hasGraphLayout(graphId: string): bool",
    "function resetGraphLayout(graphId: string): void",
    "function setViewportTransient(",
    "function commitViewport(): void",
    "root.setViewportTransient(x, y, nextZoom)",
):
    if token not in session:
        fail("session missing " + token)

for token in ("codeWorkflowSubflowTargetId", "codeWorkflowNodeId"):
    if token not in persistent:
        fail("persistent state missing " + token)

if 'Node { targetId: "bar/media"' in page:
    fail("page still contains the old fixed component projection")
if "setText(" in ir_service:
    fail("semantic IR service must remain source-read-only")
if page.count("setText(") != 1 \
        or "sourceDraftWriter.setText(root.sourceDraft)" not in page:
    fail("Code Workflow editor may only stage its draft through sourceDraftWriter")

print("ok - Code Workflow source-backed semantic IR contract")
