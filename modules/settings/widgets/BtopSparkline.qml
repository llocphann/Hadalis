import QtQuick
import qs.modules.common

Item {
    id: root

    property var samples: []
    property real maxValue: 100
    property color lineColor: Appearance.colors.colPrimary
    property bool fillGraph: true

    implicitHeight: 38

    function safeSamples(): var {
        const source = Array.isArray(root.samples) ? root.samples : []
        const values = []
        for (const sample of source) {
            const value = Number(sample)
            if (Number.isFinite(value))
                values.push(Math.max(0, value))
        }
        return values
    }

    function requestPaint(): void {
        graph.requestPaint()
    }

    onSamplesChanged: root.requestPaint()
    onMaxValueChanged: root.requestPaint()
    onLineColorChanged: root.requestPaint()
    onFillGraphChanged: root.requestPaint()
    onWidthChanged: root.requestPaint()
    onHeightChanged: root.requestPaint()

    Canvas {
        id: graph
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            const ctx = getContext("2d")
            const w = width
            const h = height
            ctx.clearRect(0, 0, w, h)
            if (w <= 1 || h <= 1)
                return

            ctx.lineWidth = 1
            ctx.strokeStyle = Qt.rgba(
                Appearance.colors.colOutline.r,
                Appearance.colors.colOutline.g,
                Appearance.colors.colOutline.b,
                0.24)
            for (let i = 1; i < 4; i++) {
                const y = Math.round(h * i / 4) + 0.5
                ctx.beginPath()
                ctx.moveTo(0, y)
                ctx.lineTo(w, y)
                ctx.stroke()
            }

            const values = root.safeSamples()
            if (values.length === 0)
                return

            const denominator = Math.max(1, Number(root.maxValue))
            const pointX = index => values.length === 1
                ? w : index * w / Math.max(1, values.length - 1)
            const pointY = value => h - Math.max(
                0, Math.min(1, value / denominator)) * (h - 2) - 1

            if (root.fillGraph) {
                ctx.beginPath()
                ctx.moveTo(0, h)
                for (let index = 0; index < values.length; index++)
                    ctx.lineTo(pointX(index), pointY(values[index]))
                ctx.lineTo(w, h)
                ctx.closePath()
                ctx.fillStyle = Qt.rgba(
                    root.lineColor.r,
                    root.lineColor.g,
                    root.lineColor.b,
                    0.16)
                ctx.fill()
            }

            ctx.beginPath()
            for (let index = 0; index < values.length; index++) {
                const x = pointX(index)
                const y = pointY(values[index])
                if (index === 0)
                    ctx.moveTo(x, y)
                else
                    ctx.lineTo(x, y)
            }
            ctx.lineWidth = 1.5
            ctx.lineJoin = "round"
            ctx.lineCap = "round"
            ctx.strokeStyle = root.lineColor
            ctx.stroke()

            const lastX = pointX(values.length - 1)
            const lastY = pointY(values[values.length - 1])
            ctx.beginPath()
            ctx.arc(lastX, lastY, 2.2, 0, Math.PI * 2)
            ctx.fillStyle = root.lineColor
            ctx.fill()
        }
    }
}
