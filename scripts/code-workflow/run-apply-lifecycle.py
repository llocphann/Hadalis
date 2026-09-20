#!/usr/bin/env python3
"""Automated isolated acceptance for the production Code Workflow Apply lifecycle.

Requires a headless Sway executable, Quickshell and a built qmljs grammar.
The driver stages a committed Hadalis tree into a new work directory and only
mutates workflowprobe/ApplyTarget.qml inside that temporary runtime.
"""

from __future__ import annotations

import argparse
from hashlib import sha256
import importlib.util
import json
import os
from pathlib import Path
import sys
import time

HERE = Path(__file__).resolve().parent

prepare_spec = importlib.util.spec_from_file_location(
    "prepare_runtime",
    HERE / "prepare-runtime.py",
)
prepare_module = importlib.util.module_from_spec(prepare_spec)
prepare_spec.loader.exec_module(prepare_module)

runtime_spec = importlib.util.spec_from_file_location(
    "workflow_runtime",
    HERE / "run-runtime.py",
)
runtime_module = importlib.util.module_from_spec(runtime_spec)
runtime_spec.loader.exec_module(runtime_module)

Probe = runtime_module.Probe
wait_for = runtime_module.wait_for


SUCCESS_NEEDLE = "property bool applyFlag: false"
ROLLBACK_NEEDLE = "property int rollbackProbe: 1"
CONFLICT_NEEDLE = "property bool conflictProbe: false"


def file_sha(path: Path) -> str:
    return sha256(path.read_bytes()).hexdigest()


def wait_snapshot(probe: Probe, predicate, description: str, timeout=45):
    return wait_for(
        lambda: (
            snapshot
            if predicate(snapshot := probe.snapshot())
            else None
        ),
        description,
        timeout=timeout,
    )


def analyze(probe: Probe, needle: str):
    probe.ipc("workflowAnalyze", needle, "")
    first = wait_snapshot(
        probe,
        lambda s: (
            s["workflowAnalyzer"]["status"] == "ready"
            and s["workflowAnalyzer"]["reviewedAnchor"]
                .get("status") == "resolved"
            and bool(
                s["workflowAnalyzer"]["reviewedAnchor"]
                    .get("semanticAnchor")
            )
        ),
        "reviewed source anchor analysis",
    )
    anchor = first["workflowAnalyzer"]["reviewedAnchor"][
        "semanticAnchor"
    ]
    probe.ipc("workflowAnalyze", needle, anchor)
    second = wait_snapshot(
        probe,
        lambda s: (
            s["workflowAnalyzer"]["status"] == "ready"
            and s["workflowAnalyzer"]["semanticAnchor"] == anchor
            and s["workflowAnalyzer"]["semanticRebind"]
                .get("status") == "resolved"
        ),
        "stable semantic anchor rebind",
    )
    return anchor, second


def preview_prepare(probe: Probe, needle: str, replacement: str):
    anchor, analyzed = analyze(probe, needle)
    if probe.ipc("workflowPreview", replacement) != "true":
        raise AssertionError("production literal preview did not start")
    preview = wait_snapshot(
        probe,
        lambda s: s["workflowTransaction"]["status"] == "preview",
        "literal patch preview",
    )
    probe.ipc("workflowEvaluate")
    ready = wait_snapshot(
        probe,
        lambda s: s["workflowTransaction"]["preApplyReady"],
        "pre-Apply readiness",
    )
    if probe.ipc("workflowPrepare") != "true":
        raise AssertionError("Apply artifact preparation did not start")
    prepared = wait_snapshot(
        probe,
        lambda s: s["workflowTransaction"]["applyArtifactsReady"],
        "exact Apply artifacts",
    )
    return anchor, analyzed, preview, ready, prepared


def reset_fixture(probe: Probe):
    probe.ipc("workflowClear")
    wait_snapshot(
        probe,
        lambda s: (
            s["workflowTransaction"]["status"] == "clean"
            and not s["workflowTransaction"]["applyArtifactsReady"]
        ),
        "transaction clear",
    )


def run_success(probe: Probe, target: Path, report: dict):
    before = target.read_bytes()
    anchor, analyzed, preview, ready, prepared = preview_prepare(
        probe, SUCCESS_NEEDLE, "true"
    )
    before_epoch = analyzed["epoch"]

    if probe.ipc("workflowBeginLifecycle") != "true":
        raise AssertionError("internal production Apply lifecycle did not start")
    applied = wait_snapshot(
        probe,
        lambda s: (
            s["workflowTransaction"]["status"] == "applied"
            and s["applyTarget"]["applyFlag"] is True
        ),
        "watcher reload, candidate verify and semantic rebind",
        timeout=60,
    )
    after = target.read_bytes()

    probe.record(
        "2H success uses watcher reload and semantic rebind",
        before != after
        and b"property bool applyFlag: true" in after
        and applied["epoch"] != before_epoch
        and applied["workflowTransaction"]["pendingApplyPhase"] == "idle"
        and applied["workflowTransaction"]["applyEnabled"] is False,
        {
            "anchor": anchor,
            "beforeSha256": sha256(before).hexdigest(),
            "afterSha256": sha256(after).hexdigest(),
            "lifecycle": applied["workflowTransaction"],
        },
    )
    report["success"] = {
        "anchor": anchor,
        "preview": preview["workflowTransaction"],
        "ready": ready["workflowTransaction"],
        "prepared": prepared["workflowTransaction"],
        "applied": applied["workflowTransaction"],
    }
    reset_fixture(probe)


def run_rollback(probe: Probe, target: Path, report: dict):
    before = target.read_bytes()
    anchor, _analyzed, _preview, _ready, _prepared = preview_prepare(
        probe, ROLLBACK_NEEDLE, '"not-an-int"'
    )

    if probe.ipc("workflowBeginLifecycle") != "true":
        raise AssertionError("rollback fixture lifecycle did not start")
    recovered = wait_snapshot(
        probe,
        lambda s: (
            s["workflowTransaction"]["status"] == "rollback-complete"
            and s["applyTarget"]["rollbackProbe"] == 1
        ),
        "reload failure and exact rollback",
        timeout=60,
    )
    after = target.read_bytes()

    probe.record(
        "2H reload failure rolls back exact snapshot",
        before == after
        and b"property int rollbackProbe: 1" in after
        and recovered["reloadFailures"] >= 1
        and recovered["workflowTransaction"]["pendingApplyPhase"] == "idle"
        and recovered["workflowTransaction"]["applyEnabled"] is False,
        {
            "anchor": anchor,
            "reloadFailures": recovered["reloadFailures"],
            "reloadError": recovered["lastReloadError"],
            "lifecycle": recovered["workflowTransaction"],
        },
    )
    report["rollback"] = {
        "anchor": anchor,
        "snapshotSha256": sha256(before).hexdigest(),
        "restoredSha256": sha256(after).hexdigest(),
        "state": recovered["workflowTransaction"],
    }
    reset_fixture(probe)


def run_external_edit(probe: Probe, target: Path, report: dict):
    anchor, _analyzed, _preview, _ready, prepared = preview_prepare(
        probe, CONFLICT_NEEDLE, "true"
    )

    text = target.read_text(encoding="utf-8")
    marker = "// external-edit-after-artifacts"
    if marker in text:
        raise AssertionError("external-edit marker already exists")
    target.write_text(text + "\n" + marker + "\n", encoding="utf-8")

    changed = wait_snapshot(
        probe,
        lambda s: (
            not s["workflowTransaction"]["applyArtifactsReady"]
            and s["workflowTransaction"]["pendingApplyPhase"] == "idle"
        ),
        "external edit invalidates prepared handoff",
        timeout=45,
    )
    begin = probe.ipc("workflowBeginLifecycle")
    final_text = target.read_text(encoding="utf-8")

    probe.record(
        "2H external edit invalidates prepared Apply and is preserved",
        begin == "false"
        and marker in final_text
        and changed["workflowTransaction"]["applyEnabled"] is False,
        {
            "anchor": anchor,
            "prepared": prepared["workflowTransaction"],
            "afterEdit": changed["workflowTransaction"],
        },
    )
    report["externalEdit"] = {
        "anchor": anchor,
        "beginResult": begin,
        "sourceSha256": file_sha(target),
        "state": changed["workflowTransaction"],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--work-dir", type=Path, required=True)
    parser.add_argument("--revision", default="HEAD")
    parser.add_argument("--sway", type=Path, required=True)
    parser.add_argument("--grammar", type=Path, required=True)
    args = parser.parse_args()

    work_dir = args.work_dir.resolve()
    grammar = args.grammar.resolve()
    sway = args.sway.resolve()
    if work_dir.exists():
        raise SystemExit("work directory must not already exist")
    if not grammar.is_file():
        raise SystemExit("qmljs grammar does not exist")
    if not sway.is_file():
        raise SystemExit("Sway executable does not exist")

    manifest = prepare_module.prepare(work_dir, args.revision)
    target = work_dir / "config/workflowprobe/ApplyTarget.qml"
    if not target.is_file():
        raise RuntimeError("isolated ApplyTarget fixture was not staged")
    if target.is_symlink():
        raise RuntimeError("refusing symlinked ApplyTarget fixture")
    target.resolve().relative_to((work_dir / "config").resolve())

    report = {
        "schema": 1,
        "gate": "Phase 2H",
        "manifest": manifest,
        "grammar": str(grammar),
        "grammar_sha256": file_sha(grammar),
        "sway": str(sway),
        "checks": [],
        "environment":
            "headless Sway, isolated XDG/private bus, production "
            "CodeWorkflowAnalyzer/CodeWorkflowTransaction, dev-only fixture",
        "limitations": [
            "No production Settings Apply button is enabled by this harness.",
            "The fixture exists only in the exported temporary runtime.",
            "This is compositor/runtime acceptance, not package-managed "
            "read-only source acceptance.",
        ],
    }

    probe = Probe(work_dir, report, pointer=None, sway=sway)
    probe.env["HADALIS_WORKFLOW_GRAMMAR"] = str(grammar)
    # Gate 2H is lifecycle evidence, not a GPU acceptance test.
    probe.env["QT_QUICK_BACKEND"] = "software"
    try:
        probe.launch()
        run_success(probe, target, report)
        run_rollback(probe, target, report)
        run_external_edit(probe, target, report)
    except Exception as exc:
        report["failure"] = repr(exc)
        try:
            report["failureSnapshot"] = probe.snapshot()
        except Exception:
            pass
    finally:
        probe.close()
        (work_dir / "apply-lifecycle-report.json").write_text(
            json.dumps(report, indent=2) + "\n",
            encoding="utf-8",
        )

    print(json.dumps({
        "report": str(work_dir / "apply-lifecycle-report.json"),
        "checks": len(report["checks"]),
        "failure": report.get("failure"),
    }, indent=2))
    return int(bool(report.get("failure")))


if __name__ == "__main__":
    raise SystemExit(main())
