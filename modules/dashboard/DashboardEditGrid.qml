import QtQuick
import qs.modules.common
import qs.modules.common.functions

Canvas {
    id: root

    property int gridSize: 24
    property string gridStyle: "dots"
    property color accentColor: Appearance.colors.colPrimary
    property real gridOpacity: 0.16

    antialiasing: true

    onGridSizeChanged: requestPaint()
    onGridStyleChanged: requestPaint()
    onAccentColorChanged: requestPaint()
    onGridOpacityChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        if (width <= 0 || height <= 0 || gridSize <= 0)
            return

        const step = Math.max(8, gridSize)
        ctx.strokeStyle = accentColor
        ctx.fillStyle = accentColor
        ctx.globalAlpha = gridOpacity

        if (gridStyle === "lines") {
            ctx.lineWidth = 1
            for (let x = 0.5; x <= width; x += step) {
                ctx.beginPath()
                ctx.moveTo(x, 0)
                ctx.lineTo(x, height)
                ctx.stroke()
            }
            for (let y = 0.5; y <= height; y += step) {
                ctx.beginPath()
                ctx.moveTo(0, y)
                ctx.lineTo(width, y)
                ctx.stroke()
            }
        } else if (gridStyle === "cross") {
            ctx.lineWidth = 1
            const arm = Math.max(2, Math.min(4, step * 0.16))
            for (let x = 0; x <= width; x += step) {
                for (let y = 0; y <= height; y += step) {
                    ctx.beginPath()
                    ctx.moveTo(x - arm, y)
                    ctx.lineTo(x + arm, y)
                    ctx.moveTo(x, y - arm)
                    ctx.lineTo(x, y + arm)
                    ctx.stroke()
                }
            }
        } else {
            const radius = Math.max(1, Math.min(2.2, step * 0.055))
            for (let x = 0; x <= width; x += step) {
                for (let y = 0; y <= height; y += step) {
                    ctx.beginPath()
                    ctx.arc(x, y, radius, 0, Math.PI * 2)
                    ctx.fill()
                }
            }
        }

        ctx.globalAlpha = 1
    }
}
