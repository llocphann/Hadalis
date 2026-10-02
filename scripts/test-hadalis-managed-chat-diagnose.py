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
    # The real diagnostic must use a compact read-only native operation, not
    # the old full-history "read" operation (which exceeded the capture cap).
    import contextlib
    import io
    from unittest.mock import patch

    module = load()
    config = {"profiles": [{"id":"p1","enabled":True}]}
    state = {"profiles": {"p1": {
        "status":"session_changed", "pending":None, "recovery":None,
        "last_error":"Managed chat changed outside Automation; checkpoint retained",
        "session":{"conversation_id":"private-chat","project_id":"private-project"},
        "response_message_id":"private-response"
    }}}
    out = io.StringIO()
    with patch.object(module,"read_snapshot",return_value=(config,state,[])):
        with patch.object(module,"native_command",return_value={
            "relation":"NON_USER_DESCENDANT"}) as query:
            with contextlib.redirect_stdout(out):
                assert module.main()==0
            assert query.call_count==1
            assert query.call_args.args==("branch",)
            assert query.call_args.kwargs["expected_response_message_id"]=="private-response"
    public = out.getvalue()
    assert "PROFILE_1_BRANCH=NON_USER_DESCENDANT" in public
    assert "private-" not in public

    # A protocol pause must expose only a fixed code, not private evidence.
    protocol_state = {"profiles": {"p1": {**state["profiles"]["p1"],
        "status":"evidence_required",
        "recovery":{"kind":"response_protocol","code":"unsupported_diagnosis"}}}}
    out = io.StringIO()
    with patch.object(module,"read_snapshot",
                      return_value=(config,protocol_state,[])):
        with patch.object(module,"native_command",return_value={
            "relation":"NON_USER_DESCENDANT"}):
            with contextlib.redirect_stdout(out):
                assert module.main()==0
    assert "PROFILE_1_PROTOCOL_CODE=UNSUPPORTED_DIAGNOSIS" in out.getvalue()
    assert "private-" not in out.getvalue()

    error = module.NativeOperationError({
        "code":"DESKTOP_RATE_LIMITED","resource":"conversation","http_status":429
    },"branch")
    out = io.StringIO()
    with patch.object(module,"read_snapshot",return_value=(config,state,[])):
        with patch.object(module,"native_command",side_effect=error):
            with contextlib.redirect_stdout(out):
                assert module.main()==0
    public = out.getvalue()
    assert "PROFILE_1_BRANCH=READ_UNAVAILABLE" in public
    assert "PROFILE_1_BRANCH_ERROR_CODE=DESKTOP_RATE_LIMITED" in public
    assert "PROFILE_1_BRANCH_ERROR_RESOURCE=CONVERSATION" in public
    assert "PROFILE_1_BRANCH_HTTP_STATUS=429" in public
    assert "private-" not in public

    print("PASS: managed-chat identity diagnostic classification is deterministic")


if __name__ == "__main__":
    run()
