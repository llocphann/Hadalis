import QtQuick
import qs.modules.common

Canvas {
    id: root

    property var guides: []
    opacity: guides.length > 0 ? 1 : 0

    onGuidesChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    Behavior on opacity {
        enabled: Appearance.animationsEnabled
        NumberAnimation {
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve:
                Appearance.animation.elementMoveFast.bezierCurve
        }
    }

    function arrowHead(ctx, x, y, dx, dy): void {
        const size = 4
        const length = Math.max(0.001, Math.sqrt(dx * dx + dy * dy))
        const ux = dx / length
        const uy = dy / length
        const px = -uy
        const py = ux

        ctx.beginPath()
        ctx.moveTo(x, y)
        ctx.lineTo(
            x - ux * size + px * size * 0.7,
            y - uy * size + py * size * 0.7)
        ctx.lineTo(
            x - ux * size - px * size * 0.7,
            y - uy * size - py * size * 0.7)
        ctx.closePath()
        ctx.fill()
    }

    function drawDistanceLabel(ctx, x, y, value): void {
        const text = String(Math.max(0, Math.round(Number(value ?? 0)))) + " px"
        ctx.save()
        ctx.font = "500 10px sans-serif"
        const metrics = ctx.measureText(text)
        const width = metrics.width + 8
        const height = 16

        ctx.globalAlpha = 0.92
        ctx.fillStyle = Appearance.colors.colSurfaceContainerHighest
        ctx.fillRect(x - width / 2, y - height / 2, width, height)

        ctx.globalAlpha = 1
        ctx.fillStyle = Appearance.colors.colOnSurface
        ctx.textAlign = "center"
        ctx.textBaseline = "middle"
        ctx.fillText(text, x, y + 0.5)
        ctx.restore()
    }

    onPaint: {
        const ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        if (!root.guides || root.guides.length === 0)
            return

        ctx.strokeStyle = Appearance.colors.colPrimary
        ctx.fillStyle = Appearance.colors.colPrimary
        ctx.lineWidth = 1.25

        for (let i = 0; i < root.guides.length; ++i) {
            const guide = root.guides[i]
            const kind = String(guide?.kind ?? "")

            if (kind === "vertical") {
                ctx.save()
                ctx.setLineDash([4, 4])
                ctx.beginPath()
                ctx.moveTo(Number(guide.x), Number(guide.y1))
                ctx.lineTo(Number(guide.x), Number(guide.y2))
                ctx.stroke()
                ctx.restore()
                continue
            }

            if (kind === "horizontal") {
                ctx.save()
                ctx.setLineDash([4, 4])
                ctx.beginPath()
                ctx.moveTo(Number(guide.x1), Number(guide.y))
                ctx.lineTo(Number(guide.x2), Number(guide.y))
                ctx.stroke()
                ctx.restore()
                continue
            }

            if (kind === "diagonal") {
                ctx.save()
                ctx.globalAlpha = 0.72
                ctx.setLineDash([3, 5])
                ctx.beginPath()
                ctx.moveTo(Number(guide.x1), Number(guide.y1))
                ctx.lineTo(Number(guide.x2), Number(guide.y2))
                ctx.stroke()
                ctx.restore()
                continue
            }

            if (kind === "spacingH") {
                const x1 = Number(guide.x1)
                const x2 = Number(guide.x2)
                const y = Number(guide.y)
                ctx.beginPath()
                ctx.moveTo(x1, y)
                ctx.lineTo(x2, y)
                ctx.stroke()
                root.arrowHead(ctx, x1, y, 1, 0)
                root.arrowHead(ctx, x2, y, -1, 0)
                root.drawDistanceLabel(
                    ctx, (x1 + x2) / 2, y - 10, guide.distance)
                continue
            }

            if (kind === "spacingV") {
                const x = Number(guide.x)
                const y1 = Number(guide.y1)
                const y2 = Number(guide.y2)
                ctx.beginPath()
                ctx.moveTo(x, y1)
                ctx.lineTo(x, y2)
                ctx.stroke()
                root.arrowHead(ctx, x, y1, 0, 1)
                root.arrowHead(ctx, x, y2, 0, -1)
                root.drawDistanceLabel(
                    ctx, x + 24, (y1 + y2) / 2, guide.distance)
            }
        }
    }
}
