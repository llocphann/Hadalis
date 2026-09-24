import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import Quickshell

AndroidQuickToggleButton {
    id: root
    
    property bool auto: Config.options?.light?.night?.automatic ?? false

    name: Translation.tr("Night Light")
    statusText: {
        const state = toggled ? Translation.tr("Active") : Translation.tr("Inactive")
        return auto ? Translation.tr("Auto, %1").arg(state) : state
    }

    toggled: NightLight.active
    buttonIcon: auto ? "night_sight_auto" : "bedtime"
    
    mainAction: () => {
        NightLight.toggle()
    }

    altAction: () => {
        root.openMenu()
    }

    Component.onCompleted: {
        NightLight.fetchState()
    }
    
    StyledToolTip {
        text: Translation.tr("Night Light | Right-click to configure")
    }
}

