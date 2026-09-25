#!/usr/bin/env python3
"""Regression contract for process-free WorldClock offset refreshes."""

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
SERVICE = ROOT / "services/WorldClock.qml"


def main() -> int:
    text = SERVICE.read_text(encoding="utf-8")

    required = (
        'new Intl.DateTimeFormat("en-US"',
        'timeZone: key',
        'hourCycle: "h23"',
        'formatter.formatToParts(instant)',
        'const intlOffsets = root._intlOffsets(root.timezones)',
        'if (intlOffsets !== null)',
        'root.offsetsMinutes = intlOffsets',
    )
    for needle in required:
        if needle not in text:
            raise AssertionError(f"WorldClock missing Intl fast-path contract: {needle}")

    # Portability stays intact: date(1) is still the fallback when Qt's JS Intl
    # implementation is unavailable or cannot parse a configured timezone.
    if 'command: ["date", "+%z"]' not in text:
        raise AssertionError("WorldClock must preserve the date(1) compatibility fallback")

    refresh = re.search(
        r"function refreshOffsets\(\): void \{(?P<body>.*?)\n    \}\n\n"
        r"    function _completeOffset",
        text,
        flags=re.S,
    )
    if not refresh:
        raise AssertionError("could not isolate WorldClock.refreshOffsets")

    body = refresh.group("body")
    fast_path = body.find("const intlOffsets = root._intlOffsets(root.timezones)")
    fallback = body.find("root._runNextOffset()")
    if fast_path < 0 or fallback < 0 or fast_path > fallback:
        raise AssertionError("Intl offset calculation must run before the process fallback")

    print("world clock offset lifecycle contract: ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
