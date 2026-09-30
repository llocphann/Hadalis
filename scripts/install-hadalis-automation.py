#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def require_command(name: str) -> str:
    path = shutil.which(name)
    if path is None:
        raise SystemExit(f"required command not found: {name}")
    return path


def quote(value: str | Path) -> str:
    text = str(value)
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def environment(name: str, value: str | Path) -> str:
    # systemd Environment= parses shell-like words, not shell assignments.
    # Quote the complete NAME=VALUE token; quoting only the RHS can be
    # rejected as an invalid environment assignment on current systemd.
    return f"Environment={quote(f'{name}={value}')}"


def write_unit(path: Path, content: str) -> None:
    path.write_text(content.rstrip() + "\n", encoding="utf-8")
    print(f"wrote {path}")


def install_desktop_launcher(chatgpt: str) -> Path | None:
    """Make ordinary menu/autostart launches compatible with the CDP host.

    Electron's single-instance launcher cannot add debugging flags to an
    already-running app. Preserve the existing desktop entry's metadata and
    actions; only its main Exec command changes in a user-local override.
    """
    data_home = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share")))
    data_dirs = [data_home] + [Path(p) for p in os.environ.get(
        "XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":") if p]
    source = next((p / "applications/chatgpt.desktop" for p in data_dirs
                   if (p / "applications/chatgpt.desktop").is_file()), None)
    if source is None:
        print("ChatGPT desktop entry unavailable; use hadalis-chatgpt.service to launch")
        return None
    executable = chatgpt.replace("%", "%%")
    for char in ("\\", '"', "`", "$"):
        executable = executable.replace(char, "\\" + char)
    # Exec is parsed once as a desktop-entry string and once as argv.
    executable = executable.replace("\\", "\\\\")
    command = (f'Exec="{executable}" --remote-debugging-address=127.0.0.1 '
               '--remote-debugging-port=9222 %U')
    lines = source.read_text(encoding="utf-8").splitlines()
    in_main = False
    replaced = False
    for i, line in enumerate(lines):
        if line.startswith("["):
            in_main = line == "[Desktop Entry]"
        elif in_main and line.startswith("Exec="):
            lines[i] = command
            replaced = True
    if not replaced:
        raise RuntimeError(f"ChatGPT desktop entry has no main Exec command: {source}")
    target = data_home / "applications/chatgpt.desktop"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"wrote {target}")
    return target


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Install Hadalis autonomous user services"
    )
    parser.add_argument(
        "--enable-now",
        action="store_true",
        help="also enable and start the installed services",
    )
    parser.add_argument(
        "--reset-session-state",
        action="store_true",
        help=(
            "safely clear persisted bridge session state before service startup; "
            "fails if another bridge instance currently holds the lock"
        ),
    )
    args = parser.parse_args()

    python = require_command("python3")
    chatgpt = require_command("chatgpt")
    require_command("git")
    require_command("node")
    systemctl = require_command("systemctl")

    units = Path.home() / ".config" / "systemd" / "user"
    units.mkdir(parents=True, exist_ok=True)

    write_unit(
        units / "hadalis-chatgpt.service",
        f"""[Unit]
Description=ChatGPT Desktop for Hadalis automation
PartOf=graphical-session.target

[Service]
Type=simple
WorkingDirectory={ROOT}
ExecStart={quote(python)} -m automation.chat_bridge.desktop_host
{environment("PYTHONUNBUFFERED", "1")}
{environment("HADALIS_CHATGPT_BIN", chatgpt)}
{environment("HADALIS_CHATGPT_CDP_URL", "http://127.0.0.1:9222")}
Restart=on-failure
RestartPreventExitStatus=76
RestartSec=3

[Install]
WantedBy=graphical-session.target
""",
    )

    write_unit(
        units / "hadalis-worker.service",
        f"""[Unit]
Description=Hadalis deterministic local worker

[Service]
Type=simple
WorkingDirectory={ROOT}
ExecStart={quote(python)} {quote(ROOT / "automation" / "worker" / "daemon.py")}
{environment("PYTHONUNBUFFERED", "1")}
Restart=on-failure
RestartSec=3

[Install]
WantedBy=default.target
""",
    )

    write_unit(
        units / "hadalis-chat-bridge.service",
        f"""[Unit]
Description=Hadalis deterministic ChatGPT bridge
Requires=hadalis-chatgpt.service
After=hadalis-chatgpt.service
PartOf=graphical-session.target

[Service]
Type=simple
WorkingDirectory={ROOT}
ExecStart={quote(python)} -m automation.manager.daemon
{environment("PYTHONUNBUFFERED", "1")}
{environment("HADALIS_CHATGPT_CDP_URL", "http://127.0.0.1:9222")}
Restart=on-failure
RestartPreventExitStatus=75
RestartSec=3

[Install]
WantedBy=graphical-session.target
""",
    )

    install_desktop_launcher(chatgpt)
    subprocess.run([systemctl, "--user", "daemon-reload"], check=True)

    systemd_analyze = shutil.which("systemd-analyze")
    if systemd_analyze is not None:
        subprocess.run(
            [
                systemd_analyze,
                "--user",
                "verify",
                str(units / "hadalis-chatgpt.service"),
                str(units / "hadalis-worker.service"),
                str(units / "hadalis-chat-bridge.service"),
            ],
            check=True,
        )

    if args.reset_session_state:
        subprocess.run(
            [
                python,
                "-m",
                "automation.manager.daemon",
                "--reset-state",
            ],
            cwd=ROOT,
            check=True,
        )

    if args.enable_now:
        subprocess.run(
            [
                systemctl,
                "--user",
                "enable",
                "--now",
                "hadalis-chatgpt.service",
                "hadalis-worker.service",
                "hadalis-chat-bridge.service",
            ],
            check=True,
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
