.pragma library

function unit(value) { return Number.isFinite(value) ? Math.max(0, Math.min(1, value)) : 0 }
function smooth(from, to, value) {
    const t = unit((value-from)/(to-from))
    return t*t*(3-2*t)
}
function usePortal(from, to, scale) {
    return scale>0 && Number.isFinite(scale) && to?.grounded===true
        && [from?.x,from?.y,to?.x,to?.y].every(Number.isFinite)
        && Math.hypot(to.x-from.x,to.y-from.y)>=440*scale
}
function reveal(progress) {
    const t=unit(progress)
    return t<.5 ? 1-smooth(.18,.40,t) : smooth(.60,.82,t)
}
function opening(progress) {
    const t=unit(progress)
    return smooth(0,.16,t)*(1-smooth(.84,1,t))
}
function rollingAngle(distance, progress, direction, scale) {
    if (![distance,direction,scale].every(Number.isFinite) || distance<=0 || scale<=0) return 0
    // Whole rotations end upright, so settling never snaps a half-turned face.
    const turns=Math.max(1,Math.ceil(distance/(2*Math.PI*32*scale)))
    return 360*turns*unit(progress)*(direction<0 ? -1 : 1)
}
