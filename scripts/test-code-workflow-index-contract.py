#!/usr/bin/env python3
"""Regression contract for cached whole-tree Code Workflow discovery."""

from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[1]
INDEXER = ROOT / "scripts" / "code-workflow" / "index.py"
SERVICE = ROOT / "services" / "CodeWorkflowIndex.qml"
QMLDIR = ROOT / "services" / "qmldir"
PAGE = ROOT / "modules" / "settings" / "CodeWorkflow.qml"
SESSION = ROOT / "services" / "CodeWorkflowSession.qml"


def require(text: str, token: str, message: str) -> None:
    if token not in text:
        raise SystemExit("FAIL: " + message)


indexer = INDEXER.read_text(encoding="utf-8")
service = SERVICE.read_text(encoding="utf-8")
qmldir = QMLDIR.read_text(encoding="utf-8")
page = PAGE.read_text(encoding="utf-8")
session = SESSION.read_text(encoding="utf-8")

for token in (
    "CACHE_SCHEMA = 1",
    "def discover_qml(root: Path) -> list[Path]:",
    "def load_cache(path: Path, parser_signature: dict) -> dict:",
    "def write_cache(path: Path, payload: dict) -> None:",
    '"indexerSha256": helper_hashes["index.py"]',
    '"nativeAdapterSha256": helper_hashes["native.py"]',
    '"semanticsSha256": helper_hashes["semantics.py"]',
    '"kind": "parse-failed"',
    '"liveRuntimeEvidence": False',
    '"editable": False',
):
    require(indexer, token, "indexer contract missing " + token)

for token in (
    'property string status: "idle"',
    "readonly property var boundaries:",
    'Quickshell.shellPath("scripts/code-workflow/index.py")',
    '"--cache", root.cachePath',
    "root._pendingRefresh = true",
    "function cancel(): void",
    "root._cancelled = true",
    "indexProcess.running = false",
):
    require(service, token, "index service contract missing " + token)

require(
    qmldir,
    "singleton CodeWorkflowIndex 1.0 CodeWorkflowIndex.qml",
    "runtime-boundary index service must be exported",
)

for token in (
    "workspaceIndexStatus: CodeWorkflowIndex.status",
    "workspaceBoundaryCount: CodeWorkflowIndex.boundaryCount",
    'if (CodeWorkflowIndex.status === "idle")',
    "CodeWorkflowIndex.refresh(false)",
):
    require(page, token, "Workflow index reconciliation missing " + token)

for token in (
    'property string selectedSemanticSourcePath: ""',
    "function selectIndexedSemantic(sourcePath: string, anchor: string): bool",
    "root.selectedSemanticSourcePath = nextPath",
):
    require(session, token, "indexed semantic session boundary missing " + token)

for token in (
    'category: "workspace-boundary"',
    '"workspace-boundaries", "Workspace boundaries", "hub"',
    "CodeWorkflowSession.selectedSemanticSourcePath.length > 0",
    "CodeWorkflowSession.selectIndexedSemantic(",
    '" · read only · " + sourcePath',
    "readonly property var selectedIndexedBoundary:",
    '"Indexed parser boundary · "',
    '"Indexed runtime-boundary evidence · READ ONLY · "',
    "visible: root.inspectedSemanticAnchor.length === 0",
    "readonly property var sourceRuntimeBoundaries:",
    "CodeWorkflowRuntime.relativeSourcePath(root.sourcePath)",
    "readonly property string sourceRuntimeBoundarySummary:",
    "currentSourceBoundaryCount: root.sourceRuntimeBoundaries.length",
    '" parser boundaries · "',
    '" · source evidence only"',
    '"Refresh workspace index"',
    'enabled: CodeWorkflowIndex.status !== "indexing"',
    "onClicked: CodeWorkflowIndex.refresh(false)",
    "function reconcileIndexedSemanticInspectSelection(): void",
    "const stillIndexed = CodeWorkflowIndex.boundaries.some(",
    "root.reconcileIndexedSemanticInspectSelection()",
):
    require(page, token, "workspace boundary navigation missing " + token)

grammar = os.environ.get("HADALIS_WORKFLOW_GRAMMAR", "")
library = os.environ.get("HADALIS_TREE_SITTER_LIBRARY", "")
if not grammar or not Path(grammar).is_file():
    print("ok - Code Workflow index static contract (native grammar unavailable)")
    raise SystemExit(0)


def run_index(root: Path, cache: Path) -> dict:
    command = [
        sys.executable,
        str(INDEXER),
        "--root", str(root),
        "--grammar", grammar,
        "--cache", str(cache),
    ]
    if library:
        command.extend(["--library", library])
    completed = subprocess.run(
        command,
        check=False,
        capture_output=True,
        text=True,
    )
    try:
        payload = json.loads(completed.stdout)
    except json.JSONDecodeError as exc:
        raise SystemExit(
            "FAIL: indexer emitted invalid JSON: "
            + completed.stdout
            + "\n"
            + completed.stderr
        ) from exc
    if completed.returncode != 0 or payload.get("status") != "ok":
        raise SystemExit(
            "FAIL: indexer failed: "
            + json.dumps(payload, ensure_ascii=False)
            + "\n"
            + completed.stderr
        )
    return payload


with tempfile.TemporaryDirectory(prefix="hadalis-workflow-index-") as tmp:
    fixture_root = Path(tmp) / "root"
    fixture_root.mkdir()
    source = fixture_root / "Boundary.qml"
    cache = Path(tmp) / "cache" / "index.json"

    source.write_text(
        "import QtQuick\n"
        "Item {\n"
        "    Timer { interval: 1000 }\n"
        "}\n",
        encoding="utf-8",
    )
    first = run_index(fixture_root, cache)
    if first.get("filesScanned") != 1 or first.get("filesParsed") != 1:
        raise SystemExit("FAIL: first index must parse the fixture exactly once")
    if first.get("cacheHits") != 0 or first.get("boundaryCount") != 1:
        raise SystemExit("FAIL: first index must expose one uncached boundary")
    boundary = (first.get("boundaries") or [{}])[0]
    if (
        boundary.get("sourcePath") != "Boundary.qml"
        or boundary.get("runtimeBoundary") != "timer"
        or boundary.get("runtimeCapability") != "Timer"
        or boundary.get("editable") is not False
    ):
        raise SystemExit("FAIL: Timer boundary projection drifted")

    second = run_index(fixture_root, cache)
    if (
        second.get("filesScanned") != 1
        or second.get("filesParsed") != 0
        or second.get("cacheHits") != 1
        or second.get("boundaryCount") != 1
    ):
        raise SystemExit("FAIL: byte-identical second index must be cache-only")

    source.write_text(
        "import QtQuick\n"
        "Item {\n"
        "    Timer { interval: 1000 }\n"
        "    Process { }\n"
        "}\n",
        encoding="utf-8",
    )
    third = run_index(fixture_root, cache)
    if (
        third.get("filesScanned") != 1
        or third.get("filesParsed") != 1
        or third.get("cacheHits") != 0
        or third.get("boundaryCount") != 2
    ):
        raise SystemExit("FAIL: changed source must invalidate only its cache record")
    kinds = sorted(
        item.get("runtimeBoundary")
        for item in third.get("boundaries") or []
    )
    if kinds != ["process", "timer"]:
        raise SystemExit("FAIL: reconciled runtime boundaries are incomplete")

    source.unlink()
    fourth = run_index(fixture_root, cache)
    if (
        fourth.get("filesScanned") != 0
        or fourth.get("filesParsed") != 0
        or fourth.get("cacheHits") != 0
        or fourth.get("boundaryCount") != 0
        or fourth.get("filesRemoved") != ["Boundary.qml"]
    ):
        raise SystemExit("FAIL: removed QML must be pruned from the cached index")

    unreadable = fixture_root / "Unreadable.qml"
    unreadable.write_bytes(b"\xff")
    fifth = run_index(fixture_root, cache)
    if fifth.get("status") != "ok" or fifth.get("boundaryCount") != 0:
        raise SystemExit("FAIL: one unreadable source must not abort the workspace index")
    if not any(
        item.get("sourcePath") == "Unreadable.qml"
        and item.get("kind") == "source-read-failed"
        for item in fifth.get("diagnostics") or []
    ):
        raise SystemExit("FAIL: unreadable source must remain explicit diagnostic evidence")

print("ok - Code Workflow cached runtime-boundary index contract")
