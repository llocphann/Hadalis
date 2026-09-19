#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
ANALYZER_DIR = ROOT / "scripts/code-workflow"
sys.path.insert(0, str(ANALYZER_DIR))

import analyze as workflow_analyze


def fail(message: str) -> None:
    raise SystemExit("FAIL: " + message)


entry = {
    "anchor": "stable-abc",
    "anchor_unique": True,
    "kind": "binding",
    "name": "visible",
    "range": [120, 150],
    "parent_range": [100, 180],
    "scope": ["Item#root[1]"],
    "opaque_context": False,
    "editable": False,
}
resolved = workflow_analyze.resolve_semantic_anchor([entry], "stable-abc")
if resolved.get("status") != "resolved":
    fail("unique semantic anchor must re-resolve")
if resolved.get("range") != [120, 150]:
    fail("semantic rebind must expose the current range")
if resolved.get("editable") is not False:
    fail("semantic rebind must remain read-only")

missing = workflow_analyze.resolve_semantic_anchor([entry], "missing")
if missing.get("status") != "missing":
    fail("missing semantic anchor must fail closed")

collision = dict(entry)
collision["range"] = [220, 250]
ambiguous = workflow_analyze.resolve_semantic_anchor(
    [entry, collision], "stable-abc")
if ambiguous.get("status") != "ambiguous":
    fail("colliding semantic anchor must fail closed")

non_unique = dict(entry)
non_unique["anchor_unique"] = False
non_unique_result = workflow_analyze.resolve_semantic_anchor(
    [non_unique], "stable-abc")
if non_unique_result.get("status") != "ambiguous":
    fail("extractor-marked non-unique anchor must not be trusted")

persistent = (ROOT / "modules/common/Persistent.qml").read_text(encoding="utf-8")
session = (ROOT / "services/CodeWorkflowSession.qml").read_text(encoding="utf-8")
service = (ROOT / "services/CodeWorkflowAnalyzer.qml").read_text(encoding="utf-8")
page = (ROOT / "modules/settings/CodeWorkflow.qml").read_text(encoding="utf-8")
analyzer = (ROOT / "scripts/code-workflow/analyze.py").read_text(encoding="utf-8")

for token in (
    "codeWorkflowSemanticAnchor",
    "codeWorkflowSemanticAnchorNodeId",
):
    if token not in persistent:
        fail("persistent semantic-anchor state missing " + token)

for token in (
    'property string semanticAnchor: ""',
    'property string semanticAnchorNodeId: ""',
    "function clearSemanticAnchor(): void",
    "function bindSemanticAnchor(nodeId: string, anchor: string): bool",
    "root.semanticAnchorNodeId !== root.selectedNodeId",
):
    if token not in session:
        fail("session semantic-anchor contract missing " + token)

for token in (
    '"--semantic-anchor"',
    "resolve_semantic_anchor(",
    '"semanticRebind": semantic_rebind',
    '"semanticAnchorUnique"',
):
    if token not in analyzer:
        fail("analyzer semantic-anchor contract missing " + token)

for token in (
    'property string semanticAnchor: ""',
    'property var semanticRebind: ({ status: "not-requested" })',
    "function request(path: string, needle: string, semanticAnchor: string, force: bool): void",
    'command.push("--semantic-anchor", nextSemanticAnchor)',
):
    if token not in service:
        fail("analyzer service semantic-anchor contract missing " + token)

for token in (
    "root.storedSemanticAnchor,",
    "function captureSemanticAnchor(): void",
    "evidence?.semanticAnchorUnique !== true",
    "CodeWorkflowSession.bindSemanticAnchor(",
    'StyledText { text: "Semantic rebind";',
):
    if token not in page:
        fail("Code Workflow semantic-anchor UI contract missing " + token)

for forbidden in ("setText(", "writeAdapter()", "atomicWrites"):
    if forbidden in analyzer:
        fail("semantic-anchor milestone must not introduce source writes: " + forbidden)

print("ok - Code Workflow stable semantic-anchor rebind contract")
