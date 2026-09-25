#!/usr/bin/env python3
"""Lifecycle contract for TimerService second-resolution timers."""

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
SERVICE = ROOT / "services/TimerService.qml"


def timer_block(text: str, timer_id: str) -> str:
    match = re.search(
        rf"Timer \{{\s*\n\s*id: {re.escape(timer_id)}\b(?P<body>.*?)\n\s*\}}",
        text,
        flags=re.S,
    )
    if not match:
        raise AssertionError(f"missing {timer_id}")
    return match.group(0)


def main() -> int:
    text = SERVICE.read_text(encoding="utf-8")

    required = (
        "function _nextSecondBoundaryDelayMs(): int",
        "pomodoroTimer.interval = root._nextSecondBoundaryDelayMs()",
        "countdownTimer.interval = root._nextSecondBoundaryDelayMs()",
        "onPomodoroRunningChanged:",
        "onPomodoroPausedChanged:",
        "onCountdownRunningChanged:",
        "onCountdownPausedChanged:",
        "root._syncPomodoroTick(true)",
        "root._syncCountdownTick(true)",
    )
    for needle in required:
        if needle not in text:
            raise AssertionError(f"TimerService missing lifecycle contract: {needle}")

    for timer_id in ("pomodoroTimer", "countdownTimer"):
        block = timer_block(text, timer_id)
        if "repeat: false" not in block:
            raise AssertionError(f"{timer_id} must be one-shot")
        if "interval: 200" in block:
            raise AssertionError(f"{timer_id} must not restore 5 Hz polling")
        if "running:" in block:
            raise AssertionError(f"{timer_id} lifecycle must be scheduled explicitly")

    stopwatch = timer_block(text, "stopwatchTimer")
    if "interval: 33" not in stopwatch or "repeat: true" not in stopwatch:
        raise AssertionError("stopwatch high-resolution presentation must remain unchanged")

    print("timer service lifecycle contract: ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
