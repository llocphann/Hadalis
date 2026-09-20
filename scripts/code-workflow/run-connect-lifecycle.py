#!/usr/bin/env python3
"""Live isolated acceptance for the reviewed Connect lifecycle boundary.

The harness runs the production shell in an isolated Sway/Quickshell runtime.
It uses production Connect preview + artifact preparation, but invokes the
research-only 2K-O commit engine externally. No production Settings action can
start a Connect source write at this gate.
"""

from __future__ import annotations

import argparse
from hashlib import sha256
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys

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


def file_sha(path: Path) -> str:
    return sha256(path.read_bytes()).hexdigest()


def wait_snapshot(probe: Probe, predicate, description: str, timeout=60):
    return wait_for(
        lambda: (
            snapshot
            if predicate(snapshot := probe.snapshot())
            else None
        ),
        description,
        timeout=timeout,
    )


def engine(
    work_dir: Path,
    operation: str,
    manifest_path: str,
) -> dict:
    helper = (
        work_dir
        / "config"
        / "scripts"
        / "code-workflow"
        / "connect_commit.py"
    )
    completed = subprocess.run(
        [
            sys.executable,
            str(helper),
            operation,
            "--root",
            str(work_dir / "config"),
            "--manifest",
            manifest_path,
        ],
        cwd=helper.parent,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
        timeout=30,
    )
    raw = completed.stdout.strip()
    try:
        payload = json.loads(raw) if raw else {}
    except json.JSONDecodeError as exc:
        raise AssertionError(
            f"Connect engine emitted invalid JSON: {raw!r}; "
            f"stderr={completed.stderr!r}"
        ) from exc
    payload["_returnCode"] = completed.returncode
    payload["_stderr"] = completed.stderr.strip()
    return payload


def reset_connect(probe: Probe) -> dict:
    wait_snapshot(
        probe,
        lambda s: (
            not s["workflowTransaction"]["connectPreparationBusy"]
            and not s["workflowTransaction"]["applyLifecycleBusy"]
        ),
        "Connect transaction idle before clear",
        timeout=60,
    )
    probe.ipc("workflowClear")
    return wait_snapshot(
        probe,
        lambda s: (
            s["workflowTransaction"]["status"] == "clean"
            and s["workflowTransaction"]["activeCommandKind"] == ""
            and s["workflowTransaction"]["connectArtifactsReady"] is False
        ),
        "Connect transaction clear",
        timeout=30,
    )


def prepare_connect(
    probe: Probe,
    clock_path: Path,
) -> tuple[dict, bytes]:
    source_before = clock_path.read_bytes()
    if probe.ipc("workflowConnectPreview") != "true":
        raise AssertionError("production Connect preview did not start")

    preview = wait_snapshot(
        probe,
        lambda s: (
            s["workflowTransaction"]["status"] == "preview"
            and s["workflowTransaction"]["activeCommandKind"]
                == "connect-binding"
            and s["workflowTransaction"]["activeCommandSourcePath"]
                == "modules/bar/ClockWidget.qml"
            and bool(
                s["workflowTransaction"]["activeCommandCandidateSha256"]
            )
        ),
        "production Connect preview",
    )

    capability = wait_snapshot(
        probe,
        lambda s: (
            s["workflowTransaction"]["connectPreparationCapability"]
                .get("ready") is True
            and not s["workflowTransaction"]["connectPreparationBusy"]
        ),
        "production Connect preparation capability",
    )

    if probe.ipc("workflowConnectPrepare") != "true":
        raise AssertionError(
            "production Connect artifact preparation did not start"
        )

    prepared = wait_snapshot(
        probe,
        lambda s: (
            s["workflowTransaction"]["status"] == "preview"
            and s["workflowTransaction"]["connectArtifactsReady"] is True
            and bool(
                (s["workflowTransaction"].get(
                    "activeConnectPreparation") or {}).get("manifestPath")
            )
            and (s["workflowTransaction"].get(
                "activeConnectSafety") or {}).get("freshness") == "fresh"
        ),
        "qualified production Connect artifacts",
        timeout=90,
    )

    if clock_path.read_bytes() != source_before:
        raise AssertionError(
            "production Connect preparation modified tracked source"
        )

    return {
        "preview": preview["workflowTransaction"],
        "capability": capability["workflowTransaction"],
        "prepared": prepared["workflowTransaction"],
    }, source_before


def wait_reload(
    probe: Probe,
    previous_epoch: str,
    description: str,
) -> dict:
    return wait_snapshot(
        probe,
        lambda s: (
            s["epoch"] != previous_epoch
            and s["ready"] is True
            and s["reloadCompletions"] == 1
            and s["reloadFailures"] == 0
        ),
        description,
        timeout=90,
    )


def run_success(
    probe: Probe,
    work_dir: Path,
    clock_path: Path,
    config_path: Path,
    report: dict,
) -> None:
    prepared_state, source_before = prepare_connect(probe, clock_path)
    before = probe.snapshot()
    preparation = (
        prepared_state["prepared"]["activeConnectPreparation"] or {}
    )
    manifest_path = str(preparation["manifestPath"])
    inserted_anchor = str(preparation["insertedSemanticAnchor"])
    config_before = config_path.read_bytes()

    committed = engine(work_dir, "commit", manifest_path)
    if committed.get("status") != "written":
        raise AssertionError(
            "2K-P Connect commit failed: "
            + json.dumps(committed, sort_keys=True)
        )

    reloaded = wait_reload(
        probe,
        before["epoch"],
        "Connect candidate watcher-driven reload",
    )
    verified = engine(work_dir, "verify", manifest_path)

    probe.ipc("workflowConnectAnalyze", inserted_anchor)
    rebound = wait_snapshot(
        probe,
        lambda s: (
            s["workflowAnalyzer"]["status"] == "ready"
            and s["workflowAnalyzer"]["semanticAnchor"]
                == inserted_anchor
            and s["workflowAnalyzer"]["semanticRebind"]
                .get("status") == "resolved"
            and len(s["workflowAnalyzer"]["diagnostics"]) == 0
        ),
        "inserted Connect semantic anchor rebind",
        timeout=60,
    )

    probe.record(
        "2K-P candidate commit reloads once and rebinds inserted anchor",
        committed.get("sourceWritten") is True
        and committed.get("rollbackRequired") is False
        and verified.get("status") == "verified"
        and verified.get("sourceState") == "candidate-present"
        and verified.get("dependencyState") == "fresh"
        and file_sha(clock_path) == committed.get("candidateSha256")
        and config_path.read_bytes() == config_before
        and rebound["workflowAnalyzer"]["semanticRebind"]
            .get("status") == "resolved",
        {
            "manifestPath": manifest_path,
            "insertedSemanticAnchor": inserted_anchor,
            "commit": committed,
            "verify": verified,
            "reloadCompletions": reloaded["reloadCompletions"],
            "rebind": rebound["workflowAnalyzer"],
        },
    )

    rollback_epoch = rebound["epoch"]
    rolled_back = engine(work_dir, "rollback", manifest_path)
    if rolled_back.get("status") != "rolled-back":
        raise AssertionError(
            "2K-P success cleanup rollback failed: "
            + json.dumps(rolled_back, sort_keys=True)
        )
    restored = wait_reload(
        probe,
        rollback_epoch,
        "Connect rollback watcher-driven reload",
    )

    probe.record(
        "2K-P rollback restores exact Clock bytes without touching Config",
        clock_path.read_bytes() == source_before
        and config_path.read_bytes() == config_before
        and rolled_back.get("dependencyState") == "fresh"
        and restored["reloadCompletions"] == 1,
        {
            "rollback": rolled_back,
            "sourceSha256": file_sha(clock_path),
            "configSha256": file_sha(config_path),
        },
    )

    report["success"] = {
        "prepared": prepared_state,
        "commit": committed,
        "verify": verified,
        "rebind": rebound["workflowAnalyzer"],
        "rollback": rolled_back,
    }
    reset_connect(probe)


def run_rebind_failure(
    probe: Probe,
    work_dir: Path,
    clock_path: Path,
    config_path: Path,
    report: dict,
) -> None:
    prepared_state, source_before = prepare_connect(probe, clock_path)
    before = probe.snapshot()
    preparation = (
        prepared_state["prepared"]["activeConnectPreparation"] or {}
    )
    manifest_path = str(preparation["manifestPath"])
    inserted_anchor = str(preparation["insertedSemanticAnchor"])
    config_before = config_path.read_bytes()

    committed = engine(work_dir, "commit", manifest_path)
    if committed.get("status") != "written":
        raise AssertionError("rebind-failure fixture commit did not write")
    reloaded = wait_reload(
        probe,
        before["epoch"],
        "rebind-failure candidate reload",
    )

    invalid_anchor = inserted_anchor + "#forced-missing"
    probe.ipc("workflowConnectAnalyze", invalid_anchor)
    failed_rebind = wait_snapshot(
        probe,
        lambda s: (
            s["workflowAnalyzer"]["status"] == "ready"
            and s["workflowAnalyzer"]["semanticAnchor"] == invalid_anchor
            and s["workflowAnalyzer"]["semanticRebind"]
                .get("status") != "analyzing"
            and s["workflowAnalyzer"]["semanticRebind"]
                .get("status") != "resolved"
        ),
        "forced Connect semantic rebind failure",
        timeout=60,
    )

    rolled_back = engine(work_dir, "rollback", manifest_path)
    if rolled_back.get("status") != "rolled-back":
        raise AssertionError(
            "failed semantic rebind did not permit exact rollback"
        )
    restored = wait_reload(
        probe,
        failed_rebind["epoch"],
        "failed-rebind rollback reload",
    )

    probe.record(
        "2K-P semantic rebind failure rolls back exact source snapshot",
        failed_rebind["workflowAnalyzer"]["semanticRebind"]
            .get("status") != "resolved"
        and clock_path.read_bytes() == source_before
        and config_path.read_bytes() == config_before
        and restored["reloadCompletions"] == 1,
        {
            "candidateReload": reloaded["reloadCompletions"],
            "failedRebind": failed_rebind["workflowAnalyzer"],
            "rollback": rolled_back,
        },
    )

    report["rebindFailure"] = {
        "prepared": prepared_state,
        "commit": committed,
        "failedRebind": failed_rebind["workflowAnalyzer"],
        "rollback": rolled_back,
    }
    reset_connect(probe)


def run_external_dependency_edit(
    probe: Probe,
    work_dir: Path,
    clock_path: Path,
    config_path: Path,
    report: dict,
) -> None:
    prepared_state, source_before = prepare_connect(probe, clock_path)
    preparation = (
        prepared_state["prepared"]["activeConnectPreparation"] or {}
    )
    manifest_path = str(preparation["manifestPath"])
    config_before = config_path.read_bytes()
    marker = b"\n// 2K-P external Config edit after preparation\n"
    if marker.strip() in config_before:
        raise AssertionError("2K-P external Config marker already exists")

    before = probe.snapshot()
    config_path.write_bytes(config_before + marker)
    invalidated = wait_snapshot(
        probe,
        lambda s: (
            s["epoch"] != before["epoch"]
            and s["ready"] is True
            and s["workflowTransaction"]["connectArtifactsReady"] is False
        ),
        "external Config edit invalidates prepared Connect handoff",
        timeout=90,
    )

    blocked = engine(work_dir, "commit", manifest_path)
    probe.record(
        "2K-P external Config edit invalidates handoff and blocks source write",
        blocked.get("status") == "conflict"
        and blocked.get("reason")
            == "external-source-sha-mismatch-before-write"
        and blocked.get("sourceWritten") is False
        and clock_path.read_bytes() == source_before
        and marker.strip() in config_path.read_bytes()
        and invalidated["workflowTransaction"]["connectArtifactsReady"]
            is False,
        {
            "engine": blocked,
            "transaction": invalidated["workflowTransaction"],
        },
    )

    report["externalDependencyEdit"] = {
        "prepared": prepared_state,
        "blockedCommit": blocked,
        "state": invalidated["workflowTransaction"],
    }

    # Fixture cleanup only; this is an isolated exported runtime.
    config_path.write_bytes(config_before)


def main() -> int:
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
    clock_path = work_dir / "config/modules/bar/ClockWidget.qml"
    config_path = work_dir / "config/modules/common/Config.qml"
    for path in (clock_path, config_path):
        if not path.is_file() or path.is_symlink():
            raise RuntimeError(
                "isolated Connect lifecycle source fixture is invalid: "
                + str(path)
            )
        path.resolve().relative_to((work_dir / "config").resolve())

    report = {
        "schema": 1,
        "gate": "Phase 2K-P",
        "manifest": manifest,
        "grammar": str(grammar),
        "grammarSha256": file_sha(grammar),
        "sway": str(sway),
        "checks": [],
        "environment":
            "headless Sway, isolated XDG/private bus, production "
            "Connect preview/preparation, research-only 2K-O commit engine",
        "limitations": [
            "No production Settings Connect Apply action exists.",
            "connect_commit.py is invoked only by this isolated harness.",
            "The source tree under test is a temporary exported runtime.",
        ],
    }

    probe = Probe(work_dir, report, pointer=None, sway=sway)
    probe.env["HADALIS_WORKFLOW_GRAMMAR"] = str(grammar)
    probe.env["QT_QUICK_BACKEND"] = "software"
    try:
        probe.launch()
        run_success(
            probe, work_dir, clock_path, config_path, report)
        run_rebind_failure(
            probe, work_dir, clock_path, config_path, report)
        run_external_dependency_edit(
            probe, work_dir, clock_path, config_path, report)
    except Exception as exc:
        report["failure"] = repr(exc)
        try:
            report["failureSnapshot"] = probe.snapshot()
        except Exception:
            pass
    finally:
        probe.close()
        (work_dir / "connect-lifecycle-report.json").write_text(
            json.dumps(report, indent=2) + "\n",
            encoding="utf-8",
        )

    print(json.dumps({
        "report": str(work_dir / "connect-lifecycle-report.json"),
        "checks": len(report["checks"]),
        "failure": report.get("failure"),
    }, indent=2))
    return int(bool(report.get("failure")))


if __name__ == "__main__":
    raise SystemExit(main())
