import QtQuick

/**
 * Compatibility focus bridge for Niri surfaces.
 *
 * Niri keyboard focus is owned by the layer-shell PanelWindow. Callers keep
 * this lightweight object so their existing focus lifecycle API stays stable.
 */
Item {
    id: root
    property var windows: []
    property bool active: false
    signal cleared()
}
