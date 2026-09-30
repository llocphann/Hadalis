#!/usr/bin/env python3
from pathlib import Path
r=Path(__file__).resolve().parents[1]
t=(r/"modules/abyss/AbyssPerimeter.qml").read_text()
p=(r/"modules/abyss/AbyssGenericPopupPresenter.qml").read_text()
assert 'function closeGenericPopup(expectedKind = "")' in t
assert 'if (expected && current !== expected)' in t
assert 'onCloseRequested: kind => window.closeGenericPopup(kind)' in t
hover=t[t.index("onPopupHoveredRequested:"):t.index("onPopupHoverStateChanged:")]
assert "window.closeGenericPopup()" in hover and "window.closePopup()" not in hover
assert "liquid.dismissPopups()" in t[t.index("function closePopup():"):t.index("Item {",t.index("function closePopup():"))]
assert "A different kind waits behind the current visual tail" in p
print("abyss generic popup ownership contract: ok")
