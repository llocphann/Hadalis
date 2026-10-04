#!/usr/bin/env python3
"""Render the real Companion settings page using isolated config and a private D-Bus.

The optional roundtrip invokes actual controls, reopens their saved configuration,
and checks the live preview before resetting only Companion. Never starts its daemon
or screenshots the desktop. The short-lived window exports its own QML board.
"""
import argparse
import json
import os
from pathlib import Path
import runpy
import signal
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--section", choices=("overview", "behavior", "rendering", "ai"), default="behavior")
    parser.add_argument("--quality", choices=("performance", "balanced", "quality"), default="quality")
    parser.add_argument("--width", type=int, default=1040)
    parser.add_argument("--height", type=int, default=960)
    parser.add_argument("--roundtrip", action="store_true")
    parser.add_argument("--legacy-config", action="store_true", help="start with the original Companion config fields only")
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists() or not output.parent.is_dir():
        parser.error("output must be a new file in an existing directory")
    if not 480 <= args.width <= 1600 or not 700 <= args.height <= 1600:
        parser.error("preview dimensions must be 480..1600 by 700..1600")
    if not os.environ.get("WAYLAND_DISPLAY") or not os.environ.get("XDG_RUNTIME_DIR"):
        parser.error("a Wayland session is required for the standalone preview")
    core = runpy.run_path(str(ROOT / "scripts/wull-manual-visual-matrix.py"))
    with tempfile.TemporaryDirectory(prefix="wull-settings-") as temporary:
        shell, xdg = core["staged"](Path(temporary))
        (shell / "shell.qml").write_text((ROOT / "scripts/wull-fixtures/settings/CompanionSettingsPreview.qml").read_text())
        config = xdg / "config/illogical-impulse/config.json"
        options = json.loads(config.read_text())
        options["panelFamily"] = "abyss"
        if args.legacy_config:
            for key in ("personality", "appearanceFrequency", "animationsEnabled", "effectsEnabled", "hideInFullscreen", "renderQuality", "translucency", "exploreFeatures"):
                options["abyss"]["companion"].pop(key, None)
        config.write_text(json.dumps(options))
        env = core["private_env"](xdg, output)
        env.pop("WULL_VISUAL_MATRIX_PRIVATE_FILE", None)
        env.update({
            "WULL_SETTINGS_CAPTURE": str(output), "WULL_SETTINGS_WIDTH": str(args.width),
            "WULL_SETTINGS_HEIGHT": str(args.height), "WULL_SETTINGS_SECTION": args.section,
            "WULL_SETTINGS_QUALITY": args.quality,
            "QT_QPA_PLATFORM": "wayland", "QSG_RHI_BACKEND": "opengl", "QT_QUICK_BACKEND": "rhi",
            "QT_QUICK_CONTROLS_STYLE": "Basic", "XDG_RUNTIME_DIR": os.environ["XDG_RUNTIME_DIR"],
            "WAYLAND_DISPLAY": os.environ["WAYLAND_DISPLAY"],
        })
        for phase in (["write", "read"] if args.roundtrip else ["preview"]):
            env["WULL_SETTINGS_PHASE"] = phase
            log_path = Path(temporary) / (phase + ".log")
            with log_path.open("w") as log:
                process = subprocess.Popen(["dbus-run-session", "--", "qs", "--path", str(shell / "shell.qml")],
                    cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT,
                    stdin=subprocess.DEVNULL, start_new_session=True)
                try:
                    code = process.wait(timeout=15)
                finally:
                    if process.poll() is None:
                        os.killpg(process.pid, signal.SIGTERM)
                        process.wait(timeout=3)
            content = log_path.read_text()
            marker = "WULL_SETTINGS_PERSISTENCE=WRITTEN" if phase == "write" else "WULL_SETTINGS_CAPTURE=SAVED"
            bad = ("ReferenceError:", "TypeError:", "SyntaxError:", "Unable to assign", "Failed to load configuration", "WULL_SETTINGS_CHECK=FAIL")
            if code or marker not in content or any(message in content for message in bad):
                print(content[-14000:])
                raise SystemExit("Companion settings QML proof failed: " + phase)
            if phase == "write":
                saved = json.loads(config.read_text())["abyss"]["companion"]
                assert saved["personality"] == "calm" and saved["appearanceFrequency"] == "occasional"
                assert saved["enabled"] and not saved["animationsEnabled"] and not saved["effectsEnabled"]
                assert not saved["exploreFeatures"]
                assert saved["renderQuality"] == "quality"
                assert abs(saved["translucency"] - 0.24) < 0.001
        assert output.is_file(), "settings capture missing"
    print("WULL_SETTINGS_REAL_QML_CAPTURE_PASS" + (" PERSISTENCE_ROUNDTRIP_PASS" if args.roundtrip else ""))
    print(output)


if __name__ == "__main__":
    main()
