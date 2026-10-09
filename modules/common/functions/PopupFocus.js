.pragma library

// A clicked button's retained Qt focus is not an input session. Keep hover
// popups open only for an editable text control in their own content tree.
function editableDescendant(item, scope) {
    if (!item || !item.visible || !item.enabled || item.readOnly !== false
            || item.cursorPosition === undefined)
        return false
    for (let ancestor = item; ancestor; ancestor = ancestor.parent)
        if (ancestor === scope) return true
    return false
}
