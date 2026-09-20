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


def junction_morphology(
    mask: bytearray,
    width: int,
    height: int,
    geometry: dict,
) -> dict:
    """Measure whether the contact shoulder is exposed at the seam, then tapers.

    The user's failure mode is not merely disconnection: a corrective corner can
    remain connected while sitting underneath the popup body. For a real unified
    field, a free tangent side must protrude outside the popup close to the owner
    seam, then converge back to the popup side deeper into the body.
    """
    popup = geometry["popupRect"]
    inner = geometry["frameInner"]
    edge = str(geometry["edge"])
    logical_width = float(geometry["width"])
    logical_height = float(geometry["height"])
    smooth_k = max(1.0, float(geometry["smoothK"]))

    if logical_width <= 0 or logical_height <= 0:
        raise RuntimeError("invalid logical output size for morphology check")

    sx = width / logical_width
    sy = height / logical_height

    px = float(popup["x"])
    py = float(popup["y"])
    pw = float(popup["width"])
    ph = float(popup["height"])
    il = float(inner["x"])
    it = float(inner["y"])
    ir = il + float(inner["width"])
    ib = it + float(inner["height"])

    near_depth = min(smooth_k * 0.25, (ph if edge in ("top", "bottom") else pw) * 0.20)
    deep_depth = min(smooth_k * 0.95, (ph if edge in ("top", "bottom") else pw) * 0.40)
    deep_depth = max(deep_depth, near_depth + min(4.0, smooth_k * 0.20))

    def row_extent(y_logical: float) -> tuple[float, float]:
        y = max(0, min(height - 1, int(round(y_logical * sy))))
        left = int(round(px * sx))
        right = int(round((px + pw) * sx))
        radius = max(2, int(math.ceil(smooth_k * 2.0 * sx)))

        left_start = max(0, left - radius)
        left_stop = min(width - 1, left + max(2, int(math.ceil(2.0 * sx))))
        left_hits = [
            x for x in range(left_start, left_stop + 1)
            if mask[y * width + x]
        ]

        right_start = max(0, right - max(2, int(math.ceil(2.0 * sx))))
        right_stop = min(width - 1, right + radius)
        right_hits = [
            x for x in range(right_start, right_stop + 1)
            if mask[y * width + x]
        ]

        left_exposure = max(0.0, (left - min(left_hits)) / sx) if left_hits else 0.0
        right_exposure = max(0.0, (max(right_hits) - right) / sx) if right_hits else 0.0
        return left_exposure, right_exposure

    def column_extent(x_logical: float) -> tuple[float, float]:
        x = max(0, min(width - 1, int(round(x_logical * sx))))
        top = int(round(py * sy))
        bottom = int(round((py + ph) * sy))
        radius = max(2, int(math.ceil(smooth_k * 2.0 * sy)))

        top_start = max(0, top - radius)
        top_stop = min(height - 1, top + max(2, int(math.ceil(2.0 * sy))))
        top_hits = [
            y for y in range(top_start, top_stop + 1)
            if mask[y * width + x]
        ]

        bottom_start = max(0, bottom - max(2, int(math.ceil(2.0 * sy))))
        bottom_stop = min(height - 1, bottom + radius)
        bottom_hits = [
            y for y in range(bottom_start, bottom_stop + 1)
            if mask[y * width + x]
        ]

        top_exposure = max(0.0, (top - min(top_hits)) / sy) if top_hits else 0.0
        bottom_exposure = max(0.0, (max(bottom_hits) - bottom) / sy) if bottom_hits else 0.0
        return top_exposure, bottom_exposure

    tolerance = max(1.5, 2.0 / min(sx, sy))
    if edge == "top":
        near = row_extent(py + near_depth)
        deep = row_extent(py + deep_depth)
        labels = ("left", "right")
        free = (px > il + tolerance, px + pw < ir - tolerance)
    elif edge == "bottom":
        near = row_extent(py + ph - near_depth)
        deep = row_extent(py + ph - deep_depth)
        labels = ("left", "right")
        free = (px > il + tolerance, px + pw < ir - tolerance)
    elif edge == "left":
        near = column_extent(px + near_depth)
        deep = column_extent(px + deep_depth)
        labels = ("top", "bottom")
        free = (py > it + tolerance, py + ph < ib - tolerance)
    else:
        near = column_extent(px + pw - near_depth)
        deep = column_extent(px + pw - deep_depth)
        labels = ("top", "bottom")
        free = (py > it + tolerance, py + ph < ib - tolerance)

    free_indices = [index for index, value in enumerate(free) if value]
    if not free_indices:
        return {
            "passed": False,
            "reason": "no free tangent side available to assess shoulder",
            "near_depth": near_depth,
            "deep_depth": deep_depth,
            "near_exposure": dict(zip(labels, near)),
            "deep_exposure": dict(zip(labels, deep)),
            "free_sides": [],
        }

    near_required = max(3.0, smooth_k * 0.20)
    deep_allowed = max(3.0, smooth_k * 0.15)
    taper_required = max(2.0, smooth_k * 0.12)

    per_side = {}
    passed = True
    for index in free_indices:
        name = labels[index]
        near_value = float(near[index])
        deep_value = float(deep[index])
        taper = near_value - deep_value
        side_passed = (
            near_value >= near_required
            and deep_value <= deep_allowed
            and taper >= taper_required
        )
        per_side[name] = {
            "near": near_value,
            "deep": deep_value,
            "taper": taper,
            "passed": side_passed,
        }
        passed = passed and side_passed

    return {
        "passed": passed,
        "near_depth": near_depth,
        "deep_depth": deep_depth,
        "near_required": near_required,
        "deep_allowed": deep_allowed,
        "taper_required": taper_required,
        "near_exposure": dict(zip(labels, near)),
        "deep_exposure": dict(zip(labels, deep)),
        "free_sides": [labels[index] for index in free_indices],
        "per_side": per_side,
    }


def parse_marker(path: Path, marker: str):
    text = path.read_text(encoding="utf-8", errors="replace")
    for line in reversed(text.splitlines()):
        if marker in line:
            payload = line.split(marker, 1)[1].strip()
            return json.loads(payload)
    return None


def parse_markers(path: Path, marker: str) -> list[dict]:
    values: list[dict] = []
    text = path.read_text(encoding="utf-8", errors="replace")
    for line in text.splitlines():
        if marker not in line:
            continue
        payload = line.split(marker, 1)[1].strip()
        try:
            value = json.loads(payload)
        except json.JSONDecodeError:
            continue
        if isinstance(value, dict):
            values.append(value)
    return values


def count_strong_material_pixels(path: Path) -> int:
    width, height, pixels = ppm_payload(path)
    del width, height
    count = 0
    for offset in range(0, len(pixels), 3):
        red, green, blue = pixels[offset:offset + 3]
        if red >= 170 and blue >= 170 and green <= 100:
            count += 1
    return count


def layer_surface_creation_count(log_text: str, layer: str) -> int:
    namespace = f"hadalis:u1-unified-surface-{layer}"
    return sum(
        1
        for line in log_text.splitlines()
        if "get_layer_surface" in line and namespace in line
    )


def niri_windows(niri: str, env: dict[str, str]) -> list[dict]:
    raw = subprocess.check_output(
        [niri, "msg", "-j", "windows"],
        env=env,
        text=True,
        stderr=subprocess.PIPE,
        timeout=8,
    )
    value = json.loads(raw)
    if not isinstance(value, list):
        raise RuntimeError(f"unexpected niri windows payload: {value!r}")
    return [item for item in value if isinstance(item, dict)]


def window_by_title(niri: str, env: dict[str, str], title: str) -> dict | None:
    for item in niri_windows(niri, env):
        if str(item.get("title") or "") == title:
            return item
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
    inner = geometry["frameInner"]
    tolerance = 0.01

    inner_left = float(inner["x"])
    inner_top = float(inner["y"])
    inner_right = inner_left + float(inner["width"])
    inner_bottom = inner_top + float(inner["height"])

    if source_t <= 0.05:
        value = float(popup["x"] if edge in ("top", "bottom") else popup["y"])
        expected = inner_left if edge in ("top", "bottom") else inner_top
        return abs(value - expected) <= tolerance
    if source_t >= 0.95:
        if edge in ("top", "bottom"):
            value = float(popup["x"]) + float(popup["width"])
            return abs(value - inner_right) <= tolerance
        value = float(popup["y"]) + float(popup["height"])
        return abs(value - inner_bottom) <= tolerance
    return True


def run_motion_lifecycle_case(
    *,
    work: Path,
    quickshell: str,
    grim: str,
    env: dict[str, str],
    output: str,
    scale: float,
    layer: str,
) -> dict:
    log_path = work / f"motion-lifecycle-{layer}.log"
    case_env = env.copy()
    case_env.update(
        HADALIS_U1_OUTPUT=output,
        HADALIS_U1_EDGE="top",
        HADALIS_U1_LAYER=layer,
        HADALIS_U1_MODE="bounded",
        HADALIS_U1_SOURCE_T="0.08",
        HADALIS_U1_ANIMATE="1",
        HADALIS_U1_REVEAL_CYCLE="0",
        HADALIS_U1_TRACE_GEOMETRY="1",
        HADALIS_U1_BENCHMARK="0",
        HADALIS_U1_COLOR="#ff00ff",
        QT_QUICK_CONTROLS_STYLE="Basic",
        WAYLAND_DEBUG="client",
    )
    case_env.pop("HYPRLAND_INSTANCE_SIGNATURE", None)

    process = None
    captures: list[dict] = []
    try:
        with log_path.open("w", encoding="utf-8") as log:
            process = subprocess.Popen(
                dbus_session([quickshell, "-p", str(HERE), "--no-color"], case_env),
                env=case_env,
                stdout=log,
                stderr=log,
                start_new_session=True,
            )

        targets = (
            ("left", lambda value: float(value.get("sourceT", 1)) <= 0.20),
            ("center", lambda value: 0.45 <= float(value.get("sourceT", -1)) <= 0.55),
            ("right", lambda value: float(value.get("sourceT", -1)) >= 0.80),
        )

        for label, predicate in targets:
            def target_ready():
                if process.poll() is not None:
                    text = log_path.read_text(encoding="utf-8", errors="replace")
                    raise RuntimeError(
                        f"motion lifecycle exited before {label}:\n{text[-5000:]}"
                    )
                values = parse_markers(log_path, "HADALIS_U1_GEOMETRY ")
                matches = [value for value in values if predicate(value)]
                return matches[-1] if matches else None

            geometry = wait_for(
                target_ready,
                f"motion lifecycle source position {label}",
                timeout=12,
            )
            shot_path = work / f"motion-{layer}-{label}.ppm"
            subprocess.run(
                [grim, "-t", "ppm", "-o", output, str(shot_path)],
                env=case_env,
                check=True,
                text=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.PIPE,
                timeout=15,
            )
            width, height, mask, count, _ = material_mask(shot_path)
            components = component_sizes(mask, width, height)
            dominant_ratio = components[0] / count if components else 0
            if dominant_ratio < 0.98:
                raise RuntimeError(
                    f"motion {layer}/{label}: disconnected material "
                    f"ratio={dominant_ratio:.6f}"
                )
            captures.append(
                {
                    "label": label,
                    "sourceT": geometry.get("sourceT"),
                    "capture": shot_path.name,
                    "material_pixels": count,
                    "dominant_ratio": dominant_ratio,
                }
            )

        values = parse_markers(log_path, "HADALIS_U1_GEOMETRY ")
        source_values = [float(value["sourceT"]) for value in values if "sourceT" in value]
        if len(source_values) < 5:
            raise RuntimeError("motion lifecycle produced too few geometry samples")
        source_span = max(source_values) - min(source_values)
        if source_span < 0.65:
            raise RuntimeError(f"motion lifecycle source span too small: {source_span}")

        log_text = log_path.read_text(encoding="utf-8", errors="replace")
        creations = layer_surface_creation_count(log_text, layer)
        if creations != 1:
            raise RuntimeError(
                f"motion lifecycle remapped layer surface: creations={creations}"
            )
        return {
            "scale": scale,
            "layer": layer,
            "source_span": source_span,
            "geometry_samples": len(values),
            "layer_surface_creations": creations,
            "captures": captures,
            "passed": True,
        }
    finally:
        terminate(process)


def run_reveal_lifecycle_case(
    *,
    work: Path,
    quickshell: str,
    env: dict[str, str],
    output: str,
    scale: float,
    layer: str,
) -> dict:
    log_path = work / f"reveal-lifecycle-{layer}.log"
    case_env = env.copy()
    case_env.update(
        HADALIS_U1_OUTPUT=output,
        HADALIS_U1_EDGE="top",
        HADALIS_U1_LAYER=layer,
        HADALIS_U1_MODE="bounded",
        HADALIS_U1_SOURCE_T="0.5",
        HADALIS_U1_ANIMATE="0",
        HADALIS_U1_REVEAL_CYCLE="1",
        HADALIS_U1_TRACE_GEOMETRY="1",
        HADALIS_U1_BENCHMARK="0",
        HADALIS_U1_COLOR="#ff00ff",
        QT_QUICK_CONTROLS_STYLE="Basic",
        WAYLAND_DEBUG="client",
    )
    case_env.pop("HYPRLAND_INSTANCE_SIGNATURE", None)

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

        def reveal_swept():
            if process.poll() is not None:
                text = log_path.read_text(encoding="utf-8", errors="replace")
                raise RuntimeError(
                    f"reveal lifecycle exited early:\n{text[-5000:]}"
                )
            values = parse_markers(log_path, "HADALIS_U1_GEOMETRY ")
            reveals = [float(value["reveal"]) for value in values if "reveal" in value]
            if len(reveals) < 8:
                return None
            return values if min(reveals) <= 0.08 and max(reveals) >= 0.92 else None

        values = wait_for(reveal_swept, "reveal lifecycle sweep", timeout=10)
        reveals = [float(value["reveal"]) for value in values if "reveal" in value]
        log_text = log_path.read_text(encoding="utf-8", errors="replace")
        creations = layer_surface_creation_count(log_text, layer)
        if creations != 1:
            raise RuntimeError(
                f"reveal lifecycle remapped layer surface: creations={creations}"
            )
        return {
            "scale": scale,
            "layer": layer,
            "reveal_min": min(reveals),
            "reveal_max": max(reveals),
            "geometry_samples": len(values),
            "layer_surface_creations": creations,
            "passed": True,
        }
    finally:
        terminate(process)


def run_fullscreen_lifecycle_case(
    *,
    work: Path,
    niri: str,
    quickshell: str,
    grim: str,
    env: dict[str, str],
    output: str,
    scale: float,
    layer: str,
) -> dict:
    title = "Hadalis U1 Fullscreen Probe"
    log_path = work / f"fullscreen-lifecycle-{layer}.log"
    case_env = env.copy()
    case_env.update(
        HADALIS_U1_OUTPUT=output,
        HADALIS_U1_EDGE="top",
        HADALIS_U1_LAYER=layer,
        HADALIS_U1_MODE="bounded",
        HADALIS_U1_SOURCE_T="0.5",
        HADALIS_U1_ANIMATE="0",
        HADALIS_U1_REVEAL_CYCLE="0",
        HADALIS_U1_TRACE_GEOMETRY="1",
        HADALIS_U1_FULLSCREEN_PROBE="1",
        HADALIS_U1_BENCHMARK="0",
        HADALIS_U1_COLOR="#ff00ff",
        QT_QUICK_CONTROLS_STYLE="Basic",
        WAYLAND_DEBUG="client",
    )
    case_env.pop("HYPRLAND_INSTANCE_SIGNATURE", None)

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

        def ready():
            if process.poll() is not None:
                text = log_path.read_text(encoding="utf-8", errors="replace")
                raise RuntimeError(
                    f"fullscreen lifecycle {layer} exited early:\n{text[-5000:]}"
                )
            geometry = parse_marker(log_path, "HADALIS_U1_GEOMETRY ")
            window = window_by_title(niri, case_env, title)
            return (geometry, window) if geometry and window else None

        geometry, window = wait_for(
            ready,
            f"fullscreen probe window ({layer})",
            timeout=20,
        )
        window_id = window.get("id")
        if window_id is None:
            raise RuntimeError(f"fullscreen probe has no Niri window id: {window}")

        before_path = work / f"fullscreen-{layer}-before.ppm"
        fullscreen_path = work / f"fullscreen-{layer}-active.ppm"
        after_path = work / f"fullscreen-{layer}-after.ppm"

        subprocess.run(
            [grim, "-t", "ppm", "-o", output, str(before_path)],
            env=case_env,
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            timeout=15,
        )
        bw, bh, before_mask, before_count, before_bbox = material_mask(before_path)

        subprocess.run(
            [niri, "msg", "action", "fullscreen-window", "--id", str(window_id)],
            env=case_env,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=8,
        )
        time.sleep(1.0)
        subprocess.run(
            [grim, "-t", "ppm", "-o", output, str(fullscreen_path)],
            env=case_env,
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            timeout=15,
        )
        fullscreen_count = count_strong_material_pixels(fullscreen_path)

        if layer == "overlay" and fullscreen_count < 100:
            raise RuntimeError(
                "Overlay U1 material disappeared behind fullscreen content"
            )

        subprocess.run(
            [niri, "msg", "action", "fullscreen-window", "--id", str(window_id)],
            env=case_env,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=8,
        )
        time.sleep(1.0)
        subprocess.run(
            [grim, "-t", "ppm", "-o", output, str(after_path)],
            env=case_env,
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            timeout=15,
        )
        aw, ah, after_mask, after_count, _ = material_mask(after_path)
        if (bw, bh) != (aw, ah):
            raise RuntimeError(
                f"fullscreen lifecycle capture mismatch: {bw}x{bh} vs {aw}x{ah}"
            )
        return_iou = crop_iou(
            before_mask,
            after_mask,
            bw,
            bh,
            before_bbox,
        )
        if return_iou < 0.995:
            raise RuntimeError(
                f"{layer} material did not return identically after fullscreen: "
                f"IoU={return_iou:.6f}"
            )

        log_text = log_path.read_text(encoding="utf-8", errors="replace")
        creations = layer_surface_creation_count(log_text, layer)
        if creations != 1:
            raise RuntimeError(
                f"fullscreen lifecycle remapped layer surface: creations={creations}"
            )

        return {
            "scale": scale,
            "layer": layer,
            "window_id": window_id,
            "dpr": geometry.get("dpr"),
            "before_material_pixels": before_count,
            "fullscreen_material_pixels": fullscreen_count,
            "after_material_pixels": after_count,
            "return_iou": return_iou,
            "layer_surface_creations": creations,
            "overlay_visible_above_fullscreen": (
                fullscreen_count >= 100 if layer == "overlay" else None
            ),
            "passed": True,
        }
    finally:
        terminate(process)


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
    parser.add_argument(
        "--skip-lifecycle",
        action="store_true",
        help="Skip motion/reveal/fullscreen lifecycle gates during focused topology iteration.",
    )
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
        "motion_lifecycle": {},
        "reveal_lifecycle": {},
        "fullscreen_lifecycle": {},
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
                    morphology = junction_morphology(
                        bounded_mask,
                        bw,
                        bh,
                        bounded_geometry,
                    )

                    passed = (
                        dominant_ratio >= 0.98
                        and iou >= 0.995
                        and clamp_ok
                        and source_ok
                        and morphology["passed"]
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
                        "junction_morphology": morphology,
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
                        f"shoulder={min((v['near'] for v in morphology.get('per_side', {}).values()), default=0):.2f} "
                        f"dpr={bounded_geometry.get('dpr')} {'PASS' if passed else 'FAIL'}"
                    )
                    if not passed:
                        raise RuntimeError(f"U1 topology case failed: {case}")

        if not args.skip_lifecycle:
            lifecycle_scale = float(args.scales[0])
            set_output_scale(niri, child_env, output_name, lifecycle_scale)
            report["motion_lifecycle"] = run_motion_lifecycle_case(
                work=work,
                quickshell=quickshell,
                grim=grim,
                env=child_env,
                output=output_name,
                scale=lifecycle_scale,
                layer=args.layer,
            )
            report["reveal_lifecycle"] = run_reveal_lifecycle_case(
                work=work,
                quickshell=quickshell,
                env=child_env,
                output=output_name,
                scale=lifecycle_scale,
                layer=args.layer,
            )
            for lifecycle_layer in ("top", "overlay"):
                report["fullscreen_lifecycle"][lifecycle_layer] = run_fullscreen_lifecycle_case(
                    work=work,
                    niri=niri,
                    quickshell=quickshell,
                    grim=grim,
                    env=child_env,
                    output=output_name,
                    scale=lifecycle_scale,
                    layer=lifecycle_layer,
                )

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
