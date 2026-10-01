#!/usr/bin/env python3
"""MegaQML Phase 2a static contract. Never invokes MEGAcmd."""
from pathlib import Path
r = Path(__file__).resolve().parents[1]
get = lambda p: (r / p).read_text(encoding="utf-8")
s = get("services/deferred/CloudStorageService.qml")
p = get("modules/settings/CloudStorageConfig.qml")
d = get("modules/settings/SettingsPageRegistryData.qml")
q = get("services/deferred/qmldir")
reg = get("modules/settings/SettingsPageRegistry.qml")
assert 'singleton CloudStorageService 1.0 CloudStorageService.qml' in q
assert 'key:"cloud-storage"' in d
assert 'component:"modules/settings/CloudStorageConfig.qml"' in d
assert 'index === 36' in reg
assert '[24, 7, 6, 35, 36]' in d and '[24, 7, 6, 36]' in d
assert 'settingsPageIndex: 36' in p and 'activateSettingsSearchSection' in p
assert 'registerConsumer()' in p and 'unregisterConsumer()' in p
for route in ("overview", "drive", "transfers", "sync", "backups", "sharing", "contacts", "mounts", "security", "preferences"):
    assert 'key:"' + route + '"' in p, route
assert 'operation: "detect"' in s and 'StaticProtocol.parseDetectResponse(payload, root._pendingId)' in s
assert 'import "CloudStorageStaticProtocol.js" as StaticProtocol' in s
assert 'root.dependencySnapshot = null' in s
assert 'root._pendingId' in s
assert 'root._pendingGeneration === root.generation' in s
assert 'readonly property bool connected: false' in s
assert 'readonly property bool liveAuthQualified: false' in s
for forbidden in ('"auth_begin"', 'password:', 'secret:', 'mega-login email', 'mutationProc'):
    assert forbidden not in p and forbidden not in s, forbidden
print("PASS MegaQML Phase 2a static source contract")
