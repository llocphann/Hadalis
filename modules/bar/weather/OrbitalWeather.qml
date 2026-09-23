pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property date now: new Date()
    property bool showUnavailableMessage: true
    // Popup opts into liquid mode explicitly. Dashboard keeps the existing
    // lightweight orbital cards unless a future design intentionally changes it.
    property bool liquidMode: false
    property bool liquidAnimationActive: false
    readonly property var hours: (Weather.data?.hourly ?? []).slice(0, 8)

    readonly property real pointWidth: Math.max(42,
        Math.min(54, width * 0.13))
    readonly property real pointHeight: Math.max(52,
        Math.min(66, height * 0.25))
    readonly property real orbitRadiusX: Math.max(1,
        (width - pointWidth - 18) / 2)
    readonly property real orbitRadiusY: Math.max(1,
        (height - pointHeight - 22) / 2)
    readonly property var hourAngles: {
        const result = []
        for (let i = 0; i < root.hours.length; ++i)
            result.push(root.orbitAngleForHour(root.hours[i]?.label))
        return result
    }
    readonly property bool liquidFallback:
        root.liquidMode && !liquidField.shaderCompiled

    implicitWidth: 360
    implicitHeight: 230

    function hourFromLabel(label): real {
        const match = String(label ?? "").match(/^(\d{1,2})(?::(\d{2}))?/)
        if (!match)
            return 0
        const hour = parseInt(match[1], 10)
        const minute = parseInt(match[2] ?? "0", 10)
        if (isNaN(hour) || isNaN(minute))
            return 0
        return (((hour % 24) + 24) % 24) + minute / 60
    }

    function arcAngle(startAngle, endAngle, fraction): real {
        if (fraction <= 0)
            return startAngle
        if (fraction >= 1)
            return endAngle

        const samples = 72
        const rx = root.orbitRadiusX
        const ry = root.orbitRadiusY
        const lengths = [0]
        let total = 0
        let prevX = Math.cos(startAngle) * rx
        let prevY = Math.sin(startAngle) * ry

        for (let sample = 1; sample <= samples; ++sample) {
            const t = sample / samples
            const angle = startAngle + (endAngle - startAngle) * t
            const x = Math.cos(angle) * rx
            const y = Math.sin(angle) * ry
            const dx = x - prevX
            const dy = y - prevY
            total += Math.sqrt(dx * dx + dy * dy)
            lengths.push(total)
            prevX = x
            prevY = y
        }

        const target = total * fraction
        let sample = 1
        while (sample < lengths.length && lengths[sample] < target)
            ++sample

        const before = lengths[Math.max(0, sample - 1)]
        const span = Math.max(0.0001, lengths[sample] - before)
        const local = (target - before) / span
        const t = (sample - 1 + local) / samples
        return startAngle + (endAngle - startAngle) * t
    }

    function orbitAngleForHour(label): real {
        const hour = root.hourFromLabel(label)
        const shiftedHour = (hour - 6 + 24) % 24
        const quadrant = Math.floor(shiftedHour / 6)
        const fraction = (shiftedHour - quadrant * 6) / 6
        const start = -Math.PI / 2 + quadrant * Math.PI / 2
        const end = start + Math.PI / 2
        return root.arcAngle(start, end, fraction)
    }

    LiquidOrbitalField {
        id: liquidField
        anchors.fill: parent
        z: 0
        visible: root.liquidMode && root.hours.length > 0
        hourAngles: root.hourAngles
        orbitRadiusX: root.orbitRadiusX
        orbitRadiusY: root.orbitRadiusY
        nodeWidth: root.pointWidth
        nodeHeight: root.pointHeight
        activeIndex: 0
        animate: root.liquidAnimationActive
    }

    // Proven lightweight fallback for a software scene graph or a shader
    // compile failure. Normal popup rendering never paints this guide.
    Canvas {
        id: orbitGuide
        anchors.centerIn: parent
        width: Math.max(1, root.orbitRadiusX * 2 + 4)
        height: Math.max(1, root.orbitRadiusY * 2 + 4)
        opacity: 0.42
        visible: !root.liquidMode || root.liquidFallback

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            if (width <= 0 || height <= 0)
                return

            ctx.beginPath()
            for (let angle = 0; angle <= Math.PI * 2 + 0.01; angle += 0.05) {
                const x = width / 2 + Math.cos(angle) * root.orbitRadiusX
                const y = height / 2 + Math.sin(angle) * root.orbitRadiusY
                if (angle === 0)
                    ctx.moveTo(x, y)
                else
                    ctx.lineTo(x, y)
            }
            ctx.strokeStyle = Appearance.colors.colPrimary
            ctx.globalAlpha = 0.5
            ctx.lineWidth = 1.5
            ctx.setLineDash([4, 9])
           ÝœÝ›ÚÙJ
BˆÝ™ÛØ˜[[HHBˆBˆB‚ˆÛÛ[[“^[Ý]Âˆ[˜ÚÜœË˜Ù[\’[Žˆ\™[ˆÜXÚ[™Îˆ›ÛÝ›\]ZY[ÙHÈˆˆBˆŽˆÂˆÚYˆX]›Z[Š›ÛÝ›\]ZY[ÙHÈNLˆN›ÛÝÚY
ˆL
B‚ˆX]\šX[Þ[X›ÛÂˆš\ÚX›Nˆ›ÛÝ›\]ZY[ÙBˆ^[Ý]˜[YÛ›Y[ˆ][YÛ’Ù[\‚ˆ^[Ý]˜›ÝÛSX\™Ú[ŽˆBˆ^ˆXÛÛœË™Ù]ÙX]\’XÛÛŠˆÙX]\‹™]OËÐÛÙKˆÙX]\‹š\ÓšYÚ›ÝÊ
JHÏÈ˜ÛÝY‚ˆXÛÛ”Ú^™NˆX]›X^
\X\˜[˜ÙK™›Ûœ^[Ú^™K›\™Ù\ŠBˆÛÛÜŽˆ\X\˜[˜ÙK˜ÛÛÜœË˜ÛÛš[X\žBˆB‚ˆÝ[Y^Âˆ^[Ý]™š[ÚYˆYBˆÜš^›Û[[YÛ›Y[ˆ^[YÛ’Ù[\‚ˆ^ˆ›ÛÝÚYHÎˆÈ]™›Ü›X]]J›ÛÝ››ÝË™SSHŠBˆˆ]™›Ü›X]]J›ÛÝ››ÝË™SSHŠBˆ›ÛÙZYÚˆ›ÛÝ›\]ZY[ÙHÈ›Û“YY][Hˆ›Û‘[ZP›Ûˆ›Ûœ^[Ú^™Nˆ›ÛÝ›\]ZY[ÙBˆÈ\X\˜[˜ÙK™›Ûœ^[Ú^™KœÛX[ˆˆ\X\˜[˜ÙK™›Ûœ^[Ú^™KœÛX[ˆÛÛÜŽˆ\X\˜[˜ÙK˜ÛÛÜœË˜ÛÛÛ”Ý\™˜XÙU˜\šX[ˆ[YNˆ^‘[YTšYÚˆB‚ˆ›ÝÓ^[Ý]Âˆ^[Ý]˜[YÛ›Y[ˆ][YÛ’Ù[\‚ˆ^[Ý]ÜX\™Ú[Žˆ›ÛÝ›\]ZY[ÙHÈˆ‚ˆÜXÚ[™Îˆ‚ˆX]\šX[Þ[X›ÛÂˆš\ÚX›Nˆ\›ÛÝ›\]ZY[ÙBˆ^ˆXÛÛœË™Ù]ÙX]\’XÛÛŠˆÙX]\‹™]OËÐÛÙKˆÙX]\‹š\ÓšYÚ›ÝÊ
JHÏÈ˜ÛÝY‚ˆXÛÛ”Ú^™Nˆ\X\˜[˜ÙK™›Ûœ^[Ú^™K››Ü›X[ˆÛÛÜŽˆ\X\˜[˜ÙK˜ÛÛÜœË˜ÛÛš[X\žBˆB‚ˆÝ[Y^Âˆ^ˆÙX]\‹™]OË[\ÏÈ‹Kp¬‚ˆ›ÛÙZYÚˆ›ÛÝ›\]ZY[ÙHÈ›Û“YY][Hˆ›Û‘[ZP›Ûˆ›Ûœ^[Ú^™Nˆ›ÛÝ›\]ZY[ÙBˆÈX]›X^
K\X\˜[˜ÙK™›Ûœ^[Ú^™K›\™Ù\ŠBˆˆ\X\˜[˜ÙK™›Ûœ^[Ú^™K››Ü›X[ˆÛÛÜŽˆ\X\˜[˜ÙK˜ÛÛÜœË˜ÛÛÛ”Ý\™˜XÙBˆBˆB‚ˆÝ[Y^Âˆ^[Ý]™š[ÚYˆYBˆÜš^›Û[[YÛ›Y[ˆ^[YÛ’Ù[\‚ˆ^ˆÙX]\‹™]OË™\ØÜš\[Û‚ˆÏÈÙX]\‹™\ØÜšX™UÙX]\ŠÙX]\‹™]OËÐÛÙHÏÈŒLLÈŠBˆ›Ûœ^[Ú^™Nˆ›ÛÝ›\]ZY[ÙBˆÈ\X\˜[˜ÙK™›Ûœ^[Ú^™KœÛX[\‚ˆˆ\X\˜[˜ÙK™›Ûœ^[Ú^™KœÛX[\ÝˆÛÛÜŽˆ\X\˜[˜ÙK˜ÛÛÜœË˜ÛÛÛ”Ý\™˜XÙU˜\šX[ˆ[YNˆ^‘[YTšYÚˆBˆB‚ˆ™\X]\ˆÂˆYˆÜ˜š]Ý\œÂˆ[Ù[ˆ›ÛÝšÝ\œÂ‚ˆ[YØ]Nˆ][HÂˆYˆÝ\”Ú[ˆ™\]Z\™Y›Ü\H[[™^ˆ™\]Z\™Y›Ü\H˜\ˆ[Ù[]B‚ˆ™XYÛ›H›Ü\H™X[[™ÛNˆ›ÛÝšÝ\[™Û\ÖÚ[™^BˆÏÈ›ÛÝ›Ü˜š][™ÛQ›Ü’Ý\Š[Ù[]OË›X™[
Bˆ™XYÛ›H›Ü\H›ÛÛYÚYÚYˆ[™^OOH‚ˆÚYˆ›ÛÝœÚ[ÚYˆZYÚˆ›ÛÝœÚ[ZYÚˆˆ›ÛÝÚYÈ‚ˆ
ÈX]˜ÛÜÊ[™ÛJH
ˆ›ÛÝ›Ü˜š]˜Y]\ÖHÚYÈ‚ˆNˆ›ÛÝšZYÚÈ‚ˆ
ÈX]œÚ[Š[™ÛJH
ˆ›ÛÝ›Ü˜š]˜Y]\ÖHHZYÚÈ‚ˆŽˆ‚ˆ™XÝ[™ÛHÂˆ[˜ÚÜœË™š[ˆ\™[ˆš\ÚX›Nˆ\›ÛÝ›\]ZY[ÙH›ÛÝ›\]ZY˜[˜XÚÂˆ˜Y]\Îˆ\X\˜[˜ÙKœ›Ý[™[™Ë››Ü›X[ˆÛÛÜŽˆÝ\”Ú[šYÚYÚYˆÈ\X\˜[˜ÙK˜ÛÛÜœË˜ÛÛš[X\žPÛÛZ[™\‚ˆˆ\X\˜[˜ÙK˜ÛÛÜœË˜ÛÛÝ\™˜XÙPÛÛZ[™\’YÚˆ›Ü™\‹ÚYˆBˆ›Ü™\‹˜ÛÛÜŽˆÝ\”Ú[šYÚYÚYˆÈ\X\˜[˜ÙK˜ÛÛÜœË˜ÛÛš[X\žBˆˆ\X\˜[˜ÙK˜ÛÛÜœË˜ÛÛÝ][™U˜\šX[ˆB‚ˆÛÛ[[“^[Ý]Âˆ[˜ÚÜœË˜Ù[\’[Žˆ\™[ˆÜXÚ[™Îˆ›ÛÝ›\]ZY[ÙHÈˆˆB‚ˆÝ[Y^Âˆ^[Ý]˜[YÛ›Y[ˆ][YÛ’Ù[\‚ˆ^ˆÝ\”Ú[›[Ù[]OË›X™[ÏÈˆ‚ˆ›ÛÙZYÚˆÝ\”Ú[šYÚYÚYˆÈ›Û‘[ZP›Ûˆ›Û“YY][Bˆ›Ûœ^[Ú^™Nˆ\X\˜[˜ÙK™›Ûœ^[Ú^™KœÛX[\ÝˆÛÛÜŽˆ›ÛÝ›\]ZY[ÙBˆÈ\X\˜[˜ÙK˜ÛÛÜœË˜ÛÛÛ”Ý\™˜XÙBˆˆÝ\”Ú[šYÚYÚYˆÈ\X\˜[˜ÙK˜ÛÛÜœË˜ÛÛÛ”š[X\žPÛÛZ[™\‚ˆˆ\X\˜[˜ÙK˜ÛÛÜœË˜ÛÛÛ”Ý\™˜XÙU˜\šX[ˆB‚ˆX]\šX[Þ[X›ÛÂˆ^[Ý]˜[YÛ›Y[ˆ][YÛ’Ù[\‚ˆ^ˆXÛÛœË™Ù]ÙX]\’XÛÛŠˆÝ\”Ú[›[Ù[]OË˜ÛÙKˆÝ\”Ú[›[Ù[]OËš\ÓšYÚÏÈ˜[ÙJHÏÈ˜ÛÝY‚ˆXÛÛ”Ú^™NˆX]›X^
MKˆX]›Z[Š›ÛÝ›\]ZY[ÙHÈŒHˆŒˆÝ\”Ú[ÚY
ˆ
JBˆÛÛÜŽˆ\X\˜[˜ÙK˜ÛÛÜœË˜ÛÛš[X\žBˆB‚ˆÝ[Y^Âˆ^[Ý]˜[YÛ›Y[ˆ][YÛ’Ù[\‚ˆ^ˆÝ\”Ú[›[Ù[]OË[\ÏÈ‹Kp¬‚ˆ›ÛÙZYÚˆÝ\”Ú[šYÚYÚYˆÈ›Û‘[ZP›Ûˆ›Û“YY][Bˆ›Ûœ^[Ú^™Nˆ\X\˜[˜ÙK™›Ûœ^[Ú^™KœÛX[\ÝˆÛÛÜŽˆ›ÛÝ›\]ZY[ÙBˆÈ\X\˜[˜ÙK˜ÛÛÜœË˜ÛÛÛ”Ý\™˜XÙBˆˆÝ\”Ú[šYÚYÚYˆÈ\X\˜[˜ÙK˜ÛÛÜœË˜ÛÛÛ”š[X\žPÛÛZ[™\‚ˆˆ\X\˜[˜ÙK˜ÛÛÜœË˜ÛÛÛ”Ý\™˜XÙBˆBˆBˆBˆB‚ˆÝ[Y^Âˆ[˜ÚÜœË˜Ù[\’[Žˆ\™[ˆ[˜ÚÜœË™\XØ[Ù[\“Ù™œÙ]ˆNˆŽˆBˆš\ÚX›Nˆ›ÛÝœÚÝÕ[˜]˜Z[X›SY\ÜØYÙH	‰ˆ›ÛÝšÝ\œË›[™ÝOOHˆ^ˆ˜[œÛ][Û‹Š’Ý\›H›Ü™XØ\Ý[˜]˜Z[X›HŠBˆ›Ûœ^[Ú^™Nˆ\X\˜[˜ÙK™›Ûœ^[Ú^™KœÛX[\‚ˆÛÛÜŽˆ\X\˜[˜ÙK˜ÛÛÜœË˜ÛÛÛ”Ý\™˜XÙU˜\šX[ˆBŸB