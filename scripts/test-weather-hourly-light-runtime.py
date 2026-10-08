#!/usr/bin/env python3
"""Actual popup labels follow light/dark changes in both shell compositions."""
import json
import tempfile
from pathlib import Path
from native_test_session import private_wayland, run_qs

ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="hadalis-weather-hour-ink-") as name:
    folder = Path(name)
    for entry in ["modules", "services", "GlobalStates.qml", "qmldir", "assets", "scripts", "defaults", "translations"]:
        (folder / entry).symlink_to(ROOT / entry)
    (folder / "shell.qml").write_text(r'''
import QtQuick
import QtTest
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.bar.weather
ShellRoot {
    Component.onCompleted: Quickshell.watchFiles = false
    FloatingWindow {
        visible: true; implicitWidth: 500; implicitHeight: 370; color: "#efa071"
        WeatherPopupContent { id: popup; anchors.centerIn: parent; width: 414; height: 314 }
    }
    TestCase {
        id: test; when: false; optional: true
        function check(value, message) { if (!value) throw new Error(message) }
        function labels(item, result) {
            if (typeof item.text === "string" && /^\d\d:\d\d$/.test(item.text) && item.visible)
                result.push(item)
            for (const child of item.children ?? []) labels(child, result)
            return result
        }
        function runChecks() {
            try {
                tryCompare(Config, "ready", true, 4000)
                Config.setNestedValue("performance.reduceAnimations", true)
                Weather.data = {temp: "25°", wCode: "113", description: "Overcast",
                    hourly: Array.from({length: 8}, (_, i) => ({label: String(i * 3).padStart(2, "0") + ":00",
                        temp: "25°", code: "113", isNight: false}))}
                let checked = 0
                for (const family of ["abyss", "ii"]) {
                    Config.setNestedValue("panelFamily", family)
                    wait(100)
                    for (const dark of [false, true, false]) {
                        Appearance.m3colors.darkmode = dark
                        wait(30)
                        const actual = labels(popup, [])
                        check(actual.length >= 8, "hourly labels missing from " + family)
                        for (const label of actual) {
                            check(label.color.a > .5, "hourly label faded out")
                            if (!dark) check(label.color.r === 0 && label.color.g === 0 && label.color.b === 0,
                                "white/light hour survived light mode on " + family + ": " + label.text)
                            else check(label.color.r + label.color.g + label.color.b > .4,
                                "light-mode black was retained in dark mode")
                            checked++
                        }
                    }
                }
                console.info("WEATHER_HOUR_INK_PASS", checked, "actual hourly labels, both routes, live light/dark/light changes")
            } catch (e) { console.error("WEATHER_HOUR_INK_FAIL", e.message, e.stack) }
            Qt.quit()
        }
    }
    Timer { interval: 100; running: true; onTriggered: test.runChecks() }
}
''')
    with private_wayland(folder) as env:
        if env is None:
            print("SKIP: hourly label rendering requires private Niri")
            raise SystemExit(0)
        config = folder / "config/illogical-impulse/config.json"
        config.parent.mkdir()
        data = json.loads((ROOT / "defaults/config.json").read_text())
        data["panelFamily"] = "abyss"
        config.write_text(json.dumps(data))
        env["QT_QUICK_BACKEND"] = "software"
        result = run_qs(folder, env, 20)
        bad = ["WEATHER_HOUR_INK_FAIL", "ReferenceError:", "TypeError:", "Binding loop", "Failed to load configuration"]
        if result.returncode or "WEATHER_HOUR_INK_PASS" not in result.stdout or any(s in result.stdout for s in bad):
            print(result.stdout)
            raise SystemExit(1)
        print("WEATHER_HOUR_INK_PASS actual popup hours remain black in light mode and follow dark-mode ink on both routes")
