#!/usr/bin/env python3
"""Temporary real SettingsPageHost + real Material page fixture, synthetic only.

No production shell, real vendor executable, account access or network work.
"""
from contextlib import redirect_stdout
import io
from pathlib import Path
import runpy
import sys

if len(sys.argv) != 2:
    raise SystemExit(64)
dest = Path(sys.argv[1]).resolve(strict=True)
repo = Path(__file__).resolve().parents[1]
base = repo / "scripts/test-megaqml-ui-fixture.py"
if not (dest / "shell.qml").is_file() or (dest / "scripts/native-dispatch").exists():
    raise SystemExit(65)

# Reuse the previously qualified real-page, copied-service and inert-visual
# fixture. Run only this reviewed Python builder in the same interpreter.
original_argv = sys.argv
sys.argv = [str(base), "material", str(dest)]
try:
    with redirect_stdout(io.StringIO()) as captured:
        runpy.run_path(str(base), run_name="__main__")
    assert captured.getvalue().strip() == (
        "PASS isolated MegaQML material source-only UI fixture")
finally:
    sys.argv = original_argv

def fresh(path, contents):
    target = dest / path
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists():
        raise SystemExit(66)
    target.write_text(contents, encoding="utf-8")

# Copy the *full* production host and its actual pure JS loading projection.
# Only the three ambient import headers change to the reviewed temp modules.
host_path = "modules/settings/SettingsPageHost.qml"
source = (repo / host_path).read_text(encoding="utf-8")
for before, after in (
    ("import qs.modules.common.widgets\n", 'import "../common/widgets"\n'),
    ("import qs.modules.common\n", 'import "../common"\n'),
    ("import qs.services\n", 'import "../../services"\n'),
):
    if source.count(before) != 1:
        raise SystemExit(67)
    source = source.replace(before, after, 1)
if "import qs." in source:
    raise SystemExit(68)
fresh(host_path, source)
fresh("modules/settings/SettingsPageLoadingState.js",
      (repo / "modules/settings/SettingsPageLoadingState.js"
       ).read_text(encoding="utf-8"))
fresh("modules/settings/SettingsArrangement.qml",
      "pragma Singleton\nimport QtQuick\n"
      "QtObject { function migrateLegacyPageIndices() {} }\n")
fresh("modules/settings/qmldir",
      "singleton SettingsArrangement 1.0 SettingsArrangement.qml\n")
fresh("modules/settings/MegaHostDummy.qml", "import QtQuick\nItem {}\n")

# Existing local stubs are rewritten ONLY within the temporary fixture.
service_qmldir = dest / "services/qmldir"
service_qmldir.write_text(service_qmldir.read_text(encoding="utf-8")
                          + "singleton Config 1.0 Config.qml\n", encoding="utf-8")
fresh("services/Config.qml",
      "pragma Singleton\nimport QtQuick\n"
      "QtObject { property bool ready: false }\n")
(dest / "services/Appearance.qml").write_text(
    "pragma Singleton\nimport QtQuick\nQtObject {\n"
    " readonly property bool animationsEnabled: false\n"
    " readonly property QtObject sizes: QtObject {"
    " property int spacingSmall: 4; property int spacingMedium: 8 }\n"
    " readonly property QtObject animation: QtObject {"
    " readonly property QtObject elementMoveFast: QtObject {"
    " property int duration: 0; property int type: 0;"
    " property var bezierCurve: [] } }\n"
    " readonly property QtObject font: QtObject {"
    " readonly property QtObject pixelSize: QtObject {"
    " property int hugeass: 24; property int normal: 12;"
    " property int small: 10 } }\n"
    " readonly property QtObject colors: QtObject {"
    " property color colOnSurface: 'white'; property color colSubtext: 'gray';"
    " property color colError: 'red'; property color colOnLayer1: 'white'"
    " } }\n", encoding="utf-8")

widgets = {
    "SettingsMaterialPreset.qml":
        "pragma Singleton\nimport QtQuick\n"
        "QtObject { property color cardColor: 'transparent' }\n",
    "MaterialSymbol.qml":
        "import QtQuick\nItem { property string text: '';"
        " property int iconSize: 12; property color color: 'white' }\n",
    "RippleButtonWithIcon.qml":
        "import QtQuick\nItem { property string materialIcon: '';"
        " property string mainText: ''; signal clicked() }\n",
}
qmldir = dest / "modules/common/widgets/qmldir"
for name, contents in widgets.items():
    fresh("modules/common/widgets/" + name, contents)
qmldir.write_text(qmldir.read_text(encoding="utf-8") + "".join(
    ("singleton " if name == "SettingsMaterialPreset.qml" else "")
    + name[:-4] + " 1.0 " + name + "\n"
    for name in sorted(widgets)), encoding="utf-8")

assert not (dest / "services/deferred" / "Config.qml").exists()
assert not (dest / "scripts/native-dispatch").exists()
print("PASS isolated MegaQML real host source fixture")
