#!/usr/bin/env python3
"""Fail if staged Rust binaries are wired into the current Hadalis runtime.

This guard exists specifically because the native migration is being developed
in parallel. Until the maintainer approves cutover, runtime/package files must
continue to reference the existing Python/QML implementation.
"""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

NATIVE_BINARY_MARKERS = (
    "inir-inputd",
    "inir-native",
    "inir-mpdd",
    "inir-theme",
)

RUNTIME_ROOTS = (
    ROOT / "services",
    ROOT / "modules",
    ROOT / "defaults",
    ROOT / "assets" / "systemd",
    ROOT / "distro",
    ROOT / "nix",
)

RUNTIME_FILES = (
    ROOT / "shell.qml",
    ROOT / "settings.qml",
    ROOT / "setup",
    ROOT / "Makefile",
    ROOT / "scripts" / "inir",
)

TEXT_SUFFIXES = {
    ".qml",
    ".service",
    ".socket",
    ".timer",
    ".kdl",
    ".sh",
    ".py",
    ".nix",
    ".toml",
    ".json",
    ".md",
    ".install",
}


def iter_runtime_files():
    for path in RUNTIME_FILES:
        if path.is_file():
            yield path
    for root in RUNTIME_ROOTS:
        if not root.exists():
            continue
        for path in root.rglob("*"):
            if not path.is_file():
                continue
            if path.suffix in TEXT_SUFFIXES or path.name in {"PKGBUILD", "Makefile"}:
                yield path


def main() -> int:
    violations: list[str] = []
    for path in iter_runtime_files():
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue

        for marker in NATIVE_BINARY_MARKERS:
            if marker in text:
                violations.append(f"{path.relative_to(ROOT)} references {marker}")

    if violations:
        print("Native staging cutover guard failed:")
        for violation in violations:
            print(f"  - {violation}")
        print(
            "Rust must remain unwired until the maintainer explicitly approves "
            "the final migration report."
        )
        return 1

    print("Native staging guard: PASS (Rust binaries are not wired into runtime/package paths)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
