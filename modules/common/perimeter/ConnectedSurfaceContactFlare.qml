import QtQuick

// Canonical local reconstruction of Caelestia's circular smooth-union contact
// lobe. The hard union is a square corner between the neighbouring edge field
// and the connected body. Circular smin(a, b, k) = 0 adds exactly the region
// outside a quarter-circle of radius k. This renderer paints that excess region
// only; callers rotate/mirror this one silhouette for every contact endpoint.
Canvas {
    id: root

    property color fillColor: "white"
    // Quarter turns clockwise after the optional canonical horizontal mirror.
    property int quarterTurns: 0
    property bool mirrored: false

    antialiasing: true

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onFillColorChanged: requestPaint()
    onQuarterTurnsChanged: requestPaint()
    onMirroredChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)

        const r = Math.max(0, Math.min(width, height))
        if (!(r > 0))
            return

        ctx.save()

        // Canonical orientation:
        //   seam / Screen Edge ─────────
        //                         [flare]
        //                              │ body
        //                              │
        //
        // Mirror first, then rotate. Because Canvas composes transforms right to
        // left, rotate() is issued before scale() in the CTM.
        ctx.translate(r / 2, r / 2)
        ctx.rotate(root.quarterTurns * Math.PI / 2)
        ctx.scale(root.mirrored ? -1 : 1, 1)
        ctx.translate(-r / 2, -r / 2)

        ctx.beginPath()
        ctx.moveTo(0, 0)
        ctx.lineTo(r, 0)
        ctx.lineTo(r, r)
        // Exact inverse quarter-circle: square minus the quarter disk centred at
        // (0, r). This is the zero-isocontour of Caelestia's circular smooth-min
        // for two perpendicular contact surfaces, not a rounded body corner.
        ctx.arc(0, r, r, 0, -Math.PI / 2, true)
        ctx.closePath()
        ctx.fillStyle = root.fillColor
        ctx.fill()

        ctx.restore()
    }
}
