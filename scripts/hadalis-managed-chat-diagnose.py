#!/usr/bin/env python3
"""Finite read-only diagnosis of concurrent Hadalis managed-chat identity.

Prints only status categories/booleans: never messages, IDs, prompts or API
responses. This tool performs NO submissions, resets or profile state writes.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from automation.manager.store import read_snapshot
from automation.manager.daemon import NativeOperationError, native_command


def branch_relation(conversation: dict, expected: str) -> str:
    """Compare a saved response to the current branch without exposing text."""
    if not isinstance(conversation, dict) or not isinstance(expected, str) or not expected:
        return "INSUFFICIENT_EVIDENCE"
    mapping = conversation.get("mapping")
    node_id = conversation.get("current_node")
    if not isinstance(mapping, dict) or not isinstance(node_id, str):
        return "HISTORY_UNAVAILABLE"
    if node_id == expected:
        return "EXACT_CURRENT_NODE"
    seen = set()
    intervening_user = False
    steps = 0
    while node_id and node_id in mapping and node_id not in seen and steps < 10000:
        seen.add(node_id)
        node = mapping[node_id]
        if not isinstance(node, dict):
            return "HISTORY_UNAVAILABLE"
        if node_id == expected or (node.get("message") or {}).get("id") == expected:
            return "LATER_USER_TURN" if intervening_user else "NON_USER_DESCENDANT"
        message = node.get("message")
        if isinstance(message, dict) and (message.get("author") or {}).get("role") == "user":
            intervening_user = True
        node_id = node.get("parent")
        steps += 1
    if expected in mapping or any(isinstance(n, dict) and
        isinstance(n.get("message"), dict) and n["message"].get("id") == expected
        for n in mapping.values()):
        return "DIFFERENT_BRANCH"
    return "EXPECTED_RESPONSE_NOT_IN_HISTORY"


def main() -> int:
    config, state, issues = read_snapshot()
    if issues:
        print("CONFIG=UNQUALIFIED")
        return 2
    print("CONFIG=PASS")
    pairs = [
        (profile, state.get("profiles", {}).get(profile["id"]))
        for profile in config["profiles"]
        if profile.get("enabled")
    ]
    print("ENABLED_PROFILE_COUNT=" + str(len(pairs)))
    chats = [
        item.get("session", {}).get("conversation_id")
        for _, item in pairs if isinstance(item, dict) and
        isinstance(item.get("session"), dict) and
        item["session"].get("conversation_id")
    ]
    print("ACTIVE_SESSIONS_SHARE_CONVERSATION=" +
          ("YES" if len(chats) != len(set(chats)) else "NO"))
    for number, (_, item) in enumerate(pairs, 1):
        label = "PROFILE_" + str(number) + "_"
        if not isinstance(item, dict):
            print(label + "STATE=MISSING")
            continue
        status = str(item.get("status", "unknown"))
        print(label + "STATUS=" + status if status.isidentifier() else label + "STATUS=OTHER")
        print(label + "PENDING=" + ("YES" if item.get("pending") else "NO"))
        recovery = item.get("recovery") or {}
        kind = recovery.get("kind", "") if isinstance(recovery, dict) else ""
        print(label + "SUPERSEDED_RECEIPT=" + (
            "YES" if kind == "session_superseded" else "NO"))
        error = item.get("last_error", "")
        print(label + "GUARD=" + (
            "LATER_USER" if isinstance(error, str) and "later user" in error.lower()
            else "CURSOR_MISMATCH" if isinstance(error, str) and
                 "changed outside Automation" in error
            else "OTHER"))
        session = item.get("session") or {}
        conversation_id = session.get("conversation_id")
        expected = item.get("response_message_id")
        if not conversation_id or not expected:
            print(label + "BRANCH=NO_COMPLETED_MANAGED_TURN")
            continue
        # The old "read" command returned the *entire* conversation over
        # stdout; long managed chats could exceed the 120 KB manager cap.
        # This dedicated operation returns only a finite branch relation.
        try:
            summary = native_command(
                "branch", conversation_id=conversation_id,
                project_id=session.get("project_id"),
                expected_response_message_id=expected)
            relation = summary.get("relation")
            allowed = {
                "EXACT_CURRENT_NODE", "NON_USER_DESCENDANT",
                "LATER_USER_TURN", "DIFFERENT_BRANCH",
                "EXPECTED_RESPONSE_NOT_IN_HISTORY",
                "HISTORY_UNAVAILABLE", "HISTORY_BOUND_EXCEEDED",
            }
            print(label + "BRANCH=" +
                  (relation if relation in allowed else "UNQUALIFIED"))
        except NativeOperationError as exc:
            observation = exc.observation
            print(label + "BRANCH=READ_UNAVAILABLE")
            print(label + "BRANCH_ERROR_CODE=" + observation["code"])
            print(label + "BRANCH_ERROR_RESOURCE=" +
                  observation.get("resource", "NONE").upper())
            print(label + "BRANCH_HTTP_STATUS=" +
                  str(observation.get("http_status", "NONE")))
        except (OSError, RuntimeError, ValueError) as exc:
            # Never print exception messages or raw Desktop responses.
            reason = ("CAPTURE_BOUND" if str(exc) ==
                      "Desktop response exceeded capture bound" else
                      "UNCLASSIFIED")
            print(label + "BRANCH=READ_UNAVAILABLE")
            print(label + "BRANCH_ERROR_CODE=" + reason)
    print("RESULT=READ_ONLY_IDENTITY_DIAGNOSIS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
