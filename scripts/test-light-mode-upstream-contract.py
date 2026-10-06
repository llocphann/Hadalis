#!/usr/bin/env python3
"""Guard shared light-mode semantics adapted from snowarch/iNiR."""

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(path: str, *needles: str) -> None:
    content = read(path)
    missing = [needle for needle in needles if needle not in content]
    if missing:
        raise AssertionError(f"{path}: missing light-mode contract: {missing}")


def main() -> int:
    require(
        "services/MaterialThemeLoader.qml",
        'Config.setNestedValue("appearance.wallpaperTheming.autoDarkLightMode", false)',
    )
    require(
        "scripts/colors/switchwall.sh",
        'lum_source="$imgpath"',
        '-alpha off -resize 64x64',
        'generate_colors_material_args+=(--mode "$mode_flag")',
    )
    require(
        "scripts/colors/generate_colors_material.py",
        "layer1_active, 4.5",
        'selection = mix_hex(primary_container, layer3, 0.75)',
        'if args.scheme != "scheme-monochrome":',
        '("term7", 75.0 if darkmode else 35.0, 4.5)',
        "current.update(material_colors)",
        "current.update(app_palette_json)",
    )
    require(
        "scripts/colors/generate_terminal_configs.py",
        "def contrast_hex(a, b):",
        'colors.setdefault("selectionBg"',
        'selection_foreground    {colors.get("term15"',
        'contrast_hex(colors.get("term7"',
    )
    require(
        "scripts/colors/apply-gtk-theme.sh",
        "theme-meta.json",
        "APPLIED_ICON_THEME",
        'bash "$SCRIPT_DIR/icon-theme-for-mode.sh"',
    )
    require(
        "services/IconThemeService.qml",
        "function _apply(themeName: string, skipRestart: bool): void",
        "id: variantProc",
        "icon-theme-for-mode.sh",
    )
    if not (ROOT / "scripts/colors/icon-theme-for-mode.sh").is_file():
        raise AssertionError("scripts/colors/icon-theme-for-mode.sh is missing")

    print("light-mode upstream contract: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
