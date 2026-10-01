#!/usr/bin/env python3
"""Verify disposable real-host fixture contains exact reviewed source bodies."""
from pathlib import Path
import subprocess
import sys
import tempfile

repo = Path(__file__).resolve().parents[1]
builder = repo / "scripts/test-megaqml-host-ui-fixture.py"
with tempfile.TemporaryDirectory(prefix="megaqml-realhost-unit-") as tmp:
    fixture = Path(tmp)
    (fixture / "shell.qml").write_bytes((
        repo / "scripts/megaqml-fixtures/runtime-ui-host/shell.qml").read_bytes())
    child = subprocess.run([sys.executable, str(builder), str(fixture)],
                           capture_output=True, text=True, check=True, timeout=5)
    assert child.stdout.strip() == "PASS isolated MegaQML real host source fixture"
    assert child.stderr == ""

    host_path = "modules/settings/SettingsPageHost.qml"
    expected = (repo / host_path).read_text(encoding="utf-8")
    for before, after in (
        ("import qs.modules.common.widgets\n", 'import "../common/widgets"\n'),
        ("import qs.modules.common\n", 'import "../common"\n'),
        ("import qs.services\n", 'import "../../services"\n'),
    ):
        assert expected.count(before) == 1
        expected = expected.replace(before, after, 1)
    assert (fixture / host_path).read_text(encoding="utf-8") == expected
    assert (fixture / "modules/settings/SettingsPageLoadingState.js").read_bytes() == (
        repo / "modules/settings/SettingsPageLoadingState.js").read_bytes()

    page_path = "modules/settings/CloudStorageConfig.qml"
    page = (fixture / page_path).read_text(encoding="utf-8")
    original = (repo / page_path).read_text(encoding="utf-8")
    assert original[original.index("ContentPage {"):] in page
    for name in ("CloudStorageService.qml", "CloudStorageStaticProtocol.js",
                 "CloudStoragePreflightProtocol.js"):
        assert (fixture / "services/deferred" / name).read_bytes() == (
            repo / "services/deferred" / name).read_bytes()

    assert "singleton SettingsArrangement 1.0 SettingsArrangement.qml" in (
        fixture / "modules/settings/qmldir").read_text(encoding="utf-8")
    assert "singleton Config 1.0 Config.qml" in (
        fixture / "services/qmldir").read_text(encoding="utf-8")
    assert "singleton SettingsMaterialPreset 1.0 SettingsMaterialPreset.qml" in (
        fixture / "modules/common/widgets/qmldir").read_text(encoding="utf-8")
    assert not (fixture / "scripts/native-dispatch").exists()
    assert not (fixture / "modules/settings/SettingsPageRegistry.qml").exists()
    assert not (fixture / "modules/settings/SettingsPageRegistryData.qml").exists()
    assert not (fixture / "modules/settings/SettingsOverlay.qml").exists()
    assert not (fixture / "waffleSettings.qml").exists()
print("PASS MegaQML exact real host and page temporary fixture contract")
