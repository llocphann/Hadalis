#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import time
from typing import Any

from automation.chat_bridge.controller import BridgeAction, BridgeState, transition
from automation.chat_bridge.protocol import (
    CONTINUATION_PROMPT,
    ROTATION_BOOTSTRAP_PROMPT,
    parse_loop_directive,
)

ROOT = Path(__file__).resolve().parents[2]
DESKTOP_CLI = ROOT / "automation" / "chat_bridge" / "desktop_cli.mjs"
RESULTS_DIR = "automation/results"
POLL_SECONDS = float(os.environ.get("HADALIS_RESULT_POLL_SECONDS", "10"))
DESKTOP_TIMEOUT_SECONDS = float(
    os.environ.get("HADALIS_DESKTOP_TIMEOUT_SECONDS", "720")
)


def state_path() -> Path:
    base = Path(
        os.environ.get(
            "XDG_STATE_HOME",
            str(Path.home() / ".local" / "state"),
        )
    )
    path = base / "hadalis-automation" / "chat-bridge.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    return path


def save_state(state: BridgeState, job_id: str | None = None) -> None:
    payload = {
        "state": state.value,
        "job_id": job_id,
        "updated_at_unix": int(time.time()),
    }
    path = state_path()
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    tmp.replace(path)


def run(argv: list[str], *, input_text: str | None = None, timeout: float | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        argv,
        cwd=ROOT,
        input=input_text,
        text=True,
        capture_output=True,
        check=False,
        timeout=timeout,
    )


def desktop(command: str, prompt: str | None = None) -> dict[str, Any]:
    result = run(
        ["node", str(DESKTOP_CLI), command],
        input_text=prompt,
        timeout=DESKTOP_TIMEOUT_SECONDS,
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"desktop bridge failed ({result.returncode}): {result.stderr.strip()}"
        )
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        raise RuntimeError(
            f"desktop bridge returned invalid JSON: {result.stdout[:1000]!r}"
        ) from exc


def extract_response_text(payload: dict[str, Any]) -> str:
    response = payload.get("response")
    if not isinstance(response, dict):
        raise RuntimeError("desktop bridge response object is missing")
    text = response.get("text")
    if not isinstance(text, str) or not text.strip():
        raise RuntimeError("desktop bridge response text is missing")
    return text


def git_fetch_dev() -> None:
    result = run(["git", "fetch", "origin", "dev"], timeout=120)
    if result.returncode != 0:
        raise RuntimeError(f"git fetch origin dev failed: {result.stderr.strip()}")


def result_exists(job_id: str) -> bool:
    path = f"{RESULTS_DIR}/{job_id}.json"
    result = run(
        ["git", "cat-file", "-e", f"origin/dev:{path}"],
        timeout=30,
    )
    return result.returncode == 0


def wait_for_result(job_id: str) -> None:
    save_state(BridgeState.WAIT_LOCAL, job_id)
    while True:
        git_fetch_dev()
        if result_exists(job_id):
            return
        time.sleep(POLL_SECONDS)


def resolve_directive(response_text: str) -> tuple[BridgeState, BridgeAction, str | None]:
    directive = parse_loop_directive(response_text)
    outcome = transition(BridgeState.READY, directive)
    return outcome.state, outcome.action, outcome.job_id


def process_response(response_text: str) -> tuple[bool, str | None, str | None]:
    state, action, job_id = resolve_directive(response_text)
    save_state(state, job_id)

    if action is BridgeAction.STOP:
        return True, None, None

    if action is BridgeAction.WAIT_CONNECTOR:
        print(
            "GitHub connector is blocked. Reconnect it, then restart hadalis-chat-bridge.",
            file=sys.stderr,
        )
        raise SystemExit(75)

    if action is BridgeAction.WAIT_RESULT:
        assert job_id is not None
        wait_for_result(job_id)
        return False, "send", CONTINUATION_PROMPT

    if action is BridgeAction.SEND_CONTINUATION:
        return False, "send", CONTINUATION_PROMPT

    if action is BridgeAction.ROTATE_CHAT:
        return False, "rotate-send", ROTATION_BOOTSTRAP_PROMPT

    raise AssertionError(f"unhandled bridge action: {action}")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Deterministic Hadalis ChatGPT Desktop loop controller"
    )
    parser.add_argument(
        "--initial-prompt-file",
        type=Path,
        help="Send this prompt first instead of attaching to the current ChatGPT turn.",
    )
    args = parser.parse_args()

    if args.initial_prompt_file is None:
        payload = desktop("await-current")
    else:
        prompt = args.initial_prompt_file.read_text(encoding="utf-8")
        payload = desktop("send", prompt)

    while True:
        response_text = extract_response_text(payload)
        done, command, prompt = process_response(response_text)
        if done:
            save_state(BridgeState.DONE)
            return 0

        assert command is not None
        assert prompt is not None
        payload = desktop(command, prompt)


if __name__ == "__main__":
    raise SystemExit(main())
