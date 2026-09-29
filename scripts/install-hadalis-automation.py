#!/usr/bin/env python3
from __future__ import annotations

import argparse
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


def write_unit(path: Path, content: str) -> None:
    path.write_text(content.rstrip() + "\n", encoding="utf-8")
    print(f"wrote {path}")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Install Hadalis autonomous user services"
    )
    parser.add_argument(
        "--enable-now",
        action="store_true",
        help="also enable and start the installed services",
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
After=graphical-session.target

[Service]
Type=simple
ExecStart={quote(chatgpt)} --remote-debugging-address=127.0.0.1 --remote-debugging-port=9222
Restart=on-failure
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
WorkingDirectory={quote(ROOT)}
ExecStart={quote(python)} {quote(ROOT / "automation" / "worker" / "daemon.py")}
Environment=PYTHONUNBUFFERED=1
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
WorkingDirectory={quote(ROOT)}
ExecStart={quote(python)} -m automation.chat_bridge.runtime
Environment=PYTHONUNBUFFERED=1
Environment=HADALIS_CHATGPT_CDP_URL=http://127.0.0.1:9222
Restart=on-failure
RestartPreventExitStatus=75
RestartSec=3

[Install]
WantedBy=graphical-session.target
""",
    )

    subprocess.run([systemctl, "--user", "daemon-reload"], check=True)

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
