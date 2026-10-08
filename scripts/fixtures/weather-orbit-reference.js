// Frozen equal-arc functions from dev 1ab03d221; source SHA256 49123f001367b89df9bc1b60d40870a54a3e3691b85a298d3d0a35bfa06a352f
var root;
function bind(item) {root=item;}
    function hourFromLabel(label) {
        const match = String(label ?? "").match(/^(\d{1,2})(?::(\d{2}))?/) 
        if (!match)
            return 0
        const hour = parseInt(match[1], 10)
        const minute = parseInt(match[2] ?? "0", 10)
        if (isNaN(hour) || isNaN(minute))
            return 0
        return (((hour % 24) + 24) % 24) + minute / 60
    }
    function arcAngle(startAngle, endAngle, fraction) {
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
    function orbitAngleForHour(label) {
        const hour = root.hourFromLabel(label)
        const shiftedHour = (hour - 6 + 24) % 24
        const quadrant = Math.floor(shiftedHour / 6)
        const fraction = (shiftedHour - quadrant * 6) / 6
        // The reference places the 3-hour buckets on exact 45° parametric
        // positions. Keep Dashboard's older equal-arc placement, but use the
        // reference geometry in popup liquid mode.
        if (root.liquidMode)
            return -Math.PI / 2 + shiftedHour * Math.PI / 12
        const start = -Math.PI / 2 + quadrant * Math.PI / 2
        const end = start + Math.PI / 2
        return root.arcAngle(start, end, fraction)
    }
