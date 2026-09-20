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
) -> tuple[dict, bytes]:
    source_before = clock_path.read_bytes()
    probe.ipc("workflowDisconnectAnalyze")
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
                .get("semanticValueText") == "DateTime.timeDisplay"
        ),
        "reviewed Clock time binding analysis",
        timeout=60,
    )

    if probe.ipc("workflowDisconnectPreview") != "true":
        raise AssertionError("production Disconnect preview did not start")
    preview = wait_snapshot(
        probe,
        lambda s: (
            s["workflowTransaction"]["status"] == "preview"
            and s["workflowTransaction"]["activeCommandKind"]
                == "disconnect-binding"
            and s["workflowTransaction"]["activeCommandSourcePath"]
                == "modules/bar/ClockWidget.qml"
            and bool(
                s["workflowTransaction"]["activeCommandCandidateSha256"]
            )
        ),
        "production Disconnect preview",
        timeout=60,
    )

    if probe.ipc("workflowDisconnectPrepare") != "true":
        raise AssertionError(
            "production Disconnect artifact preparation did not start")
    prepared = wait_snapshot(
        probe,
        lambda s: (
            s["workflowTransaction"]["status"] == "preview"
            and s["workflowTransaction"]["disconnectArtifactsReady"]
                is True
            and not s["workflowTransaction"]["disconnectPreparationBusy"]
            and bool(
                (s["workflowTransaction"].get(
                    "activeDisconnectPreparation") or {})
                .get("manifestPath")
            )
        ),
        "production Disconnect artifacts",
        timeout=90,
    )
    if clock_path.read_bytes() != source_before:
        raise AssertionError(
            "Disconnect preparation modified tracked Clock source")

    return {
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
) -> None:
    prepared_state, source_before = prepare_disconnect(
        probe, clock_path)
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
            "Disconnect Apply started before authorization")
    authorized = authorize_disconnect(probe)
    before = probe.snapshot()

    if probe.ipc("workflowDisconnectApply") != "true":
        raise AssertionError(
            "authorized Disconnect Apply did not start")
    if probe.ipc("workflowDisconnectApply") != "false":
        raise AssertionError(
            "Disconnect Apply accepted duplicate start")

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
        "user-facing Disconnect Apply success",
        timeout=120,
    )

    probe.record(
        "2K-T-B authorized Disconnect applies once and proves old anchor absent",
        before_auth["workflowTransaction"]["disconnectApplyEnabled"]
            is False
        and before["workflowTransaction"]["disconnectApplyEnabled"] is True
        and before["epoch"] != completed["epoch"]
        and completed["reloadCompletions"] == 1
        and completed["reloadFailures"] == 0
        and clock_path.read_bytes() == candidate
        and file_sha(clock_path) == candidate_sha
        and b"DateTime.timeDisplay" not in candidate,
        {
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
    report["success"] = {
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
) -> None:
    prepared_state, source_before = prepare_disconnect(
        probe, clock_path)
    preparation = (
        prepared_state["prepared"].get(
            "activeDisconnectPreparation") or {})
    manifest_path = Path(str(preparation["manifestPath"]))

    probe.ipc("workflowDisconnectAnalyzeDate")
    date_analysis = wait_snapshot(
        probe,
        lambda s: (
            s["workflowAnalyzer"]["status"] == "ready"
            and (s["workflowAnalyzer"].get("reviewedAnchor") or {})
                .get("status") == "resolved"
            and (s["workflowAnalyzer"].get("reviewedAnchor") or {})
                .get("semanticValueText") == "DateTime.date"
        ),
        "surviving Clock date binding analysis",
        timeout=60,
    )
    date_anchor = str(
        date_analysis["workflowAnalyzer"]["reviewedAnchor"]
            ["semanticAnchor"])
    if not date_anchor:
        raise AssertionError(
            "surviving date binding has no semantic anchor")

    manifest = json.loads(
        manifest_path.read_text(encoding="utf-8"))
    original_anchor = str(manifest["semanticAnchor"])
    manifest["semanticAnchor"] = date_anchor
    manifest_path.write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    manifest_sha = file_sha(manifest_path)
    if probe.ipc(
        "workflowDisconnectOverridePreparedAnchor",
        date_anchor,
        manifest_sha,
    ) != "true":
        raise AssertionError(
            "ProbeShell could not align Disconnect postcondition fixture")

    authorized = authorize_disconnect(probe)
    if probe.ipc("workflowDisconnectApply") != "true":
        raise AssertionError(
            "forced postcondition Disconnect Apply did not start")
    if probe.ipc("workflowDisconnectApply") != "false":
        raise AssertionError(
            "forced postcondition Disconnect Apply accepted duplicate start")

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
        "Disconnect absence-postcondition automatic rollback",
        timeout=150,
    )
    result = (
        recovered["workflowTransaction"]["disconnectLifecycleResult"]
        or {}
    )

    probe.record(
        "2K-T-B failed old-anchor absence postcondition rolls back exact source",
        clock_path.read_bytes() == source_before
        and bool(
            recovered["workflowTransaction"]
                ["disconnectLifecycleError"])
        and result.get("recoveryMode")
            in ("watcher", "explicit-recovery")
        and (result.get("verify") or {}).get("sourceState")
            == "base-present",
        {
            "originalDeletedAnchor": original_anchor,
            "forcedSurvivingAnchor": date_anchor,
            "manifestSha256": manifest_sha,
            "authorization":
                authorized["workflowTransaction"]
                    ["activeDisconnectAuthorization"],
            "lifecycle": recovered["workflowTransaction"],
        },
    )
    report["postconditionFailure"] = {
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
        "gate": "Phase 2K-T-B",
        "manifest": manifest,
        "grammar": str(grammar),
        "grammarSha256": file_sha(grammar),
        "sway": str(sway),
        "checks": [],
        "environment":
            "headless Sway, isolated XDG/private bus, production "
            "Disconnect preview/preparation/authorization/Apply lifecycle",
        "limitations": [
            "Only reviewed edge clock.data.time is write-authorized.",
            "Direct-binding replacement and other Disconnect edges remain "
            "preview-only.",
            "The source tree under test is a temporary exported runtime.",
        ],
    }

    probe = Probe(work_dir, report, pointer=None, sway=sway)
    probe.env["HADALIS_WORKFLOW_GRAMMAR"] = str(grammar)
    probe.env["QT_QUICK_BACKEND"] = "software"
    try:
        probe.launch()
        run_success(probe, work_dir, clock_path, report)
        run_postcondition_failure(probe, clock_path, report)
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
