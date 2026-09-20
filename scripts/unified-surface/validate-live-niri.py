#!/usr/bin/env python3
"""Run U1 pixel/topology validation inside an isolated nested Niri session.

This script is intentionally local-GPU only. It never edits or reloads the
host Niri config: a fresh nested Niri instance owns its output, scale changes,
U1 layer surfaces, screenshots and benchmark processes.
"""
from __future__ import annotations

import argparse
from collections import deque
import json
import math
import os
from pathlib import Path
import shlex
import shutil
import signal
import subprocess
import tempfile
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


def command_path(explicit: str | None, name: str) -> str:
    if explicit:
        resolved = shutil.which(explicit) if "/" not in explicit else explicit
        if resolved and Path(resolved).exists():
            return str(Path(resolved).resolve())
        raise RuntimeError(f"{name}: explicit command not found: {explicit}")
    resolved = shutil.which(name)
    if not resolved:
        raise RuntimeError(f"required command not found: {name}")
    return str(Path(resolved).resolve())


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


def material_mask(path: Path) -> tuple[int, int, bytearray, int, tuple[int, int, int, int]]:
    width, height, pixels = ppm_payload(path)
    mask = bytearray(width * height)
    count = 0
    min_x, min_y = width, height
    max_x = max_y = -1
    for pixel_index in range(width * height):
        offset = pixel_index * 3
        red, green, blue = pixels[offset:offset + 3]
        # Interior of opaque #ff00ff remains strongly separable from an empty
        # nested-Niri background; AA edge pixels may fall outside this threshold.
        if red >= 170 and blue >= 170 and green <= 100:
            mask[pixel_index] = 1
            count += 1
            x = pixel_index % width
            y = pixel_index // width
            min_x = min(min_x, x)
            max_x = max(max_x, x)
            min_y = min(min_y, y)
            max_y = max(max_y, y)

    if count == 0:
        raise RuntimeError(f"{path.name}: no U1 material pixels detected")
    return width, height, mask, count, (min_x, min_y, max_x, max_y)


def component_sizes(mask: bytearray, width: int, height: int) -> list[int]:
    remaining = {index for index, value in enumerate(mask) if value}
    sizes: list[int] = []
    while remaining:
        seed = remaining.pop()
        queue = deque([seed])
        size = 0
        while queue:
            current = queue.popleft()
            size += 1
            x = current % width
            y = current // width
            for dy in (-1, 0, 1):
                ny = y + dy
                if ny < 0 or ny >= height:
                    continue
                for dx in (-1, 0, 1):
                    if dx == 0 and dy == 0:
                        continue
                    nx = x + dx
                    if nx < 0 or nx >= width:
                        continue
                    neighbor = ny * width + nx
                    if neighbor in remaining:
                        remaining.remove(neighbor)
                        queue.append(neighbor)
        sizes.append(size)
    return sorted(sizes, reverse=True)


def crop_iou(
    first: bytearray,
    second: bytearray,
    width: int,
    height: int,
    bbox: tuple[int, int, int, int],
    margin: int = 3,
) -> float:
    x0, y0, x1, y1 = bbox
    x0 = max(0, x0 - margin)
    y0 = max(0, y0 - margin)
    x1 = min(width - 1, x1 + margin)
    y1 = min(height - 1, y1 + margin)

    intersection = 0
    union = 0
    for y in range(y0, y1 + 1):
        start = y * width + x0
        stop = y * width + x1 + 1
        for a, b in zip(first[start:stop], second[start:stop]):
            if a or b:
                union += 1
                if a and b:
                    intersection += 1
    return intersection / union if union else 1.0


def parse_marker(path: Path, marker: str):
    text = path.read_text(encoding="utf-8", errors="replace")
    for line in reversed(text.splitlines()):
        if marker in line:
            payload = line.split(marker, 1)[1].strip()
            return json.loads(payload)
    return None


def niri_outputs(niri: str, env: dict[str, str]) -> dict:
    raw = subprocess.check_output(
        [niri, "msg", "-j", "outputs"],
        env=env,
        text=True,
        stderr=subprocess.PIPE,
        timeout=8,
    )
    value = json.loads(raw)
    if not isinstance(value, dict) or not value:
        raise RuntimeError(f"unexpected niri outputs payload: {value!r}")
    return value


def mapped_output(outputs: dict) -> tuple[str, dict]:
    for name, info in outputs.items():
        if isinstance(info, dict) and info.get("logical"):
            return str(name), info
    raise RuntimeError("nested Niri has no mapped output")


def output_scale(info: dict) -> float:
    logical = info.get("logical") or {}
    return float(logical.get("scale", 0))


def set_output_scale(niri: str, env: dict[str, str], name: str, scale: float) -> dict:
    subprocess.run(
        [niri, "msg", "output", name, "scale", f"{scale:g}"],
        env=env,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=8,
    )

    def applied():
        outputs = niri_outputs(niri, env)
        info = outputs.get(name)
        if not info:
            return None
        current = output_scale(info)
        return info if abs(current - scale) <= 0.001 else None

    return wait_for(applied, f"Niri output scale {scale:g}", timeout=10)


def run_u1_case(
    *,
    work: Path,
    quickshell: str,
    grim: str,
    env: dict[str, str],
    output: str,
    scale: float,
    edge: str,
    source_t: float,
    mode: str,
    layer: str,
) -> tuple[dict, Path, str]:
    token = f"s{scale:g}-{layer}-{edge}-t{source_t:g}-{mode}".replace(".", "_")
    log_path = work / f"{token}.log"
    shot_path = work / f"{token}.ppm"

    case_env = env.copy()
    case_env.update(
        HADALIS_U1_OUTPUT=output,
        HADALIS_U1_EDGE=edge,
        HADALIS_U1_LAYER=layer,
        HADALIS_U1_MODE=mode,
        HADALIS_U1_SOURCE_T=f"{source_t:.6f}",
        HADALIS_U1_ANIMATE="0",
        HADALIS_U1_REVEAL_CYCLE="0",
        HADALIS_U1_BENCHMARK="0",
        HADALIS_U1_COLOR="#ff00ff",
        QT_QUICK_CONTROLS_STYLE="Basic",
    )
    case_env.pop("HYPRLAND_INSTANCE_SIGNATURE", None)

    process = None
    try:
        with log_path.open("w", encoding="utf-8") as log:
            process = subprocess.Popen(
                dbus_session(
                    [quickshell, "-p", str(HERE), "--no-color"],
                    case_env,
                ),
                env=case_env,
                stdout=log,
                stderr=log,
                start_new_session=True,
            )

        def geometry_ready():
            if process.poll() is not None:
                text = log_path.read_text(encoding="utf-8", errors="replace")
                raise RuntimeError(
                    f"U1 exited before geometry ({token}):\n{text[-5000:]}"
                )
            return parse_marker(log_path, "HADALIS_U1_GEOMETRY ")

        geometry = wait_for(geometry_ready, f"U1 geometry {token}", timeout=20)
        time.sleep(0.25)
        if process.poll() is not None:
            raise RuntimeError(f"U1 exited before capture ({token})")

        subprocess.run(
            [grim, "-t", "ppm", "-o", output, str(shot_path)],
            env=case_env,
            check=True,
            text=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            timeout=15,
        )

        log_text = log_path.read_text(encoding="utf-8", errors="replace")
        fatal = (
            "QQmlApplicationEngine failed",
            "Failed to load component",
            "Failed to create graphics context",
            "Failed to create RHI",
            "ShaderEffect: Failed",
            "Failed to deserialize",
            "SyntaxError:",
            "ReferenceError:",
            "TypeError:",
            "is not a type",
        )
        found = [marker for marker in fatal if marker in log_text]
        if found:
            raise RuntimeError(f"{token}: fatal renderer/QML marker(s): {found}")

        return geometry, shot_path, log_path.name
    finally:
        terminate(process)


def clamp_expected(geometry: dict, source_t: float, edge: str) -> bool:
    popup = geometry["popupRect"]
    width = float(geometry["width"])
    height = float(geometry["height"])
    tolerance = 0.01

    if source_t <= 0.05:
        value = float(popup["x"] if edge in ("top", "bottom") else popup["y"])
        return abs(value) <= tolerance
    if source_t >= 0.95:
        if edge in ("top", "bottom"):
            value = float(popup["x"]) + float(popup["width"])
            return abs(value - width) <= tolerance
        value = float(popup["y"]) + float(popup["height"])
        return abs(value - height) <= tolerance
    return True


def benchmark_mode(
    *,
    work: Path,
    quickshell: str,
    env: dict[str, str],
    output: str,
    edge: str,
    mode: str,
    target_hz: float,
    warmup: int,
    samples: int,
) -> dict:
    log_path = work / f"benchmark-{mode}.log"
    case_env = env.copy()
    case_env.update(
        HADALIS_U1_OUTPUT=output,
        HADALIS_U1_EDGE=edge,
        HADALIS_U1_LAYER="overlay",
        HADALIS_U1_MODE=mode,
        HADALIS_U1_ANIMATE="1",
        HADALIS_U1_REVEAL_CYCLE="0",
        HADALIS_U1_BENCHMARK="1",
        HADALIS_U1_TARGET_HZ=f"{target_hz:g}",
        HADALIS_U1_WARMUP_FRAMES=str(warmup),
        HADALIS_U1_SAMPLE_FRAMES=str(samples),
        HADALIS_U1_COLOR="#ff00ff",
        QT_QUICK_CONTROLS_STYLE="Basic",
    )

    process = None
    try:
        with log_path.open("w", encoding="utf-8") as log:
            process = subprocess.Popen(
                dbus_session([quickshell, "-p", str(HERE), "--no-color"], case_env),
                env=case_env,
                stdout=log,
                stderr=log,
                start_new_session=True,
            )

        timeout = max(20.0, (warmup + samples) / max(30.0, target_hz) * 4.0 + 10.0)

        def report_ready():
            if process.poll() is not None:
                text = log_path.read_text(encoding="utf-8", errors="replace")
                raise RuntimeError(
                    f"benchmark {mode} exited early:\n{text[-5000:]}"
                )
            return parse_marker(log_path, "HADALIS_U1_BENCHMARK ")

        return wait_for(report_ready, f"benchmark {mode}", timeout=timeout)
    finally:
        terminate(process)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--work-dir", type=Path)
    parser.add_argument("--niri")
    parser.add_argument("--quickshell")
    parser.add_argument("--grim")
    parser.add_argument(
        "--scales",
        type=float,
        nargs="+",
        default=[1.25],
        help="Nested-Niri scales to validate. Full U1 matrix: 1 1.25 1.5 1.75 2.",
    )
    parser.add_argument(
        "--edges",
        nargs="+",
        choices=("top", "bottom", "left", "right"),
        default=["top", "bottom", "left", "right"],
    )
    parser.add_argument(
        "--source-ts",
        type=float,
        nargs="+",
        default=[0.02, 0.5, 0.98],
        help="Synthetic source positions; extremes exercise screen-edge clamping.",
    )
    parser.add_argument("--layer", choices=("top", "overlay"), default="overlay")
    parser.add_argument("--benchmark", action="store_true")
    parser.add_argument("--benchmark-warmup", type=int, default=60)
    parser.add_argument("--benchmark-samples", type=int, default=300)
    args = parser.parse_args()

    if not os.environ.get("WAYLAND_DISPLAY") or not os.environ.get("XDG_RUNTIME_DIR"):
        raise RuntimeError("nested Niri validation requires an existing Wayland session")

    niri = command_path(args.niri, "niri")
    quickshell = command_path(args.quickshell, "quickshell")
    grim = command_path(args.grim, "grim")

    if args.work_dir:
        work = args.work_dir.resolve()
        if work.exists():
            raise RuntimeError(f"refusing to reuse work directory: {work}")
        work.mkdir(parents=True)
    else:
        work = Path(tempfile.mkdtemp(prefix="hadalis-u1-live-"))

    runtime = work / "runtime"
    runtime.mkdir(mode=0o700)
    capture_path = work / "nested-display.json"
    niri_log_path = work / "nested-niri.log"
    config_path = work / "niri.kdl"

    capture = (
        "import json,os;"
        f"open({str(capture_path)!r},'w').write(json.dumps("
        "{k:os.environ[k] for k in "
        "('WAYLAND_DISPLAY','NIRI_SOCKET','XDG_RUNTIME_DIR') if k in os.environ}))"
    )
    config_path.write_text(
        'spawn-at-startup "python3" "-c" ' + json.dumps(capture) + "\n"
        "prefer-no-csd\n"
        "hotkey-overlay {\n    skip-at-startup\n}\n",
        encoding="utf-8",
    )

    outer_runtime = Path(os.environ["XDG_RUNTIME_DIR"])
    outer_display = os.environ["WAYLAND_DISPLAY"]
    outer_socket = Path(outer_display)
    if not outer_socket.is_absolute():
        outer_socket = outer_runtime / outer_socket

    nested_env = os.environ.copy()
    nested_env["WAYLAND_DISPLAY"] = str(outer_socket)
    nested_env["XDG_RUNTIME_DIR"] = str(runtime)
    nested_env["XDG_CONFIG_HOME"] = str(work / "xdg-config")
    nested_env["XDG_CACHE_HOME"] = str(work / "xdg-cache")
    nested_env["XDG_STATE_HOME"] = str(work / "xdg-state")
    nested_env["XDG_DATA_HOME"] = str(work / "xdg-data")
    nested_env.pop("NIRI_SOCKET", None)
    nested_env.pop("HYPRLAND_INSTANCE_SIGNATURE", None)

    report: dict[str, object] = {
        "version": 1,
        "work_dir": str(work),
        "nested": True,
        "scales": args.scales,
        "edges": args.edges,
        "source_ts": args.source_ts,
        "layer": args.layer,
        "cases": [],
        "benchmarks": {},
        "failure": None,
    }

    niri_process = None
    try:
        with niri_log_path.open("w", encoding="utf-8") as log:
            niri_process = subprocess.Popen(
                dbus_session([niri, "-c", str(config_path)], nested_env),
                env=nested_env,
                stdout=log,
                stderr=log,
                start_new_session=True,
            )

        wait_for(
            lambda: capture_path.exists() and capture_path.stat().st_size > 0,
            "nested Niri display",
            timeout=30,
        )
        if niri_process.poll() is not None:
            raise RuntimeError("nested Niri exited during startup")

        child_env = os.environ.copy()
        child_env.update(json.loads(capture_path.read_text(encoding="utf-8")))
        child_env["XDG_CONFIG_HOME"] = str(work / "child-config")
        child_env["XDG_CACHE_HOME"] = str(work / "child-cache")
        child_env["XDG_STATE_HOME"] = str(work / "child-state")
        child_env["XDG_DATA_HOME"] = str(work / "child-data")
        child_env["XDG_CURRENT_DESKTOP"] = "niri"
        child_env["QT_QUICK_CONTROLS_STYLE"] = "Basic"
        child_env.pop("HYPRLAND_INSTANCE_SIGNATURE", None)

        outputs = niri_outputs(niri, child_env)
        output_name, info = mapped_output(outputs)
        report["output"] = output_name
        report["initial_output"] = info

        for scale in args.scales:
            if not math.isfinite(scale) or scale <= 0:
                raise RuntimeError(f"invalid scale: {scale}")
            info = set_output_scale(niri, child_env, output_name, scale)
            report.setdefault("scale_outputs", {})[f"{scale:g}"] = info

            for edge in args.edges:
                for source_t in args.source_ts:
                    if source_t < 0 or source_t > 1:
                        raise RuntimeError(f"invalid sourceT: {source_t}")

                    bounded_geometry, bounded_path, bounded_log = run_u1_case(
                        work=work,
                        quickshell=quickshell,
                        grim=grim,
                        env=child_env,
                        output=output_name,
                        scale=scale,
                        edge=edge,
                        source_t=source_t,
                        mode="bounded",
                        layer=args.layer,
                    )
                    full_geometry, full_path, full_log = run_u1_case(
                        work=work,
                        quickshell=quickshell,
                        grim=grim,
                        env=child_env,
                        output=output_name,
                        scale=scale,
                        edge=edge,
                        source_t=source_t,
                        mode="full",
                        layer=args.layer,
                    )

                    bw, bh, bounded_mask, bounded_count, bounded_bbox = material_mask(bounded_path)
                    fw, fh, full_mask, full_count, _ = material_mask(full_path)
                    if (bw, bh) != (fw, fh):
                        raise RuntimeError(
                            f"capture size mismatch bounded={bw}x{bh} full={fw}x{fh}"
                        )

                    components = component_sizes(bounded_mask, bw, bh)
                    dominant_ratio = components[0] / bounded_count if components else 0
                    iou = crop_iou(
                        bounded_mask,
                        full_mask,
                        bw,
                        bh,
                        bounded_bbox,
                    )
                    clamp_ok = clamp_expected(bounded_geometry, source_t, edge)
                    source_ok = abs(float(bounded_geometry["sourceT"]) - source_t) <= 0.001

                    passed = (
                        dominant_ratio >= 0.98
                        and iou >= 0.995
                        and clamp_ok
                        and source_ok
                    )
                    case = {
                        "scale": scale,
                        "edge": edge,
                        "sourceT": source_t,
                        "layer": args.layer,
                        "bounded_pixels": bounded_count,
                        "full_pixels": full_count,
                        "bounded_components": components[:5],
                        "dominant_ratio": dominant_ratio,
                        "bounded_full_iou": iou,
                        "clamp_ok": clamp_ok,
                        "source_ok": source_ok,
                        "dpr": bounded_geometry.get("dpr"),
                        "bounded_effect_rect": bounded_geometry.get("effectRect"),
                        "bounded_capture": bounded_path.name,
                        "full_capture": full_path.name,
                        "bounded_log": bounded_log,
                        "full_log": full_log,
                        "passed": passed,
                    }
                    report["cases"].append(case)
                    print(
                        f"U1 scale={scale:g} edge={edge} t={source_t:g} "
                        f"dominant={dominant_ratio:.5f} iou={iou:.5f} "
                        f"dpr={bounded_geometry.get('dpr')} {'PASS' if passed else 'FAIL'}"
                    )
                    if not passed:
                        raise RuntimeError(f"U1 topology case failed: {case}")

        if args.benchmark:
            outputs = niri_outputs(niri, child_env)
            info = outputs[output_name]
            current_mode_index = info.get("current_mode")
            modes = info.get("modes") or []
            target_hz = 60.0
            if isinstance(current_mode_index, int) and current_mode_index < len(modes):
                refresh = modes[current_mode_index].get("refresh_rate")
                if refresh:
                    target_hz = float(refresh) / 1000.0

            benches = {}
            for mode in ("control", "bounded", "full"):
                benches[mode] = benchmark_mode(
                    work=work,
                    quickshell=quickshell,
                    env=child_env,
                    output=output_name,
                    edge="top",
                    mode=mode,
                    target_hz=target_hz,
                    warmup=max(0, args.benchmark_warmup),
                    samples=max(60, args.benchmark_samples),
                )
            control = benches["control"]
            bounded = benches["bounded"]
            p95_limit = float(control["p95Ms"]) * 1.10
            missed_limit = float(control["missedRatio"]) + 0.01
            benches["gate"] = {
                "p95_limit_ms": p95_limit,
                "missed_ratio_limit": missed_limit,
                "bounded_p95_pass": float(bounded["p95Ms"]) <= p95_limit,
                "bounded_missed_pass": float(bounded["missedRatio"]) <= missed_limit,
            }
            benches["gate"]["passed"] = (
                benches["gate"]["bounded_p95_pass"]
                and benches["gate"]["bounded_missed_pass"]
            )
            report["benchmarks"] = benches
            if not benches["gate"]["passed"]:
                raise RuntimeError(f"U1 benchmark gate failed: {benches['gate']}")

    except Exception as exc:
        report["failure"] = repr(exc)
    finally:
        terminate(niri_process)
        report_path = work / "report.json"
        report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(f"U1 evidence: {report_path}")

    if report["failure"] is not None:
        print(json.dumps({"failure": report["failure"]}, indent=2))
        return 1

    print("U1 live nested-Niri validation: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
