pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs
import qs.modules.common
import qs.modules.common.widgets
import "../looks/AbyssWave.js" as Wave

ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 16
    property string activeSection: "surface"
    readonly property var waveValues: Wave.parameters(Config.options?.abyss?.waves)
    function waveChange(key,value): void {
        const updates={"abyss.waves.preset":"custom"}
        Object.keys(Wave.presets.balanced).forEach(k => updates["abyss.waves."+k]=waveValues[k])
        updates["abyss.waves."+key]=value
        Config.setNestedValues(updates)
    }
    component Percent: WindowDialogSlider {
        id: control
        required property string configKey
        property real fallback: 0
        property real minimum: 0
        property real maximum: 1
        Layout.fillWidth:true
        from:0;to:100;stepSize:1
        value:100*(Config.getNestedValue(configKey,fallback)-minimum)/(maximum-minimum)
        onMoved: Config.setNestedValue(configKey,minimum+(maximum-minimum)*value/100)
    }
    component WaveControl: WindowDialogSlider {
        id: control
        required property string parameter
        Layout.fillWidth:true
        from:0;to:100;stepSize:1
        value:root.waveValues[parameter]*100
        onMoved: root.waveChange(parameter,value/100)
    }
    SettingsTaskNavigator {
        icon:"water";title:"Abyss"
        description:"The Material layout you know, carried by one continuous Screen Edge."
        currentValue:root.activeSection
        onSelected:value=>root.activeSection=value
        options:[
            {displayName:"Surface",value:"surface",icon:"opacity"},
            {displayName:"Waves",value:"waves",icon:"waves"},
            {displayName:"Modules",value:"modules",icon:"widgets"},
            {displayName:"Popups",value:"popups",icon:"chat_bubble"},
            {displayName:"Live Editor",value:"editor",icon:"edit"},
            {displayName:"Interaction",value:"interaction",icon:"touch_app"},
            {displayName:"Performance",value:"performance",icon:"speed"}]
    }
    SettingsCardSection {
        title:"Surface";icon:"opacity";settingsTaskSection:"surface"
        visible:root.activeSection==="surface"
        SettingsGroup {
            ConfigSwitch {
                text:"Transparent surfaces";autoToggle:false
                checked:(Config.options?.abyss?.surface?.opacity ?? .78)<.999
                onToggledByUser:checked=>Config.setNestedValue("abyss.surface.opacity",checked ? .78 : 1)
            }
            Percent { text:"Surface opacity";configKey:"abyss.surface.opacity";fallback:.78;minimum:.35 }
            Percent { text:"Screen Edge depth";configKey:"abyss.perimeter.thickness";fallback:16;minimum:10;maximum:40 }
            Percent { text:"Curvature";configKey:"abyss.perimeter.radius";fallback:34;minimum:12;maximum:64 }
            Percent { text:"Fusion softness";configKey:"abyss.surface.softness";fallback:24;minimum:4;maximum:48 }
            ConfigSwitch {
                text:"Wallpaper blur";autoToggle:false
                checked:Config.options?.abyss?.effects?.blur?.enabled ?? true
                onToggledByUser:checked=>Config.setNestedValue("abyss.effects.blur.enabled",checked)
            }
            Percent { text:"Blur strength";configKey:"abyss.effects.blur.radius";fallback:10;maximum:24 }
            ConfigSwitch {
                text:"Refraction (Quality)";autoToggle:false
                checked:Config.options?.abyss?.effects?.refraction?.enabled ?? false
                onToggledByUser:checked=>Config.setNestedValue("abyss.effects.refraction.enabled",checked)
            }
            Percent { text:"Refraction strength";configKey:"abyss.effects.refraction.strength";fallback:6;maximum:16 }
            Percent { text:"Rim highlight";configKey:"abyss.effects.surfaceHighlight";fallback:.45 }
            Percent { text:"Glow";configKey:"abyss.effects.glow.strength";fallback:.08;maximum:.3 }
            RippleButton {
                buttonText:"Use opaque Material appearance";implicitHeight:36;Layout.fillWidth:true
                onClicked:Config.setNestedValues({"abyss.surface.opacity":1,"abyss.waves.enabled":false,
                    "abyss.effects.blur.enabled":false,"abyss.effects.refraction.enabled":false,
                    "abyss.effects.glow.strength":0,"abyss.effects.surfaceHighlight":0,
                    "abyss.perimeter.radius":Config.options?.appearance?.screenEdge?.radius ?? 25})
            }
        }
    }
    SettingsCardSection {
        title:"Waves";icon:"waves";settingsTaskSection:"waves"
        visible:root.activeSection==="waves"
        SettingsGroup {
            ConfigSwitch {
                text:"Enable waves";autoToggle:false
                checked:Config.options?.abyss?.waves?.enabled ?? false
                onToggledByUser:checked=>Config.setNestedValue("abyss.waves.enabled",checked)
            }
            ConfigSelectionArray {
                currentValue:Config.options?.abyss?.waves?.preset ?? "balanced"
                options:[{displayName:"Calm",value:"calm"},{displayName:"Balanced",value:"balanced"},
                    {displayName:"Fluid",value:"fluid"},{displayName:"Deep",value:"deep"},{displayName:"Custom",value:"custom"}]
                onSelected:value=>{
                    const updates={"abyss.waves.preset":value}
                    if(Wave.presets[value]) Object.keys(Wave.presets[value]).forEach(k=>updates["abyss.waves."+k]=Wave.presets[value][k])
                    Config.setNestedValues(updates)
                }
            }
            AbyssWavePreview {}
            WaveControl { text:"Wave size";parameter:"amplitude" }
            WaveControl { text:"Propagation distance";parameter:"propagation" }
            WaveControl { text:"Wave speed";parameter:"speed" }
            WaveControl { text:"Decay";parameter:"decay" }
            WaveControl { text:"Surface tension";parameter:"tension" }
            WaveControl { text:"Viscosity";parameter:"viscosity" }
            WaveControl { text:"Secondary rebound";parameter:"rebound" }
            WaveControl { text:"Corner propagation";parameter:"corner" }
            ConfigSwitch {
                text:"Occasional idle ripple";autoToggle:false
                checked:Config.options?.abyss?.waves?.idle ?? false
                onToggledByUser:checked=>Config.setNestedValue("abyss.waves.idle",checked)
            }
            SettingsNote { text:"Idle ripples update at 10 Hz and sleep between disturbances. The preview uses the desktop solver; reduced motion also applies here." }
        }
    }
    SettingsCardSection {
        title:"Modules";icon:"widgets";settingsTaskSection:"modules"
        visible:root.activeSection==="modules"
        SettingsGroup {
            SettingsNote { text:"Place modules on any edge with Live Editor. Their media, resource, clock, tray and workspace settings remain shared." }
            RippleButton { buttonText:"Edit Abyss layout";implicitHeight:36;Layout.fillWidth:true;onClicked:GlobalStates.startAbyssEditing() }
            Percent { text:"Overall module scale";configKey:"abyss.modules.size";fallback:1;minimum:.6;maximum:1.8 }
            Percent { text:"Top Edge module size";configKey:"abyss.modules.edgeSizes.top";fallback:1;minimum:.6;maximum:1.8 }
            Percent { text:"Right Edge module size";configKey:"abyss.modules.edgeSizes.right";fallback:1;minimum:.6;maximum:1.8 }
            Percent { text:"Bottom Edge module size";configKey:"abyss.modules.edgeSizes.bottom";fallback:1;minimum:.6;maximum:1.8 }
            Percent { text:"Left Edge module size";configKey:"abyss.modules.edgeSizes.left";fallback:1;minimum:.6;maximum:1.8 }
            SettingsNote { text:"Modules inherit their Edge size. Enable Custom size in Live Editor to override one module. Per-output sizes, snapping guides and start/center/end groups are available there." }
            AbyssOutputSelector { configPath:"bar.screenList";title:"Module outputs" }
            RippleButton { buttonText:"Module functionality settings";implicitHeight:36;Layout.fillWidth:true;onClicked:GlobalStates.openSettingsSection(10,"modules") }
        }
    }
    SettingsCardSection {
        title:"Popups";icon:"chat_bubble";settingsTaskSection:"popups"
        visible:root.activeSection==="popups"
        SettingsGroup {
            SettingsNote { text:"Popups retain their existing layouts and follow the edge of their source module. The output field paints their outer surface once." }
            AbyssPositionSettings {}
            Percent { text:"Small popup wave strength";configKey:"abyss.waves.small";fallback:.7;maximum:2 }
            Percent { text:"Large panel wave strength";configKey:"abyss.waves.large";fallback:1;maximum:2 }
            Percent { text:"Dock wave strength";configKey:"abyss.waves.dock";fallback:.5;maximum:2 }
            Percent { text:"Notification wave strength";configKey:"abyss.waves.notifications";fallback:.3;maximum:2 }
            AbyssOutputSelector { configPath:"sidebar.screenList";title:"Sidebar outputs" }
            AbyssOutputSelector { configPath:"notifications.screenList";title:"Notification outputs" }
        }
    }
    SettingsCardSection {
        title:"Live Editor";icon:"edit";settingsTaskSection:"editor"
        visible:root.activeSection==="editor"
        SettingsGroup {
            SettingsNote { text:"Settings closes while you place modules on the desktop. Done saves; Cancel restores the saved layout. Choose a profile per output or use the layout as the global default." }
            RippleButton { buttonText:"Edit Abyss layout";implicitHeight:36;Layout.fillWidth:true;onClicked:GlobalStates.startAbyssEditing() }
        }
    }
    SettingsCardSection {
        title:"Interaction";icon:"touch_app";settingsTaskSection:"interaction"
        visible:root.activeSection==="interaction"
        SettingsGroup {
            Percent { text:"Hover response";configKey:"abyss.waves.hover";fallback:1 }
            Percent { text:"Press response";configKey:"abyss.waves.press";fallback:1 }
            Percent { text:"Opening response";configKey:"abyss.waves.open";fallback:1 }
            Percent { text:"Closing response";configKey:"abyss.waves.close";fallback:1 }
            Percent { text:"Drag response";configKey:"abyss.waves.drag";fallback:1 }
            Percent { text:"Motion intensity";configKey:"abyss.motion.intensity";fallback:.6 }
            ConfigSwitch {
                text:"Reduce animations (all families)";autoToggle:false
                checked:Config.options?.performance?.reduceAnimations ?? false
                onToggledByUser:checked=>Config.setNestedValue("performance.reduceAnimations",checked)
            }
        }
    }
    SettingsCardSection {
        title:"Performance";icon:"speed";settingsTaskSection:"performance"
        visible:root.activeSection==="performance"
        SettingsGroup {
            ConfigSelectionArray {
                currentValue:Config.options?.abyss?.quality ?? "balanced"
                options:[{displayName:"Performance",value:"performance"},{displayName:"Balanced",value:"balanced"},{displayName:"Quality",value:"quality"}]
                onSelected:value=>Config.setNestedValue("abyss.quality",value)
            }
            SettingsNote { text:"Performance uses 128 wave samples. Balanced and Quality use 256. The solver stops after settling and while the output is hidden or locked. Wallpaper glass uses a static image; application pixels are not captured." }
            ConfigSwitch {
                text:"Visible during fullscreen";autoToggle:false
                checked:Config.options?.abyss?.perimeter?.visibleInFullscreen ?? false
                onToggledByUser:checked=>Config.setNestedValue("abyss.perimeter.visibleInFullscreen",checked)
            }
        }
    }
}
