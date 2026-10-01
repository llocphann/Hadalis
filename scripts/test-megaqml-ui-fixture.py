#!/usr/bin/env python3
"""Build an isolated QML component fixture; copy real page logic, stub only UI dependencies.

Never import repository-wide services, spawn commands, or copy the production dispatcher.
The only executable supplied by the shell runner is its separate Python fake.
"""
from pathlib import Path
import sys

if len(sys.argv) != 3 or sys.argv[1] not in ("material", "waffle", "shared"):
    raise SystemExit(64)
kind = sys.argv[1]
repo = Path(__file__).resolve().parents[1]
dest = Path(sys.argv[2]).resolve(strict=True)
if not (dest / "shell.qml").is_file() or (dest / "scripts/native-dispatch").exists():
    raise SystemExit(65)

def write(path, source):
    target = dest / path
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists():
        raise SystemExit(66)
    target.write_text(source, encoding="utf-8")

for name in ("CloudStorageService.qml", "CloudStorageStaticProtocol.js",
             "CloudStoragePreflightProtocol.js"):
    source = repo / "services/deferred" / name
    write("services/deferred/" + name, source.read_text(encoding="utf-8"))
write("services/deferred/qmldir",
      "singleton CloudStorageService 1.0 CloudStorageService.qml\n")
write("services/qmldir",
      "singleton Translation 1.0 Translation.qml\n"
      "singleton Appearance 1.0 Appearance.qml\n")
write("services/Translation.qml",
      "pragma Singleton\nimport QtQuick\nQtObject { function tr(value) { return value } }\n")
write("services/Appearance.qml",
      "pragma Singleton\nimport QtQuick\nQtObject {"
      " readonly property QtObject colors: QtObject {"
      " property color colOnSurface: \"white\";"
      " property color colSubtext: \"gray\";"
      " property color colOnLayer0: \"white\""
      " } }\n")

stub = {
    "modules/common/ContentPage.qml":
        "import QtQuick\nItem { property int settingsPageIndex: -1;"
        " property string settingsPageName: \"\" }\n",
    "modules/common/widgets/SettingsTaskNavigator.qml":
        "import QtQuick\nItem { property bool showIntro: true;"
        " property string currentValue: \"\"; property var options: [];"
        " property bool highContrastSelection: false;"
        " signal selected(var value) }\n",
    "modules/common/widgets/SettingsCardSection.qml":
        "import QtQuick\nItem { property bool expanded: false;"
        " property string icon: \"\"; property string title: \"\" }\n",
    "modules/common/widgets/SettingsGroup.qml":
        "import QtQuick\nItem {}\n",
    "modules/common/widgets/StyledComboBox.qml":
        "import QtQuick\nItem { property var model: [];"
        " property int currentIndex: 0; signal activated(int index) }\n",
    "modules/common/widgets/SettingsNote.qml":
        "import QtQuick\nItem { property bool warning: false;"
        " property string text: \"\" }\n",
    "modules/common/widgets/StyledText.qml":
        "import QtQuick\nText {}\n",
    "modules/common/widgets/RippleButton.qml":
        "import QtQuick\nimport QtQuick.Controls\n"
        "Control { property string buttonText: \"\";"
        " signal clicked() }\n",
    "modules/common/widgets/MaterialSymbol.qml":
        "import QtQuick\nItem { property string text: \"\";"
        " property int iconSize: 16; property color color: \"white\" }\n",
    "modules/waffle/settings/WSettingsPage.qml":
        "import QtQuick\nItem { property int settingsPageIndex: -1;"
        " property string pageTitle: \"\"; property string pageIcon: \"\";"
        " property string pageDescription: \"\" }\n",
    "modules/waffle/settings/WSettingsCard.qml":
        "import QtQuick\nItem { property string title: \"\";"
        " property string icon: \"\" }\n",
    "modules/waffle/settings/WSettingsDropdown.qml":
        "import QtQuick\nItem { property string label: \"\";"
        " property string icon: \"\"; property string currentValue: \"\";"
        " property var options: []; signal selected(var value) }\n",
    "modules/waffle/settings/WSettingsInfoBar.qml":
        # Match the real file's enum declaration shape; avoid a self-type
        # reference in the intentionally inert isolated test stub.
        "import QtQuick\nItem {\n"
        " enum Severity { Info, Warning, Error, Success }\n"
        " property int severity: 0\n"
        " property string message: \"\"\n"
        "}\n",
    "modules/waffle/settings/WSettingsButton.qml":
        "import QtQuick\nItem { property string label: \"\";"
        " property string icon: \"\"; property string buttonText: \"\";"
        " property string buttonIcon: \"\";"
        " property string accessibleButtonName: \"\";"
        " signal buttonClicked() }\n",
}
for path, contents in stub.items():
    if kind == "material" and "modules/waffle/" in path:
        continue
    if kind == "waffle" and "modules/common/" in path:
        continue
    write(path, contents)

# Register the small stub module types explicitly so an isolated local
# directory import resolves predictably without an ambient Hadalis import path.
# These qmldir files and type stubs exist only under the disposable fixture.
stub_directories = {}
for relative in stub:
    if kind == "material" and "modules/waffle/" in relative:
        continue
    if kind == "waffle" and "modules/common/" in relative:
        continue
    parent = str(Path(relative).parent)
    stub_directories.setdefault(parent, []).append(Path(relative).name)
for directory, filenames in stub_directories.items():
    write(directory + "/qmldir", "".join(
        Path(name).stem + " 1.0 " + name + "\n" for name in sorted(filenames)))

# Shared test places both untouched real page bodies in the SAME temporary
# Quickshell module tree; the one exact copied service is a common singleton.
for page_kind in (("material", "waffle") if kind == "shared" else (kind,)):
    if page_kind == "material":
        path = "modules/settings/CloudStorageConfig.qml"
        replacements = {
            "import qs.services.deferred\n": 'import "../../services/deferred"\n',
            "import qs.services\n": 'import "../../services"\n',
            "import qs.modules.common.widgets\n": 'import "../common/widgets"\n',
            "import qs.modules.common\n": 'import "../common"\n',
        }
    else:
        path = "modules/waffle/settings/pages/WCloudStoragePage.qml"
        replacements = {
            "import qs.services.deferred\n": 'import "../../../../services/deferred"\n',
            "import qs.services\n": 'import "../../../../services"\n',
            "import qs.modules.waffle.settings\n": 'import ".."\n',
        }
    source = (repo / path).read_text(encoding="utf-8")
    for before, after in replacements.items():
        if source.count(before) != 1:
            raise SystemExit(67)
        source = source.replace(before, after, 1)
    if "import qs." in source:
        raise SystemExit(68)
    write(path, source)
print("PASS isolated MegaQML " + kind + " source-only UI fixture")
