#!/usr/bin/env python3
"""Unit checks isolated UI component fixture generation, never running Quickshell."""
from pathlib import Path
import subprocess
import sys
import tempfile

repo = Path(__file__).resolve().parents[1]
generator = repo / "scripts/test-megaqml-ui-fixture.py"
shell = repo / "scripts/megaqml-fixtures/runtime-ui/shell.qml"
source = generator.read_text(encoding="utf-8")
assert "subprocess" not in source and "os.system" not in source
assert '"services/deferred/" + name' in source
assert 'if "import qs." in source' in source
for kind, relative, replacement in (
    ("material", "modules/settings/CloudStorageConfig.qml",
     'import "../../services/deferred"'),
    ("waffle", "modules/waffle/settings/pages/WCloudStoragePage.qml",
     'import "../../../../services/deferred"'),
):
    with tempfile.TemporaryDirectory(prefix="megaqml-ui-unit-") as temp:
        fixture = Path(temp)
        (fixture / "shell.qml").write_bytes(shell.read_bytes())
        child = subprocess.run([sys.executable, str(generator), kind, str(fixture)],
                               capture_output=True, text=True, timeout=3, check=True)
        assert child.stdout.strip() == (
            "PASS isolated MegaQML " + kind + " source-only UI fixture")
        assert child.stderr == ""
        actual = (fixture / relative).read_text(encoding="utf-8")
        original = (repo / relative).read_text(encoding="utf-8")
        assert replacement in actual and "import qs." not in actual
        body = original[original.index("// Independent Waffle"):] if kind == "waffle" \
            else original[original.index("ContentPage {"):]
        assert body in actual
        for name in ("CloudStorageService.qml", "CloudStorageStaticProtocol.js",
                 "CloudStoragePreflightProtocol.js"):
            assert (fixture / "services/deferred" / name).read_bytes() == (
                repo / "services/deferred" / name).read_bytes()
        assert (fixture / "services/Translation.qml").is_file()
        if kind == "material":
            assert "ContentPage 1.0 ContentPage.qml" in (
                fixture / "modules/common/qmldir").read_text()
            assert "StyledText 1.0 StyledText.qml" in (
                fixture / "modules/common/widgets/qmldir").read_text()
            assert not (fixture / "modules/waffle/settings/qmldir").exists()
        else:
            assert "WSettingsPage 1.0 WSettingsPage.qml" in (
                fixture / "modules/waffle/settings/qmldir").read_text()
            assert "WSettingsInfoBar 1.0 WSettingsInfoBar.qml" in (
                fixture / "modules/waffle/settings/qmldir").read_text()
            info_bar = (fixture / "modules/waffle/settings/WSettingsInfoBar.qml"
                        ).read_text()
            assert "enum Severity { Info, Warning, Error, Success }" in info_bar
            assert "property int severity: 0" in info_bar
            assert "WSettingsInfoBar.Severity.Info" not in info_bar
            assert not (fixture / "modules/common/qmldir").exists()
        assert not (fixture / "scripts/native-dispatch").exists()
        assert not (fixture / "services/Config.qml").exists()
        assert not (fixture / "modules/settings/OverviewConfig.qml").exists()
print("PASS MegaQML isolated Material and Waffle UI source fixture contract")

# A shared fixture must resolve both real page bodies from one exact copied
# service singleton; do not use independent temp configurations per page.
with tempfile.TemporaryDirectory(prefix="megaqml-shared-unit-") as temp:
    fixture = Path(temp)
    (fixture / "shell.qml").write_bytes((
        repo / "scripts/megaqml-fixtures/runtime-ui-shared/shell.qml").read_bytes())
    child = subprocess.run([sys.executable, str(generator), "shared", str(fixture)],
                           capture_output=True, text=True, timeout=3, check=True)
    assert child.stdout.strip() == "PASS isolated MegaQML shared source-only UI fixture"
    assert child.stderr == ""
    for relative, required_import, body_anchor in (
        ("modules/settings/CloudStorageConfig.qml",
         'import "../../services/deferred"', "ContentPage {"),
        ("modules/waffle/settings/pages/WCloudStoragePage.qml",
         'import "../../../../services/deferred"', "// Independent Waffle"),
    ):
        actual = (fixture / relative).read_text(encoding="utf-8")
        original = (repo / relative).read_text(encoding="utf-8")
        assert required_import in actual and "import qs." not in actual
        assert original[original.index(body_anchor):] in actual
    for name in ("CloudStorageService.qml", "CloudStorageStaticProtocol.js",
                 "CloudStoragePreflightProtocol.js"):
        assert (fixture / "services/deferred" / name).read_bytes() == (
            repo / "services/deferred" / name).read_bytes()
    assert "ContentPage 1.0 ContentPage.qml" in (
        fixture / "modules/common/qmldir").read_text()
    assert "WSettingsPage 1.0 WSettingsPage.qml" in (
        fixture / "modules/waffle/settings/qmldir").read_text()
    assert not (fixture / "scripts/native-dispatch").exists()
    assert not (fixture / "services/Config.qml").exists()

# The shared fixture must signal the actual controls of BOTH copied pages,
# not bypass their signal handlers with direct service calls. This is only a
# source-level fixture invariant; the one-service runtime result is separate.
shared_shell = (repo / "scripts/megaqml-fixtures/runtime-ui-shared/shell.qml"
                ).read_text(encoding="utf-8")
for token in (
        'root.offlineControl(root.material)',
        'root.offlineControl(root.waffle)',
        'materialButton.clicked()',
        'waffleButton.buttonClicked()',
        'replayButton.buttonClicked()',
        'root.sawPreflightChildStart',
        'svc._preflightGeneration !== -1',
        'root.fail("PREFLIGHT_TIMEOUT")',
        'root.fail("PREFLIGHT_RELEASE")',
        'MEGAQML_QS_UI_SHARED_TIMEOUT_OK',
        'root.releaseCase',
        'root.fail("CANCEL_RELEASE")',
        'root.fail("CANCEL_REAP")',
        'root.fail("CANCEL_REOPEN")',
        'root.fail("CANCEL_RECHECK")',
        'root.goodMissing(svc, 4, 1)',
        'MEGAQML_QS_UI_SHARED_RELEASE_OK',
        'svc.preflightSerial !== 3',
        'root.fail("REPLAY_REJECT")',
        'svc.preflightSerial !== 1',
        'svc.preflightSerial !== 2',
        'svc.preflightState !== "dependency_missing"',
        'svc.preflightState !== "not_requested"',
        'root.goodMissing(svc, 3, 2)',
        'MEGAQML_QS_SHARED_STAGE_',
        'console.log("MEGAQML_QS_UI_SHARED_OK")'):
    assert token in shared_shell, token
for token in ('root.material.setSection("overview")',
              'root.waffle.setSection("overview")'):
    assert token in shared_shell, token
assert "mega-login" not in shared_shell
assert 'operation: "connect_preflight"' not in shared_shell  # page owns it

# Fake-present is a distinct lifecycle path: executable readiness is NOT
# authenticated, and both copied page controls must receive inert responses.
present_shell = (repo / "scripts/megaqml-fixtures/runtime-ui-preflight-present/shell.qml"
                 ).read_text(encoding="utf-8")
for token in (
        'root.materialComponent.createObject(',
        'root.waffleComponent.createObject(',
        'root.buttonUnder(root.material)',
        'root.buttonUnder(root.waffle)',
        'button.clicked()',
        'button.buttonClicked()',
        'svc.preflightState !== "dependencies_ready"',
        'svc.backendState === "installed_disconnected"',
        '!svc.connected && !svc.liveAuthQualified',
        'MEGAQML_QS_UI_PRESENT_OK'):
    assert token in present_shell, token
assert "mega-login" not in present_shell
assert "scripts/native-dispatch" not in present_shell
with tempfile.TemporaryDirectory(prefix="megaqml-present-unit-") as temp:
    fixture = Path(temp)
    (fixture / "shell.qml").write_text(present_shell, encoding="utf-8")
    child = subprocess.run([sys.executable, str(generator), "shared", str(fixture)],
                           capture_output=True, text=True, timeout=3, check=True)
    assert child.stdout.strip() == "PASS isolated MegaQML shared source-only UI fixture"
    assert child.stderr == ""
    for relative in ("modules/settings/CloudStorageConfig.qml",
                     "modules/waffle/settings/pages/WCloudStoragePage.qml"):
        assert (fixture / relative).is_file()
    for name in ("CloudStorageService.qml", "CloudStorageStaticProtocol.js",
                 "CloudStoragePreflightProtocol.js"):
        assert (fixture / "services/deferred" / name).read_bytes() == (
            repo / "services/deferred" / name).read_bytes()
    assert not (fixture / "scripts/native-dispatch").exists()

# Reuse the same temporary shared fixture builder with the independent race
# shell; no production root or second CloudStorageService instance allowed.
with tempfile.TemporaryDirectory(prefix="megaqml-race-unit-") as temp:
    fixture = Path(temp)
    (fixture / "shell.qml").write_bytes((
        repo / "scripts/megaqml-fixtures/runtime-ui-race/shell.qml").read_bytes())
    result = subprocess.run(
        [sys.executable, str(generator), "shared", str(fixture)],
        capture_output=True, text=True, timeout=3, check=True)
    assert result.stdout.strip() == "PASS isolated MegaQML shared source-only UI fixture"
    assert result.stderr == ""
    assert (fixture / "modules/settings/CloudStorageConfig.qml").is_file()
    assert (fixture / "modules/waffle/settings/pages/WCloudStoragePage.qml").is_file()
    assert (fixture / "services/deferred/CloudStorageService.qml").read_bytes() == (
        repo / "services/deferred/CloudStorageService.qml").read_bytes()
    assert not (fixture / "scripts/native-dispatch").exists()
# The separate overlap fixture exercises two real children reaching both
# deadlines, then verifies static retry and manual preflight retry after reap.
overlap_shell = (repo / "scripts/megaqml-fixtures/runtime-ui-preflight-overlap/shell.qml"
                 ).read_text(encoding="utf-8")
for token in (
        'root.offlineControl(root.page)',
        'button.clicked()',
        'root.bothChildrenStarted = true',
        'svc._pendingInput !== ""',
        'svc._preflightInput !== ""',
        'svc.preflightError',
        'Offline readiness invalidated by static dependency timeout.',
        'svc.refreshStatic()',
        'svc.requestSerial !== 2',
        'svc.preflightSerial !== 2',
        'root.fail("CANCEL_REAP")',
        'root.fail("STATIC_RECOVER")',
        'root.fail("PREFLIGHT_RECOVER")',
        'MEGAQML_QS_UI_OVERLAP_OK'):
    assert token in overlap_shell, token
assert "mega-login" not in overlap_shell
assert "scripts/native-dispatch" not in overlap_shell
with tempfile.TemporaryDirectory(prefix="megaqml-overlap-unit-") as temp:
    fixture = Path(temp)
    (fixture / "shell.qml").write_text(overlap_shell, encoding="utf-8")
    child = subprocess.run([sys.executable, str(generator), "shared", str(fixture)],
                           capture_output=True, text=True, timeout=3, check=True)
    assert child.stdout.strip() == "PASS isolated MegaQML shared source-only UI fixture"
    assert child.stderr == ""
    assert (fixture / "services/deferred/CloudStorageService.qml").read_bytes() == (
        repo / "services/deferred/CloudStorageService.qml").read_bytes()
    assert (fixture / "modules/settings/CloudStorageConfig.qml").is_file()
    assert not (fixture / "scripts/native-dispatch").exists()

