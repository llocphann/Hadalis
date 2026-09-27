import QtQuick
import qs.modules.common
import qs.modules.abyss.looks
import "looks/AbyssWave.js" as Wave

Item {
    id: root
    width: sampleCount; height: 1
    property real outputWidth: 1920
    property real outputHeight: 1080
    property bool presented: true
    property var records: []
    readonly property int sampleCount: AbyssStyle.quality === "performance" ? 128 : 256
    readonly property var parameters: Wave.parameters(Config.options?.abyss?.waves)
    property var simulation: null
    property string mode: "SLEEPING"
    property int revision: 0
    property real lastStep: 0
    readonly property bool running: ticker.running
    readonly property var texture: textureSource
    property bool wavesEnabled: Config.options?.abyss?.waves?.enabled ?? false
    property bool audioEnabled: false
    property bool idleDisturbance: false
    property int idlePoint: 0
    readonly property bool motionAllowed: presented && AbyssStyle.motionEnabled && wavesEnabled
    readonly property bool audioAllowed: presented && AbyssStyle.motionEnabled && audioEnabled
    readonly property bool integrationAllowed: motionAllowed || audioAllowed
    signal configurationChanged()
    function reset(): void {
        simulation = Wave.create(sampleCount,outputWidth,outputHeight,parameters)
        Wave.setMass(simulation,records)
        mode = "SLEEPING"
        revision++
        configurationChanged()
    }
    function impulse(edge, along, span, strength, mass = 1, channel = "module"): void {
        if (!motionAllowed || strength === 0) return
        if (!simulation) reset()
        const factor = channel === "module" ? (Math.abs(strength)<0.5 ? parameters.hover : parameters.press)
            : (parameters[channel] ?? 1)
        Wave.impulse(simulation,edge,along,span,strength*factor*AbyssStyle.motionIntensity,mass)
        idleDisturbance = channel === "idle"
        lastStep = Date.now()
        mode = simulation.mode
        revision++
    }
    function feedSpectrum(edges,points,ceiling,strength): void {
        if(!audioAllowed) return
        if(!simulation) reset()
        if(!Wave.spectrum(simulation,edges,points,ceiling,strength*AbyssStyle.motionIntensity)) return
        idleDisturbance=false
        lastStep=Date.now();mode=simulation.mode;revision++
    }
    function clearSpectrum(): void {
        if(!simulation || !simulation.hasSpectrum) return
        if(!integrationAllowed) { reset();return }
        Wave.spectrum(simulation,[],[],100,0)
        lastStep=Date.now();mode=simulation.mode
    }
    onAudioAllowedChanged: if(!audioAllowed) clearSpectrum()
    onIntegrationAllowedChanged: if (!integrationAllowed) reset()
    onOutputWidthChanged: reset()
    onOutputHeightChanged: reset()
    onSampleCountChanged: reset()
    onParametersChanged: {
        if (simulation) simulation.parameters = parameters
        configurationChanged()
    }
    onRecordsChanged: if (simulation) Wave.setMass(simulation,records)
    onRevisionChanged: samples.requestPaint()
    Component.onCompleted: reset()
    Timer {
        id: ticker
        interval: root.idleDisturbance ? 100 : AbyssStyle.quality === "performance" ? 33 : 16
        repeat: true
        running: root.integrationAllowed && root.mode !== "SLEEPING"
        onTriggered: {
            const now = Date.now()
            Wave.advance(root.simulation,Math.min(.05,(now-root.lastStep)/1000))
            root.lastStep = now
            root.mode = root.simulation.mode
            root.revision++
        }
    }
    Timer {
        interval: 8000;repeat:true
        running: root.motionAllowed && root.parameters.idle
        onTriggered: if (root.mode === "SLEEPING") {
            root.idlePoint = (root.idlePoint+1)%7
            root.impulse("top",root.outputWidth*(root.idlePoint+.5)/7,120,.04,1,"idle")
        }
    }
    // One tiny, explicitly updated texture; no desktop capture or time uniform.
    Canvas {
        id: samples
        width: root.sampleCount; height: 1
        renderTarget: Canvas.Image
        onAvailableChanged: if (available) requestPaint()
        onPainted: textureSource.scheduleUpdate()
        onPaint: {
            if (!root.simulation) return
            const ctx = getContext("2d")
            ctx.clearRect(0,0,width,height)
            for (let i=0;i<width;i++) {
                const value = Math.round((root.simulation.displacement[i]/384+.5)*65535)
                ctx.fillStyle = "rgb("+(value>>8)+","+(value&255)+",0)"
                ctx.fillRect(i,0,1,1)
            }
        }
    }
    ShaderEffectSource {
        id: textureSource
        width: samples.width; height: samples.height
        x: -width; y: -height
        sourceItem: samples
        hideSource: true
        live: false
        smooth: true
        textureSize: Qt.size(root.sampleCount,1)
    }
}
