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
assert 'docs/evidence/megaqml/phase2f-' in runner
quickshell_runner = get("scripts/test-megaqml-quickshell-smoke.sh")
quickshell_base = get("scripts/megaqml-fixtures/runtime-baseline/shell.qml")
quickshell_dormant = get("scripts/megaqml-fixtures/runtime-dormant/shell.qml")
assert 'INIR_NATIVE_BIN_DIR="$work/no-native-binaries"' in quickshell_runner
assert 'QT_QPA_PLATFORM=offscreen' in quickshell_runner
assert 'runtime-$kind/shell.qml' in quickshell_runner
assert 'cp -- services/deferred/CloudStorageService.qml' in quickshell_runner
assert 'cp -- services/deferred/CloudStorageStaticProtocol.js' in quickshell_runner
assert 'test ! -e "$fixture_dir/scripts/native-dispatch"' in quickshell_runner
assert 'import "./services" as Deferred' in quickshell_dormant
quickshell_classifier = get("scripts/test-megaqml-quickshell-classify.py")
assert 'quickshell_smoke_category=' in quickshell_classifier
classifier_test = get("scripts/test-megaqml-quickshell-classifier-contract.py")
assert 'PASS MegaQML isolated runtime diagnostic redaction' in classifier_test
assert 'run_test megaqml_quickshell_diagnostics' in runner
assert 'print(f"quickshell_smoke_category=' in quickshell_classifier
assert 'quickshell_baseline' in runner and 'quickshell_service_dormant' in runner
assert 'MEGAQML_QS_BASELINE_OK' in quickshell_base
assert 'MEGAQML_QS_DORMANT_OK' in quickshell_dormant
assert 'service.consumerCount === 0' in quickshell_dormant
assert 'service.requestSerial === 0' in quickshell_dormant
assert 'registerConsumer()' not in quickshell_dormant
active_fixture = get("scripts/megaqml-fixtures/runtime-active/shell.qml")
fake_dispatch = get("scripts/megaqml-fixtures/fake-static-dispatch.py")
fake_contract = get("scripts/test-megaqml-fake-dispatch-contract.py")
assert 'service.registerConsumer()' in active_fixture
assert 'service.unregisterConsumer()' in active_fixture
assert 'MEGAQML_QS_ACTIVE_PRESENT_OK' in active_fixture
assert 'MEGAQML_QS_ACTIVE_MISSING_OK' in active_fixture
assert 'json.dumps(' in fake_dispatch and 'subprocess' not in fake_dispatch
assert 'PASS MegaQML synthetic runtime dispatcher: 2 cases' in fake_contract
assert 'run_test megaqml_fake_dispatch_fixture' in runner
assert 'quickshell_active_present' in runner and 'quickshell_active_missing' in runner
assert 'export PATH="$work/allowed-bin"' in quickshell_runner
assert 'cp -- scripts/megaqml-fixtures/fake-static-dispatch.py' in quickshell_runner
assert 'docs/evidence/megaqml/phase2f-' in runner
print("PASS MegaQML Phase 2f static source contract")
