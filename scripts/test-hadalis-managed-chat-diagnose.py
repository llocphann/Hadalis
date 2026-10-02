#!/usr/bin/env python3
"""Synthetic regression tests. No Desktop or session state access."""
from __future__ import annotations

import importlib.util
from pathlib import Path


def load():
    spec = importlib.util.spec_from_file_location(
        "hadalis_managed_chat_diagnose",
        Path(__file__).with_name("hadalis-managed-chat-diagnose.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def run():
    relation = load().branch_relation

    def node(parent, role="assistant", message_id=None):
        return {"parent": parent, "message": {
            "id": message_id, "author": {"role": role}}}

    original = {
        "current_node": "reply",
        "mapping": {
            "user": node(None, "user"),
            "reply": node("user", "assistant", "expected")
        }
    }
    assert relation(original, "reply") == "EXACT_CURRENT_NODE"
    assert relation(original, "expected") == "NON_USER_DESCENDANT"

    tail = dict(original, current_node="internal",
                mapping={**original["mapping"],
                         "internal": node("reply", "assistant")})
    assert relation(tail, "expected") == "NON_USER_DESCENDANT"

    later_user = dict(tail, current_node="second",
                      mapping={**tail["mapping"],
                               "next_user": node("internal", "user"),
                               "second": node("next_user", "assistant")})
    assert relation(later_user, "expected") == "LATER_USER_TURN"

    alternate = dict(later_user, current_node="sibling",
                     mapping={**later_user["mapping"],
                              "sibling": node("user", "assistant")})
    assert relation(alternate, "expected") == "DIFFERENT_BRANCH"
    assert relation(alternate, "not_present") == "EXPECTED_RESPONSE_NOT_IN_HISTORY"
    assert relation({"current_node": "missing", "mapping": {}}, "expected") ==         "EXPECTED_RESPONSE_NOT_IN_HISTORY"
    assert relation({}, "expected") == "HISTORY_UNAVAILABLE"
    print("PASS: managed-chat identity diagnostic classification is deterministic")


if __name__ == "__main__":
    run()
