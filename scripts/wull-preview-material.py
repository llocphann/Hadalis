#!/usr/bin/env python3
"""Compare three real Wull shader quality tiers against the unchanged concept."""
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
    parser.add_argument("--probe-directory", type=Path, help="optional existing empty directory for actual RGBA material probes")
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists() or not output.parent.is_dir():
        parser.error("output must be a new file in an existing directory")
    probes = args.probe_directory.resolve() if args.probe_directory else None
    if probes and (not probes.is_dir() or any(probes.iterdir())):
        parser.error("probe directory must be an existing empty directory")
    if not os.environ.get("WAYLAND_DISPLAY") or not os.environ.get("XDG_RUNTIME_DIR"):
        parser.error("a Wayland session is required for this standalone preview")
    core = runpy.run_path(str(ROOT / "scripts/wull-manual-visual-matrix.py"))
    with tempfile.TemporaryDirectory(prefix="wull-material-") as temporary:
        shell, xdg = core["staged"](Path(temporary))
        (shell / "shell.qml").write_text((ROOT / "scripts/wull-fixtures/settings/MaterialQualityPreview.qml").read_text())
        env = core["private_env"](xdg, output)
        env.pop("WULL_VISUAL_MATRIX_PRIVATE_FILE", None)
        env.update({"WULL_MATERIAL_CAPTURE": str(output),
            "WULL_MATERIAL_REFERENCE": str(ROOT / "docs/wull-visual/design-20261003/reference-closeup.png"),
            "QT_QPA_PLATFORM": "wayland", "QSG_RHI_BACKEND": "opengl", "QT_QUICK_BACKEND": "rhi",
            "QT_QUICK_CONTROLS_STYLE": "Basic", "XDG_RUNTIME_DIR": os.environ["XDG_RUNTIME_DIR"],
            "WAYLAND_DISPLAY": os.environ["WAYLAND_DISPLAY"]})
        if probes:
            env["WULL_MATERIAL_PROBES"] = str(probes)
        log_path = Path(temporary) / "material.txt"
        with log_path.open("w") as log:
            process = subprocess.Popen(["dbus-run-session", "--", "qs", "--path", str(shell / "shell.qml")],
                cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL, start_new_session=True)
            try:
                code = process.wait(timeout=15)
            finally:
                if process.poll() is None:
                    os.killpg(process.pid, signal.SIGTERM)
                    process.wait(timeout=3)
        content = log_path.read_text()
        bad = ("ReferenceError:", "TypeError:", "SyntaxError:", "Unable to assign", "Failed to load configuration", "WULL_MATERIAL_CHECK=FAIL")
        if code or "WULL_MATERIAL_TIERS=PASS" not in content or any(message in content for message in bad):
            print(content[-12000:])
            raise SystemExit("Wull material quality comparison failed")
        assert output.is_file()
        if probes:
            assert "WULL_MATERIAL_ALPHA_PROBES=SAVED" in content
            from PIL import Image
            samples = []
            for index, level in enumerate((0, 0.16, 0.35)):
                with Image.open(probes / f"translucency-{index}.png") as source:
                    assert source.mode == "RGBA" and source.size == (228, 276)
                    def mean_alpha(x, y):
                        return sum(source.getpixel((px, py))[3] / 255
                            for px in range(x * 3 - 2, x * 3 + 3)
                            for py in range(y * 3 - 2, y * 3 + 3)) / 25
                    samples.append({"translucency": level, "core_alpha": mean_alpha(38, 35),
                        "left_eye_alpha": mean_alpha(21, 54), "right_eye_alpha": mean_alpha(46, 54)})
            assert samples[0]["core_alpha"] > samples[1]["core_alpha"] > samples[2]["core_alpha"] > 0.7, samples
            assert all(s["left_eye_alpha"] > 0.99 and s["right_eye_alpha"] > 0.99 for s in samples), samples
            (probes / "alpha-samples.json").write_text(json.dumps(samples, indent=2) + "\n")
            print("WULL_REAL_RGBA_TRANSLUCENCY_AND_OPAQUE_EYES_PASS")
    print("WULL_MATERIAL_THREE_TIERS_REAL_QML_AND_POLICY_PASS")
    print(output)


if __name__ == "__main__":
    main()
