#!/usr/bin/env python3
"""Guard the reversible Rust trial-cutover boundary.

Runtime call sites may route through scripts/native-dispatch, but they must not
invoke Rust binaries directly. Python fallbacks stay present until the
maintainer explicitly approves a permanent cutover.
"""

from __future__ import annotations

from pathlib import Path
import re

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
)

# The launcher lifecycle code must name native processes so it can identify and
# clean orphaned trial helpers after a KillMode=process shell restart. It is
# separately covered by test-native-selector-contract.sh; it is not a runtime
# call site for those binaries.
LIFECYCLE_REFERENCE_FILES = {
    ROOT / "scripts" / "inir",
}

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

        for line_number, line in enumerate(text.splitlines(), start=1):
            for marker in NATIVE_BINARY_MARKERS:
                if marker not in line:
                    continue

                # The selector can expose binary readiness as metadata (for
                # example `inir-mpdd=ready`). That is not a direct runtime
                # binding. Reject executable/path contexts instead of any
                # harmless mention of a binary name.
                direct_path = any(
                    token in line
                    for token in (
                        f"/{marker}",
                        f"./{marker}",
                        f"$BIN_DIR/{marker}",
                        f"${BIN_DIR}/{marker}",
                    )
                )
                direct_command = bool(
                    re.search(
                        rf"(?:ExecStart\\s*=|command\\s*:|execDetached\\s*\\(\\s*\\[|"
                        rf"\\bexec\\s+|\\bcommand\\s+|\\binstall\\s+|\\bcp\\s+|\\bln\\s+)"
                        rf"[^#\\n]*\\b{re.escape(marker)}\\b",
                        line,
                    )
                )
                if direct_path or direct_command:
                    violations.append(
                        f"{path.relative_to(ROOT)}:{line_number} binds directly to {marker}"
                    )

    if violations:
        print("Native trial-cutover guard failed:")
        for violation in violations:
            print(f"  - {violation}")
        print(
            "Runtime/package paths must use scripts/native-dispatch rather than "
            "binding directly to Rust binaries."
        )
        return 1

    print("Native trial-cutover guard: PASS (runtime paths do not bind directly to Rust binaries)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
