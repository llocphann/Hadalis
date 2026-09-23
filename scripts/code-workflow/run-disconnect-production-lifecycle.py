#!/usr/bin/env python3
"""Live isolated acceptance for the reviewed Disconnect transaction lifecycle."""

from __future__ import annotations

import argparse
from hashlib import sha256
import importlib.util
import json
from pathlib import Path
import subprocess
import sys

HERE = Path(__file__).resolve().parent

live_spec = importlib.util.spec_from_file_location(
    "connect_live",
    HERE / "run-connect-lifecycle.py",
)
live = importlib.util.module_from_spec(live_spec)
live_spec.loader.exec_module(live)

Probe = live.Probe
prepare_module = live.prepare_module
wait_snapshot = live.wait_snapshot
recover_after_rollback = live.recover_after_rollback

DISCONNECT_TARGETS = {
    "clock.data.time": {
        "expectedCurrent": "DateTime.timeDisplay",
        "otherEdgeId": "clock.data.date",
        "otherExpectedCurrent": "DateTime.date",
    },
    "clock.data.date": {
        "expectedCurrent": "DateTime.date",
        "otherEdgeId": "clock.data.time",
        "otherExpectedCurrent": "DateTime.timeDisplay",
    },
}


def file_sha(path: Path) -> str:
    return sha256(path.read_bytes()).hexdigest()


def engine(
    work_dir: Path,
    operation: str,
    manifest_path: str,
    manifest_sha256: str,
) -> dict:
    helper = (
        work_dir
        / "config"
        / "scripts"
        / "code-workflow"
        / "disconnect_commit.py"
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
            "--manifest-sha256",
            manifest_sha256,
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
            f"Disconnect engine emitted invalid JSON: {raw!r}; "
            f"stderr={completed.stderr!r}"
        ) from exc
    payload["_returnCode"] = completed.returncode
    payload["_stderr"] = completed.stderr.strip()
    return payload


def reset_disconnect(probe: Probe) -> dict:
    wait_snapshot(
        probe,
        lambda s: (
            not s["workflowTransaction"]["disconnectPreparationBusy"]
            and not s["workflowTransaction"]["disconnectLifecycleBusy"]
            and not s["workflowTransaction"]["connectLifecycleBusy"]
            and not s["workflowTransaction"]["applyLifecycleBusy"]
        ),
        "Disconnect transaction idle before clear",
        timeout=60,
    )
    probe.ipc("workflowClear")
    return wait_snapshot(
        probe,
        lambda s: (
            s["workflowTransaction"]["status"] == "clean"
            and s["workflowTransaction"]["activeCommandKind"] == ""
            and s["workflowTransaction"]["disconnectArtifactsReady"] is False
        ),
        "Disconnect transaction clear",
        timeout=30,
    )


def prepare_disconnect(
    probe: Probe,
    clock_path: Path,
    edge_id: str,
) -> tuple[dict, bytes]:
    target = DISCONNECT_TARGETS[edge_id]
    source_before = clock_path.read_bytes()
    if probe.ipc("workflowDisconnectAnalyzeEdge", edge_id) != "true":
        raise AssertionError("reviewed Disconnect analysis did not start")
    analyzed = wait_snapshot(
        probe,
        lambda s: (
            s["workflowAnalyzer"]["status"] == "ready"
            and s["workflowAnalyzer"]["sourcePath"]
                == "modules/bar/ClockWidget.qml"
            and (s["workflowAnalyzer"].get("reviewedAnchor") or {})
                .get("status") == "resolved"
            and (s["workflowAnalyzer"].get("reviewedAnchor") or {})
                .get("semanticKind") == "binding"
            and (s["workflowAnalyzer"].get("reviewedAnchor") or {})
                .get("semanticName") == "text"
            and (s["workflowAnalyzer"].get("reviewedAnchor") or {})
                .get("semanticValueText") == target["expectedCurrent"]
        ),
        f"reviewed Clock Disconnect analysis {edge_id}",
        timeout=60,
    )

    if probe.ipc("workflowDisconnectPreviewEdge", edge_id) != "true":
        raise AssertionError(
            f"production Disconnect preview did not start for {edge_id}")
    preview = wait_snapshot(
        probe,
        lambda s: (
            s["workflowTransaction"]["status"] == "preview"
            and s["workflowTransaction"]["activeCommandKind"]
                == "disconnect-binding"
            and s["workflowTransaction"]["activeCommandSourcePath"]
                == "modules/bar/ClockWidget.qml"
            and s["workflowTransaction"]["activeCommandReviewedEdgeId"]
                == edge_id
            and bool(
                s["workflowTransaction"]["activeCommandCandidateSha256"]
            )
        ),
        f"production Disconnect preview {edge_id}",
        timeout=60,
    )

    if probe.ipc("workflowDisconnectPrepare") != "true":
        raise AssertionError(
            f"production Disconnect artifact preparation did not start for {edge_id}")
    prepared = wait_snapshot(
        probe,
        lambda s: (
            s["workflowTransaction"]["status"] == "preview"
            and s["workflowTransaction"]["disconnectArtifactsReady"]
                is True
            and not s["workflowTransaction"]["disconnectPreparationBusy"]
            and (
                s["workflowTransaction"].get(
                    "activeDisconnectPreparation") or {}
            ).get("reviewedEdgeId") == edge_id
            and bool(
                (s["workflowTransaction"].get(
                    "activeDisconnectPreparation") or {})
                .get("manifestPath")
            )
        ),
        f"production Disconnect artifacts {edge_id}",
        timeout=90,
    )
    if clock_path.read_bytes() != source_before:
        raise AssertionError(
            f"Disconnect preparation modified Clock source for {edge_id}")

    return {
        "edgeId": edge_id,
        "analyzed": analyzed["workflowAnalyzer"],
        "preview": preview["workflowTransaction"],
        "prepared": prepared["workflowTransaction"],
    }, source_before

def authorize_disconnect(probe: Probe) -> dict:
    if probe.ipc("workflowDisconnectAuthorize") != "true":
        raise AssertionError("explicit Disconnect authorization failed")
    return wait_snapshot(
        probe,
        lambda s: (
            s["workflowTransaction"]["disconnectAuthorizationReady"]
                is True
            and s["workflowTransaction"]["disconnectApplyEnabled"] is True
            and (
                s["workflowTransaction"].get(
                    "activeDisconnectAuthorization") or {}
            ).get("authorizationProof")
                == "explicit-disconnect-write-authorization-v1"
        ),
        "explicit Disconnect authorization",
        timeout=30,
    )


def cleanup_success(
    probe: Probe,
    work_dir: Path,
    preparation: dict,
    previous_epoch: str,
    source_before: bytes,
    clock_path: Path,
) -> dict:
    rolled_back = engine(
        work_dir,
        "rollback",
        str(preparation["manifestPath"]),
        str(preparation["manifestSha256"]),
    )
    if rolled_back.get("status") != "rolled-back":
        raise AssertionError(
            "2K-T-B success cleanup rollback failed: "
            + json.dumps(rolled_back, sort_keys=True))
    if clock_path.read_bytes() != source_before:
        raise AssertionError(
            "2K-T-B success cleanup did not restore exact Clock bytes")
    restored, mode = recover_after_rollback(
        probe,
        previous_epoch,
        "2K-T-B success cleanup",
    )
    return {
        "rollback": rolled_back,
        "recoveryMode": mode,
        "reloadCompletions": restored["reloadCompletions"],
    }


def run_success(
    probe: Probe,
    work_dir: Path,
    clock_path: Path,
    report: dict,
    edge_id: str,
) -> None:
    target = DISCONNECT_TARGETS[edge_id]
    prepared_state, source_before = prepare_disconnect(
        probe, clock_path, edge_id)
    prepared_tx = prepared_state["prepared"]
    preparation = (
        prepared_tx.get("activeDisconnectPreparation") or {})
    manifest_path = Path(str(preparation["manifestPath"]))
    candidate_path = Path(str(preparation["candidatePath"]))
    candidate = candidate_path.read_bytes()
    candidate_sha = str(
        prepared_tx["activeCommandCandidateSha256"])

    before_auth = probe.snapshot()
    if probe.ipc("workflowDisconnectApply") != "false":
        raise AssertionError(
            f"Disconnect Apply started before authorization for {edge_id}")
    authorized = authorize_disconnect(probe)
    before = probe.snapshot()

    if probe.ipc("workflowDisconnectApply") != "true":
        raise AssertionError(
            f"authorized Disconnect Apply did not start for {edge_id}")
    if probe.ipc("workflowDisconnectApply") != "false":
        raise AssertionError(
            f"Disconnect Apply accepted duplicate start for {edge_id}")

    completed = wait_snapshot(
        probe,
        lambda s: (
            s["workflowTransaction"]["status"] == "disconnect-applied"
            and s["workflowTransaction"]["pendingDisconnectPhase"]
                == "idle"
            and s["workflowTransaction"]["disconnectLifecycleBusy"]
                is False
            and s["workflowTransaction"]["disconnectApplyEnabled"]
                is False
            and s["workflowTransaction"]["disconnectAuthorizationReady"]
                is False
            and (s["workflowTransaction"].get(
                "disconnectLifecycleResult") or {}).get("status")
                == "disconnect-applied"
            and s["workflowAnalyzer"]["status"] == "ready"
            and s["workflowAnalyzer"]["semanticRebind"]
                .get("status") == "missing"
            and len(s["workflowAnalyzer"]["diagnostics"]) == 0
        ),
        f"user-facing Disconnect Apply success {edge_id}",
        timeout=120,
    )

    probe.record(
        f"2K-T-C {edge_id} authorized Disconnect applies once and proves old anchor absent",
        before_auth["workflowTransaction"]["disconnectApplyEnabled"]
            is False
        and before["workflowTransaction"]["disconnectApplyEnabled"] is True
        and before["epoch"] != completed["epoch"]
        and completed["reloadCompletions"] == 1
        and completed["reloadFailures"] == 0
        and clock_path.read_bytes() == candidate
        and file_sha(clock_path) == candidate_sha
        and target["expectedCurrent"].encode("utf-8") not in candidate,
        {
            "edgeId": edge_id,
            "manifestPath": str(manifest_path),
            "candidateSha256": candidate_sha,
            "authorization":
                authorized["workflowTransaction"]
                    ["activeDisconnectAuthorization"],
            "lifecycle":
                completed["workflowTransaction"]
                    ["disconnectLifecycleResult"],
            "analyzer": completed["workflowAnalyzer"],
        },
    )

    cleanup = cleanup_success(
        probe,
        work_dir,
        preparation,
        completed["epoch"],
        source_before,
        clock_path,
    )
    report.setdefault("successes", {})[edge_id] = {
        "prepared": prepared_state,
        "authorized": authorized["workflowTransaction"],
        "completed": completed["workflowTransaction"],
        "cleanup": cleanup,
    }
    reset_disconnect(probe)

def run_postcondition_failure(
    probe: Probe,
    clock_path: Path,
    report: dict,
    edge_id: str,
) -> None:
    target = DISCONNECT_TARGETS[edge_id]
    prepared_state, source_before = prepare_disconnect(
        probe, clock_path, edge_id)
    preparation = (
        prepared_state["prepared"].get(
            "activeDisconnectPreparation") or {})
    manifest_path = Path(str(preparation["manifestPath"]))

    other_edge = target["otherEdgeId"]
    if probe.ipc("workflowDisconnectAnalyzeEdge", other_edge) != "true":
        raise AssertionError(
            f"surviving Disconnect analysis did not start for {other_edge}")
    other_analysis = wait_snapshot(
        probe,
        lambda s: (
            s["workflowAnalyzer"]["status"] == "ready"
            and (s["workflowAnalyzer"].get("reviewedAnchor") or {})
                .get("status") == "resolved"
            and (s["workflowAnalyzer"].get("reviewedAnchor") or {})
                .get("semanticValueText") == target["otherExpectedCurrent"]
        ),
        f"surviving Clock binding analysis {other_edge}",
        timeout=60,
    )
    other_anchor = str(
        other_analysis["workflowAnalyzer"]["reviewedAnchor"]
            ["semanticAnchor"])
    if not other_anchor:
        raise AssertionError(
            f"surviving binding has no semantic anchor for {other_edge}")

    manifest = json.loads(
        manifest_path.read_text(encoding="utf-8"))
    original_anchor = str(manifest["semanticAnchor"])
    manifest["semanticAnchor"] = other_anchor
    manifest_path.write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    manifest_sha = file_sha(manifest_path)
    if probe.ipc(
        "workflowDisconnectOverridePreparedAnchor",
        other_anchor,
        manifest_sha,
    ) != "true":
        raise AssertionError(
            f"ProbeShell could not align Disconnect postcondition fixture for {edge_id}")

    authorized = authorize_disconnect(probe)
    if probe.ipc("workflowDisconnectApply") != "true":
        raise AssertionError(
            f"forced postcondition Disconnect Apply did not start for {edge_id}")
    if probe.ipc("workflowDisconnectApply") != "false":
        raise AssertionError(
            f"forced postcondition Disconnect Apply accepted duplicate start for {edge_id}")

    recovered = wait_snapshot(
        probe,
        lambda s: (
            s["workflowTransaction"]["status"]
                == "disconnect-rollback-complete"
            and s["workflowTransaction"]["pendingDisconnectPhase"]
                == "idle"
            and s["workflowTransaction"]["disconnectLifecycleBusy"]
                is False
            and s["workflowTransaction"]["disconnectApplyEnabled"]
                is False
            and s["workflowTransaction"]["disconnectAuthorizationReady"]
                is False
            and (s["workflowTransaction"].get(
                "disconnectLifecycleResult") or {}).get("status")
                == "disconnect-rolled-back"
        ),
        f"Disconnect absence-postcondition automatic rollback {edge_id}",
        timeout=150,
    )
    result = (
        recovered["workflowTransaction"]["disconnectLifecycleResult"]
        or {}
    )

    probe.record(
        f"2K-T-C {edge_id} failed old-anchor absence postcondition rolls back exact source",
        clock_path.read_bytes() == source_before
        and bool(
            recovered["workflowTransaction"]
                ["disconnectLifecycleError"])
        and result.get("recoveryMode")
            in ("watcher", "explicit-recovery")
        and (result.get("verify") or {}).get("sourceState")
            == "base-present",
        {
            "edgeId": edge_id,
            "originalDeletedAnchor": original_anchor,
            "forcedSurvivingAnchor": other_anchor,
            "manifestSha256": manifest_sha,
            "authorization":
                authorized["workflowTransaction"]
                    ["activeDisconnectAuthorization"],
            "lifecycle": recovered["workflowTransaction"],
        },
    )
    report.setdefault("postconditionFailures", {})[edge_id] = {
        "prepared": prepared_state,
        "authorized": authorized["workflowTransaction"],
        "recovered": recovered["workflowTransaction"],
    }
    reset_disconnect(probe)

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

    report = {
        "schema": 1,
        "gate": "Phase 2K-T-C",
        "manifest": manifest,
        "grammar": str(grammar),
        "grammarSha256": file_sha(grammar),
        "sway": str(sway),
        "checks": [],
        "environment":
            "headless Sway, isolated XDG/private bus, production "
            "Disconnect preview/preparation/authorization/Apply lifecycle",
        "limitations": [
            "Only reviewed edges clock.data.time and clock.data.date are "
            "write-authorized.",
            "All other Disconnect edges remain preview-only.",
            "The source tree under test is a temporary exported runtime.",
        ],
    }

    probe = Probe(work_dir, report, pointer=None, sway=sway)
    probe.env["HADALIS_WORKFLOW_GRAMMAR"] = str(grammar)
    probe.env["QT_QUICK_BACKEND"] = "software"
    try:
        probe.launch()
        for edge_id in DISCONNECT_TARGETS:
            run_success(probe, work_dir, clock_path, report, edge_id)
        for edge_id in DISCONNECT_TARGETS:
            run_postcondition_failure(
                probe, clock_path, report, edge_id)
    except Exception as exc:
        report["failure"] = repr(exc)
        try:
            report["failureSnapshot"] = probe.snapshot()
        except Exception:
            pass
    finally:
        probe.close()
        (work_dir / "disconnect-production-lifecycle-report.json").write_text(
            json.dumps(report, indent=2) + "\n",
            encoding="utf-8",
        )

    print(json.dumps({
        "report": str(
            work_dir / "disconnect-production-lifecycle-report.json"),
        "checks": len(report["checks"]),
        "failure": report.get("failure"),
    }, indent=2))
    return int(bool(report.get("failure")))


if __name__ == "__main__":
    raise SystemExit(main())
