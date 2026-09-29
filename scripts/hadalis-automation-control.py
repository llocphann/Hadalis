#!/usr/bin/env python3
"""Narrow JSON control interface for the Quickshell Automation settings page."""
from __future__ import annotations

import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from automation.manager import control  # noqa: E402


def main(argv: list[str]) -> dict:
    if not argv or argv[0] == "status":
        if len(argv) > 1:
            raise ValueError("status takes no arguments")
        return control.status()
    operation, *args = argv
    if operation == "service" and len(args) == 2:
        return control.control_service(args[0], args[1])
    if operation == "profile-action" and len(args) == 2:
        return control.profile_action(args[0], args[1])
    if operation == "profile-create" and len(args) == 1:
        return control.create_profile(args[0])
    if operation == "profile-duplicate" and len(args) == 2:
        return control.create_profile(args[1], args[0])
    if operation == "profile-set" and len(args) in {3, 4}:
        if len(args) == 4 and args[3] != "confirm-delete":
            raise ValueError("invalid confirmation")
        return control.set_profile(args[0], args[1], args[2], len(args) == 4)
    if operation == "profile-reset-prompt" and len(args) == 2:
        return control.reset_prompt(args[0], args[1])
    if operation == "maintenance-set" and len(args) in {2, 3}:
        if len(args) == 3 and args[2] != "confirm-delete":
            raise ValueError("invalid confirmation")
        return control.set_maintenance(args[0], args[1], len(args) == 3)
    if operation == "profile-remove" and len(args) == 1:
        return control.remove_profile(args[0])
    raise ValueError("unknown or malformed automation control action")


if __name__ == "__main__":
    try:
        result = main(sys.argv[1:])
        print(json.dumps(result, ensure_ascii=False))
    except (ValueError, RuntimeError, OSError, json.JSONDecodeError) as exc:
        print(json.dumps({"ok": False, "error": str(exc)[:500]}))
        raise SystemExit(1)
