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
        for name in ("CloudStorageService.qml", "CloudStorageStaticProtocol.js"):
            assert (fixture / "services/deferred" / name).read_bytes() == (
                repo / "services/deferred" / name).read_bytes()
        assert (fixture / "services/Translation.qml").is_file()
        assert not (fixture / "scripts/native-dispatch").exists()
        assert not (fixture / "services/Config.qml").exists()
        assert not (fixture / "modules/settings/OverviewConfig.qml").exists()
print("PASS MegaQML isolated Material and Waffle UI source fixture contract")
