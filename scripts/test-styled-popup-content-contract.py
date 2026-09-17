#!/usr/bin/env python3
"""Guard the connected bar-popup presentation contract.

The feature/backend objects stay where they are. StyledPopup owns only the presentation
shell: it hosts exactly one visual Item, resolves output ownership from the real visual
anchor, renders into one full-output layer surface, and limits input to the connected
surface mask. These checks catch the QML type-graph mistakes that otherwise make the
entire Bar/VerticalBar unavailable at startup.
"""

from __future__ import annotations

import re
import subprocess
from pathlib import Path

STYLED_POPUP_PATH = Path("modules/bar/StyledPopup.qml")
TASKBAR_PATH = Path("modules/bar/BarTaskbar.qml")
TASKBAR_PREVIEW_PATH = Path("modules/bar/BarTaskbarPreview.qml")
TRAY_PATH = Path("modules/bar/SysTray.qml")
SETTINGS_QMLDIR_PATH = Path("modules/settings/qmldir")
SETTINGS_REGISTRY_PATH = Path("modules/settings/SettingsPageRegistry.qml")

CONSUMER_ROOT_RE = re.compile(r"^\s*StyledPopup\s*\{")
IMPLEMENTATION_ROOT_RE = re.compile(r"^\s*LazyLoader\s*\{")
DIRECT_OBJECT_RE = re.compile(r"^\s*([A-Z][A-Za-z0-9_]*)\s*\{")
EXPLICIT_CONTENT_RE = re.compile(r"^\s*contentItem\s*:\s*([A-Z][A-Za-z0-9_]*)\s*\{")
NON_VISUAL_RE = re.compile(
    r"^\s*(Connections|Timer|Binding|Component|QtObject|Instantiator|PanelWindow|"
    r"PopupWindow|Process|FileView|Socket)\s*\{"
)


def tracked_qml_files() -> list[Path]:
    raw = subprocess.check_output(["git", "ls-files", "-z", "--", "*.qml"])
    return [Path(name) for name in raw.decode().split("\0") if name]


def brace_delta(line: str, state: dict[str, object]) -> int:
    """Count structural braces while ignoring comments and quoted strings."""
    delta = 0
    i = 0
    quote = state.get("quote")
    block_comment = bool(state.get("block_comment"))
    escaped = False

    while i < len(line):
        ch = line[i]
        nxt = line[i + 1] if i + 1 < len(line) else ""

        if block_comment:
            if ch == "*" and nxt == "/":
                block_comment = False
                i += 2
                continue
            i += 1
            continue

        if quote:
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == quote:
                quote = None
            i += 1
            continue

        if ch == "/" and nxt == "/":
            break
        if ch == "/" and nxt == "*":
            block_comment = True
            i += 2
            continue
        if ch in ('"', "'", "`"):
            quote = ch
            escaped = False
            i += 1
            continue
        if ch == "{":
            delta += 1
        elif ch == "}":
            delta -= 1
        i += 1

    state["quote"] = quote
    state["block_comment"] = block_comment
    return delta


def direct_child_violations(path: Path) -> list[tuple[int, str]]:
    """Find non-visual direct children of every StyledPopup block in a file."""
    lines = path.read_text(encoding="utf-8").splitlines()
    state: dict[str, object] = {"quote": None, "block_comment": False}
    depth = 0
    direct_depths: list[int] = []
    found: list[tuple[int, str]] = []

    for line_no, line in enumerate(lines, 1):
        if path == STYLED_POPUP_PATH:
            if depth == 0 and IMPLEMENTATION_ROOT_RE.match(line):
                direct_depths.append(1)
        elif CONSUMER_ROOT_RE.match(line):
            direct_depths.append(depth + 1)

        if direct_depths and depth in direct_depths:
            match = NON_VISUAL_RE.match(line)
            if match:
                found.append((line_no, match.group(1)))

        depth += brace_delta(line, state)
        direct_depths = [direct_depth for direct_depth in direct_depths if depth >= direct_depth]

    return found


def visual_content_violations(path: Path) -> list[str]:
    """Each StyledPopup consumer must supply exactly one visual content root."""
    if path == STYLED_POPUP_PATH:
        return []

    lines = path.read_text(encoding="utf-8").splitlines()
    state: dict[str, object] = {"quote": None, "block_comment": False}
    depth = 0
    blocks: list[dict[str, int]] = []
    failures: list[str] = []

    for line_no, line in enumerate(lines, 1):
        if CONSUMER_ROOT_RE.match(line):
            blocks.append({"direct_depth": depth + 1, "count": 0, "line": line_no})

        for block in blocks:
            if depth != block["direct_depth"]:
                continue
            if DIRECT_OBJECT_RE.match(line) or EXPLICIT_CONTENT_RE.match(line):
                block["count"] += 1

        depth += brace_delta(line, state)

        still_open: list[dict[str, int]] = []
        for block in blocks:
            if depth < block["direct_depth"]:
                if block["count"] != 1:
                    failures.append(
                        f"{path}:{block['line']}: StyledPopup has {block['count']} direct visual "
                        "content roots; expected exactly one Item-compatible root"
                    )
            else:
                still_open.append(block)
        blocks = still_open

    return failures


def require(text: str, needle: str, label: str, failures: list[str]) -> None:
    if needle not in text:
        failures.append(f"{label}: missing required contract `{needle}`")


def forbid(text: str, needle: str, label: str, failures: list[str]) -> None:
    if needle in text:
        failures.append(f"{label}: forbidden legacy/invalid contract `{needle}`")


def source_contract_failures() -> list[str]:
    failures: list[str] = []
    styled = STYLED_POPUP_PATH.read_text(encoding="utf-8")
    taskbar = TASKBAR_PATH.read_text(encoding="utf-8")
    preview = TASKBAR_PREVIEW_PATH.read_text(encoding="utf-8")
    tray = TRAY_PATH.read_text(encoding="utf-8")
    settings_qmldir = SETTINGS_QMLDIR_PATH.read_text(encoding="utf-8")
    settings_registry = SETTINGS_REGISTRY_PATH.read_text(encoding="utf-8")

    # Output/window ownership must come from the actual bar control. QsWindow's
    # mapping API is non-reactive, so windowTransform must participate in the
    # geometry binding. A valid screen is mandatory before the full-output layer
    # surface is allowed to exist; otherwise a dangling output can leave an input
    # mask attached to the wrong monitor.
    require(styled, "root.hoverTarget.QsWindow.window", str(STYLED_POPUP_PATH), failures)
    require(styled, "root._anchorScreen !== null", str(STYLED_POPUP_PATH), failures)
    require(styled, "hostWindow.windowTransform", str(STYLED_POPUP_PATH), failures)
    require(styled, "screen: root._anchorScreen", str(STYLED_POPUP_PATH), failures)
    require(styled, "WlrLayershell.layer: WlrLayer.Overlay", str(STYLED_POPUP_PATH), failures)
    require(styled, "mask: connectedMask", str(STYLED_POPUP_PATH), failures)
    require(styled, "exclusionMode: ExclusionMode.Ignore", str(STYLED_POPUP_PATH), failures)
    require(styled, "devicePixelRatio: popupWindow.devicePixelRatio", str(STYLED_POPUP_PATH), failures)
    require(styled, "property var presentationWindow: null", str(STYLED_POPUP_PATH), failures)
    forbid(styled, "const host = root.QsWindow", str(STYLED_POPUP_PATH), failures)
    forbid(styled, "WlrLayershell.exclusionMode", str(STYLED_POPUP_PATH), failures)

    # Historical taskbar callers may still provide anchor.window. If present, the
    # compatibility group must have a statically known type; `property QtObject`
    # cannot expose its dynamically declared `window` member to grouped syntax.
    if "anchor.window:" in taskbar:
        require(preview, "component LegacyAnchor: QtObject", str(TASKBAR_PREVIEW_PATH), failures)
        require(preview, "property LegacyAnchor anchor: LegacyAnchor", str(TASKBAR_PREVIEW_PATH), failures)
    forbid(preview, "property QtObject anchor: QtObject", str(TASKBAR_PREVIEW_PATH), failures)

    # Presentation peers that need the lazily-created surface (tray focus grab)
    # must use the explicit handle rather than QsWindow on the StyledPopup loader.
    require(tray, "overflowPopup.presentationWindow", str(TRAY_PATH), failures)
    forbid(tray, "overflowPopup.QsWindow", str(TRAY_PATH), failures)

    # Public settings routes intentionally expose Hug-only facades. Their base
    # types and facades must be registered in the settings module or Loader will
    # fail with a blank/error page before any controls are created.
    for registration in (
        "QuickConfig 1.0 QuickConfig.qml",
        "QuickConfigHugOnly 1.0 QuickConfigHugOnly.qml",
        "BarConfig 1.0 BarConfig.qml",
        "BarConfigHugOnly 1.0 BarConfigHugOnly.qml",
    ):
        require(settings_qmldir, registration, str(SETTINGS_QMLDIR_PATH), failures)
    require(
        settings_registry,
        'component: "modules/settings/BarConfigHugOnly.qml"',
        str(SETTINGS_REGISTRY_PATH),
        failures,
    )
    require(
        settings_registry,
        'component: "modules/settings/QuickConfigHugOnly.qml"',
        str(SETTINGS_REGISTRY_PATH),
        failures,
    )

    return failures


def main() -> int:
    failures: list[str] = []
    scanned = 0

    for path in tracked_qml_files():
        text = path.read_text(encoding="utf-8")
        if path != STYLED_POPUP_PATH and "StyledPopup" not in text:
            continue
        scanned += 1
        for line_no, object_type in direct_child_violations(path):
            failures.append(
                f"{path}:{line_no}: direct {object_type} child violates "
                "StyledPopup default property Item contentItem"
            )
        failures.extend(visual_content_violations(path))

    failures.extend(source_contract_failures())

    if failures:
        print("Connected StyledPopup contract failed:")
        for failure in failures:
            print(f"  - {failure}")
        print(
            "Keep one visual content root per popup, keep feature helpers inside that "
            "Item (or explicit object properties), and keep output ownership on the "
            "real visual anchor."
        )
        return 1

    print(
        f"Connected StyledPopup contract passed ({scanned} candidate QML files scanned; "
        "content/anchor/mask/lifecycle/settings contracts verified)."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
