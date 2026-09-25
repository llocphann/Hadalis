#!/usr/bin/env python3
"""Regression contract for process-light SystemInfo identity resolution."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SYSTEM_INFO = ROOT / "services/SystemInfo.qml"


def main() -> int:
    text = SYSTEM_INFO.read_text(encoding="utf-8")

    required = (
        'String(Quickshell.env("USER") ?? "").trim()',
        'id: passwdFile',
        'passwdFile.path = "/etc/passwd"',
        'onLoaded: root._consumePasswd(passwdFile.text())',
        'root._startDisplayNameFallback(name)',
        'command = ["/usr/bin/getent", "passwd", normalized]',
        'command: ["/usr/bin/id", "-un"]',
    )
    for needle in required:
        if needle not in text:
            raise AssertionError(f"SystemInfo identity contract missing: {needle}")

    env_block = text.split("function refreshIdentity(): void", 1)[1].split("Timer {", 1)[0]
    if 'getDisplayName.running = true' in env_block:
        raise AssertionError("normal USER resolution must not spawn getent before /etc/passwd lookup")
    if 'root._resolveDisplayName(envUsername)' not in env_block:
        raise AssertionError("normal USER resolution must use the in-process passwd path")

    consume = text.split("function _consumePasswd", 1)[1].split("function refreshIdentity", 1)[0]
    if 'fields[0] !== name' not in consume or 'fields[4].split(",")[0].trim()' not in consume:
        raise AssertionError("passwd lookup must preserve exact username/GECOS semantics")
    if 'root._startDisplayNameFallback(name)' not in consume:
        raise AssertionError("NSS-only users must retain getent compatibility fallback")

    print("SystemInfo identity lifecycle contract: ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
