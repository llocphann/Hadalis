import QtQuick
import qs.modules.common

Item {
    id: root

    property var samples: []
    property real maxValue: 100
    property color lineColor: Appearance.colors.colPrimary
    property bool fillGraph: true
    property bool dotted: false
    property int historyCapacity: 60

    implicitHeight: 38

    function safeSamples(): var {
        const source = Array.isArray(root.samples) ? root.samples : []
        const values = []
        for (const sample of source) {
            if (sample === null || sample === undefined) {
                values.push(null)
                continue
            }
            const value = Number(sample)
            values.push(Number.isFinite(value)
                ? Math.max(0, value) : null)
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
    onDottedChanged: root.requestPaint()
    onHistoryCapacityChanged: root.requestPaint()
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

            if (!root.dotted) {
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
            }

            const values = root.safeSamples()
            if (values.length === 0
                    || !values.some(value => value !== null))
                return

            const denominator = Math.max(1, Number(root.maxValue))
            const pointX = index => values.length === 1
                ? w / 2
                : 1 + index * Math.max(0, w - 2)
                    / Math.max(1, values.length - 1)
            const pointY = value => h - Math.max(
                0, Math.min(1, value / denominator)) * (h - 2) - 1

            if (root.dotted) {
                const step = 4
                const capacity = Math.max(
                    1, values.length, root.historyCapacity)
                ctx.fillStyle = Qt.rgba(
                    root.lineColor.r, root.lineColor.g,
                    root.lineColor.b, 0.84)
                for (let x = 1; x < w - 1; x += step) {
                    const slot = Math.min(capacity - 1,
                        Math.floor(x * capacity / w))
                    const index = slot - (capacity - values.length)
                    if (index < 0)
                        continue
                    const value = values[index]
                    if (value === null)
                        continue
                    const top = pointY(value)
                    for (let y = h - 2; y >= top; y -= step)
                        ctx.fillRect(x, y, 1.5, 1.5)
                }
                return
            }

            if (root.fillGraph) {
                let segmentStart = -1
                for (let index = 0; index <= values.length; index++) {
                    const value = index < values.length
                        ? values[index] : null
                    if (value !== null && segmentStart < 0)
                        segmentStart = index
                    if (value !== null)
                        continue
                    if (segmentStart < 0)
                        continue

                    const segmentEnd = index - 1
                    ctx.beginPath()
                    ctx.moveTo(pointX(segmentStart), h)
                    for (let point = segmentStart;
                            point <= segmentEnd; point++)
                        ctx.lineTo(pointX(point), pointY(values[point]))
                    ctx.lineTo(pointX(segmentEnd), h)
                    ctx.closePath()
                    ctx.fillStyle = Qt.rgba(
                        root.lineColor.r,
                        root.lineColor.g,
                        root.lineColor.b,
                        0.16)
                    ctx.fill()
                    segmentStart = -1
                }
            }

            ctx.beginPath()
            let drawing = false
            for (let index = 0; index < values.length; index++) {
                const value = values[index]
                if (value === null) {
                    drawing = false
                    continue
                }
                const x = pointX(index)
                const y = pointY(value)
                if (!drawing) {
                    ctx.moveTo(x, y)
                    drawing = true
                } else {
                    ctx.lineTo(x, y)
                }
            }
            ctx.lineWidth = 1.5
            ctx.lineJoin = "round"
            ctx.lineCap = "round"
            ctx.strokeStyle = root.lineColor
            ctx.stroke()

            let lastIndex = values.length - 1
            while (lastIndex >= 0 && values[lastIndex] === null)
                lastIndex--
            if (lastIndex >= 0) {
                const lastX = pointX(lastIndex)
                const lastY = pointY(values[lastIndex])
                ctx.beginPath()
                ctx.arc(lastX, lastY, 2.2, 0, Math.PI * 2)
                ctx.fillStyle = root.lineColor
                ctx.fill()
            }
        }
    }
}
