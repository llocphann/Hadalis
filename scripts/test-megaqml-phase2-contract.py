#!/usr/bin/env python3
"""MegaQML Phase 2a static contract. Never invokes MEGAcmd."""
from pathlib import Path
import re
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
assert 'docs/evidence/megaqml/phase2p-' in runner
quickshell_runner = get("scripts/test-megaqml-quickshell-smoke.sh")
quickshell_base = get("scripts/megaqml-fixtures/runtime-baseline/shell.qml")
quickshell_dormant = get("scripts/megaqml-fixtures/runtime-dormant/shell.qml")
assert 'INIR_NATIVE_BIN_DIR="$work/no-native-binaries"' in quickshell_runner
assert 'QT_QPA_PLATFORM=offscreen' in quickshell_runner
assert 'fixture_kind="${kind%%-*}"' in quickshell_runner
assert 'runtime-$fixture_kind/shell.qml' in quickshell_runner
for case_name in ("baseline", "dormant", "active-present", "active-missing",
                  "active-wrong-id", "active-unsafe-secret", "active-malformed",
                  "refresh-coalesce", "refresh-stale-reacquire",
                  "recovery-exit", "recovery-timeout", "ui-material", "ui-waffle"):
    # The active cases use the same source fixture, not a nonexistent
    # runtime-active-present/ runtime-active-missing directory.
    fixture_kind = case_name.split("-", 1)[0]
    assert (r / f"scripts/megaqml-fixtures/runtime-{fixture_kind}/shell.qml").is_file()
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
assert 'PASS MegaQML synthetic runtime dispatcher: 12 cases plus four second requests and two race requests' in fake_contract
assert 'shared-race' in fake_dispatch
assert '((2, True), (3, False))' in fake_contract
recovery_fixture = get("scripts/megaqml-fixtures/runtime-recovery/shell.qml")
assert 'svc.refreshStatic()' in recovery_fixture
assert 'svc.requestSerial === 2' in recovery_fixture
assert 'MEGAQML_QS_EXIT_RECOVERY_OK' in recovery_fixture
assert 'MEGAQML_QS_TIMEOUT_RECOVERY_OK' in recovery_fixture
assert 'Static dependency check timed out.' in recovery_fixture
assert 'Rust helper failed before static detection completed.' in recovery_fixture
assert 'PRIVATE_FAKE_STDERR_CANARY' not in recovery_fixture
for retry_case in ("retry-exit", "retry-timeout"):
    assert retry_case in fake_dispatch and retry_case in recovery_fixture
for runtime_case in ("quickshell_recover_exit", "quickshell_recover_timeout"):
    assert 'run_test ' + runtime_case in runner
for shell_case in ("recovery-exit", "recovery-timeout"):
    assert shell_case in quickshell_runner
refresh_fixture = get("scripts/megaqml-fixtures/runtime-refresh/shell.qml")
assert 'service.refreshStatic()' in refresh_fixture
assert 'service.unregisterConsumer()' in refresh_fixture
assert 'service.registerConsumer()' in refresh_fixture
assert 'MEGAQML_QS_COALESCED_OK' in refresh_fixture
assert 'MEGAQML_QS_REACQUIRE_OK' in refresh_fixture
assert 'service.requestSerial === 2' in refresh_fixture
assert 'stale-reacquire' in fake_dispatch and 'coalesce' in fake_dispatch
assert 'run_test quickshell_refresh_coalesce' in runner
assert 'run_test quickshell_refresh_stale_reacquire' in runner
for run_type in ("refresh-coalesce", "refresh-stale-reacquire"):
    assert run_type in quickshell_runner
assert 'export MEGAQML_FIXTURE_CASE="${kind#*-}"' in quickshell_runner
assert 'MEGAQML_QS_EXIT_FAILURE_OK' in active_fixture
assert 'MEGAQML_QS_TIMEOUT_OK' in active_fixture
assert 'Static dependency check timed out.' in active_fixture
assert 'Rust helper failed before static detection completed.' in active_fixture
assert 'PRIVATE_FAKE_STDERR_CANARY' in fake_dispatch
assert 'time.monotonic()' in fake_dispatch
for lifecycle_case in ("quickshell_exit_failure", "quickshell_deadline_reap"):
    assert lifecycle_case in runner
for lifecycle_kind in ("active-exit-failure", "active-hang"):
    assert lifecycle_kind in quickshell_runner
assert 'PRIVATE_FAKE_STDERR_CANARY' not in active_fixture
assert 'export PATH="$work/allowed-bin"' in quickshell_runner
assert 'MEGAQML_QS_REJECTED_OK' in active_fixture
for invalid_case in ("wrong-id", "unsafe-secret", "malformed"):
    assert invalid_case in active_fixture and invalid_case in fake_dispatch
for required_case in ("quickshell_reject_wrong_id", "quickshell_reject_unsafe_secret",
                      "quickshell_reject_malformed"):
    assert required_case in runner
assert 'export MEGAQML_FIXTURE_CASE="${kind#*-}"' in quickshell_runner
assert 'run_test megaqml_fake_dispatch_fixture' in runner
ui_fixture_source = get("scripts/test-megaqml-ui-fixture.py")
ui_fixture_contract = get("scripts/test-megaqml-ui-fixture-contract.py")
ui_shell = get("scripts/megaqml-fixtures/runtime-ui/shell.qml")
for token in ("CloudStorageConfig.qml", "WCloudStoragePage.qml",
              "CloudStorageService.qml", "CloudStorageStaticProtocol.js"):
    assert token in ui_fixture_source
assert "import qs." in ui_fixture_source  # rewritten only in temporary copy
assert 'source.replace(before, after, 1)' in ui_fixture_source
assert 'stub_directories = {}' in ui_fixture_source
assert '" 1.0 " + name' in ui_fixture_source
assert 'ContentPage 1.0 ContentPage.qml' in ui_fixture_contract
assert 'WSettingsPage 1.0 WSettingsPage.qml' in ui_fixture_contract
assert 'scripts/native-dispatch' in ui_fixture_contract
assert 'PASS MegaQML isolated Material and Waffle UI source fixture contract' in ui_fixture_contract
host_preflight = get("scripts/test-megaqml-host-route-contract.py")
assert 'run_test megaqml_real_host_route_preflight python3 scripts/test-megaqml-host-route-contract.py' in runner
for route in ("settings.qml", "SettingsOverlay.qml", "SettingsFocus.qml",
              "SettingsPageHost.qml", "waffleSettings.qml", "WSettingsContent.qml"):
    assert route in host_preflight
assert 'PASS MegaQML real Settings host route source-only preflight' in host_preflight
assert 'run_test megaqml_real_host_fixture python3 scripts/test-megaqml-host-ui-fixture-contract.py' in runner
real_host_builder = get("scripts/test-megaqml-host-ui-fixture.py")
real_host_test = get("scripts/test-megaqml-host-ui-fixture-contract.py")
real_host = get("scripts/megaqml-fixtures/runtime-ui-host/shell.qml")
# Host fixture wraps the already-qualified page/service source builder.
# Check the wrapper and its reused builder independently.
for required in ("SettingsPageHost.qml", "SettingsPageLoadingState.js",
                 "runpy.run_path"):
    assert required in real_host_builder
for required in ("CloudStorageConfig.qml", "CloudStorageService.qml"):
    assert required in ui_fixture_source
assert 'PASS isolated MegaQML material source-only UI fixture' in real_host_builder
assert 'PASS MegaQML exact real host and page temporary fixture contract' in real_host_test
assert 'megaqml-realhost-unit-' in real_host_test
for required in ("SettingsPageHost.qml", "root.host.requestedIndex = 1",
                 "root.host.loadEnabled = false", "root.cachedCloud",
                 "MEGAQML_QS_UI_HOST_OK", '"REVISIT_CACHE"', '"HOST_RESET"',
                 '"FINAL_RELEASE"'):
    assert required in real_host
assert "mega-login" not in real_host and "scripts/native-dispatch" not in real_host
assert 'connected: false' in host_preflight
assert 'liveAuthQualified: false' in host_preflight
assert 'kind == "shared"' in ui_fixture_source
assert 'megaqml-shared-unit-' in ui_fixture_contract
assert 'PASS isolated MegaQML shared source-only UI fixture' in ui_fixture_contract
shared_ui = get("scripts/megaqml-fixtures/runtime-ui-shared/shell.qml")
for sentinel in ("MEGAQML_QS_UI_SHARED_OK", '"PREFLIGHT"', '"LOAD"',
                 '"REGISTER"', '"HIDE_ONE"', '"SECOND_RESULT"',
                 '"REACQUIRE"', '"FINAL_RELEASE"', '"TIMEOUT"'):
    assert sentinel in shared_ui
for lease_step in ("svc.consumerCount !== 2", "svc.requestSerial !== 1",
                   "root.goodMissing(svc, 1, 2)", "root.goodMissing(svc, 2, 1)",
                   "root.goodMissing(svc, 3, 1)",
                   "root.material.visible = false", "root.waffle.visible = false"):
    assert lease_step in shared_ui
assert 'root.materialComponent.createObject(' in shared_ui
assert 'root.waffleComponent.createObject(' in shared_ui
assert 'import "./services/deferred" as Deferred' in shared_ui
assert 'svc.refreshStatic()' in shared_ui
# F1 opt-in offline readiness must be verified by actual signal invocation
# on BOTH unchanged copied pages in a shared isolated QML singleton.
for page_signal in ('materialButton.clicked()', 'waffleButton.buttonClicked()'):
    assert page_signal in shared_ui, page_signal
for fixed in ('button_material', 'preflight_material',
              'button_waffle', 'preflight_waffle',
              'replay_start', 'replay_reject'):
    assert 'shared_' + fixed in quickshell_classifier
    assert 'MEGAQML_QS_SHARED_STAGE_' + fixed.upper() in classifier_test
assert 'svc.preflightState !== "not_requested"' in shared_ui
assert 'svc.preflightState !== "dependency_missing"' in shared_ui
assert 'svc.preflightSerial !== 1' in shared_ui
assert 'svc.preflightSerial !== 2' in shared_ui
assert 'svc.preflightSerial !== 3' in shared_ui
assert 'replayButton.buttonClicked()' in shared_ui
assert 'MEGAQML_FIXTURE_CASE=preflight-third-wrong-id' in quickshell_runner
assert 'preflight-third-wrong-id' in get(
    "scripts/megaqml-fixtures/fake-static-dispatch.py")
assert "mega-login" not in shared_ui and "scripts/native-dispatch" not in shared_ui
assert 'run_test megaqml_ui_component_fixture' in runner
for runtime_case, marker in (("quickshell_ui_material", "MEGAQML_QS_UI_MATERIAL_OK"),
                             ("quickshell_ui_waffle", "MEGAQML_QS_UI_WAFFLE_OK")):
    assert 'run_test ' + runtime_case in runner and marker in ui_shell
assert 'root.page.visible = false' in ui_shell
assert 'root.page.destroy()' in ui_shell
for stage in ("SCENARIO", "PREFLIGHT", "COMPONENT", "CONSTRUCT",
              "NAVIGATION", "DETECTION", "RELEASE", "DEADLINE"):
    assert 'MEGAQML_QS_UI_STAGE_' + stage in ui_shell
assert 'Qt.resolvedUrl(location)' in ui_shell
assert 'Component.Loading' in ui_shell
assert 'root.emitDeadlineCause(svc)' in ui_shell
assert 'id: pageHost' in ui_shell
assert 'root.component.createObject(pageHost, { visible: false, width: 1024 })' in ui_shell
assert 'root.createdOnce = true' in ui_shell
assert 'Date.now() - root.started >= 600 && !root.page.leaseHeld' in ui_shell
for category in ("ui_runtime_page_gone", "ui_runtime_page_hidden",
                 "ui_runtime_lease_service_mismatch",
                 "ui_runtime_lease_not_activated"):
    assert category in quickshell_classifier
for marker in ("PAGE_GONE", "PAGE_HIDDEN", "LEASE_SERVICE_MISMATCH",
               "LEASE_NOT_ACTIVATED"):
    assert 'MEGAQML_QS_UI_RUNTIME_' + marker in ui_shell
assert 'MEGAQML_QS_UI_RUNTIME_LEASE_NOT_ACTIVATED' in classifier_test
assert 'Date.now() - root.started >= 8500' in ui_shell
# PAGE_LEASE_ABSENT was superseded by four actionable fixed categories.
# Keep accepting old safe categories in the classifier for historical reports,
# but the current fixture must emit only the new split lease diagnostics.
for runtime_code in ("PAGE_GONE", "PAGE_HIDDEN", "LEASE_SERVICE_MISMATCH",
                     "LEASE_NOT_ACTIVATED", "SERVICE_CONSUMERS_ZERO",
                     "NO_REQUEST", "SERVICE_UNAVAILABLE", "CHECKING_BUSY",
                     "UNEXPECTED_STATE"):
    assert 'MEGAQML_QS_UI_RUNTIME_' + runtime_code in ui_shell
assert 'MEGAQML_QS_UI_RUNTIME_PAGE_LEASE_ABSENT' not in ui_shell
assert 'ui_runtime_page_lease_absent' in quickshell_classifier
for runtime_category in ("ui_runtime_page_lease_absent",
                         "ui_runtime_service_consumers_zero", "ui_runtime_no_request",
                         "ui_runtime_service_unavailable", "ui_runtime_checking_busy"):
    assert runtime_category in quickshell_classifier
assert 'MEGAQML_QS_UI_RUNTIME_SERVICE_CONSUMERS_ZERO' in classifier_test
assert 'enum Severity { Info, Warning, Error, Success }' in ui_fixture_source
assert 'root.component.errorString()' in ui_shell
for typ in ("CONTENT_PAGE", "W_SETTINGS_PAGE", "SHARED_SERVICE",
            "TRANSLATION", "APPEARANCE", "W_INFO_BAR"):
    assert '"MEGAQML_QS_UI_TYPE_" + fixedCode' in ui_shell
    assert '"' + typ + '"' in ui_shell
for category in ("ui_type_content_page", "ui_type_w_settings_page",
                 "ui_type_shared_service", "ui_type_translation",
                 "ui_type_w_info_bar"):
    assert category in quickshell_classifier
assert 'MEGAQML_QS_UI_TYPE_CONTENT_PAGE' in classifier_test
for cause in ("DEFAULT_PROPERTY", "TYPE_RESOLUTION", "MISSING_IMPORT",
              "PROPERTY_ASSIGNMENT", "SINGLETON", "SYNTAX", "LOADING_TIMEOUT",
              "NO_ERROR_API", "NO_DETAIL", "ABSENT", "OTHER"):
    assert 'MEGAQML_QS_UI_CAUSE_' + cause in ui_shell
for category in ("ui_cause_default_property", "ui_cause_type_resolution",
                 "ui_cause_missing_import", "ui_cause_property_assignment",
                 "ui_cause_singleton", "ui_cause_loading_timeout", "ui_cause_other"):
    assert category in quickshell_classifier
assert 'MEGAQML_QS_UI_CAUSE_DEFAULT_PROPERTY' in classifier_test
assert 'MEGAQML_QS_UI_CAUSE_TYPE_RESOLUTION' in classifier_test
for safe_category in ("ui_component_load", "ui_component_create", "ui_navigation",
                      "ui_detection", "ui_consumer_release", "ui_detection_deadline"):
    assert safe_category in quickshell_classifier
assert 'MEGAQML_QS_UI_STAGE_COMPONENT' in classifier_test
assert 'MEGAQML_QS_UI_STAGE_CONSTRUCT' in classifier_test
for shell_case in ("ui-material", "ui-waffle", "ui-shared", "ui-race", "ui-host"):
    assert shell_case in quickshell_runner
assert 'scripts/test-megaqml-ui-fixture.py' in quickshell_runner
# Both ui-shared and ui-race use their dedicated fixture paths through
# the reviewed runtime-$kind mapping, not a hard-coded shared path.
assert 'source_fixture="scripts/megaqml-fixtures/runtime-$kind/shell.qml"' in quickshell_runner
assert 'if [[ "$kind" == ui-shared || "$kind" == ui-race || "$kind" == ui-host ]]; then' in quickshell_runner
assert 'ui-shared) marker=MEGAQML_QS_UI_SHARED_OK' in quickshell_runner
assert 'ui-race) marker=MEGAQML_QS_UI_RACE_OK' in quickshell_runner
assert 'ui-host) marker=MEGAQML_QS_UI_HOST_OK' in quickshell_runner
assert 'scripts/test-megaqml-host-ui-fixture.py' in quickshell_runner
assert 'run_test quickshell_ui_host bash scripts/test-megaqml-quickshell-smoke.sh ui-host' in runner
assert '"ui-host"' in quickshell_classifier
assert 'host_revisit_cache' in quickshell_classifier
assert 'MEGAQML_QS_HOST_STAGE_HOST_RESET' in classifier_test
assert 'runtime-$kind/shell.qml' in quickshell_runner
assert 'fixture_ui_kind=shared' in quickshell_runner
assert 'MEGAQML_FIXTURE_CASE=shared-race' in quickshell_runner
assert 'race_stale_reply' in quickshell_classifier
assert 'MEGAQML_QS_RACE_STAGE_STALE_REPLY' in classifier_test
race_diagnostics = get("scripts/megaqml-fixtures/runtime-ui-race/RaceStageGuard.js")
race_unit = get("scripts/test-megaqml-race-stage-guard.mjs")
assert 'import "./RaceStageGuard.js" as RaceStageGuard' in get(
    "scripts/megaqml-fixtures/runtime-ui-race/shell.qml")
assert 'RaceStageGuard.stageTwo(' in get(
    "scripts/megaqml-fixtures/runtime-ui-race/shell.qml")
assert 'cp -- scripts/megaqml-fixtures/runtime-ui-race/RaceStageGuard.js' in quickshell_runner
assert 'THIRD_FINISHED' in race_unit and 'STALE_SNAPSHOT' in race_unit
assert 'node scripts/test-megaqml-race-stage-guard.mjs' in get(
    "scripts/test-megaqml-phase2p-contracts.sh")
for cause in ("installed", "lease", "unavailable", "snapshot"):
    assert '"race_stale_' + cause + '"' in quickshell_classifier
    assert 'MEGAQML_QS_RACE_STAGE_STALE_' + cause.upper() in classifier_test
    assert '"STALE_' + cause.upper() + '"' in race_diagnostics
assert 'run_test quickshell_ui_shared bash scripts/test-megaqml-quickshell-smoke.sh ui-shared' in runner
assert 'run_test quickshell_ui_race bash scripts/test-megaqml-quickshell-smoke.sh ui-race' in runner
assert 'run_test megaqml_race_repeatability bash scripts/test-megaqml-race-repeat.sh' in runner
assert 'run_test megaqml_race_repeat_contract bash scripts/test-megaqml-phase2p-contracts.sh' in runner
wrapper = get("scripts/test-megaqml-race-repeat.sh")
repeat_unit = get("scripts/test-megaqml-race-repeat-contract.py")
guard = get("scripts/test-megaqml-phase2p-history-guard.py")
guard_unit = get("scripts/test-megaqml-phase2p-history-guard-contract.py")
combined = get("scripts/test-megaqml-phase2p-contracts.sh")
for token in ("repetitions=8", "race_repeat_passes",
              "race_repeat_first_failure", "race_repeat_failure_category"):
    assert token in wrapper
assert "PRIVATE_PATH_AND_PASSWORD_CANARY" in repeat_unit
assert "phase2p-" in guard and "unreviewed changed path" in guard
assert "tampered evidence" in guard_unit
assert "bash -n scripts/test-megaqml-race-repeat.sh" in combined
assert 'test-megaqml-phase2p-history-guard.py "$expected" "$remote_sha"' in runner
assert 'test-megaqml-phase2p-history-guard.py "$source_sha" "$remote_sha"' in runner
actual = re.findall(r'^\s*run_test ([a-z0-9_]+) ', runner, re.MULTILINE)
expected = re.search(r'EXPECTED_TESTS = """([\s\S]*?)"""\.split\(\)', guard)
assert expected is not None and len(actual) == 40
assert actual == expected.group(1).split()

assert 'quickshell_ui_shared quickshell_ui_race megaqml_race_repeatability quickshell_ui_host; do' in runner
race_ui = get("scripts/megaqml-fixtures/runtime-ui-race/shell.qml")
assert 'import "./services/deferred" as Deferred' in race_ui
assert 'property bool sawStaleInstalled: false' in race_ui
assert 'function onBackendStateChanged()' in race_ui
assert 'root.materialComponent.createObject(' in race_ui
assert 'root.waffleComponent.createObject(' in race_ui
for marker in ('"FIRST_START"', '"HIDE_ONE"', '"QUEUE"',
               '"SECOND_START"', '"LAST_RELEASE"', '"REACQUIRE"',
               '"THIRD_RESULT"', '"FINAL_RELEASE"', '"TIMEOUT"'):
    assert marker in race_ui
assert 'svc.requestSerial !== 3' in race_ui
assert 'svc.generation !== beforeRelease + 1' in race_ui
assert 'MEGAQML_QS_UI_RACE_OK' in race_ui
assert 'mega-login' not in race_ui and 'scripts/native-dispatch' not in race_ui
assert 'megaqml-race-unit-' in ui_fixture_contract
assert 'quickshell_ui_waffle quickshell_ui_shared quickshell_ui_race megaqml_race_repeatability quickshell_ui_host; do' in runner
assert 'quickshell_ui_waffle quickshell_ui_shared; do' not in runner
assert '"ui-material", "ui-waffle", "ui-shared"' in quickshell_classifier
assert 'MEGAQML_QS_SHARED_STAGE_HIDE_ONE' in classifier_test
assert 'shared_second_result' in quickshell_classifier
assert 'MEGAQML_QS_SHARED_STAGE_TIMEOUT' in classifier_test
assert 'MEGAQML_UI_KIND' in quickshell_runner
assert 'MEGAQML_FIXTURE_CASE=missing' in quickshell_runner
assert 'quickshell_active_present' in runner and 'quickshell_active_missing' in runner
assert 'export PATH="$work/allowed-bin"' in quickshell_runner
assert 'cp -- scripts/megaqml-fixtures/fake-static-dispatch.py' in quickshell_runner
# This complete runner publishes Phase 2m evidence. The focused
# standalone loader runner intentionally retains the historical 2k prefix.
assert 'docs/evidence/megaqml/phase2p-' in runner
assert 'docs/evidence/megaqml/phase2k-' not in runner
assert 'docs/evidence/megaqml/phase2l-' not in runner
assert 'docs/evidence/megaqml/phase2m-' not in runner
assert 'docs/evidence/megaqml/phase2n-' not in runner
assert 'docs/evidence/megaqml/phase2o-' not in runner
# Full requalification must tolerate only independently reviewed Wull commits
# on shared dev and fail closed on unrelated concurrent source changes.
assert 'wull_only_advance()' in runner
assert 'git merge-base --is-ancestor "$older" "$newer"' in runner
assert 'git diff --name-only -z "$older" "$newer" --' in runner
assert 'git merge --ff-only FETCH_HEAD' in runner
assert 'REMOTE_MISMATCH_UNREVIEWED' in runner
assert 'PUBLICATION_SKIPPED_REMOTE_MOVED_UNREVIEWED' in runner
assert 'PUBLICATION_SKIPPED_DIRTY_AFTER_MERGE' in runner
for allowlisted in ('docs/wull-*', 'scripts/wull-*', 'scripts/test-wull-*',
                    'modules/abyss/*',
                    'to-do/cloud-bot/ABYSS_WATER_DROPLET_COMPANION.md'):
    assert allowlisted in runner
focused = get("scripts/test-megaqml-ui-loader-local.sh")
assert 'docs/evidence/megaqml/phase2k-loader-' in focused
assert 'scripts/test-megaqml-quickshell-smoke.sh ui-material' in focused
assert 'scripts/test-megaqml-quickshell-smoke.sh ui-waffle' in focused
assert 'scripts/test-megaqml-quickshell-smoke.sh baseline' in focused
assert 'scripts/test-megaqml-ui-fixture-contract.py' in focused
assert 'scripts/test-megaqml-quickshell-classifier-contract.py' in focused
assert 'quickshell_smoke_category=' in focused
assert "grep '^quickshell_smoke_category='" in focused
for gate in ('REMOTE_MISMATCH', 'SOURCE_MISMATCH', 'DIRTY_WORKTREE',
             'PUBLICATION_SKIPPED_REMOTE_MOVED', 'git diff --cached --check'):
    assert gate in focused
assert 'git push --quiet origin HEAD:refs/heads/dev' in focused
assert 'wull_only_advance()' in focused
assert 'git merge-base --is-ancestor "$older" "$newer"' in focused
assert 'git diff --name-only -z "$older" "$newer" --' in focused
assert 'git merge --ff-only FETCH_HEAD' in focused
assert 'REMOTE_MISMATCH_UNREVIEWED' in focused
assert 'PUBLICATION_SKIPPED_REMOTE_MOVED_UNREVIEWED' in focused
for allowlisted in ('docs/wull-*', 'scripts/wull-*', 'scripts/test-wull-*',
                    'modules/abyss/*',
                    'to-do/cloud-bot/ABYSS_WATER_DROPLET_COMPANION.md'):
    assert allowlisted in focused
assert 'scripts/native-dispatch' not in focused
assert 'mega-login' not in focused
# F1 additive contract: the explicit preflight is inert and cannot be mistaken
# for vendor authorization. This supplements, rather than weakens, Phase 2p.
preflight_parser = get("services/deferred/CloudStoragePreflightProtocol.js")
rust_source = get("native/inir-mega/src/main.rs")
for required in ('const LIVE_AUTH_VENDOR_ENABLED: bool = false;',
                 'Operation::ConnectPreflight =>',
                 '"probe_kind": "static_connect_preflight"',
                 '"connection_attempted": false',
                 '"connected": false',
                 '"auth_qualified": false',
                 '"account_reads_enabled": false',
                 'PREFLIGHT_INPUT_FORBIDDEN'):
    assert required in rust_source, required
assert "static_detection(path_env)" in rust_source
assert "requestConnectPreflight()" in s
assert 'operation: "connect_preflight"' in s
assert 'import "CloudStoragePreflightProtocol.js" as PreflightProtocol' in s
assert "PreflightProtocol.parseConnectPreflightResponse(" in s
assert "root._preflightGeneration !== root.generation" in s
assert "preflightDeadline.restart()" in s
assert "preflightProc.signal(9)" in s
for required in ('result.connected !== false',
                 'result.connection_attempted !== false',
                 'result.auth_qualified !== false',
                 'result.account_reads_enabled !== false',
                 'result.vendor_execution !== "blocked_pending_disposable_qualification"'):
    assert required in preflight_parser, required
for path in ("modules/settings/CloudStorageConfig.qml",
             "modules/waffle/settings/pages/WCloudStoragePage.qml"):
    page = get(path)
    assert "Check connection readiness (offline)" in page, path
    assert "CloudStorageService.requestConnectPreflight()" in page, path
    assert "root.leaseHeld && !CloudStorageService.preflightBusy" in page, path
    assert '"auth_begin"' not in page, path
assert "CloudStoragePreflightProtocol.js" in get("scripts/test-megaqml-ui-fixture.py")
assert "CloudStoragePreflightProtocol.js" in get("scripts/test-megaqml-quickshell-smoke.sh")
assert "connect_preflight" in boundary
assert "CloudStoragePreflightProtocol.js" in module_test

print("PASS MegaQML Phase 2p static source contract")
