import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick

Canvas {
    id: root
    property list<var> points // Input from Cava
    property color color: CavaTheme.primaryColor
    property real lineWidth: 3
    property real amplitudeScale: 1.0

    property real phase: 0
    property double _lastUpdateMs: 0
    
    property int smoothing: 2

    onPointsChanged: {
        if (!root.visible)
            return
        const now = Date.now()
        if (root._lastUpdateMs > 0)
            root.phase += (now - root._lastUpdateMs) * 0.003125
        root._lastUpdateMs = now
        root.requestPaint()
    }
    onVisibleChanged: {
        root._lastUpdateMs = 0
        if (root.visible)
            root.requestPaint()
    }

    onPaint: {
        var ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);

        var points = root.points;
        var n = points.length;
        // Fallback to sine wave if no cava points or player paused
        if (n < 2) {
            // Draw a flat line or simple sine if we want "alive" look when silent
            // For now, draw flat line
            ctx.beginPath();
            ctx.moveTo(0, height / 2);
            ctx.lineTo(width, height / 2);
            ctx.strokeStyle = Qt.rgba(root.color.r, root.color.g, root.color.b, 0.3);
            ctx.lineWidth = 1;
            ctx.stroke();
            return;
        }

        // Smoothing + drawing in one rolling-window pass. This preserves
        // the exact edge-clamped moving average without allocating a second
        // n-element array for every CAVA frame.
        var smoothWindow = Math.max(0, root.smoothing);
        var count = smoothWindow * 2 + 1;
        var sum = 0;
        for (var j = -smoothWindow; j <= smoothWindow; ++j)
            sum += points[Math.max(0, Math.min(n - 1, j))];

        ctx.beginPath();
        var centerY = height / 2;
        var maxVal = 1000.0; // Cava max value usually
        ctx.moveTo(0, centerY); // Start at left center

        for (var i = 0; i < n; ++i) {
            var x = (i / (n - 1)) * width;
            var smoothed = sum / count;
            var magnitude = (smoothed / maxVal) * (height / 2) * root.amplitudeScale;
            var waveCarrier = Math.sin(i * 0.5 + root.phase);
            var y = centerY + magnitude * waveCarrier * 3; // *3 for visibility
            ctx.lineTo(x, y);

            var outgoing = Math.max(0, Math.min(n - 1, i - smoothWindow));
            var incoming = Math.max(0, Math.min(n - 1, i + smoothWindow + 1));
            sum += points[incoming] - points[outgoing];
        }
        
        ctx.strokeStyle = root.color;
        ctx.lineWidth = root.lineWidth;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        ctx.stroke();
    }
}
