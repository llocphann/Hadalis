#!/usr/bin/env python3
"""Smoke-test the isolated U1 QML/QSB on an owned headless Sway output.

This validates compositor-independent startup, layer-shell mapping, ShaderEffect
loading and actual material pixels at fractional scale. It does not claim to
validate Niri-specific stacking order.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shlex
import shutil
import signal
import subprocess
import time

HERE = Path(__file__).resolve().parent


def wait_for(callback, description: str, timeout: float = 30.0):
    deadline = time.monotonic() + timeout
    last = None
    while time.monotonic() < deadline:
        try:
            last = callback()
            if last:
                return last
        except (OSError, subprocess.SubprocessError, ValueError, json.JSONDecodeError) as exc:
            last = repr(exc)
        time.sleep(0.1)
    raise RuntimeError(f"timeout waiting for {description}; last={last!r}")


def terminate(process: subprocess.Popen | None) -> None:
    if process is None or process.poll() is not None:
        return
    try:
        os.killpg(process.pid, signal.SIGTERM)
        process.wait(timeout=5)
    except (ProcessLookupError, subprocess.TimeoutExpired):
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            pass


def dbus_session(command: list[str], env: dict[str, str]) -> list[str]:
    runner = env.get("HADALIS_WORKFLOW_DBUS_RUN_SESSION") or shutil.which("dbus-run-session")
    if not runner:
        raise RuntimeError("dbus-run-session was not found")

    wrapped = [runner]
    config = env.get("HADALIS_WORKFLOW_DBUS_SESSION_CONFIG", "")
    daemon = env.get("HADALIS_WORKFLOW_DBUS_DAEMON", "")
    if config:
        wrapped.append("--config-file=" + config)
    if daemon:
        wrapped.append("--dbus-daemon=" + daemon)
    return [*wrapped, "--", *command]


def ppm_payload(path: Path) -> tuple[int, int, bytes]:
    data = path.read_bytes()
    if not data.startswith(b"P6"):
        raise RuntimeError(f"{path.name}: expected binary PPM (P6)")

    index = 2
    tokens: list[bytes] = []
    while len(tokens) < 3:
        while index < len(data) and data[index:index + 1].isspace():
            index += 1
        if index < len(data) and data[index:index + 1] == b"#":
            newline = data.find(b"\n", index)
            if newline < 0:
                raise RuntimeError(f"{path.name}: truncated PPM comment")
            index = newline + 1
            continue
        start = index
        while index < len(data) and not data[index:index + 1].isspace():
            index += 1
        if start == index:
            raise RuntimeError(f"{path.name}: truncated PPM header")
        tokens.append(data[start:index])

    width, height, max_value = map(int, tokens)
    if max_value != 255:
        raise RuntimeError(f"{path.name}: unsupported PPM max value {max_value}")
    while index < len(data) and data[index:index + 1].isspace():
        index += 1
    pixels = data[index:]
    expected = width * height * 3
    if len(pixels) != expected:
        raise RuntimeError(
            f"{path.name}: expected {expected} RGB bytes, got {len(pixels)}"
        )
    return width, height, pixels


def count_magenta(path: Path) -> tuple[int, int, int]:
    width, height, pixels = ppm_payload(path)
    hits = 0
    for index in range(0, len(pixels), 3):
        red, green, blue = pixels[index:index + 3]
        if red >= 120 and blue >= 120 and green <= 100:
            hits += 1
    return width, height, hits


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--work-dir", type=Path, required=True)
    parser.add_argument("--sway", type=Path, required=True)
    parser.add_argument("--quickshell", type=Path, required=True)
    parser.add_argument("--grim", type=Path, required=True)
    args = parser.parse_args()

    directory = args.work_dir.resolve()
    if directory.exists():
        raise RuntimeError(f"refusing to reuse smoke directory: {directory}")
    directory.mkdir(parents=True)

    runtime = directory / "runtime"
    runtime.mkdir(mode=0o700)
    display_file = directory / "display.json"
    sway_log_path = directory / "sway.log"
    config = directory / "sway.conf"

    capture = (
        "import json,os;"
        f"open({str(display_file)!r},'w').write(json.dumps("
        "{k:os.environ[k] for k in "
        "('WAYLAND_DISPLAY','SWAYSOCK','XDG_RUNTIME_DIR') if k in os.environ}))"
    )
    config.write_text(
        "xwayland disable\n"
        "output HEADLESS-1 resolution 1280x800 scale 1.25\n"
        "seat seat0 fallback true\n"
        "exec python3 -c " + shlex.quote(capture) + "\n",
        encoding="utf-8",
    )

    host_env = os.environ.copy()
    for key in ("WAYLAND_DISPLAY", "DISPLAY", "SWAYSOCK", "NIRI_SOCKET"):
        host_env.pop(key, None)
    host_env.update(
        XDG_RUNTIME_DIR=str(runtime),
        WLR_BACKENDS="headless",
        WLR_HEADLESS_OUTPUTS="1",
        WLR_RENDERER="pixman",
        XDG_CONFIG_HOME=str(directory / "xdg-config"),
        XDG_CACHE_HOME=str(directory / "xdg-cache"),
        XDG_STATE_HOME=str(directory / "xdg-state"),
        XDG_DATA_HOME=str(directory / "xdg-data"),
    )

    # Nix Sway keeps runtime libraries next to bin/. This mirrors Hadalis'
    # existing owned-headless-compositor harness without touching the desktop.
    sibling_lib = args.sway.resolve().parent.parent / "lib"
    if sibling_lib.is_dir():
        host_env["LD_LIBRARY_PATH"] = str(sibling_lib)

    report: dict[str, object] = {
        "version": 1,
        "backend": "sway-headless-pixman",
        "requested_scale": 1.25,
        "cases": [],
        "failure": None,
    }

    sway_process = None
    try:
        with sway_log_path.open("w", encoding="utf-8") as sway_log:
            sway_process = subprocess.Popen(
                dbus_session(
                    [str(args.sway.resolve()), "-c", str(config)],
                    host_env,
                ),
                env=host_env,
                stdout=sway_log,
                stderr=sway_log,
                start_new_session=True,
            )

        wait_for(
            lambda: display_file.exists() and display_file.stat().st_size > 0,
            "headless Sway display",
            timeout=20,
        )
        if sway_process.poll() is not None:
            raise RuntimeError("headless Sway exited during startup")

        child_env = os.environ.copy()
        child_env.update(json.loads(display_file.read_text(encoding="utf-8")))
        child_env.update(
            XDG_CURRENT_DESKTOP="sway",
            QT_QUICK_CONTROLS_STYLE="Basic",
            QSG_RHI_BACKEND="opengl",
            LIBGL_ALWAYS_SOFTWARE="1",
            QT_OPENGL="software",
        )
        child_env.pop("HYPRLAND_INSTANCE_SIGNATURE", None)
        child_env.pop("NIRI_SOCKET", None)

        swaymsg = args.sway.resolve().with_name("swaymsg")

        def active_output():
            raw = subprocess.check_output(
                [str(swaymsg), "-t", "get_outputs", "-r"],
                env=child_env,
                text=True,
                timeout=5,
            )
            outputs = [item for item in json.loads(raw) if item.get("active")]
            return outputs[0] if outputs else None

        output = wait_for(active_output, "active headless output", timeout=15)
        output_name = str(output["name"])
        actual_scale = float(output.get("scale", 0))
        if abs(actual_scale - 1.25) > 0.001:
            raise RuntimeError(
                f"headless output scale mismatch: expected 1.25, got {actual_scale}"
            )
        report["output"] = output_name
        report["actual_scale"] = actual_scale

        cases = (
            ("overlay-top", "overlay", "top"),
            ("top-left", "top", "left"),
        )
        fatal_markers = (
            "QQmlApplicationEngine failed",
            "Failed to load component",
            "ShaderEffect: Failed",
            "Failed to deserialize",
            "SyntaxError:",
            "ReferenceError:",
            "TypeError:",
            "is not a type",
        )

        for name, layer, edge in cases:
            log_path = directory / f"{name}.log"
            shot_path = directory / f"{name}.ppm"
            case_env = child_env.copy()
            case_env.update(
                HADALIS_U1_OUTPUT=output_name,
                HADALIS_U1_LAYER=layer,
                HADALIS_U1_EDGE=edge,
                HADALIS_U1_MODE="bounded",
                HADALIS_U1_ANIMATE="0",
                HADALIS_U1_REVEAL_CYCLE="0",
                HADALIS_U1_BENCHMARK="0",
                HADALIS_U1_COLOR="#ff00ff",
            )

            process = None
            try:
                with log_path.open("w", encoding="utf-8") as log:
                    process = subprocess.Popen(
                        dbus_session(
                            [
                                str(args.quickshell.resolve()),
                                "-p",
                                str(HERE),
                                "--no-color",
                            ],
                            case_env,
                        ),
                        env=case_env,
                        stdout=log,
                        stderr=log,
                        start_new_session=True,
                    )

                def u1_ready():
                    if process.poll() is not None:
                        text = log_path.read_text(encoding="utf-8", errors="replace")
                        raise RuntimeError(
                            f"Quickshell exited before U1 ready ({name}):\n{text[-4000:]}"
                        )
                    text = log_path.read_text(encoding="utf-8", errors="replace")
                    return "[Hadalis U1] output=" in text

                wait_for(u1_ready, f"U1 ready marker ({name})", timeout=20)
                time.sleep(1.0)
                if process.poll() is not None:
                    raise RuntimeError(f"Quickshell exited after U1 startup ({name})")

                subprocess.run(
                    [
                        str(args.grim.resolve()),
                        "-t",
                        "ppm",
                        "-o",
                        output_name,
                        str(shot_path),
                    ],
                    env=case_env,
                    check=True,
                    timeout=15,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.PIPE,
                    text=True,
                )
                if not shot_path.is_file() or shot_path.stat().st_size < 1024:
                    raise RuntimeError(f"{name}: compositor capture is missing/too small")

                width, height, magenta_pixels = count_magenta(shot_path)
                if magenta_pixels < 100:
                    raise RuntimeError(
                        f"{name}: expected rendered U1 material pixels, got {magenta_pixels}"
                    )

                log_text = log_path.read_text(encoding="utf-8", errors="replace")
                found = [marker for marker in fatal_markers if marker in log_text]
                if found:
                    raise RuntimeError(
                        f"{name}: fatal QML/shader marker(s) in log: {found}"
                    )

                report["cases"].append(
                    {
                        "name": name,
                        "layer": layer,
                        "edge": edge,
                        "capture": shot_path.name,
                        "width": width,
                        "height": height,
                        "magenta_pixels": magenta_pixels,
                        "quickshell_alive": True,
                    }
                )
            finally:
                terminate(process)

    except Exception as exc:
        report["failure"] = repr(exc)
    finally:
        terminate(sway_process)
        (directory / "report.json").write_text(
            json.dumps(report, indent=2) + "\n",
            encoding="utf-8",
        )

    if report["failure"] is not None:
        print(json.dumps(report, indent=2))
        return 1

    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
