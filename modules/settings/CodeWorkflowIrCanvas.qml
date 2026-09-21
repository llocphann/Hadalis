pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

Item {
    id: root
    // The canvas itself is the hard viewport boundary. The transformed graph
    // may pan beyond it, but nodes, routes, labels and graph-local effects must
    // never paint into the toolbar or adjacent SplitView panes.
    clip: true

    // Text inside `world` is transformed by graph zoom. Native glyph
    // rasterization becomes visibly thin/hollow at fractional zoom levels,
    // while the Qt renderer remains stable under scene transforms.
    component GraphText: StyledText {
        renderType: Text.QtRendering
    }

    readonly property var graph:
        CodeWorkflowIr.graphFor(CodeWorkflowSession.subflowTargetId)
    readonly property var nodes: root.graph?.nodes ?? []
    readonly property var edges: root.graph?.edges ?? []

    readonly property real nodeWidth: 190
    readonly property real nodeHeight: 88
    readonly property real worldWidth: root.graphExtent("x", 1050)
    readonly property real worldHeight: root.graphExtent("y", 570)
    property string hoveredEdgeId: ""
    readonly property var edgeRouteCache: root.buildEdgeRouteCache()

    function graphExtent(axis: string, minimum: real): real {
        let extent = minimum
        for (const node of root.nodes) {
            const position = Number(node?.[axis] ?? 0)
            const size = axis === "x" ? root.nodeWidth : root.nodeHeight
            extent = Math.max(extent, position + size + 80)
        }
        return extent
    }

    function nodeById(nodeId: string): var {
        return root.nodes.find(node => node.id === nodeId) ?? null
    }

    function rawNodeBounds(): var {
        if (root.nodes.length === 0)
            return { minX: 0, minY: 0, maxX: 0, maxY: 0 }

        let minX = Number.POSITIVE_INFINITY
        let minY = Number.POSITIVE_INFINITY
        let maxX = Number.NEGATIVE_INFINITY
        let maxY = Number.NEGATIVE_INFINITY
        for (const node of root.nodes) {
            const x = Number(node?.x ?? 0)
            const y = Number(node?.y ?? 0)
            minX = Math.min(minX, x)
            minY = Math.min(minY, y)
            maxX = Math.max(maxX, x + root.nodeWidth)
            maxY = Math.max(maxY, y + root.nodeHeight)
        }
        return { minX, minY, maxX, maxY }
    }

    function normalizeRoutePoints(points): var {
        const compact = []
        for (const point of points) {
            const next = {
                x: Number(point?.x ?? 0),
                y: Number(point?.y ?? 0)
            }
            const previous = compact[compact.length - 1]
            if (previous
                    && Math.abs(previous.x - next.x) < 0.001
                    && Math.abs(previous.y - next.y) < 0.001)
                continue
            compact.push(next)
        }

        let changed = true
        while (changed && compact.length > 2) {
            changed = false
            for (let index = 1; index < compact.length - 1; ++index) {
                const before = compact[index - 1]
                const point = compact[index]
                const after = compact[index + 1]
                const sameX = Math.abs(before.x - point.x) < 0.001
                    && Math.abs(point.x - after.x) < 0.001
                const sameY = Math.abs(before.y - point.y) < 0.001
                    && Math.abs(point.y - after.y) < 0.001
                if (sameX || sameY) {
                    compact.splice(index, 1)
                    changed = true
                    break
                }
            }
        }
        return compact
    }

    function pointToward(fromPoint, toPoint, distance: real): var {
        if (Math.abs(fromPoint.x - toPoint.x) < 0.001) {
            return {
                x: fromPoint.x,
                y: fromPoint.y
                    + Math.sign(toPoint.y - fromPoint.y) * distance
            }
        }
        return {
            x: fromPoint.x
                + Math.sign(toPoint.x - fromPoint.x) * distance,
            y: fromPoint.y
        }
    }

    function smoothStepSvg(points): string {
        if (!points || points.length < 2)
            return ""

        const radius = 14
        let path = "M " + points[0].x + " " + points[0].y
        for (let index = 1; index < points.length - 1; ++index) {
            const previous = points[index - 1]
            const point = points[index]
            const next = points[index + 1]
            const incoming = Math.abs(point.x - previous.x)
                + Math.abs(point.y - previous.y)
            const outgoing = Math.abs(next.x - point.x)
                + Math.abs(next.y - point.y)
            const corner = Math.min(radius, incoming / 2, outgoing / 2)
            if (corner < 0.5) {
                path += " L " + point.x + " " + point.y
                continue
            }
            const before = root.pointToward(point, previous, corner)
            const after = root.pointToward(point, next, corner)
            path += " L " + before.x + " " + before.y
                + " Q " + point.x + " " + point.y
                + " " + after.x + " " + after.y
        }
        const last = points[points.length - 1]
        path += " L " + last.x + " " + last.y
        return path
    }

    function routeFromPoints(points, vertical: bool, direction: real): var {
        const normalized = root.normalizeRoutePoints(points)
        if (normalized.length < 2)
            return null

        const first = normalized[0]
        const last = normalized[normalized.length - 1]
        let labelFrom = normalized[0]
        let labelTo = normalized[1]
        let foundTargetHorizontal = false
        for (let index = normalized.length - 1; index >= 1; --index) {
            const segmentFrom = normalized[index - 1]
            const segmentTo = normalized[index]
            const horizontal =
                Math.abs(segmentTo.y - segmentFrom.y) < 0.001
            if (!horizontal)
                continue
            labelFrom = segmentFrom
            labelTo = segmentTo
            foundTargetHorizontal = true
            break
        }

        if (!foundTargetHorizontal) {
            let bestSpan = -1
            for (let index = 1; index < normalized.length; ++index) {
                const segmentFrom = normalized[index - 1]
                const segmentTo = normalized[index]
                const span = Math.abs(segmentTo.x - segmentFrom.x)
                    + Math.abs(segmentTo.y - segmentFrom.y)
                if (span > bestSpan) {
                    bestSpan = span
                    labelFrom = segmentFrom
                    labelTo = segmentTo
                }
            }
        }
        return {
            points: normalized,
            vertical: vertical,
            direction: direction,
            x0: first.x,
            y0: first.y,
            x3: last.x,
            y3: last.y,
            labelX: (labelFrom.x + labelTo.x) / 2,
            labelY: (labelFrom.y + labelTo.y) / 2,
            labelSpan: Math.abs(labelTo.x - labelFrom.x)
                + Math.abs(labelTo.y - labelFrom.y),
            labelHorizontal:
                Math.abs(labelTo.y - labelFrom.y) < 0.001,
            svg: root.smoothStepSvg(normalized)
        }
    }

    function routeBounds(route): var {
        if (!route?.points || route.points.length === 0)
            return { minX: 0, minY: 0, maxX: 0, maxY: 0 }

        let minX = Number.POSITIVE_INFINITY
        let minY = Number.POSITIVE_INFINITY
        let maxX = Number.NEGATIVE_INFINITY
        let maxY = Number.NEGATIVE_INFINITY
        for (const point of route.points) {
            minX = Math.min(minX, point.x)
            minY = Math.min(minY, point.y)
            maxX = Math.max(maxX, point.x)
            maxY = Math.max(maxY, point.y)
        }
        return { minX, minY, maxX, maxY }
    }

    function segmentIntersectsRect(
        fromPoint, toPoint,
        left: real, top: real, right: real, bottom: real
    ): bool {
        if (Math.abs(fromPoint.x - toPoint.x) < 0.001) {
            const x = fromPoint.x
            const minY = Math.min(fromPoint.y, toPoint.y)
            const maxY = Math.max(fromPoint.y, toPoint.y)
            return x >= left && x <= right
                && maxY >= top && minY <= bottom
        }
        if (Math.abs(fromPoint.y - toPoint.y) < 0.001) {
            const y = fromPoint.y
            const minX = Math.min(fromPoint.x, toPoint.x)
            const maxX = Math.max(fromPoint.x, toPoint.x)
            return y >= top && y <= bottom
                && maxX >= left && minX <= right
        }
        return false
    }

    function routeIntersectsNode(route, node, padding: real): bool {
        const left = Number(node?.x ?? 0) - padding
        const top = Number(node?.y ?? 0) - padding
        const right = Number(node?.x ?? 0) + root.nodeWidth + padding
        const bottom = Number(node?.y ?? 0) + root.nodeHeight + padding
        const points = route?.points ?? []
        for (let index = 1; index < points.length; ++index) {
            if (root.segmentIntersectsRect(
                    points[index - 1], points[index],
                    left, top, right, bottom))
                return true
        }
        return false
    }

    function routeCollisionCount(route, edge): int {
        let collisions = 0
        for (const node of root.nodes) {
            const nodeId = String(node?.id ?? "")
            if (nodeId === String(edge?.from ?? "")
                    || nodeId === String(edge?.to ?? ""))
                continue
            if (root.routeIntersectsNode(route, node, 10))
                collisions += 1
        }
        return collisions
    }

    function routeLength(route): real {
        const points = route?.points ?? []
        let length = 0
        for (let index = 1; index < points.length; ++index) {
            length += Math.abs(points[index].x - points[index - 1].x)
                + Math.abs(points[index].y - points[index - 1].y)
        }
        return length
    }

    function edgeLaneOffset(
        edge, vertical: bool, direction: real
    ): real {
        const fromId = String(edge?.from ?? "")
        const siblings = root.edges.filter(candidate =>
            String(candidate?.from ?? "") === fromId)
        if (siblings.length <= 1)
            return 0

        const axis = vertical ? "x" : "y"
        siblings.sort((left, right) => {
            const leftNode = root.nodeById(left?.to ?? "")
            const rightNode = root.nodeById(right?.to ?? "")
            const leftPosition = Number(leftNode?.[axis] ?? 0)
            const rightPosition = Number(rightNode?.[axis] ?? 0)
            if (Math.abs(leftPosition - rightPosition) > 0.001)
                return leftPosition - rightPosition
            return String(left?.id ?? "").localeCompare(
                String(right?.id ?? ""))
        })

        const edgeId = String(edge?.id ?? "")
        const index = siblings.findIndex(candidate =>
            String(candidate?.id ?? "") === edgeId)
        if (index < 0)
            return 0

        const middle = (siblings.length - 1) / 2
        return Math.max(-64, Math.min(
            64, (middle - index) * 8 * direction))
    }

    function segmentsCross(firstA, firstB, secondA, secondB): bool {
        const firstVertical =
            Math.abs(firstA.x - firstB.x) < 0.001
        const secondVertical =
            Math.abs(secondA.x - secondB.x) < 0.001
        if (firstVertical === secondVertical)
            return false

        const verticalA = firstVertical ? firstA : secondA
        const verticalB = firstVertical ? firstB : secondB
        const horizontalA = firstVertical ? secondA : firstA
        const horizontalB = firstVertical ? secondB : firstB
        const x = verticalA.x
        const y = horizontalA.y
        const epsilon = 0.001
        return x > Math.min(horizontalA.x, horizontalB.x) + epsilon
            && x < Math.max(horizontalA.x, horizontalB.x) - epsilon
            && y > Math.min(verticalA.y, verticalB.y) + epsilon
            && y < Math.max(verticalA.y, verticalB.y) - epsilon
    }

    function routeCrossingCount(route, occupiedRoutes): int {
        const points = route?.points ?? []
        let crossings = 0
        for (const occupied of (occupiedRoutes ?? [])) {
            const otherPoints = occupied?.points ?? []
            for (let first = 1; first < points.length; ++first) {
                for (let second = 1;
                        second < otherPoints.length; ++second) {
                    if (root.segmentsCross(
                            points[first - 1], points[first],
                            otherPoints[second - 1],
                            otherPoints[second]))
                        crossings += 1
                }
            }
        }
        return crossings
    }

    function segmentOverlapLength(firstA, firstB, secondA, secondB): real {
        const firstVertical =
            Math.abs(firstA.x - firstB.x) < 0.001
        const secondVertical =
            Math.abs(secondA.x - secondB.x) < 0.001
        if (firstVertical !== secondVertical)
            return 0

        if (firstVertical) {
            if (Math.abs(firstA.x - secondA.x) >= 0.001)
                return 0
            const start = Math.max(
                Math.min(firstA.y, firstB.y),
                Math.min(secondA.y, secondB.y))
            const end = Math.min(
                Math.max(firstA.y, firstB.y),
                Math.max(secondA.y, secondB.y))
            return Math.max(0, end - start)
        }

        if (Math.abs(firstA.y - secondA.y) >= 0.001)
            return 0
        const start = Math.max(
            Math.min(firstA.x, firstB.x),
            Math.min(secondA.x, secondB.x))
        const end = Math.min(
            Math.max(firstA.x, firstB.x),
            Math.max(secondA.x, secondB.x))
        return Math.max(0, end - start)
    }

    function routeOverlapLength(route, edge, occupiedRoutes): real {
        const points = route?.points ?? []
        let overlap = 0
        for (const occupied of (occupiedRoutes ?? [])) {
            const otherPoints = occupied?.points ?? []
            const currentFrom = String(edge?.from ?? "")
            const currentTo = String(edge?.to ?? "")
            const occupiedFrom = String(occupied?.fromId ?? "")
            const occupiedTo = String(occupied?.toId ?? "")
            for (let first = 1; first < points.length; ++first) {
                for (let second = 1;
                        second < otherPoints.length; ++second) {
                    const length = root.segmentOverlapLength(
                        points[first - 1], points[first],
                        otherPoints[second - 1], otherPoints[second])
                    if (length <= 0)
                        continue

                    // Node-level IR has one abstract port per side rather than
                    // Blender/Blueprint-style semantic sockets. Segments that
                    // overlap only while touching the same endpoint are
                    // therefore intentional bundling, regardless of whether
                    // one edge enters and the other leaves that node.
                    const currentAtSource = first === 1
                    const currentAtTarget =
                        first === points.length - 1
                    const occupiedAtSource = second === 1
                    const occupiedAtTarget =
                        second === otherPoints.length - 1
                    const sharedEndpoint =
                        (currentAtSource && occupiedAtSource
                            && currentFrom === occupiedFrom)
                        || (currentAtSource && occupiedAtTarget
                            && currentFrom === occupiedTo)
                        || (currentAtTarget && occupiedAtSource
                            && currentTo === occupiedFrom)
                        || (currentAtTarget && occupiedAtTarget
                            && currentTo === occupiedTo)
                    overlap += sharedEndpoint ? 0 : length
                }
            }
        }
        return overlap
    }

    function routeScore(route, edge, occupiedRoutes): real {
        const collisions = root.routeCollisionCount(route, edge)
        const crossings =
            root.routeCrossingCount(route, occupiedRoutes)
        const overlap =
            root.routeOverlapLength(route, edge, occupiedRoutes)
        const bends = Math.max(0, (route?.points?.length ?? 2) - 2)
        return collisions * 1000000000
            + crossings * 1000000
            + overlap * 1000
            + root.routeLength(route)
            + bends * 18
    }

    function edgeRoute(edge, occupiedRoutes = []): var {
        const fromNode = root.nodeById(edge?.from ?? "")
        const toNode = root.nodeById(edge?.to ?? "")
        if (!fromNode || !toNode)
            return null

        const fromX = Number(fromNode.x ?? 0)
        const fromY = Number(fromNode.y ?? 0)
        const toX = Number(toNode.x ?? 0)
        const toY = Number(toNode.y ?? 0)
        const fromRight = fromX + root.nodeWidth
        const toRight = toX + root.nodeWidth
        const fromCenterX = fromX + root.nodeWidth / 2
        const fromCenterY = fromY + root.nodeHeight / 2
        const toCenterX = toX + root.nodeWidth / 2
        const toCenterY = toY + root.nodeHeight / 2
        const separatedRight = toX >= fromRight
        const separatedLeft = toRight <= fromX
        const vertical = !separatedRight && !separatedLeft
        const primaryDirection = vertical
            ? (toCenterY >= fromCenterY ? 1 : -1)
            : (separatedRight ? 1 : -1)
        const laneOffset = root.edgeLaneOffset(
            edge, vertical, primaryDirection)
        const candidates = []
        const bounds = root.rawNodeBounds()

        if (!vertical) {
            const rightward = separatedRight
            const direction = rightward ? 1 : -1
            const x0 = fromX + (rightward ? root.nodeWidth : 0)
            const y0 = fromCenterY
            const x3 = toX + (rightward ? 0 : root.nodeWidth)
            const y3 = toCenterY
            const targetLabelRun = Math.min(
                84, Math.max(60, Math.abs(x3 - x0) * 0.45))
            const baseCorridor = x3
                - direction * targetLabelRun
                + laneOffset * 0.5
            const corridorOffsets = [0, 32, -32, 64, -64, 120, -120]
            for (const offset of corridorOffsets) {
                const corridor = baseCorridor + offset
                candidates.push(root.routeFromPoints([
                    { x: x0, y: y0 },
                    { x: corridor, y: y0 },
                    { x: corridor, y: y3 },
                    { x: x3, y: y3 }
                ], false, direction))
            }

            const stub = 36
            const fromStub = x0 + direction * stub
            const toStub = x3 - direction * stub
            const middleY = (y0 + y3) / 2
            const yLanes = [
                bounds.minY - 52 - Math.abs(laneOffset) * 0.25,
                bounds.maxY + 52 + Math.abs(laneOffset) * 0.25,
                middleY + 120,
                middleY - 120,
                middleY + 220,
                middleY - 220
            ]
            for (const laneY of yLanes) {
                candidates.push(root.routeFromPoints([
                    { x: x0, y: y0 },
                    { x: fromStub, y: y0 },
                    { x: fromStub, y: laneY },
                    { x: toStub, y: laneY },
                    { x: toStub, y: y3 },
                    { x: x3, y: y3 }
                ], false, direction))
            }

            // If an intervening node blocks both horizontal stubs, switch to
            // top/bottom ports and route through an outer horizontal lane.
            const horizontalPortLanes = [
                {
                    sourceY: fromY,
                    targetY: toY,
                    laneY: bounds.minY - 52 - Math.abs(laneOffset) * 0.25
                },
                {
                    sourceY: fromY + root.nodeHeight,
                    targetY: toY + root.nodeHeight,
                    laneY: bounds.maxY + 52 + Math.abs(laneOffset) * 0.25
                }
            ]
            for (const portLane of horizontalPortLanes) {
                candidates.push(root.routeFromPoints([
                    { x: fromCenterX, y: portLane.sourceY },
                    { x: fromCenterX, y: portLane.laneY },
                    { x: toCenterX, y: portLane.laneY },
                    { x: toCenterX, y: portLane.targetY }
                ], false, direction))
            }

            // Backward/long connections may still cut across an occupied
            // corridor even when they avoid every node. Give the router two
            // full-perimeter candidates that enter the target from the graph's
            // outer side, matching the "reroute around the tree" pattern used
            // by mature node editors without inventing a semantic IR node.
            const outerX = rightward
                ? bounds.maxX + 52 : bounds.minX - 52
            const targetOuterX = rightward ? toRight : toX
            const perimeterPortLanes = [
                {
                    sourceY: fromY,
                    laneY: bounds.minY - 52
                },
                {
                    sourceY: fromY + root.nodeHeight,
                    laneY: bounds.maxY + 52
                }
            ]
            for (const portLane of perimeterPortLanes) {
                candidates.push(root.routeFromPoints([
                    { x: fromCenterX, y: portLane.sourceY },
                    { x: fromCenterX, y: portLane.laneY },
                    { x: outerX, y: portLane.laneY },
                    { x: outerX, y: toCenterY },
                    { x: targetOuterX, y: toCenterY }
                ], false, direction))
            }
        } else {
            const downward = toCenterY >= fromCenterY
            const direction = downward ? 1 : -1
            const x0 = fromCenterX
            const y0 = fromY + (downward ? root.nodeHeight : 0)
            const x3 = toCenterX
            const y3 = toY + (downward ? 0 : root.nodeHeight)
            const baseCorridor = (y0 + y3) / 2 + laneOffset
            const corridorOffsets = [0, 48, -48, 96, -96, 160, -160]
            for (const offset of corridorOffsets) {
                const corridor = baseCorridor + offset
                candidates.push(root.routeFromPoints([
                    { x: x0, y: y0 },
                    { x: x0, y: corridor },
                    { x: x3, y: corridor },
                    { x: x3, y: y3 }
                ], true, direction))
            }

            const stub = 36
            const fromStub = y0 + direction * stub
            const toStub = y3 - direction * stub
            const middleX = (x0 + x3) / 2
            const xLanes = [
                bounds.minX - 52 - Math.abs(laneOffset) * 0.25,
                bounds.maxX + 52 + Math.abs(laneOffset) * 0.25,
                middleX + 120,
                middleX - 120,
                middleX + 220,
                middleX - 220
            ]
            for (const laneX of xLanes) {
                candidates.push(root.routeFromPoints([
                    { x: x0, y: y0 },
                    { x: x0, y: fromStub },
                    { x: laneX, y: fromStub },
                    { x: laneX, y: toStub },
                    { x: x3, y: toStub },
                    { x: x3, y: y3 }
                ], true, direction))
            }

            // Same-column stacks can have an intermediate node directly in
            // front of the top/bottom port. In that case, switch to a side
            // port before taking the outer lane instead of drawing through it.
            const verticalPortLanes = [
                {
                    sourceX: fromX,
                    targetX: toX,
                    laneX: bounds.minX - 52 - Math.abs(laneOffset) * 0.25
                },
                {
                    sourceX: fromRight,
                    targetX: toRight,
                    laneX: bounds.maxX + 52 + Math.abs(laneOffset) * 0.25
                }
            ]
            for (const portLane of verticalPortLanes) {
                candidates.push(root.routeFromPoints([
                    { x: portLane.sourceX, y: fromCenterY },
                    { x: portLane.laneX, y: fromCenterY },
                    { x: portLane.laneX, y: toCenterY },
                    { x: portLane.targetX, y: toCenterY }
                ], true, direction))
            }
        }

        let bestRoute = null
        let bestScore = Number.POSITIVE_INFINITY
        for (const candidate of candidates) {
            if (!candidate)
                continue
            const score = root.routeScore(
                candidate, edge, occupiedRoutes)
            if (score < bestScore) {
                bestRoute = candidate
                bestScore = score
            }
        }
        if (bestRoute) {
            bestRoute.edgeId = String(edge?.id ?? "")
            bestRoute.fromId = String(edge?.from ?? "")
            bestRoute.toId = String(edge?.to ?? "")
        }
        return bestRoute
    }

    function buildEdgeRouteCache(): var {
        const cache = ({})
        const occupiedRoutes = []
        const graph = root.graph
        for (const edge of (graph?.edges ?? [])) {
            const edgeId = String(edge?.id ?? "")
            if (edgeId.length === 0)
                continue
            const route = root.edgeRoute(edge, occupiedRoutes)
            cache[edgeId] = route
            if (route)
                occupiedRoutes.push(route)
        }
        return cache
    }

    function routeForEdge(edge): var {
        const edgeId = String(edge?.id ?? "")
        if (edgeId.length === 0)
            return root.edgeRoute(edge)
        const cached = root.edgeRouteCache[edgeId]
        return cached ?? root.edgeRoute(edge)
    }

    function routeDiagnostics(): var {
        const occupiedRoutes = []
        let collisions = 0
        let crossings = 0
        let overlapLength = 0
        let maxBends = 0
        let totalLength = 0
        let routedEdges = 0

        for (const edge of root.edges) {
            const route = root.routeForEdge(edge)
            if (!route)
                continue
            routedEdges += 1
            collisions += root.routeCollisionCount(route, edge)
            crossings += root.routeCrossingCount(route, occupiedRoutes)
            overlapLength += root.routeOverlapLength(
                route, edge, occupiedRoutes)
            maxBends = Math.max(
                maxBends,
                Math.max(0, (route.points?.length ?? 2) - 2))
            totalLength += root.routeLength(route)
            occupiedRoutes.push(route)
        }

        return {
            style: "smooth-step-lane-v2",
            edges: root.edges.length,
            routedEdges: routedEdges,
            collisions: collisions,
            crossings: crossings,
            overlapLength: Math.round(overlapLength),
            maxBends: maxBends,
            totalLength: Math.round(totalLength)
        }
    }

    function graphBounds(): var {
        if (root.nodes.length === 0)
            return {
                x: 0, y: 0,
                width: root.worldWidth,
                height: root.worldHeight
            }

        let minX = Number.POSITIVE_INFINITY
        let minY = Number.POSITIVE_INFINITY
        let maxX = Number.NEGATIVE_INFINITY
        let maxY = Number.NEGATIVE_INFINITY

        for (const node of root.nodes) {
            const x = Number(node?.x ?? 0)
            const y = Number(node?.y ?? 0)
            minX = Math.min(minX, x)
            minY = Math.min(minY, y)
            maxX = Math.max(maxX, x + root.nodeWidth)
            maxY = Math.max(maxY, y + root.nodeHeight)
        }

        // Fit the same geometry that the renderer and hit-test use.
        for (const edge of root.edges) {
            const route = root.routeForEdge(edge)
            if (!route)
                continue
            const bounds = root.routeBounds(route)
            minX = Math.min(minX, bounds.minX)
            minY = Math.min(minY, bounds.minY)
            maxX = Math.max(maxX, bounds.maxX)
            maxY = Math.max(maxY, bounds.maxY)
        }

        return {
            x: minX,
            y: minY,
            width: Math.max(1, maxX - minX),
            height: Math.max(1, maxY - minY)
        }
    }

    function pointSegmentDistance(
        px: real, py: real,
        ax: real, ay: real,
        bx: real, by: real
    ): real {
        const dx = bx - ax
        const dy = by - ay
        const lengthSquared = dx * dx + dy * dy
        if (lengthSquared <= 0.0001) {
            const sx = px - ax
            const sy = py - ay
            return Math.sqrt(sx * sx + sy * sy)
        }
        const t = Math.max(0, Math.min(1,
            ((px - ax) * dx + (py - ay) * dy) / lengthSquared))
        const qx = ax + t * dx
        const qy = ay + t * dy
        const sx = px - qx
        const sy = py - qy
        return Math.sqrt(sx * sx + sy * sy)
    }

    function edgeDistance(edge, px: real, py: real): real {
        const route = root.routeForEdge(edge)
        const points = route?.points ?? []
        if (points.length < 2)
            return 1e9

        let best = 1e9
        for (let index = 1; index < points.length; ++index) {
            best = Math.min(best, root.pointSegmentDistance(
                px, py,
                points[index - 1].x, points[index - 1].y,
                points[index].x, points[index].y))
        }
        return best
    }

    function fitGraph(): void {
        if (root.width <= 0 || root.height <= 0)
            return
        const bounds = root.graphBounds()
        const margin = 28
        const availableWidth = Math.max(1, root.width - margin * 2)
        const availableHeight = Math.max(1, root.height - margin * 2)
        const nextZoom = Math.max(
            CodeWorkflowSession.minimumZoom,
            Math.min(
            1.4,
            availableWidth / Math.max(1, bounds.width),
            availableHeight / Math.max(1, bounds.height)))
        const nextX = (root.width - bounds.width * nextZoom) / 2
            - bounds.x * nextZoom
        const nextY = (root.height - bounds.height * nextZoom) / 2
            - bounds.y * nextZoom
        CodeWorkflowSession.setViewport(nextX, nextY, nextZoom)
    }

    function revealNode(nodeId: string): void {
        const node = root.nodeById(nodeId)
        if (!node || root.width <= 0 || root.height <= 0)
            return

        const zoom = Math.max(0.0001, CodeWorkflowSession.zoom)
        const margin = 34
        const left = CodeWorkflowSession.panX
            + Number(node.x ?? 0) * zoom
        const top = CodeWorkflowSession.panY
            + Number(node.y ?? 0) * zoom
        const right = left + root.nodeWidth * zoom
        const bottom = top + root.nodeHeight * zoom
        let nextX = CodeWorkflowSession.panX
        let nextY = CodeWorkflowSession.panY

        if (left < margin)
            nextX += margin - left
        else if (right > root.width - margin)
            nextX -= right - (root.width - margin)
        if (top < margin)
            nextY += margin - top
        else if (bottom > root.height - margin)
            nextY -= bottom - (root.height - margin)

        if (Math.abs(nextX - CodeWorkflowSession.panX) > 0.5
                || Math.abs(nextY - CodeWorkflowSession.panY) > 0.5)
            CodeWorkflowSession.setViewport(
                nextX, nextY, CodeWorkflowSession.zoom)
    }

    function revealEdge(edgeId: string): void {
        const edge = root.edges.find(item =>
            String(item?.id ?? "") === String(edgeId ?? ""))
        const route = root.routeForEdge(edge)
        if (!edge || !route || root.width <= 0 || root.height <= 0)
            return

        const routeBounds = root.routeBounds(route)
        const minX = routeBounds.minX
        const minY = routeBounds.minY
        const maxX = routeBounds.maxX
        const maxY = routeBounds.maxY
        const boundsWidth = Math.max(1, maxX - minX)
        const boundsHeight = Math.max(1, maxY - minY)
        const margin = 40
        const availableWidth = Math.max(1, root.width - margin * 2)
        const availableHeight = Math.max(1, root.height - margin * 2)
        const currentZoom = Math.max(
            CodeWorkflowSession.minimumZoom,
            CodeWorkflowSession.zoom)
        const nextZoom = Math.max(
            CodeWorkflowSession.minimumZoom,
            Math.min(
                currentZoom,
                availableWidth / boundsWidth,
                availableHeight / boundsHeight))

        if (Math.abs(nextZoom - currentZoom) > 0.001) {
            CodeWorkflowSession.setViewport(
                (root.width - boundsWidth * nextZoom) / 2
                    - minX * nextZoom,
                (root.height - boundsHeight * nextZoom) / 2
                    - minY * nextZoom,
                nextZoom)
            return
        }

        const left = CodeWorkflowSession.panX + minX * nextZoom
        const top = CodeWorkflowSession.panY + minY * nextZoom
        const right = CodeWorkflowSession.panX + maxX * nextZoom
        const bottom = CodeWorkflowSession.panY + maxY * nextZoom
        let nextX = CodeWorkflowSession.panX
        let nextY = CodeWorkflowSession.panY
        if (left < margin)
            nextX += margin - left
        else if (right > root.width - margin)
            nextX -= right - (root.width - margin)
        if (top < margin)
            nextY += margin - top
        else if (bottom > root.height - margin)
            nextY -= bottom - (root.height - margin)

        if (Math.abs(nextX - CodeWorkflowSession.panX) > 0.5
                || Math.abs(nextY - CodeWorkflowSession.panY) > 0.5)
            CodeWorkflowSession.setViewport(nextX, nextY, nextZoom)
    }

    function revealPrimarySelection(): void {
        if (CodeWorkflowSession.selectedEdgeId.length > 0) {
            root.revealEdge(CodeWorkflowSession.selectedEdgeId)
            return
        }
        if (CodeWorkflowSession.selectedSemanticAnchor.length === 0)
            root.revealNode(CodeWorkflowSession.selectedNodeId)
    }

    function edgeStrokeWidth(selected: bool, highlighted: bool): real {
        const screenWidth = selected ? 3.6 : highlighted ? 3.0 : 2.4
        const zoom = Math.max(
            CodeWorkflowSession.minimumZoom,
            CodeWorkflowSession.zoom)
        return screenWidth / zoom
    }

    function nodeAtWorld(px: real, py: real): bool {
        return root.nodes.some(node => {
            const x = Number(node.x ?? 0)
            const y = Number(node.y ?? 0)
            return px >= x && px <= x + root.nodeWidth
                && py >= y && py <= y + root.nodeHeight
        })
    }

    function viewportContains(screenX: real, screenY: real): bool {
        return screenX >= 0 && screenY >= 0
            && screenX <= root.width && screenY <= root.height
    }

    function itemPointInsideViewport(
        item, localX: real, localY: real
    ): bool {
        if (!item)
            return false
        const mapped = item.mapToItem(root, localX, localY)
        return root.viewportContains(mapped.x, mapped.y)
    }

    function edgeAt(screenX: real, screenY: real): string {
        if (!root.viewportContains(screenX, screenY))
            return ""
        const zoom = Math.max(0.0001, CodeWorkflowSession.zoom)
        const worldX = (screenX - CodeWorkflowSession.panX) / zoom
        const worldY = (screenY - CodeWorkflowSession.panY) / zoom
        if (root.nodeAtWorld(worldX, worldY))
            return ""

        const tolerance = 8 / zoom
        let bestId = ""
        let bestDistance = tolerance
        for (const edge of root.edges) {
            const distance = root.edgeDistance(edge, worldX, worldY)
            if (distance <= bestDistance) {
                bestDistance = distance
                bestId = String(edge.id ?? "")
            }
        }
        return bestId
    }

    function accentForKind(kind: string): color {
        if (kind === "service")
            return Appearance.colors.colSecondary
        if (kind === "event" || kind === "action")
            return Appearance.colors.colTertiary
        if (kind === "lifecycle")
            return Appearance.colors.colPrimary
        if (kind === "binding")
            return Appearance.colors.colPrimary
        return Appearance.colors.colOnLayer1
    }

    function edgeColor(kind: string): color {
        if (kind === "event")
            return Appearance.colors.colTertiary
        if (kind === "action")
            return Appearance.colors.colSecondary
        if (kind === "data" || kind === "lifecycle")
            return Appearance.colors.colPrimary
        return Appearance.colors.colOutlineVariant
    }

    function edgeInk(kind: string, emphasized: bool): color {
        const base = root.edgeColor(kind)
        const readable = ColorUtils.readableAccentInk(
            base,
            Appearance.colors.colLayer0,
            emphasized ? 4.5 : 3.0,
            Appearance.colors.colOnLayer0)
        return readable
    }

    DragHandler {
        id: pan
        target: null
        acceptedButtons: Qt.MiddleButton
        property real baseX: 0
        property real baseY: 0

        onActiveChanged: {
            if (active) {
                baseX = CodeWorkflowSession.panX
                baseY = CodeWorkflowSession.panY
            }
        }
        onActiveTranslationChanged: {
            if (active)
                CodeWorkflowSession.setViewport(
                    baseX + activeTranslation.x,
                    baseY + activeTranslation.y,
                    CodeWorkflowSession.zoom)
        }
    }

    WheelHandler {
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const oldZoom = CodeWorkflowSession.zoom
            const delta = event.pixelDelta.y !== 0
                ? event.pixelDelta.y * 3
                : event.angleDelta.y
            const nextZoom = Math.max(
                CodeWorkflowSession.minimumZoom,
                Math.min(
                    CodeWorkflowSession.maximumZoom,
                    oldZoom * Math.pow(1.0015, delta)))
            const graphX = (event.x - CodeWorkflowSession.panX) / oldZoom
            const graphY = (event.y - CodeWorkflowSession.panY) / oldZoom
            CodeWorkflowSession.setViewport(
                event.x - graphX * nextZoom,
                event.y - graphY * nextZoom,
                nextZoom)
            event.accepted = true
        }
    }

    HoverHandler {
        id: edgeHover
        target: null

        onPointChanged: root.hoveredEdgeId = root.edgeAt(
            point.position.x, point.position.y)
        onHoveredChanged: {
            if (!hovered)
                root.hoveredEdgeId = ""
        }
    }

    TapHandler {
        id: edgeTap
        target: null
        acceptedButtons: Qt.LeftButton

        onTapped: (eventPoint, button) => {
            const edgeId = root.edgeAt(
                eventPoint.position.x, eventPoint.position.y)
            if (edgeId.length > 0)
                CodeWorkflowSession.selectEdge(edgeId)
        }
    }

    Connections {
        target: CodeWorkflowSession

        function onSubflowTargetIdChanged(): void {
            Qt.callLater(root.fitGraph)
        }

        function onSelectedNodeIdChanged(): void {
            Qt.callLater(root.revealPrimarySelection)
        }

        function onSelectedEdgeIdChanged(): void {
            Qt.callLater(root.revealPrimarySelection)
        }
    }

    PinchHandler {
        id: pinch
        target: null
        property real baseZoom: 1
        property point pivot: Qt.point(0, 0)

        onActiveChanged: {
            if (active) {
                baseZoom = CodeWorkflowSession.zoom
                pivot = Qt.point(
                    (centroid.position.x - CodeWorkflowSession.panX)
                        / CodeWorkflowSession.zoom,
                    (centroid.position.y - CodeWorkflowSession.panY)
                        / CodeWorkflowSession.zoom)
            }
        }

        function updateViewport(): void {
            if (!active)
                return
            const nextZoom = Math.max(
                CodeWorkflowSession.minimumZoom,
                Math.min(
                    CodeWorkflowSession.maximumZoom,
                    baseZoom * activeScale))
            CodeWorkflowSession.setViewport(
                centroid.position.x - pivot.x * nextZoom,
                centroid.position.y - pivot.y * nextZoom,
                nextZoom)
        }

        onActiveScaleChanged: updateViewport()
        onActiveTranslationChanged: updateViewport()
    }

    Rectangle {
        anchors.fill: parent
        color: Appearance.colors.colLayer0
        z: -2
    }

    Item {
        id: world
        width: root.worldWidth
        height: root.worldHeight
        x: CodeWorkflowSession.panX
        y: CodeWorkflowSession.panY
        scale: CodeWorkflowSession.zoom
        transformOrigin: Item.TopLeft

        Repeater {
            model: root.edges

            delegate: Shape {
                id: edgeShape
                required property var modelData

                readonly property var fromNode: root.nodeById(modelData.from)
                readonly property var toNode: root.nodeById(modelData.to)
                readonly property bool selectedEdge:
                    CodeWorkflowSession.selectedEdgeId === modelData.id
                readonly property bool hoveredEdge:
                    root.hoveredEdgeId === modelData.id
                readonly property bool highlighted:
                    selectedEdge
                    || hoveredEdge
                    || (CodeWorkflowSession.selectedEdgeId.length === 0
                        && CodeWorkflowSession.selectedSemanticAnchor.length === 0
                        && (CodeWorkflowSession.selectedNodeId
                                === modelData.from
                            || CodeWorkflowSession.selectedNodeId
                                === modelData.to))

                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                antialiasing: true
                asynchronous: false
                z: 0

                ShapePath {
                    id: edgePath
                    readonly property var route:
                        root.routeForEdge(edgeShape.modelData)

                    strokeColor: root.edgeInk(
                        edgeShape.modelData.kind,
                        edgeShape.highlighted)
                    strokeWidth: root.edgeStrokeWidth(
                        edgeShape.selectedEdge,
                        edgeShape.highlighted)
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    fillColor: "transparent"
                    PathSvg {
                        path: edgePath.route?.svg ?? ""
                    }
                }

                ShapePath {
                    id: arrowPath
                    readonly property var route: edgePath.route
                    readonly property var points: route?.points ?? []
                    readonly property var tipPoint: points.length > 0
                        ? points[points.length - 1] : ({ x: 0, y: 0 })
                    readonly property var previousPoint: points.length > 1
                        ? points[points.length - 2] : ({ x: -1, y: 0 })
                    readonly property real tipX: Number(tipPoint.x ?? 0)
                    readonly property real tipY: Number(tipPoint.y ?? 0)
                    readonly property real tangentX:
                        tipX - Number(previousPoint.x ?? tipX - 1)
                    readonly property real tangentY:
                        tipY - Number(previousPoint.y ?? tipY)
                    readonly property real tangentLength:
                        Math.max(0.001, Math.sqrt(
                            tangentX * tangentX
                            + tangentY * tangentY))
                    readonly property real unitX: tangentX / tangentLength
                    readonly property real unitY: tangentY / tangentLength
                    readonly property real screenArrowLength: 10
                    readonly property real screenArrowHalfWidth: 5
                    readonly property real worldArrowLength:
                        screenArrowLength / Math.max(
                            CodeWorkflowSession.minimumZoom,
                            CodeWorkflowSession.zoom)
                    readonly property real worldArrowHalfWidth:
                        screenArrowHalfWidth / Math.max(
                            CodeWorkflowSession.minimumZoom,
                            CodeWorkflowSession.zoom)
                    readonly property real backX:
                        tipX - unitX * worldArrowLength
                    readonly property real backY:
                        tipY - unitY * worldArrowLength
                    readonly property color ink: root.edgeInk(
                        edgeShape.modelData.kind,
                        edgeShape.highlighted)

                    strokeColor: "transparent"
                    fillColor: ink
                    startX: tipX
                    startY: tipY

                    PathLine {
                        x: arrowPath.backX - arrowPath.unitY * arrowPath.worldArrowHalfWidth
                        y: arrowPath.backY + arrowPath.unitX * arrowPath.worldArrowHalfWidth
                    }
                    PathLine {
                        x: arrowPath.backX + arrowPath.unitY * arrowPath.worldArrowHalfWidth
                        y: arrowPath.backY - arrowPath.unitX * arrowPath.worldArrowHalfWidth
                    }
                    PathLine {
                        x: arrowPath.tipX
                        y: arrowPath.tipY
                    }
                }
            }
        }

        Repeater {
            model: root.edges

            delegate: Rectangle {
                id: edgeLabel
                required property var modelData

                readonly property var fromNode: root.nodeById(modelData.from)
                readonly property var toNode: root.nodeById(modelData.to)
                readonly property var route:
                    root.routeForEdge(modelData)
                readonly property real midX:
                    Number(route?.labelX ?? 0)
                readonly property real midY:
                    Number(route?.labelY ?? 0)
                readonly property real labelWidthLimit:
                    route?.labelHorizontal === true
                        ? Math.max(24, Number(route?.labelSpan ?? 150) - 20)
                        : 150
                readonly property bool hovered:
                    (edgeLabelHover.hovered
                        && root.itemPointInsideViewport(
                            edgeLabel,
                            edgeLabelHover.point.position.x,
                            edgeLabelHover.point.position.y))
                    || root.hoveredEdgeId === String(modelData.id ?? "")

                visible: fromNode !== null
                    && toNode !== null
                    && String(modelData.label ?? "").length > 0
                x: midX - width / 2
                y: midY - height / 2
                implicitWidth: Math.min(
                    150,
                    edgeLabel.labelWidthLimit,
                    edgeLabelText.implicitWidth + 12)
                implicitHeight: edgeLabelText.implicitHeight + 6
                radius: implicitHeight / 2
                color: Appearance.colors.colLayer0
                border.width: 1
                border.color: ColorUtils.applyAlpha(
                    root.edgeInk(modelData.kind, false), 0.72)
                z: 0.5

                HoverHandler {
                    id: edgeLabelHover
                    target: edgeLabel
                }

                GraphText {
                    id: edgeLabelText
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    verticalAlignment: Text.AlignVCenter
                    text: String(edgeLabel.modelData.label ?? "")
                    color: root.edgeInk(
                        edgeLabel.modelData.kind, true)
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                StyledToolTip {
                    text: String(edgeLabel.modelData.label ?? "")
                }
            }
        }

        Repeater {
            model: root.nodes

            delegate: Rectangle {
                id: node
                required property var modelData

                readonly property bool selected:
                    CodeWorkflowSession.selectedEdgeId.length === 0
                    && CodeWorkflowSession.selectedSemanticAnchor.length === 0
                    && CodeWorkflowSession.selectedNodeId === modelData.id
                readonly property color accent:
                    root.accentForKind(modelData.kind)
                readonly property color foreground: selected
                    ? Appearance.colors.colOnPrimaryContainer
                    : Appearance.colors.colOnLayer1
                readonly property color subtext: selected
                    ? ColorUtils.readableSubtext(
                        Appearance.colors.colOnPrimaryContainer,
                        Appearance.colors.colPrimaryContainer,
                        0.78)
                    : Appearance.colors.colSubtext
                readonly property color portInk:
                    ColorUtils.readableAccentInk(
                        accent,
                        Appearance.colors.colLayer0,
                        3.0,
                        Appearance.colors.colOnLayer0)

                x: Number(modelData.x ?? 0)
                y: Number(modelData.y ?? 0)
                width: root.nodeWidth
                height: root.nodeHeight
                radius: Appearance.rounding.normal
                color: selected
                    ? Appearance.colors.colPrimaryContainer
                    : Appearance.colors.colLayer1
                border.width: selected || activeFocus ? 2 : 1
                border.color: selected || activeFocus
                    ? accent
                    : Appearance.colors.colOutlineVariant
                z: 1
                activeFocusOnTab: true

                Accessible.role: Accessible.Button
                Accessible.name: modelData.title
                    + " · " + modelData.kind
                Accessible.description:
                    modelData.description ?? "Read-only workflow node"
                Accessible.focusable: true
                Accessible.onPressAction: {
                    CodeWorkflowSession.selectNode(node.modelData.id)
                }

                TapHandler {
                    onTapped: (eventPoint, button) => {
                        if (!root.itemPointInsideViewport(
                                node,
                                eventPoint.position.x,
                                eventPoint.position.y))
                            return
                        CodeWorkflowSession.selectNode(node.modelData.id)
                        node.forceActiveFocus()
                    }
                }

                Keys.onPressed: event => {
                    if (event.key !== Qt.Key_Return
                            && event.key !== Qt.Key_Enter
                            && event.key !== Qt.Key_Space) {
                        event.accepted = false
                        return
                    }

                    CodeWorkflowSession.selectNode(node.modelData.id)
                    event.accepted = true
                }

                ColumnLayout {
                    id: nodeContent
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 3
                    clip: true

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Rectangle {
                            implicitWidth: kindLabel.implicitWidth + 10
                            implicitHeight: kindLabel.implicitHeight + 4
                            radius: implicitHeight / 2
                            color: Appearance.colors.colLayer2

                            GraphText {
                                id: kindLabel
                                anchors.centerIn: parent
                                text: String(node.modelData.kind ?? "node").toUpperCase()
                                color: ColorUtils.readableAccentInk(
                                    node.accent,
                                    Appearance.colors.colLayer2,
                                    4.5,
                                    Appearance.colors.colOnLayer1)
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.weight: Font.DemiBold
                            }
                        }

                        GraphText {
                            Layout.fillWidth: true
                            text: node.modelData.title ?? node.modelData.id
                            color: node.foreground
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            visible:
                                (node.modelData.subflowTargetId ?? "").length > 0
                                && node.modelData.subflowTargetId
                                    !== CodeWorkflowSession.subflowTargetId
                            implicitWidth: 25
                            implicitHeight: 25
                            radius: implicitHeight / 2
                            color: Appearance.colors.colLayer2
                            border.width: subflowAction.activeFocus ? 1 : 0
                            border.color: node.accent

                            MaterialSymbol {
                                anchors.centerIn: parent
                                textRenderType: Text.QtRendering
                                text: "arrow_outward"
                                iconSize: Appearance.font.pixelSize.small
                                color: node.portInk
                            }

                            MouseArea {
                                id: subflowAction
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                activeFocusOnTab: parent.visible
                                Accessible.role: Accessible.Button
                                Accessible.name: "Open "
                                    + String(node.modelData.title ?? "node")
                                    + " subflow"
                                Accessible.focusable: parent.visible
                                Accessible.onPressAction:
                                    CodeWorkflowSession.openSubflow(
                                        node.modelData.subflowTargetId)

                                onClicked: mouse => {
                                    mouse.accepted = true
                                    if (!root.itemPointInsideViewport(
                                            subflowAction,
                                            mouse.x, mouse.y))
                                        return
                                    CodeWorkflowSession.openSubflow(
                                        node.modelData.subflowTargetId)
                                }

                                Keys.onPressed: event => {
                                    if (event.key !== Qt.Key_Return
                                            && event.key !== Qt.Key_Enter
                                            && event.key !== Qt.Key_Space) {
                                        event.accepted = false
                                        return
                                    }
                                    CodeWorkflowSession.openSubflow(
                                        node.modelData.subflowTargetId)
                                    event.accepted = true
                                }
                            }
                        }
                    }

                    GraphText {
                        Layout.fillWidth: true
                        Layout.maximumWidth: node.width - 20
                        text: node.modelData.description ?? ""
                        color: node.subtext
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        elide: Text.ElideRight
                    }

                    GraphText {
                        Layout.fillWidth: true
                        Layout.maximumWidth: node.width - 20
                        text: node.modelData.sourceNeedle ?? ""
                        color: node.subtext
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        elide: Text.ElideMiddle
                    }
                }

                Rectangle {
                    x: -4
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8
                    height: 8
                    radius: 4
                    color: node.portInk
                }

                Rectangle {
                    x: parent.width - 4
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8
                    height: 8
                    radius: 4
                    color: node.portInk
                }
            }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 10
        implicitWidth: hint.implicitWidth + 16
        implicitHeight: hint.implicitHeight + 8
        radius: Appearance.rounding.small
        color: Appearance.colors.colLayer2

        StyledText {
            id: hint
            anchors.centerIn: parent
            text: (root.graph?.title ?? "Workflow")
                + " · " + root.nodes.length + " nodes · "
                + Math.round(CodeWorkflowSession.zoom * 100) + "%"
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smallest
        }
    }
}
