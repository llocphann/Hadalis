#!/usr/bin/env python3
"""Live isolated acceptance for explicit Connect write authorization.

2K-R proves authorization independently of the later Apply control. The product
UI may authorize one exact prepared Connect manifest/history command; 2K-S
separately proves the user-facing source-write wrapper. This harness proves that
preparation alone cannot start the lifecycle, authorization is exact and
revocable, history/dependency changes expire it, and manifest drift is rejected
before any source write.
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
wait_reload = live.wait_reload
recover_after_rollback = live.recover_after_rollback
reset_connect = live.reset_connect


def file_sha(path: Path) -> str:
    return sha256(path.read_bytes()).hexdigest()


def authorize(probe: Probe) -> dict:
    if probe.ipc("workflowConnectAuthorize") != "true":
        raise AssertionError("explicit Connect authorization failed")
    return wait_snapshot(
        probe,
        lambda s: (
            s["workflowTransaction"]["connectAuthorizationReady"] is True
            and s["workflowTransaction"]["connectAuthorizeEnabled"] is False
            and (
                s["workflowTransaction"].get(
                    "activeConnectAuthorization") or {}
            ).get("status") == "authorized"
        ),
        "Connect authorization ready",
        timeout=30,
    )


def run_prepare_and_revoke(
    probe: Probe,
    clock_path: Path,
    config_path: Path,
    report: dict,
) -> None:
    prepared_state, source_before = prepare_connect(probe, clock_path)
    prepared_tx = prepared_state["prepared"]
    prepared = prepared_tx["activeConnectPreparation"] or {}
    safety = prepared_tx["activeConnectSafety"] or {}
    config_before = config_path.read_bytes()

    before = probe.snapshot()
    lifecycle_without_authorization = probe.ipc(
        "workflowConnectBeginLifecycle"
    )
    if lifecycle_without_authorization != "false":
        raise AssertionError(
            "prepared Connect lifecycle started without authorization"
        )
    if clock_path.read_bytes() != source_before:
        raise AssertionError(
            "unauthorized lifecycle attempt modified Clock source"
        )

    authorized = authorize(probe)
    auth = (
        authorized["workflowTransaction"].get(
            "activeConnectAuthorization") or {}
    )
    expected_token = (
        "connect-authorized:"
        + str(prepared["transactionId"])
        + ":"
        + str(prepared_tx["activeCommandCandidateSha256"])
    )

    identity_ok = (
        auth.get("authorizationProof")
            == "explicit-connect-write-authorization-v1"
        and auth.get("authorizationToken") == expected_token
        and auth.get("targetId") == "bar/clock"
        and auth.get("connectTargetId") == "clock.connect.rootVisible"
        and auth.get("sourcePath") == "modules/bar/ClockWidget.qml"
        and auth.get("baseSha256")
            == prepared_tx["activeCommandBaseSha256"]
        and auth.get("candidateSha256")
            == prepared_tx["activeCommandCandidateSha256"]
        and auth.get("parentSemanticAnchor")
            == safety.get("parentSemanticAnchor")
        and auth.get("insertedSemanticAnchor")
            == prepared.get("insertedSemanticAnchor")
        and auth.get("targetProperty") == "visible"
        and auth.get("sourceExpression") == "root.showDate"
        and auth.get("manifestPath") == prepared.get("manifestPath")
        and auth.get("manifestSha256") == prepared.get("manifestSha256")
        and auth.get("manifestSha256")
            == file_sha(Path(str(prepared.get("manifestPath"))))
        and auth.get("transactionId") == prepared.get("transactionId")
        and auth.get("externalSourcePath")
            == prepared.get("externalSourcePath")
        and auth.get("externalSourceSha256")
            == prepared.get("externalSourceSha256")
        and auth.get("proofFreshness") == "fresh"
        and auth.get("typeCompatibility") == "unknown-unresolved"
        and auth.get("cycleStatus") == "unknown-incomplete-projection"
        and auth.get("rollbackGuarantee")
            == "exact-snapshot-auto-rollback-v1"
    )
    probe.record(
        "2K-R preparation does not authorize; explicit action binds exact identity",
        before["workflowTransaction"]["connectAuthorizationReady"] is False
        and before["workflowTransaction"]["connectAuthorizeEnabled"] is True
        and lifecycle_without_authorization == "false"
        and identity_ok
        and clock_path.read_bytes() == source_before
        and config_path.read_bytes() == config_before,
        {
            "prepared": prepared,
            "authorization": auth,
            "unauthorizedLifecycleStart":
                lifecycle_without_authorization,
        },
    )

    if probe.ipc("workflowConnectRevoke") != "true":
        raise AssertionError("explicit Connect revoke failed")
    revoked = wait_snapshot(
        probe,
        lambda s: (
            s["workflowTransaction"]["connectAuthorizationReady"] is False
            and (
                s["workflowTransaction"].get(
                    "connectAuthorizationDiagnostics") or {}
            ).get("status") == "expired"
        ),
        "Connect authorization revoked",
        timeout=30,
    )
    lifecycle_after_revoke = probe.ipc(
        "workflowConnectBeginLifecycle"
    )
    probe.record(
        "2K-R revoked authorization cannot start source lifecycle",
        lifecycle_after_revoke == "false"
        and clock_path.read_bytes() == source_before
        and config_path.read_bytes() == config_before,
        {
            "lifecycleStart": lifecycle_after_revoke,
            "diagnostics":
                revoked["workflowTransaction"]
                    ["connectAuthorizationDiagnostics"],
        },
    )

    report["prepareAndRevoke"] = {
        "prepared": prepared_state,
        "authorized": authorized["workflowTransaction"],
        "revoked": revoked["workflowTransaction"],
    }
    reset_connect(probe)


def run_history_expiration(
    probe: Probe,
    clock_path: Path,
    report: dict,
) -> None:
    prepared_state, source_before = prepare_connect(probe, clock_path)
    authorized = authorize(probe)
    auth_token = str(
        (
            authorized["workflowTransaction"].get(
                "activeConnectAuthorization") or {}
        ).get("authorizationToken", "")
    )

    if probe.ipc("workflowUndo") != "true":
        raise AssertionError("2K-R history fixture could not undo")
    wait_snapshot(
        probe,
        lambda s: (
            s["workflowTransaction"]["historyIndex"] == -1
            and s["workflowTransaction"]["connectAuthorizationReady"]
                is False
        ),
        "history undo expires Connect authorization",
        timeout=30,
    )
    if probe.ipc("workflowRedo") != "true":
        raise AssertionError("2K-R history fixture could not redo")

    redone = wait_snapshot(
        probe,
        lambda s: (
            s["workflowTransaction"]["activeCommandKind"]
                == "connect-binding"
            and s["workflowTransaction"]["status"] == "preview"
            and not s["workflowTransaction"]["connectPreparationBusy"]
            and s["workflowTransaction"]["connectArtifactsReady"] is True
            and s["workflowTransaction"]["connectAuthorizationReady"]
                is False
        ),
        "history redo keeps Connect authorization expired",
        timeout=60,
    )
    lifecycle_after_history_change = probe.ipc(
        "workflowConnectBeginLifecycle"
    )

    probe.record(
        "2K-R history selection change expires exact authorization",
        bool(auth_token)
        and lifecycle_after_history_change == "false"
        and clock_path.read_bytes() == source_before,
        {
            "authorizationToken": auth_token,
            "lifecycleStart": lifecycle_after_history_change,
            "transaction": redone["workflowTransaction"],
        },
    )

    report["historyExpiration"] = {
        "prepared": prepared_state,
        "authorized": authorized["workflowTransaction"],
        "redone": redone["workflowTransaction"],
    }
    reset_connect(probe)


def run_external_dependency_expiration(
    probe: Probe,
    clock_path: Path,
    config_path: Path,
    report: dict,
) -> None:
    prepared_state, source_before = prepare_connect(probe, clock_path)
    authorized = authorize(probe)
    config_before = config_path.read_bytes()
    marker = b"\n// 2K-R authorization dependency invalidation\n"
    if marker.strip() in config_before:
        raise AssertionError("2K-R Config marker already present")

    before = probe.snapshot()
    config_path.write_bytes(config_before + marker)
    invalidated = wait_snapshot(
        probe,
        lambda s: (
            s["epoch"] != before["epoch"]
            and s["ready"] is True
            and s["workflowTransaction"]["connectAuthorizationReady"]
                is False
            and s["workflowTransaction"]["connectArtifactsReady"] is False
        ),
        "Config edit expires Connect authorization",
        timeout=90,
    )
    lifecycle_after_config_change = probe.ipc(
        "workflowConnectBeginLifecycle"
    )

    probe.record(
        "2K-R external Config edit expires authorization before write",
        lifecycle_after_config_change == "false"
        and clock_path.read_bytes() == source_before
        and marker.strip() in config_path.read_bytes(),
        {
            "lifecycleStart": lifecycle_after_config_change,
            "transaction": invalidated["workflowTransaction"],
        },
    )

    report["dependencyExpiration"] = {
        "prepared": prepared_state,
        "authorized": authorized["workflowTransaction"],
        "invalidated": invalidated["workflowTransaction"],
    }

    restore_epoch = invalidated["epoch"]
    config_path.write_bytes(config_before)
    try:
        wait_reload(
            probe,
            restore_epoch,
            "2K-R Config fixture cleanup reload",
        )
    except AssertionError:
        probe.ipc("reload")
        wait_reload(
            probe,
            restore_epoch,
            "2K-R Config fixture explicit cleanup reload",
        )
    reset_connect(probe)


def run_manifest_drift(
    probe: Probe,
    clock_path: Path,
    config_path: Path,
    report: dict,
) -> None:
    prepared_state, source_before = prepare_connect(probe, clock_path)
    authorized = authorize(probe)
    prepared = (
        authorized["workflowTransaction"].get(
            "activeConnectPreparation") or {}
    )
    manifest_path = Path(str(prepared["manifestPath"]))
    manifest_before = manifest_path.read_bytes()
    expected_manifest_sha = str(prepared["manifestSha256"])
    config_before = config_path.read_bytes()

    manifest_path.write_bytes(
        manifest_before + b"\n"
    )
    drifted_manifest_sha = file_sha(manifest_path)
    if drifted_manifest_sha == expected_manifest_sha:
        raise AssertionError("2K-R manifest drift fixture did not drift")

    if probe.ipc("workflowConnectBeginLifecycle") != "true":
        raise AssertionError(
            "authorized manifest drift fixture did not enter lifecycle"
        )

    failed = wait_snapshot(
        probe,
        lambda s: (
            s["workflowTransaction"]["connectLifecycleBusy"] is False
            and s["workflowTransaction"]["status"] == "error"
            and s["workflowTransaction"]["pendingConnectPhase"]
                == "connect-commit-failed"
            and "manifest hash mismatch" in str(
                s["workflowTransaction"]["connectLifecycleError"])
            and s["workflowTransaction"]["connectAuthorizationReady"]
                is False
        ),
        "manifest drift rejected before Connect source write",
        timeout=60,
    )

    probe.record(
        "2K-R exact manifest SHA blocks drift before source write",
        clock_path.read_bytes() == source_before
        and config_path.read_bytes() == config_before
        and expected_manifest_sha != drifted_manifest_sha,
        {
            "expectedManifestSha256": expected_manifest_sha,
            "driftedManifestSha256": drifted_manifest_sha,
            "lifecycleError":
                failed["workflowTransaction"]["connectLifecycleError"],
            "lifecycleResult":
                failed["workflowTransaction"]["connectLifecycleResult"],
        },
    )

    manifest_path.write_bytes(manifest_before)
    report["manifestDrift"] = {
        "prepared": prepared_state,
        "authorized": authorized["workflowTransaction"],
        "failed": failed["workflowTransaction"],
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
        "gate": "Phase 2K-R",
        "manifest": manifest,
        "grammar": str(grammar),
        "grammarSha256": file_sha(grammar),
        "sway": str(sway),
        "checks": [],
        "environment":
            "headless Sway, isolated XDG/private bus, production "
            "Connect preview/preparation/authorization transaction",
        "limitations": [
            "This 2K-R harness tests authorization only; 2K-S tests user-facing Apply separately.",
            "Lifecycle start remains reachable only through ProbeShell IPC.",
            "The source tree under test is a temporary exported runtime.",
        ],
    }

    probe = Probe(work_dir, report, pointer=None, sway=sway)
    probe.env["HADALIS_WORKFLOW_GRAMMAR"] = str(grammar)
    probe.env["QT_QUICK_BACKEND"] = "software"
    try:
        probe.launch()
        run_prepare_and_revoke(
            probe, clock_path, config_path, report)
        run_history_expiration(
            probe, clock_path, report)
        run_external_dependency_expiration(
            probe, clock_path, config_path, report)
        run_manifest_drift(
            probe, clock_path, config_path, report)
    except Exception as exc:
        report["failure"] = repr(exc)
        try:
            report["failureSnapshot"] = probe.snapshot()
        except Exception:
            pass
    finally:
        probe.close()
        (work_dir / "connect-authorization-report.json").write_text(
            json.dumps(report, indent=2) + "\n",
            encoding="utf-8",
        )

    print(json.dumps({
        "report": str(
            work_dir / "connect-authorization-report.json"),
        "checks": len(report["checks"]),
        "failure": report.get("failure"),
    }, indent=2))
    return int(bool(report.get("failure")))


if __name__ == "__main__":
    raise SystemExit(main())
