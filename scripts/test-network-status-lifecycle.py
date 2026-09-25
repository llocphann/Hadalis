#!/usr/bin/env python3
"""Regression contract for process-light NetworkManager status refreshes."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
NETWORK = ROOT / "services/Network.qml"


def main() -> int:
    text = NETWORK.read_text(encoding="utf-8")

    required = (
        'command: ["nmcli", "-t", "-f", "NAME", "c", "show", "--active"]',
        'root.networkName = lines.length > 0 ? lines[0].trim() : ""',
        'command: ["nmcli", "-f", "IN-USE,SIGNAL,SSID", "device", "wifi"]',
        r'line.match(/^\*\s+(\d+)/)',
        'root.networkStrength = parseInt(match[1])',
    )
    for needle in required:
        if needle not in text:
            raise AssertionError(f"Network status contract missing: {needle}")

    forbidden = (
        'nmcli -t -f NAME c show --active | head -1',
        "nmcli -f IN-USE,SIGNAL,SSID device wifi | awk",
    )
    for needle in forbidden:
        if needle in text:
            raise AssertionError(f"Network status refresh restored helper process chain: {needle}")

    print("Network status lifecycle contract: ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
