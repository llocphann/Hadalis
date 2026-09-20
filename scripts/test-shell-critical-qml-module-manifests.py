#!/usr/bin/env python3
"""Guard shell-critical local QML module manifests.

These modules sit on the startup/open path for Dashboard and both sidebars.
A directory existing is not enough for URI imports: each imported qs.* module
must ship a qmldir with the matching module URI and exported type files.
"""

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]

MODULES = {
    "qs.modules.dashboard": {
        "dir": ROOT / "modules/dashboard",
        "required": {
            "Dashboard": "Dashboard.qml",
            "DashboardContent": "DashboardContent.qml",
            "DashboardCanvas": "DashboardCanvas.qml",
            "DashboardAlignmentGuides": "DashboardAlignmentGuides.qml",
            "DashboardEditToolbar": "DashboardEditToolbar.qml",
            "DashboardHeader": "DashboardHeader.qml",
        },
        "consumers": [
            ROOT / "modules/overview/OverviewDashboard.qml",
        ],
    },
    "qs.modules.sidebarRight.calendar": {
        "dir": ROOT / "modules/sidebarRight/calendar",
        "required": {
            "CalendarWidget": "CalendarWidget.qml",
        },
        "consumers": [
            ROOT / "modules/sidebarRight/BottomWidgetGroup.qml",
            ROOT / "modules/dashboard/DashCalendar.qml",
            ROOT / "modules/dashboard/DashAgenda.qml",
        ],
    },
    "qs.modules.sidebarRight.notepad": {
        "dir": ROOT / "modules/sidebarRight/notepad",
        "required": {
            "NotepadWidget": "NotepadWidget.qml",
        },
        "consumers": [
            ROOT / "modules/sidebarRight/BottomWidgetGroup.qml",
            ROOT / "modules/dashboard/DashNotes.qml",
        ],
    },
}


def parse_qmldir(path: Path):
    if not path.is_file():
        raise AssertionError(f"missing qmldir: {path.relative_to(ROOT)}")

    module_uri = None
    exports = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split()
        if parts[0] == "module":
            if len(parts) != 2:
                raise AssertionError(
                    f"invalid module declaration in {path.relative_to(ROOT)}: {raw}"
                )
            module_uri = parts[1]
            continue
        if len(parts) >= 3 and re.fullmatch(r"\d+(?:\.\d+)+", parts[1]):
            exports[parts[0]] = parts[2]
    return module_uri, exports


for uri, spec in MODULES.items():
    module_dir = spec["dir"]
    qmldir = module_dir / "qmldir"
    module_uri, exports = parse_qmldir(qmldir)

    if module_uri != uri:
        raise AssertionError(
            f"{qmldir.relative_to(ROOT)} declares {module_uri!r}, expected {uri!r}"
        )

    for type_name, filename in spec["required"].items():
        if exports.get(type_name) != filename:
            raise AssertionError(
                f"{qmldir.relative_to(ROOT)} must export "
                f"{type_name} 1.0 {filename}"
            )
        if not (module_dir / filename).is_file():
            raise AssertionError(
                f"{qmldir.relative_to(ROOT)} exports missing file {filename}"
            )

    import_line = f"import {uri}"
    for consumer in spec["consumers"]:
        text = consumer.read_text(encoding="utf-8")
        if import_line not in text:
            raise AssertionError(
                f"{consumer.relative_to(ROOT)} must import {uri}"
            )

print("shell-critical QML module manifests: ok")
