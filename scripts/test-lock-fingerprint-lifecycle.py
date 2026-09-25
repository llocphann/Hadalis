#!/usr/bin/env python3
"""Regression contract for demand-driven fingerprint capability probing."""

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
CONTEXT = ROOT / "modules/lock/LockContext.qml"
HOST = ROOT / "modules/lock/Lock.qml"


def main() -> int:
    context = CONTEXT.read_text(encoding="utf-8")
    host = HOST.read_text(encoding="utf-8")

    match = re.search(
        r"Process \{\s*\n\s*id: fingerprintCheckProc(?P<body>.*?)\n\s*\}",
        context,
        flags=re.S,
    )
    if not match:
        raise AssertionError("missing fingerprintCheckProc")

    body = match.group("body")
    if "running: GlobalStates.screenLocked" not in body:
        raise AssertionError("fingerprint capability probe must sleep outside lock sessions")
    if "running: true" in body:
        raise AssertionError("fingerprint capability probe must not run at shell startup")
    if "fprintd-list" not in body:
        raise AssertionError("fingerprint enrollment detection must remain intact")

    required_context = (
        "if (!GlobalStates.screenLocked || !root.fingerprintsConfigured || fingerPam.active)",
        "if (root.fingerprintsConfigured && GlobalStates.screenLocked)",
        "Qt.callLater(root.tryFingerUnlock)",
    )
    for needle in required_context:
        if needle not in context:
            raise AssertionError(f"fingerprint unlock contract missing: {needle}")

    if "function onScreenLockedChanged()" not in host:
        raise AssertionError("lock host must still react to lock activation")
    if "lockContext.reset();" not in host or "lockContext.tryFingerUnlock();" not in host:
        raise AssertionError("lock activation must preserve reset/fingerprint kick behavior")

    print("lock fingerprint lifecycle contract: ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
