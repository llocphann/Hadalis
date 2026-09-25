#!/usr/bin/env python3
"""Contract for the staged Rust Super-tap daemon port."""

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
WORKSPACE = (ROOT / "native/Cargo.toml").read_text()
LOCK = (ROOT / "native/Cargo.lock").read_text()
CARGO = (ROOT / "native/inir-superd/Cargo.toml").read_text()
SOURCE = (ROOT / "native/inir-superd/src/main.rs").read_text()
PYTHON = (ROOT / "scripts/daemon/inir_super_overview_daemon.py").read_text()
SERVICE = (ROOT / "scripts/systemd/inir-super-overview.service").read_text()
DISPATCH = (ROOT / "scripts/native-dispatch").read_text()
INSTALLER = (ROOT / "native/scripts/install-runtime.sh").read_text()
NIX = (ROOT / "nix/package.nix").read_text()
ARCH = (ROOT / "distro/arch/inir-shell/PKGBUILD").read_text()
ARCH_GIT = (ROOT / "distro/arch/inir-shell-git/PKGBUILD").read_text()


def require(text: str, token: str, message: str) -> None:
    if token not in text:
        print(message)
        sys.exit(1)


require(WORKSPACE, '"inir-superd"', "Rust Super daemon must remain in the native workspace")
require(LOCK, 'name = "inir-superd"', "Cargo.lock must include the Rust Super daemon")
require(CARGO, "evdev.workspace = true", "Rust Super daemon must use the shared evdev backend")
for token in (
    "DEBOUNCE: Duration = Duration::from_millis(250)",
    'name.contains("ydotool") || name.contains("virtual")',
    '["ipc", "overview", function]',
    '["overview", "toggle"]',
    '"WAYLAND_DISPLAY"',
    '"XDG_RUNTIME_DIR"',
    '"QT_QPA_PLATFORM"',
    '"NIRI_SOCKET"',
    "RESCAN_INTERVAL: Duration = Duration::from_secs(5)",
    "fn process_matcher_preserves_legacy_and_path_launch_forms()",
    "fn duplicate_devices_share_global_press_release_and_tap_guard()",
):
    require(SOURCE, token, f"Rust Super daemon parity contract missing: {token}")

# Stage two wires the daemon through the reversible native selector and ships
# the binary in every native runtime package. The systemd service intentionally
# remains on Python until selector parity has passed CI before production cutover.
require(DISPATCH, "super-tap)", "native-dispatch must expose the Super-tap route")
require(DISPATCH, "required_binary=inir-superd", "strict mode must require inir-superd")
require(DISPATCH, '"$BIN_DIR/inir-superd" "$@"', "Super-tap selector must execute the Rust daemon")
require(
    DISPATCH,
    'python_exec_with_module evdev -u "$ROOT_DIR/scripts/daemon/inir_super_overview_daemon.py" "$@"',
    "Super-tap selector must retain the Python evdev fallback",
)
for packaging in (INSTALLER, NIX, ARCH, ARCH_GIT):
    require(packaging, "inir-superd", "native packaging must ship inir-superd")

require(
    SERVICE,
    "inir_super_overview_daemon.py",
    "Stage-one Rust Super daemon must not silently cut over the user service",
)
require(
    PYTHON,
    "async def main():",
    "Python Super daemon fallback must remain available during staged migration",
)

print("Rust Super-tap staged migration contract OK")
