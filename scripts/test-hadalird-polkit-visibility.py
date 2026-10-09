#!/usr/bin/env python3
"""Settings must release layer-shell elevation and keyboard focus to Polkit.

This tests static contracts only. Owner Niri validation of shell-owned and
external polkit agents remains required.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
native = (ROOT / "modules/settings/SettingsOverlayNativeHost.qml").read_text()
focus = (ROOT / "modules/settings/SettingsFocus.qml").read_text()
service = (ROOT / "services/Hadalird.qml").read_text()
ui = (ROOT / "modules/settings/IntegrationsConfig.qml").read_text()
manager = (ROOT / "scripts/hadalird-manager.py").read_text()

for name, source in (("rail", native), ("focus", focus)):
    layer = re.search(r"WlrLayershell\.layer:\s*([\s\S]*?)\n\s*WlrLayershell\.keyboardFocus:", source)
    assert layer, name + ": missing window elevation binding"
    binding = layer.group(1)
    assert "Hadalird.authorizationPending" in binding, name + ": external pkexec not handled"
    assert "PolkitService.active" in binding, name + ": shell Polkit not handled"
    assert "WlrLayer.Bottom" in binding, name + ": must yield to Polkit"
    assert "WlrLayer.Top" not in binding, name + ": cannot elevate Settings above Polkit"
    focus_binding = re.search(r"WlrLayershell\.keyboardFocus:\s*([\s\S]*?)\n\s*color:", source)
    assert focus_binding and "!Hadalird.authorizationPending" in focus_binding.group(1), (
        name + ": exclusive keyboard focus remains active during authorization")

assert 'authorizationPending = ["helpers-ensure"' in service
assert '["install","remove","rollback","helpers-install","helpers-remove","helpers-ensure"]' in service
assert 'GlobalStates.settingsOverlayOpen = false' in service
assert 'GlobalStates.settingsOverlayOpen = true' in service
assert "root.authorizationPending = false" in service
assert 'privilegedAction("helpers-ensure")' in ui
assert 'if(window && window.lower) window.lower()' in ui
assert '"helpers-ensure"' in manager
assert 'gateway_call("gateway-status")' in manager
assert 'gateway_call("gateway-install")' in manager
assert 'system_call("helpers-install", package_dir)' in manager

print("HADALIRD_POLKIT_ELEVATION_PASS rail/focus yield to native/external authentication; embedded surface hides and restores")
