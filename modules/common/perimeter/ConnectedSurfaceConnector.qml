import QtQuick

Canvas {
    id: root

    required property var geometry
    property color fillColor: "white"
    property color strokeColor: "transparent"
    property real strokeWidth: geometry.borderWidth ?? 0

    readonly property bool horizontal: geometry.edge === "top" || geometry.edge === "bottom"
    readonly property real tangentExtent: horizontal ? width : height
    readonly property real sourceExtent: Math.max(0, Math.min(
        tangentExtent,
        geometry.connectorSourceExtent ?? geometry.connectorWidth ?? tangentExtent))

    x: geometry.connectorRect.x
    y: geometry.connectorRect.y
    width: geometry.connectorRect.width
    height: geometry.connectorRect.height
    visible: geometry.valid && geometry.progress > 0 && width > 0 && height > 0

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onSourceExtentChanged: requestPaint()
    onFillColorChanged: requestPaint()
    onStrokeColorChanged: requestPaint()
    onStrokeWidthChanged: requestPaint()

    Connections {
        target: root.geometry
        function onEdgeChanged(): void { root.requestPaint() }
    }

    onPaint: {
        const ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        if (!(width > 0 && height > 0))
            return

        const w = width
        const h = height
        const edge = geometry.edge
        const src = Math.max(0, Math.min(root.sourceExtent, root.tangentExtent))
        const shoulderA = 0.22
        const shoulderB = 0.78

        ctx.beginPath()
        if (edge === "top") {
            const left = (w - src) / 2
            const right = left + src
            ctx.moveTo(left, 0)
            ctx.lineTo(right, 0)
            ctx.bezierCurveTo(right, h * shoulderA, w, h * shoulderB, w, h)
            ctx.lineTo(0, h)
            ctx.bezierCurveTo(0, h * shoulderB, left, h * shoulderA, left, 0)
        } else if (edge === "bottom") {
            const left = (w - src) / 2
            const right = left + src
            ctx.moveTo(0, 0)
            ctx.lineTo(w, 0)
            ctx.bezierCurveTo(w, h * (1 - shoulderB), right, h * (1 - shoulderA), right, h)
            ctx.lineTo(left, h)
            ctx.bezierCurveTo(left, h * (1 - shoulderA), 0, h * (1 - shoulderB), 0, 0)
        } else if (edge === "left") {
            const top = (h - src) / 2
            const bottom = top + src
            ctx.moveTo(0, top)
            ctx.lineTo(0, bottom)
            ctx.bezierCurveTo(w * shoulderA, bottom, w * shoulderB, h, w, h)
            ctx.lineTo(w, 0)
            ctx.bezierCurveTo(w * shoulderB, 0, w * shoulderA, top, 0, top)
        } else {
            const top = (h - src) / 2
            const bottom = top + src
            ctx.moveTo(0, 0)
            ctx.lineTo(0, h)
            ctx.bezierCurveTo(w * (1 - shoulderB), h, w * (1 - shoulderA), bottom, w, bottom)
            ctx.lineTo(w, top)
            ctx.bezierCurveTo(w * (1 - shoulderA), top, w * (1 - shoulderB), 0, 0, 0)
        }
        ctx.closePath()
        ctx.fillStyle = root.fillColor
        ctx.fill()

        if (root.strokeWidth > 0) {
            ctx.strokeStyle = root.strokeColor
            ctx.lineWidth = root.strokeWidth
            ctx.stroke()
        }
    }
}
