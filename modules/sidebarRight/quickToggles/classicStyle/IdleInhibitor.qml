import qs.modules.common.widgets
import qs.services

QuickToggleButton {
    accessibleName: Translation.tr("Keep system awake")
    toggled: Idle.inhibit
    buttonIcon: "coffee"
    onClicked: Idle.toggleInhibit()
    StyledToolTip { text: Translation.tr("Keep system awake") }
}
