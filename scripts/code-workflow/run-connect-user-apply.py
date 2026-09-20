#!/usr/bin/env python3
"""Live isolated acceptance for the user-facing Connect Apply boundary.

The Settings button is statically bound to beginAuthorizedConnectApply().
ProbeShell exposes that same transaction wrapper for live acceptance. The
harness proves exactly-once authorized start, successful reload/verify/rebind,
and automatic rollback on semantic failure without silent retry.
"""

from __future__ import annotations

import argparse
from hashlib import sha256
import importlib.util
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent

prod_spec = importlib.util.spec_from_file_location(
    "connect_production",
    HERE / "run-connect-production-lifecycle.py",
)
prod = importlib.util.module_from_spec(prod_spec)
prod_spec.loader.exec_module(prod)

Probe = prod.Probe
prepare_module = prod.prepare_module
prepare_connect = prod.prepare_connect
wait_snapshot = prod.wait_snapshot
reset_connect = prod.reset_connect
engine = prod.engine
recover_after_rollback = prod.recover_after_rollback
authorize_connect = prod.authorize_connect


def file_sha(path: Path) -> str:
    return sha256(path.read_bytes()).hexdigest()


def cleanup_success(
    probe: Probe,
    work_dir: Path,
    manifest_path: str,
    previous_epoch: str,
    source_before: bytes,
    clock_path: Path,
) -> dict:
    rolled_back = engine(work_dir, "rollback", manifest_path)
    if rolled_back.get("status") != "rolled-back":
        raise AssertionError(
            "2K-S success cleanup rollback failed: "
            + json.dumps(rolled_back, sort_keys=True)
        )
    if clock_path.read_bytes() != source_before:
        raise AssertionError(
            "2K-S success cleanup did not restore exact Clock bytes"
        )
    restored, mode = recover_after_rollback(
        probe,
        previous_epoch,
        "2K-S success cleanup",
    )
    return {
        "rollback": rolled_back,
        "recoveryMode": mode,
        "reloadCompletions": restored["reloadCompletions"],
    }


def run_user_apply_success(
    probe: Probe,
    work_dir: Path,
    clock_path: Path,
    config_path: Path,
    report: dict,
) -> None:
    prepared_state, source_before = prepare_connect(probe, clock_path)
    prepared_tx = prepared_state["prepared"]
    prepared = prepared_tx["activeConnectPreparation"] or {}
    manifest_path = str(prepared["manifestPath"])
    inserted_anchor = str(prepared["insertedSemanticAnchor"])
    candidate_sha = str(prepared_tx["activeCommandCandidateSha256"])
    config_before = config_path.read_bytes()

    before_auth = probe.snapshot()
    pre_authorization_start = probe.ipc("workflowConnectApply")
    if pre_authorization_start != "false":
        raise AssertionError(
            "2K-S Connect Apply started before explicit authorization"
        )

    authorized = authorize_connect(probe)
    ready = wait_snapshot(
        probe,
        lambda s: (
            s["workflowTransaction"]["connectApplyEnabled"] is True
            and s["workflowTransaction"]["connectAuthorizationReady"]
                is True
            and s["workflowTransaction"]["pendingConnectPhase"] == "idle"
        ),
        "user-facing Connect Apply ready",
        timeout=30,
    )
    before = probe.snapshot()

    first_start = probe.ipc("workflowConnectApply")
    second_start = probe.ipc("workflowConnectApply")
    if first_start != "true":
        raise AssertionError("2K-S authorized Connect Apply did not start")
    if second_start != "false":
        raise AssertionError("2K-S Connect Apply was not exactly-once")

    completed = wait_snapshot(
        probe,
        lambda s: (
            s["workflowTransaction"]["status"] == "connect-applied"
            and s["workflowTransaction"]["pendingConnectPhase"] == "idle"
            and s["workflowTransaction"]["connectLifecycleBusy"] is False
            and s["workflowTransaction"]["connectApplyEnabled"] is False
            and s["workflowTransaction"]["connectAuthorizationReady"]
                is False
            and (s["workflowTransaction"].get(
                "connectLifecycleResult") or {}).get("status")
                == "connect-applied"
            and s["workflowAnalyzer"]["status"] == "ready"
            and s["workflowAnalyzer"]["semanticAnchor"]
                == inserted_anchor
            and s["workflowAnalyzer"]["semanticRebind"]
                .get("status") == "resolved"
            and len(s["workflowAnalyzer"]["diagnostics"]) == 0
        ),
        "user-facing Connect Apply success",
        timeout=120,
    )

    probe.record(
        "2K-S authorized Apply starts once and completes qualified lifecycle",
        before_auth["workflowTransaction"]["connectApplyEnabled"] is False
        and pre_authorization_start == "false"
        and ready["workflowTransaction"]["connectApplyEnabled"] is True
        and first_start == "true"
        and second_start == "false"
        and before["epoch"] != completed["epoch"]
        and completed["reloadCompletions"] == 1
        and completed["reloadFailures"] == 0
        and file_sha(clock_path) == candidate_sha
        and config_path.read_bytes() == config_before,
        {
            "manifestPath": manifest_path,
            "candidateSha256": candidate_sha,
            "insertedSemanticAnchor": inserted_anchor,
            "authorized": authorized["workflowTransaction"],
            "lifecycle":
                completed["workflowTransaction"]["connectLifecycleResult"],
            "analyzer": completed["workflowAnalyzer"],
        },
    )

    cleanup = cleanup_success(
        probe,
        work_dir,
        manifest_path,
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
    reset_connect(probe)


def run_user_apply_rollback(
    probe: Probe,
    clock_path: Path,
    config_path: Path,
    report: dict,
) -> None:
    prepared_state, source_before = prepare_connect(probe, clock_path)
    transaction = prepared_state["prepared"]
    prepared = transaction["activeConnectPreparation"] or {}
    manifest_path = Path(str(prepared["manifestPath"]))
    config_before = config_path.read_bytes()

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    valid_anchor = str(manifest["insertedSemanticAnchor"])
    invalid_anchor = valid_anchor + "#2ks-forced-missing"
    manifest["insertedSemanticAnchor"] = invalid_anchor
    manifest_path.write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    manifest_sha = file_sha(manifest_path)

    if probe.ipc(
        "workflowConnectOverridePreparedAnchor",
        invalid_anchor,
    ) != "true":
        raise AssertionError(
            "2K-S ProbeShell could not align temporary preparation anchor"
        )
    if probe.ipc(
        "workflowConnectOverridePreparedManifestSha",
        manifest_sha,
    ) != "true":
        raise AssertionError(
            "2K-S ProbeShell could not align temporary manifest SHA"
        )

    authorized = authorize_connect(probe)
    if probe.ipc("workflowConnectApply") != "true":
        raise AssertionError(
            "2K-S forced-failure authorized Apply did not start"
        )
    if probe.ipc("workflowConnectApply") != "false":
        raise AssertionError(
            "2K-S forced-failure Apply accepted a duplicate start"
        )

    recovered = wait_snapshot(
        probe,
        lambda s: (
            s["workflowTransaction"]["status"]
                == "connect-rollback-complete"
            and s["workflowTransaction"]["pendingConnectPhase"] == "idle"
            and s["workflowTransaction"]["connectLifecycleBusy"] is False
            and s["workflowTransaction"]["connectApplyEnabled"] is False
            and s["workflowTransaction"]["connectAuthorizationReady"]
                is False
            and (s["workflowTransaction"].get(
                "connectLifecycleResult") or {}).get("status")
                == "connect-rolled-back"
        ),
        "user-facing Connect Apply automatic rollback",
        timeout=150,
    )
    result = (
        recovered["workflowTransaction"]["connectLifecycleResult"] or {}
    )

    probe.record(
        "2K-S failed authorized Apply rolls back and requires regeneration",
        clock_path.read_bytes() == source_before
        and config_path.read_bytes() == config_before
        and bool(
            recovered["workflowTransaction"]["connectLifecycleError"])
        and result.get("recoveryMode")
            in ("watcher", "explicit-recovery")
        and (result.get("verify") or {}).get("sourceState")
            == "base-present",
        {
            "validAnchor": valid_anchor,
            "forcedAnchor": invalid_anchor,
            "manifestSha256": manifest_sha,
            "authorized": authorized["workflowTransaction"],
            "lifecycle": recovered["workflowTransaction"],
        },
    )

    report["rollback"] = {
        "prepared": prepared_state,
        "authorized": authorized["workflowTransaction"],
        "recovered": recovered["workflowTransaction"],
    }
    reset_connect(probe)


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

    report = {
        "schema": 1,
        "gate": "Phase 2K-S",
        "manifest": manifest,
        "grammar": str(grammar),
        "grammarSha256": file_sha(grammar),
        "sway": str(sway),
        "checks": [],
        "environment":
            "headless Sway, isolated XDG/private bus, production "
            "Connect preview/preparation/authorization/user-Apply wrapper",
        "limitations": [
            "Settings button wiring is locked by static contract; live start "
            "uses ProbeShell IPC bound to the same transaction wrapper.",
            "The source tree under test is a temporary exported runtime.",
        ],
    }

    probe = Probe(work_dir, report, pointer=None, sway=sway)
    probe.env["HADALIS_WORKFLOW_GRAMMAR"] = str(grammar)
    probe.env["QT_QUICK_BACKEND"] = "software"
    try:
        probe.launch()
        run_user_apply_success(
            probe, work_dir, clock_path, config_path, report)
        run_user_apply_rollback(
            probe, clock_path, config_path, report)
    except Exception as exc:
        report["failure"] = repr(exc)
        try:
            report["failureSnapshot"] = probe.snapshot()
        except Exception:
            pass
    finally:
        probe.close()
        (work_dir / "connect-user-apply-report.json").write_text(
            json.dumps(report, indent=2) + "\n",
            encoding="utf-8",
        )

    print(json.dumps({
        "report": str(work_dir / "connect-user-apply-report.json"),
        "checks": len(report["checks"]),
        "failure": report.get("failure"),
    }, indent=2))
    return int(bool(report.get("failure")))


if __name__ == "__main__":
    raise SystemExit(main())
