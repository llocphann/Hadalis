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
assert s.index('readDeadline.restart()') < s.index('readProc.running = true')
assert 'root._pendingId' in s
assert 'root._pendingGeneration === root.generation' in s
assert 'property bool startObserved: false' in s
assert 'readProc.startObserved = true' in s
assert 'readProc.startObserved = false' in s
assert 'readProc.signal(9)' in s
assert 'root._pendingInput = ""' in s
assert 'Never admit another request before the timed-out child is reaped.' in s
assert 'readonly property bool connected: false' in s
assert 'readonly property bool liveAuthQualified: false' in s
for forbidden in ('"auth_begin"', 'password:', 'secret:', 'mega-login email', 'mutationProc'):
    assert forbidden not in p and forbidden not in s, forbidden
parser = get("services/deferred/CloudStorageStaticProtocol.js")
for allowed in ("login: result.binaries[1].executable", "whoami: result.binaries[3].executable",
                "version: result.binaries[4].executable"):
    assert allowed in parser, allowed
for executable in ("mega-login:", "mega-whoami:", "mega-version:"):
    assert executable in p, executable
module_test = get("scripts/test-megaqml-phase2-protocol.mjs")
assert 'import assert from "node:assert/strict"' in module_test
assert 'fileURLToPath(import.meta.url)' in module_test
assert 'require("node:' not in module_test
boundary = get("scripts/test-megaqml-phase2-rust-boundary.mjs")
runner = get("scripts/test-megaqml-phase2-local.sh")
assert 'spawnSync(bin, ["request"]' in boundary
assert 'PATH:dir' in boundary and 'shell:false' in boundary
assert 'operation:"detect"' in boundary and 'auth_begin' not in boundary
assert 'cargo build --locked --offline --manifest-path native/Cargo.toml -p inir-mega' in runner
assert 'qml_minimal' in runner and 'qml_modern_syntax' in runner and 'qml_blocker=' in runner
assert '/usr/lib/qt6/bin/qmlformat qmlformat6 qmlformat' in runner
assert 'qt_formatter_selection=' in runner and 'version_major_minor=' in runner
assert 'modern_probe_pass' in runner and 'fallback_probe_unqualified' in runner
print("PASS MegaQML Phase 2a static source contract")
