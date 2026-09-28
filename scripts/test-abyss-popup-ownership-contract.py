#!/usr/bin/env python3
from pathlib import Path
t=(Path(__file__).resolve().parents[1]/"modules/abyss/AbyssPerimeter.qml").read_text()
assert 'function closeGenericPopup(expectedKind = "")' in t
assert 'if (expectedKind && current !== expectedKind)' in t
assert 'onCloseRequested: window.closeGenericPopup(popup.contentKind)' in t
hover=t[t.index("onPopupHoveredRequested:"):t.index("onPopupHoverStateChanged:")]
assert "window.closeGenericPopup()" in hover and "window.closePopup()" not in hover
assert "liquid.dismissPopups()" in t[t.index("function closePopup():"):t.index("Item {",t.index("function closePopup():"))]
print("abyss generic popup ownership contract: ok")
