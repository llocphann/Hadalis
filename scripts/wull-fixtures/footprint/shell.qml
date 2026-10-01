// Offscreen geometry diagnostic only: uses real unmodified AbyssCompanion.
import QtQuick
import Quickshell
import qs.modules.abyss.companion

ShellRoot {
    id: root

    Item {
        id: stage
        width: 1200
        height: 900
        AbyssCompanion { id: topBody; edge: "top"; x: 100; y: 100; reveal: 1 }
        AbyssCompanion { id: rightBody; edge: "right"; x: 400; y: 100; reveal: 1 }
        AbyssCompanion { id: bottomBody; edge: "bottom"; x: 100; y: 400; reveal: 1 }
        AbyssCompanion { id: leftBody; edge: "left"; x: 400; y: 400; reveal: 1 }
    }

    function inspect(host, edgeName): var {
        // Production currently contains one 76x92 WaterDropletBody plus a
        // differently-sized decorative cradle. Identify the clickable body
        // without changing the production source or depending on a new alias.
        const matches = host.children.filter(child =>
            child.width === 76 && child.height === 92)
        if (matches.length !== 1)
            return { edge: edgeName, valid: false }
        const body = matches[0]
        const corners = [
            body.mapToItem(host, 0, 0),
            body.mapToItem(host, body.width, 0),
            body.mapToItem(host, 0, body.height),
            body.mapToItem(host, body.width, body.height)
        ]
        const xs = corners.map(point => point.x)
        const ys = corners.map(point => point.y)
        const minX = Math.min(...xs), maxX = Math.max(...xs)
        const minY = Math.min(...ys), maxY = Math.max(...ys)
        const width = maxX - minX, height = maxY - minY
        return {
            edge: edgeName, valid: [minX, maxX, minY, maxY, width, height,
                host.width, host.height].every(Number.isFinite)
                && width > 0 && height > 0,
            host_width: host.width, host_height: host.height,
            body_width: body.width, body_height: body.height,
            mapped_x: Math.round(minX * 10) / 10,
            mapped_y: Math.round(minY * 10) / 10,
            mapped_width: Math.round(width * 10) / 10,
            mapped_height: Math.round(height * 10) / 10,
            within_host: minX >= -0.1 && minY >= -0.1
                && maxX <= host.width + 0.1 && maxY <= host.height + 0.1
        }
    }

    Timer {
        interval: 1000
        running: true
        onTriggered: {
            const rows = [
                root.inspect(topBody, "top"),
                root.inspect(rightBody, "right"),
                root.inspect(bottomBody, "bottom"),
                root.inspect(leftBody, "left")
            ]
            console.log("WULL_FOOTPRINT_GEOMETRY " + JSON.stringify(rows))
            Qt.quit()
        }
    }

    Timer {
        interval: 7000
        running: true
        onTriggered: {
            console.log("WULL_FOOTPRINT_TIMEOUT")
            Qt.quit()
        }
    }
}
