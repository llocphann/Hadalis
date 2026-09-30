#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

import automation.chat_bridge.desktop_host as host  # noqa: E402


def expect_runtime_error(fn) -> None:
    try:
        fn()
    except RuntimeError:
        return
    raise AssertionError("expected RuntimeError")


def main() -> None:
    old_url = host.CDP_URL
    old_bin = host.CHATGPT_BIN

    try:
        host.CDP_URL = "http://127.0.0.1:9222"
        assert host.cdp_parts() == ("127.0.0.1", 9222)

        host.CDP_URL = "http://localhost:9333"
        assert host.cdp_parts() == ("localhost", 9333)

        host.CDP_URL = "https://127.0.0.1:9222"
        expect_runtime_error(host.cdp_parts)

        host.CDP_URL = "http://192.168.1.10:9222"
        expect_runtime_error(host.cdp_parts)

        host.CDP_URL = "http://127.0.0.1:9222"
        host.CHATGPT_BIN = "/usr/bin/chatgpt"
        assert host.launch_command() == [
            "/usr/bin/chatgpt",
            "--remote-debugging-address=127.0.0.1",
            "--remote-debugging-port=9222",
        ]
    finally:
        host.CDP_URL = old_url
        host.CHATGPT_BIN = old_bin

    print("PASS: Hadalis ChatGPT CDP host safety contract")


if __name__ == "__main__":
    main()
