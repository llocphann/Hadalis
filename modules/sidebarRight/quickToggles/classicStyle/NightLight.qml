import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import Quickshell.Io

QuickToggleButton {
    id: nightLightButton
    accessibleName: Translation.tr("Night Light")
    toggled: NightLight.active
    buttonIcon: (Config.options?.light?.night?.automatic ?? false) ? "night_sight_auto" : "bedtime"
    onClicked: {
        NightLight.toggle()
    }

    altAction: () => {
        Config.setNestedValue("light.night.automatic", !(Config.options?.light?.night?.automatic ?? false))
    }

    Component.onCompleted: {
        NightLight.fetchState()
    }
    
    StyledToolTip {
        text: Translation.tr("Night Light | Right-click to toggle Auto mode")
    }
}
