#!/usr/bin/env python3
from hashlib import sha256
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
SCRIPT_DIR = ROOT / "scripts/code-workflow"
sys.path.insert(0, str(SCRIPT_DIR))

from connect import prepare_connect_binding_patch


def fail(message: str) -> None:
    raise SystemExit("FAIL: " + message)


source = (
    b"Item {\n"
    b"    id: root\n"
    b"    width: 20\n"
    b"}\n"
)
base_sha = sha256(source).hexdigest()
parent = {
    "anchor": "parent-anchor",
    "anchor_unique": True,
    "kind": "object",
    "name": "Item",
    "scope": ["Item#root[1]"],
    "range": [0, len(source) - 1],
    "initializer_range": [source.index(b"{"), source.rindex(b"}") + 1],
    "opaque_context": False,
}
entries = [
    parent,
    {
        "anchor": "id-anchor",
        "kind": "id",
        "name": "id",
        "scope": parent["scope"],
        "range": [source.index(b"id:"), source.index(b"id:") + len(b"id: root")],
    },
    {
        "anchor": "width-anchor",
        "kind": "binding",
        "name": "width",
        "scope": parent["scope"],
        "range": [
            source.index(b"width:"),
            source.index(b"width:") + len(b"width: 20"),
        ],
    },
]

prepared, candidate = prepare_connect_binding_patch(
    source, base_sha, parent, entries, "height", "parent.height")
if prepared.get("status") != "candidate":
    fail("safe absent binding insertion must produce a candidate")
expected = (
    b"Item {\n"
    b"    id: root\n"
    b"    width: 20\n"
    b"    height: parent.height\n"
    b"}\n"
)
if candidate != expected:
    fail("connect insertion must preserve local formatting and closing brace")
if prepared["patch"]["start"] != source.rfind(b"\n", 0, source.rindex(b"}")) + 1:
    fail("insertion point must be re-derived from current closing-brace line")
if prepared["insertionEvidence"]["memberIndentBytes"] != 4:
    fail("member indentation evidence drifted")

duplicate_entries = entries + [{
    "kind": "binding",
    "name": "height",
    "scope": parent["scope"],
    "range": [0, 1],
}]
blocked, no_candidate = prepare_connect_binding_patch(
    source, base_sha, parent, duplicate_entries, "height", "parent.height")
if blocked.get("reason") != "target-member-already-exists" or no_candidate is not None:
    fail("existing target member must block insertion")

bad_parent = dict(parent)
bad_parent["kind"] = "opaque"
blocked, no_candidate = prepare_connect_binding_patch(
    source, base_sha, bad_parent, entries, "height", "parent.height")
if blocked.get("status") != "unsupported" or no_candidate is not None:
    fail("opaque/non-object parent must fail closed")

inline_close = b"Item { width: 20 }\n"
inline_parent = dict(parent)
inline_parent["range"] = [0, len(inline_close) - 1]
inline_parent["initializer_range"] = [
    inline_close.index(b"{"),
    inline_close.rindex(b"}") + 1,
]
inline_entries = [
    inline_parent,
    {
        "kind": "binding",
        "name": "width",
        "scope": inline_parent["scope"],
        "range": [
            inline_close.index(b"width:"),
            inline_close.index(b"width:") + len(b"width: 20"),
        ],
    },
]
blocked, no_candidate = prepare_connect_binding_patch(
    inline_close,
    sha256(inline_close).hexdigest(),
    inline_parent,
    inline_entries,
    "height",
    "parent.height",
)
if blocked.get("reason") != "parent-closing-brace-not-on-standalone-line":
    fail("inline closing brace must block insertion proof")
if no_candidate is not None:
    fail("blocked inline parent must not produce candidate")

crlf = (
    b"Item {\r\n"
    b"    width: 20\r\n"
    b"}\r\n"
)
crlf_parent = dict(parent)
crlf_parent["scope"] = ["Item[1]"]
crlf_parent["initializer_range"] = [crlf.index(b"{"), crlf.rindex(b"}") + 1]
crlf_entries = [
    crlf_parent,
    {
        "kind": "binding",
        "name": "width",
        "scope": crlf_parent["scope"],
        "range": [
            crlf.index(b"width:"),
            crlf.index(b"width:") + len(b"width: 20"),
        ],
    },
]
prepared, candidate = prepare_connect_binding_patch(
    crlf,
    sha256(crlf).hexdigest(),
    crlf_parent,
    crlf_entries,
    "height",
    "root.height",
)
if prepared.get("insertionEvidence", {}).get("newline") != "crlf":
    fail("CRLF insertion must preserve local newline style")
if b"    height: root.height\r\n}\r\n" not in candidate:
    fail("CRLF candidate formatting drifted")

helper = (SCRIPT_DIR / "connect.py").read_text(encoding="utf-8")
semantics = (SCRIPT_DIR / "semantics.py").read_text(encoding="utf-8")
phase2 = (ROOT / "docs/CODE_WORKFLOW_PHASE2.md").read_text(encoding="utf-8")

for forbidden in ("write_text(", "write_bytes(", "os.replace(", "setText("):
    if forbidden in helper:
        fail("connect insertion proof must never write source: " + forbidden)

for token in (
    '"initializer_range": span(initializer)',
    "parentSemanticAnchor",
    '"commandKind": "connect-binding"',
    '"cycleStatus": "unknown-incomplete-projection"',
    '"typeCompatibility": "unknown-unresolved"',
    '"applyEnabled": False',
):
    haystack = semantics if "initializer_range" in token else helper
    if token not in haystack:
        fail("2K-D insertion proof missing " + token)

for token in (
    "Milestone 2K-D — parser-backed Connect insertion proof",
    "parent object anchor + binding name + source expression",
    "Type compatibility remains UNKNOWN",
    "Cycle safety remains UNKNOWN",
):
    if token not in phase2:
        fail("2K-D documentation missing " + token)

print("ok - Code Workflow 2K-D parser-backed Connect insertion proof")
