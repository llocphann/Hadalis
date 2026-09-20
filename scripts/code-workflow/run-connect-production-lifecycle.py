#!/usr/bin/env python3
"""Live isolated production-internal Connect lifecycle acceptance.

2K-Q keeps Settings free of any Connect Apply control. This harness uses
ProbeShell-only IPC to invoke the production transaction lifecycle after the
normal production Connect preview + preparation path has produced an exact
manifest. The success case crosses a watcher-driven Quickshell reload and
semantic rebind. The failure case corrupts only the temporary prepared
manifest's inserted semantic anchor, proving the transaction automatically
rolls the committed candidate back when post-reload semantic rebind fails.
"""

from __future__ import annotations

import argparse
from hashlib import sha256
import importlib.util
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent

spec = importlib.util.spec_from_file_location(
    "connect_live",
    HERE / "run-connect-lifecycle.py",
)
live = importlib.util.module_from_spec(spec)
spec.loader.exec_module(live)

Probe = live.Probe
prepare_module = live.prepare_module
prepare_connect = live.prepare_connect
wait_snapshot = live.wait_snapshot
recover_after_rollback = live.recover_after_rollback
reset_connect = live.reset_connect
engine = live.engine


def file_sha(path: Path) -> str:
    return sha256(path.read_bytes()).hexdigest()


def authorize_connect(probe: Probe) -> dict:
    if probe.ipc("workflowConnectAuthorize") != "true":
        raise AssertionError(
            "explicit Connect authorization did not succeed")
    return wait_snapshot(
        probe,
        lambda s: (
            s["workflowTransaction"]["connectAuthorizationReady"] is True
            and (
                s["workflowTransaction"].get(
                    "activeConnectAuthorization") or {}
            ).get("status") == "authorized"
        ),
        "explicit Connect write authorization",
        timeout=30,
    )


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
            "2K-Q success cleanup rollback failed: "
            + json.dumps(rolled_back, sort_keys=True)
        )
    if clock_path.read_bytes() != source_before:
        raise AssertionError(
            "2K-Q success cleanup did not restore exact Clock bytes")
    restored, mode = recover_after_rollback(
        probe,
        previous_epoch,
        "2K-Q success cleanup",
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
    config_path: Path,
    report: dict,
) -> None:
    prepared_state, source_before = prepare_connect(probe, clock_path)
    transaction = prepared_state["prepared"]
    prepared = transaction["activeConnectPreparation"] or {}
    safety = transaction["activeConnectSafety"] or {}
    manifest_path = str(prepared["manifestPath"])
    inserted_anchor = str(prepared["insertedSemanticAnchor"])
    candidate_sha = str(transaction["activeCommandCandidateSha256"])
    config_before = config_path.read_bytes()
    authorized = authorize_connect(probe)
    before = probe.snapshot()

    if probe.ipc("workflowConnectBeginLifecycle") != "true":
        raise AssertionError(
            "production internal Connect lifecycle did not start")

    completed = wait_snapshot(
        probe,
        lambda s: (
            s["workflowTransaction"]["status"] == "connect-applied"
            and s["workflowTransaction"]["pendingConnectPhase"] == "idle"
            and s["workflowTransaction"]["connectLifecycleBusy"] is False
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
        "production internal Connect lifecycle success",
        timeout=120,
    )

    probe.record(
        "2K-Q production lifecycle commits, reloads, verifies and rebinds",
        before["epoch"] != completed["epoch"]
        and completed["reloadCompletions"] == 1
        and completed["reloadFailures"] == 0
        and file_sha(clock_path) == candidate_sha
        and config_path.read_bytes() == config_before
        and safety.get("freshness") == "fresh",
        {
            "manifestPath": manifest_path,
            "candidateSha256": candidate_sha,
            "insertedSemanticAnchor": inserted_anchor,
            "lifecycleResult":
                completed["workflowTransaction"]["connectLifecycleResult"],
            "analyzer": completed["workflowAnalyzer"],
            "reloadCompletions": completed["reloadCompletions"],
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
    probe.record(
        "2K-Q success cleanup restores isolated Clock baseline",
        clock_path.read_bytes() == source_before
        and config_path.read_bytes() == config_before
        and cleanup["recoveryMode"]
            in ("watcher", "explicit-recovery"),
        cleanup,
    )

    report["success"] = {
        "prepared": prepared_state,
        "authorized": authorized["workflowTransaction"],
        "completed": completed["workflowTransaction"],
        "analyzer": completed["workflowAnalyzer"],
        "cleanup": cleanup,
    }
    reset_connect(probe)


def run_automatic_rebind_rollback(
    probe: Probe,
    work_dir: Path,
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
    invalid_anchor = valid_anchor + "#2kq-forced-missing"
    manifest["insertedSemanticAnchor"] = invalid_anchor
    manifest_path.write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )

    if probe.ipc(
        "workflowConnectOverridePreparedAnchor",
        invalid_anchor,
    ) != "true":
        raise AssertionError(
            "ProbeShell could not align temporary preparation anchor")
    manifest_sha = file_sha(manifest_path)
    if probe.ipc(
        "workflowConnectOverridePreparedManifestSha",
        manifest_sha,
    ) != "true":
        raise AssertionError(
            "ProbeShell could not align temporary manifest SHA")
    authorized = authorize_connect(probe)

    before = probe.snapshot()
    if probe.ipc("workflowConnectBeginLifecycle") != "true":
        raise AssertionError(
            "forced-rebind Connect lifecycle did not start")

    recovered = wait_snapshot(
        probe,
        lambda s: (
            s["workflowTransaction"]["status"]
                == "connect-rollback-complete"
            and s["workflowTransaction"]["pendingConnectPhase"] == "idle"
            and s["workflowTransaction"]["connectLifecycleBusy"] is False
            and (s["workflowTransaction"].get(
                "connectLifecycleResult") or {}).get("status")
                == "connect-rolled-back"
        ),
        "production Connect automatic rollback after rebind failure",
        timeout=150,
    )
    result = (
        recovered["workflowTransaction"]["connectLifecycleResult"]
        or {}
    )

    probe.record(
        "2K-Q failed inserted-anchor rebind automatically rolls source back",
        before["epoch"] != recovered["epoch"]
        and file_sha(clock_path) == sha256(source_before).hexdigest()
        and clock_path.read_bytes() == source_before
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
            "lifecycleResult": result,
            "lifecycleError":
                recovered["workflowTransaction"]["connectLifecycleError"],
            "reloadCompletions": recovered["reloadCompletions"],
        },
    )

    report["automaticRollback"] = {
        "prepared": prepared_state,
        "authorized": authorized["workflowTransaction"],
        "manifestSha256": manifest_sha,
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
        "gate": "Phase 2K-Q",
        "manifest": manifest,
        "grammar": str(grammar),
        "grammarSha256": file_sha(grammar),
        "sway": str(sway),
        "checks": [],
        "environment":
            "headless Sway, isolated XDG/private bus, production "
            "Connect preview/preparation/lifecycle state machine",
        "limitations": [
            "Settings still exposes no Connect Apply control.",
            "Lifecycle start is reachable only through ProbeShell IPC.",
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
        run_automatic_rebind_rollback(
            probe, work_dir, clock_path, config_path, report)
    except Exception as exc:
        report["failure"] = repr(exc)
        try:
            report["failureSnapshot"] = probe.snapshot()
        except Exception:
            pass
    finally:
        probe.close()
        (work_dir / "connect-production-lifecycle-report.json").write_text(
            json.dumps(report, indent=2) + "\n",
            encoding="utf-8",
        )

    print(json.dumps({
        "report": str(
            work_dir / "connect-production-lifecycle-report.json"),
        "checks": len(report["checks"]),
        "failure": report.get("failure"),
    }, indent=2))
    return int(bool(report.get("failure")))


if __name__ == "__main__":
    raise SystemExit(main())
