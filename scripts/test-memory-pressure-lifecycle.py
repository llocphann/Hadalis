#!/usr/bin/env python3
"""Regression contract for low-overhead JSGCHeap pressure sampling."""

from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SERVICE = ROOT / "services/MemoryPressureService.qml"


def main() -> int:
    text = SERVICE.read_text(encoding="utf-8")

    if "Quickshell.processId" not in text:
        raise AssertionError("MemoryPressureService must address the shell /proc maps directly")
    if 'command: ["awk",' not in text:
        raise AssertionError("MemoryPressureService must use one direct awk process per sample")
    if 'command: ["sh", "-c"' in text or "/proc/$PPID/maps" in text:
        raise AssertionError("MemoryPressureService must not restore shell + grep fan-out")

    match = re.search(
        r'command:\s*\["awk",\s*\n\s*"([^"]+)",\s*\n\s*"/proc/" \+ Quickshell\.processId \+ "/maps"\]',
        text,
    )
    if not match:
        raise AssertionError("could not recover the direct maps awk program")

    fixture = """00000000-00001000 rw-s 00000000 00:01 1 /memfd:JSGCHeap (deleted)
00001000-00002000 rw-s 00000000 00:01 2 /memfd:JSGCHeap
00002000-00003000 rw-s 00000000 00:01 3 /memfd:OtherHeap (deleted)
00003000-00004000 rw-s 00000000 00:01 4 /memfd:JSGCHeap (deleted)
"""
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", delete=False) as handle:
        handle.write(fixture)
        fixture_path = Path(handle.name)

    try:
        proc = subprocess.run(
            ["awk", match.group(1), str(fixture_path)],
            check=True,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    finally:
        fixture_path.unlink(missing_ok=True)

    counts = [int(line) for line in proc.stdout.splitlines() if line.strip()]
    if counts != [2, 3]:
        raise AssertionError(f"unexpected JSGCHeap counts: {counts!r}")

    print("memory pressure lifecycle contract: ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
