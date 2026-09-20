#!/usr/bin/env python3
"""Live isolated acceptance for the reviewed Signal/Action lifecycle."""

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
        / "signal_action_commit.py"
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
            f"Signal/Action engine emitted invalid JSON: {raw!r}; "
            f"stderr={completed.stderr!r}"
        ) from exc
    payload["_returnCode"] = completed.returncode
    payload["_stderr"] = completed.stderr.strip()
    return payload


def reset_signal_action(probe: Probe) -> dict:
    wait_snapshot(
        probe,
        lambda s: (
            not s["workflowTransaction"]["signalActionPreparationBusy"]
            and not s["workflowTransaction"]["signalActionLifecycleBusy"]
            and not s["workflowTransaction"]["bindingLifecycleBusy"]
            and not s["workflowTransaction"]["disconnectLifecycleBusy"]
            and not s["workflowTransaction"]["connectLifecycleBusy"]
            and not s["workflowTransaction"]["applyLifecycleBusy"]
        ),
        "Signal/Action transaction idle before clear",
        timeout=60,
    )
    probe.ipc("workflowClear")
    return wait_snapshot(
        probe,
        lambda s: (
            s["workflowTransaction"]["status"] == "clean"
            and s["workflowTransaction"]["activeCommandKind"] == ""
            and s["workflowTransaction"]["signalActionArtifactsReady"] is False
        ),
        "Signal/Action transaction clear",
        timeout=30,
    )


def prepare_signal_action(
    probe: Probe,
    media_path: Path,
) -> tuple[dict, bytes]:
    source_before = media_path.read_bytes()

    if probe.ipc("workflowSignalActionPreview") != "true":
        raise AssertionError("production Signal/Action preview did not start")
    preview = wait_snapshot(
        probe,
        lambda s: (
            s["workflowTransaction"]["status"] == "preview"
            and s["workflowTransaction"]["activeCommandKind"]
                == "signal-action"
            and s["workflowTransaction"]["activeCommandSourcePath"]
                == "modules/bar/Media.qml"
            and bool(
                s["workflowTransaction"]["activeCommandCandidateSha256"]
            )
        ),
        "production Signal/Action preview",
        timeout=60,
    )

    if probe.ipc("workflowSignalActionPrepare") != "true":
        raise AssertionError(
            "production Signal/Action artifact preparation did not start")
    prepared = wait_snapshot(
        probe,
        lambda s: (
            s["workflowTransaction"]["status"] == "preview"
            and s["workflowTransaction"]["signalActionArtifactsReady"]
                is True
            and not s["workflowTransaction"]["signalActionPreparationBusy"]
            and bool(
                (s["workflowTransaction"].get(
                    "activeSignalActionPreparation") or {})
                .get("manifestPath")
            )
        ),
        "production Signal/Action artifacts",
        timeout=90,
    )
    if media_path.read_bytes() != source_before:
        raise AssertionError(
            "Signal/Action preparation modified tracked Media source")

    return {
        "preview": preview["workflowTransaction"],
        "prepared": prepared["workflowTransaction"],
    }, source_before


def authorize_signal_action(probe: Probe) -> dict:
    if probe.ipc("workflowSignalActionAuthorize") != "true":
        raise AssertionError("explicit Signal/Action authorization failed")
    return wait_snapshot(
        probe,
        lambda s: (
            s["workflowTransaction"]["signalActionAuthorizationReady"]
                is True
            and s["workflowTransaction"]["signalActionApplyEnabled"] is True
            and (
                s["workflowTransaction"].get(
                    "activeSignalActionAuthorization") or {}
            ).get("authorizationProof")
                == "explicit-signal-action-write-authorization-v1"
        ),
        "explicit Signal/Action authorization",
        timeout=30,
    )


def cleanup_success(
    probe: Probe,
    work_dir: Path,
    preparation: dict,
    previous_epoch: str,
    source_before: bytes,
    media_path: Path,
) -> dict:
    rolled_back = engine(
        work_dir,
        "rollback",
        str(preparation["manifestPath"]),
        str(preparation["manifestSha256"]),
    )
    if rolled_back.get("status") != "rolled-back":
        raise AssertionError(
            "2K-W-C success cleanup rollback failed: "
            + json.dumps(rolled_back, sort_keys=True))
    if media_path.read_bytes() != source_before:
        raise AssertionError(
            "2K-W-C success cleanup did not restore exact Media bytes")
    restored, mode = recover_after_rollback(
        probe,
        previous_epoch,
        "2K-W-C success cleanup",
    )
    return {
        "rollback": rolled_back,
        "recoveryMode": mode,
        "reloadCompletions": restored["reloadCompletions"],
    }


def run_success(
    probe: Probe,
    work_dir: Path,
    media_path: Path,
    report: dict,
) -> None:
    prepared_state, source_before = prepare_signal_action(
        probe, media_path)
    prepared_tx = prepared_state["prepared"]
    preparation = (
        prepared_tx.get("activeSignalActionPreparation") or {})
    manifest_path = Path(str(preparation["manifestPath"]))
    candidate_path = Path(str(preparation["candidatePath"]))
    candidate = candidate_path.read_bytes()
    candidate_sha = str(
        prepared_tx["activeCommandCandidateSha256"])

    before_auth = probe.snapshot()
    if probe.ipc("workflowSignalActionApply") != "false":
        raise AssertionError(
            "Signal/Action Apply started before authorization")
    authorized = authorize_signal_action(probe)
    before = probe.snapshot()

    if probe.ipc("workflowSignalActionApply") != "true":
        raise AssertionError(
            "authorized Signal/Action Apply did not start")
    if probe.ipc("workflowSignalActionApply") != "false":
        raise AssertionError(
            "Signal/Action Apply accepted duplicate start")

    completed = wait_snapshot(
        probe,
        lambda s: (
            s["workflowTransaction"]["status"] == "signal-action-applied"
            and s["workflowTransaction"]["pendingSignalActionPhase"]
                == "idle"
            and s["workflowTransaction"]["signalActionLifecycleBusy"]
                is False
            and s["workflowTransaction"]["signalActionApplyEnabled"]
                is False
            and s["workflowTransaction"]["signalActionAuthorizationReady"]
                is False
            and (s["workflowTransaction"].get(
                "signalActionLifecycleResult") or {}).get("status")
                == "signal-action-applied"
            and s["workflowAnalyzer"]["status"] == "ready"
            and (s["workflowAnalyzer"].get("semanticRebind") or {})
                .get("status") == "resolved"
            and (s["workflowAnalyzer"].get("semanticRebind") or {})
                .get("kind") == "handler-candidate"
            and (s["workflowAnalyzer"].get("semanticRebind") or {})
                .get("name") == "onDoubleClicked"
            and (s["workflowAnalyzer"].get("semanticRebind") or {})
                .get("semanticValueText") == "root.toggleExpanded()"
            and len(s["workflowAnalyzer"]["diagnostics"]) == 0
        ),
        "internal Signal/Action Apply success",
        timeout=120,
    )

    probe.record(
        "2K-W-C authorized Signal/Action applies once and proves exact handler rebind",
        before_auth["workflowTransaction"]["signalActionApplyEnabled"]
            is False
        and before["workflowTransaction"]["signalActionApplyEnabled"] is True
        and before["epoch"] != completed["epoch"]
        and completed["reloadCompletions"] == 1
        and completed["reloadFailures"] == 0
        and media_path.read_bytes() == candidate
        and file_sha(media_path) == candidate_sha
        and candidate.count(
            b"onDoubleClicked: root.toggleExpanded()"
        ) == 1,
        {
            "manifestPath": str(manifest_path),
            "candidateSha256": candidate_sha,
            "authorization":
                authorized["workflowTransaction"]
                    ["activeSignalActionAuthorization"],
            "lifecycle":
                completed["workflowTransaction"]
                    ["signalActionLifecycleResult"],
            "analyzer": completed["workflowAnalyzer"],
        },
    )

    cleanup = cleanup_success(
        probe,
        work_dir,
        preparation,
        completed["epoch"],
        source_before,
        media_path,
    )
    report["success"] = {
        "prepared": prepared_state,
        "authorized": authorized["workflowTransaction"],
        "completed": completed["workflowTransaction"],
        "cleanup": cleanup,
    }
    reset_signal_action(probe)


def run_postcondition_failure(
    probe: Probe,
    media_path: Path,
    report: dict,
) -> None:
    prepared_state, source_before = prepare_signal_action(
        probe, media_path)
    preparation = (
        prepared_state["prepared"].get(
            "activeSignalActionPreparation") or {})
    manifest_path = Path(str(preparation["manifestPath"]))

    probe.ipc("workflowSignalActionAnalyzeExistingAction")
    action_analysis = wait_snapshot(
        probe,
        lambda s: (
            s["workflowAnalyzer"]["status"] == "ready"
            and s["workflowAnalyzer"]["sourcePath"]
                == "modules/bar/Media.qml"
            and (s["workflowAnalyzer"].get("reviewedAnchor") or {})
                .get("status") == "resolved"
            and (s["workflowAnalyzer"].get("reviewedAnchor") or {})
                .get("semanticKind") == "function"
            and (s["workflowAnalyzer"].get("reviewedAnchor") or {})
                .get("semanticName") == "toggleExpanded"
        ),
        "surviving Media action function analysis",
        timeout=60,
    )
    action_anchor = str(
        action_analysis["workflowAnalyzer"]["reviewedAnchor"]
            ["semanticAnchor"])
    if not action_anchor:
        raise AssertionError(
            "surviving toggleExpanded function has no semantic anchor")

    manifest = json.loads(
        manifest_path.read_text(encoding="utf-8"))
    original_anchor = str(
        manifest["insertedHandlerSemanticAnchor"])
    manifest["insertedHandlerSemanticAnchor"] = action_anchor
    manifest_path.write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    manifest_sha = file_sha(manifest_path)
    if probe.ipc(
        "workflowSignalActionOverridePreparedAnchor",
        action_anchor,
        manifest_sha,
    ) != "true":
        raise AssertionError(
            "ProbeShell could not align Signal/Action postcondition fixture")

    authorized = authorize_signal_action(probe)
    if probe.ipc("workflowSignalActionApply") != "true":
        raise AssertionError(
            "forced postcondition Signal/Action Apply did not start")
    if probe.ipc("workflowSignalActionApply") != "false":
        raise AssertionError(
            "forced postcondition Signal/Action Apply accepted duplicate start")

    recovered = wait_snapshot(
        probe,
        lambda s: (
            s["workflowTransaction"]["status"]
                == "signal-action-rollback-complete"
            and s["workflowTransaction"]["pendingSignalActionPhase"]
                == "idle"
            and s["workflowTransaction"]["signalActionLifecycleBusy"]
                is False
            and s["workflowTransaction"]["signalActionApplyEnabled"]
                is False
            and s["workflowTransaction"]["signalActionAuthorizationReady"]
                is False
            and (s["workflowTransaction"].get(
                "signalActionLifecycleResult") or {}).get("status")
                == "signal-action-rolled-back"
        ),
        "Signal/Action exact-handler postcondition automatic rollback",
        timeout=150,
    )
    result = (
        recovered["workflowTransaction"]["signalActionLifecycleResult"]
        or {}
    )

    probe.record(
        "2K-W-C wrong surviving action anchor rolls back exact Media source",
        media_path.read_bytes() == source_before
        and bool(
            recovered["workflowTransaction"]
                ["signalActionLifecycleError"])
        and result.get("recoveryMode")
            in ("watcher", "explicit-recovery")
        and (result.get("verify") or {}).get("sourceState")
            == "base-present",
        {
            "originalInsertedHandlerAnchor": original_anchor,
            "forcedWrongActionAnchor": action_anchor,
            "manifestSha256": manifest_sha,
            "authorization":
                authorized["workflowTransaction"]
                    ["activeSignalActionAuthorization"],
            "lifecycle": recovered["workflowTransaction"],
        },
    )
    report["postconditionFailure"] = {
        "prepared": prepared_state,
        "authorized": authorized["workflowTransaction"],
        "recovered": recovered["workflowTransaction"],
    }
    reset_signal_action(probe)


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
    media_path = work_dir / "config/modules/bar/Media.qml"

    report = {
        "schema": 1,
        "gate": "Phase 2K-W-C",
        "manifest": manifest,
        "grammar": str(grammar),
        "grammarSha256": file_sha(grammar),
        "sway": str(sway),
        "checks": [],
        "environment":
            "headless Sway, isolated XDG/private bus, production "
            "Signal/Action preview/preparation/authorization/internal lifecycle",
        "limitations": [
            "Only reviewed target media.signal.doubleClickToggle is write-authorized.",
            "Settings Signal/Action Apply remains unavailable.",
            "The source tree under test is a temporary exported runtime.",
        ],
    }

    probe = Probe(work_dir, report, pointer=None, sway=sway)
    probe.env["HADALIS_WORKFLOW_GRAMMAR"] = str(grammar)
    probe.env["QT_QUICK_BACKEND"] = "software"
    try:
        probe.launch()
        run_success(probe, work_dir, media_path, report)
        run_postcondition_failure(probe, media_path, report)
    except Exception as exc:
        report["failure"] = repr(exc)
        try:
            report["failureSnapshot"] = probe.snapshot()
        except Exception:
            pass
    finally:
        probe.close()
        (
            work_dir
            / "signal-action-production-lifecycle-report.json"
        ).write_text(
            json.dumps(report, indent=2) + "\n",
            encoding="utf-8",
        )

    print(json.dumps({
        "report": str(
            work_dir
            / "signal-action-production-lifecycle-report.json"),
        "checks": len(report["checks"]),
        "failure": report.get("failure"),
    }, indent=2))
    return int(bool(report.get("failure")))


if __name__ == "__main__":
    raise SystemExit(main())
