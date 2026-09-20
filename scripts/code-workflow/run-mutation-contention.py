#!/usr/bin/env python3
"""Live cross-pipeline mutation contention acceptance for 2K-V-B.

Probe-only IPC keeps four already-qualified commands simultaneously available
so one Binding
owner can prove that Disconnect, Connect and Literal lifecycle starts fail
closed while the owner is in flight. The Binding candidate then intentionally
fails its exact semantic postcondition, proving that same-source sibling
handoffs were invalidated while the owner's exact rollback identity survived.
"""

from __future__ import annotations

import argparse
from hashlib import sha256
import importlib.util
import json
from pathlib import Path


HERE = Path(__file__).resolve().parent


def load_module(name: str, filename: str):
    spec = importlib.util.spec_from_file_location(name, HERE / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


binding = load_module(
    "binding_production", "run-binding-production-lifecycle.py"
)
disconnect = load_module(
    "disconnect_production", "run-disconnect-production-lifecycle.py"
)
connect_live = load_module(
    "connect_live_contention", "run-connect-lifecycle.py"
)
connect_production = load_module(
    "connect_production_contention",
    "run-connect-production-lifecycle.py",
)
literal = load_module(
    "literal_production_contention", "run-apply-lifecycle.py"
)

Probe = binding.Probe
prepare_module = binding.prepare_module
wait_snapshot = binding.wait_snapshot


def file_sha(path: Path) -> str:
    return sha256(path.read_bytes()).hexdigest()


def select_history(
    probe: Probe,
    index: int,
    kind: str,
    description: str,
) -> dict:
    if probe.ipc("workflowTestSelectHistoryIndex", index) != "true":
        raise AssertionError(description + " selection failed")
    return wait_snapshot(
        probe,
        lambda s: (
            s["workflowTransaction"]["historyIndex"] == index
            and s["workflowTransaction"]["activeCommandKind"] == kind
        ),
        description,
        timeout=30,
    )


def history_entry(snapshot: dict, index: int) -> dict:
    summary = snapshot["workflowTransaction"].get("historySummary") or []
    for entry in summary:
        if int(entry.get("index", -1)) == index:
            return entry
    raise AssertionError(f"history summary missing index {index}")


def prepare_four_pipelines(
    probe: Probe,
    clock_path: Path,
) -> dict:
    disconnect_state, source_before = disconnect.prepare_disconnect(
        probe, clock_path
    )
    disconnect_index = int(
        disconnect_state["prepared"]["historyIndex"]
    )

    binding_state, binding_source = binding.prepare_binding(
        probe, clock_path
    )
    if binding_source != source_before:
        raise AssertionError("Binding preparation source snapshot drifted")
    binding_index = int(binding_state["prepared"]["historyIndex"])

    connect_state, connect_source = connect_live.prepare_connect(
        probe, clock_path
    )
    if connect_source != source_before:
        raise AssertionError("Connect preparation source snapshot drifted")
    connect_index = int(connect_state["prepared"]["historyIndex"])

    (
        _literal_anchor,
        _literal_analyzed,
        _literal_preview,
        _literal_ready,
        literal_prepared,
    ) = literal.preview_prepare(
        probe,
        literal.SUCCESS_NEEDLE,
        "true",
    )
    literal_index = int(
        literal_prepared["workflowTransaction"]["historyIndex"]
    )

    indices = {
        disconnect_index,
        binding_index,
        connect_index,
        literal_index,
    }
    if len(indices) != 4:
        raise AssertionError(
            "four mutation pipelines did not retain distinct history commands"
        )

    return {
        "sourceBefore": source_before,
        "disconnect": {
            "index": disconnect_index,
            "state": disconnect_state,
        },
        "binding": {
            "index": binding_index,
            "state": binding_state,
        },
        "connect": {
            "index": connect_index,
            "state": connect_state,
        },
        "literal": {
            "index": literal_index,
            "state": literal_prepared["workflowTransaction"],
        },
    }


def force_binding_postcondition_failure(
    probe: Probe,
    binding_index: int,
) -> dict:
    selected = select_history(
        probe,
        binding_index,
        "direct-binding",
        "Binding owner selection",
    )
    preparation = (
        selected["workflowTransaction"].get(
            "activeBindingPreparation"
        ) or {}
    )
    manifest_path = Path(str(preparation["manifestPath"]))

    probe.ipc("workflowBindingAnalyzeBullet")
    bullet_analysis = wait_snapshot(
        probe,
        lambda s: (
            s["workflowAnalyzer"]["status"] == "ready"
            and (s["workflowAnalyzer"].get("reviewedAnchor") or {})
                .get("status") == "resolved"
            and (s["workflowAnalyzer"].get("reviewedAnchor") or {})
                .get("semanticValueText") == '"•"'
        ),
        "V-B surviving Clock bullet binding analysis",
        timeout=60,
    )
    bullet_anchor = str(
        bullet_analysis["workflowAnalyzer"]["reviewedAnchor"][
            "semanticAnchor"
        ]
    )
    if not bullet_anchor:
        raise AssertionError("V-B bullet binding has no semantic anchor")

    manifest = json.loads(
        manifest_path.read_text(encoding="utf-8")
    )
    original_anchor = str(manifest["semanticAnchor"])
    manifest["semanticAnchor"] = bullet_anchor
    manifest_path.write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    manifest_sha = file_sha(manifest_path)
    if probe.ipc(
        "workflowBindingOverridePreparedAnchor",
        bullet_anchor,
        manifest_sha,
    ) != "true":
        raise AssertionError(
            "V-B could not align Binding rollback fixture"
        )

    return {
        "manifestPath": str(manifest_path),
        "manifestSha256": manifest_sha,
        "transactionId": str(preparation.get("transactionId", "")),
        "originalAnchor": original_anchor,
        "forcedAnchor": bullet_anchor,
    }


def authorize_siblings_and_owner(
    probe: Probe,
    prepared: dict,
) -> dict:
    disconnect_index = prepared["disconnect"]["index"]
    binding_index = prepared["binding"]["index"]
    connect_index = prepared["connect"]["index"]
    literal_index = prepared["literal"]["index"]

    select_history(
        probe,
        disconnect_index,
        "disconnect-binding",
        "Disconnect sibling selection",
    )
    disconnect_authorized = disconnect.authorize_disconnect(probe)

    select_history(
        probe,
        connect_index,
        "connect-binding",
        "Connect sibling selection",
    )
    wait_snapshot(
        probe,
        lambda s: (
            s["workflowTransaction"]["connectAuthorizeEnabled"] is True
            and s["workflowTransaction"]["connectArtifactsReady"] is True
        ),
        "Connect sibling authorization readiness",
        timeout=60,
    )
    connect_authorized = connect_production.authorize_connect(probe)

    select_history(
        probe,
        binding_index,
        "direct-binding",
        "Binding owner re-selection",
    )
    binding_authorized = binding.authorize_binding(probe)

    literal_selected = select_history(
        probe,
        literal_index,
        "literal-property",
        "Literal sibling selection",
    )
    if not (
        literal_selected["workflowTransaction"]["applyArtifactsReady"]
        and literal_selected["workflowTransaction"][
            "applyLifecycleReady"
        ]
    ):
        raise AssertionError(
            "Literal sibling was not independently lifecycle-ready"
        )

    select_history(
        probe,
        binding_index,
        "direct-binding",
        "Binding owner final selection",
    )

    return {
        "disconnect":
            disconnect_authorized["workflowTransaction"],
        "connect": connect_authorized["workflowTransaction"],
        "binding": binding_authorized["workflowTransaction"],
        "literal": literal_selected["workflowTransaction"],
    }


def run_contention(
    probe: Probe,
    clock_path: Path,
    report: dict,
) -> None:
    prepared = prepare_four_pipelines(probe, clock_path)
    source_before = prepared["sourceBefore"]
    binding_index = prepared["binding"]["index"]
    disconnect_index = prepared["disconnect"]["index"]
    connect_index = prepared["connect"]["index"]
    literal_index = prepared["literal"]["index"]

    forced = force_binding_postcondition_failure(
        probe, binding_index
    )
    authorized = authorize_siblings_and_owner(
        probe, prepared
    )
    before = probe.snapshot()

    if probe.ipc(
        "workflowContentionStartBindingAgainstAll",
        binding_index,
        disconnect_index,
        connect_index,
        literal_index,
    ) != "true":
        raise AssertionError(
            "Binding owner did not start with all competitor starts rejected"
        )

    contention = wait_snapshot(
        probe,
        lambda s: (
            (s.get("mutationContention") or {}).get(
                "ownerStarted"
            ) is True
        ),
        "persisted V-B contention evidence",
        timeout=30,
    )
    evidence = contention.get("mutationContention") or {}
    attempts = evidence.get("attempts") or {}

    for label in ("disconnect", "connect", "literal"):
        attempt = attempts.get(label) or {}
        if attempt.get("started") is not False:
            raise AssertionError(
                f"{label} competing lifecycle escaped Binding owner"
            )

    recovered = wait_snapshot(
        probe,
        lambda s: (
            s["workflowTransaction"]["status"]
                == "binding-rollback-complete"
            and s["workflowTransaction"]["pendingBindingPhase"]
                == "idle"
            and s["workflowTransaction"]["bindingLifecycleBusy"]
                is False
            and (s["workflowTransaction"].get(
                "bindingLifecycleResult"
            ) or {}).get("status") == "binding-rolled-back"
        ),
        "V-B Binding owner exact rollback",
        timeout=180,
    )

    result = (
        recovered["workflowTransaction"].get(
            "bindingLifecycleResult"
        ) or {}
    )
    verify = result.get("verify") or {}
    disconnect_entry = history_entry(
        recovered, disconnect_index
    )
    connect_entry = history_entry(
        recovered, connect_index
    )
    binding_entry = history_entry(
        recovered, binding_index
    )

    sibling_stale = (
        disconnect_entry.get("stale") is True
        and disconnect_entry.get(
            "disconnectPreparationStatus"
        ) == "stale"
        and disconnect_entry.get(
            "disconnectAuthorizationStatus"
        ) == "expired"
        and connect_entry.get("stale") is True
        and connect_entry.get(
            "connectSafetyFreshness"
        ) == "stale"
        and connect_entry.get(
            "connectPreparationStatus"
        ) == "stale"
        and connect_entry.get(
            "connectAuthorizationStatus"
        ) == "expired"
    )
    rollback_identity_survived = (
        clock_path.read_bytes() == source_before
        and binding_entry.get("bindingRolledBack") is True
        and verify.get("sourceState") == "base-present"
        and verify.get("manifestSha256")
            == forced["manifestSha256"]
        and result.get("recoveryMode")
            in ("watcher", "explicit-recovery")
    )
    starts_serialized = (
        evidence.get("ownerReady") is True
        and evidence.get("ownerStarted") is True
        and evidence.get("ownerBusyAfterStart") is True
        and (attempts.get("disconnect") or {}).get(
            "authorizationReady"
        ) is True
        and (attempts.get("disconnect") or {}).get(
            "artifactsReady"
        ) is True
        and (attempts.get("connect") or {}).get(
            "authorizationReady"
        ) is True
        and (attempts.get("connect") or {}).get(
            "artifactsReady"
        ) is True
        and (attempts.get("literal") or {}).get(
            "artifactsReady"
        ) is True
        and (attempts.get("literal") or {}).get(
            "commandMatches"
        ) is True
    )

    probe.record(
        "2K-V-B Binding owner serializes Literal/Connect/Disconnect starts",
        starts_serialized,
        {
            "before": before["workflowTransaction"],
            "contention": evidence,
            "authorizations": authorized,
        },
    )
    probe.record(
        "2K-V-B owner write stales same-source siblings and preserves exact rollback",
        sibling_stale and rollback_identity_survived,
        {
            "forcedBinding": forced,
            "bindingResult": result,
            "disconnectSibling": disconnect_entry,
            "connectSibling": connect_entry,
            "bindingOwner": binding_entry,
        },
    )

    prepared_report = dict(prepared)
    prepared_report["sourceBeforeSha256"] = sha256(
        source_before
    ).hexdigest()
    prepared_report["sourceBeforeBytes"] = len(source_before)
    prepared_report.pop("sourceBefore", None)

    report["contention"] = {
        "prepared": prepared_report,
        "forcedBinding": forced,
        "authorized": authorized,
        "evidence": evidence,
        "recovered": recovered["workflowTransaction"],
        "historySummary":
            recovered["workflowTransaction"]["historySummary"],
    }


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
        "gate": "Phase 2K-V-B",
        "manifest": manifest,
        "grammar": str(grammar),
        "grammarSha256": file_sha(grammar),
        "sway": str(sway),
        "checks": [],
        "environment":
            "headless Sway, isolated XDG/private bus, four prepared "
            "production mutation pipelines with one real Binding owner",
        "limitations": [
            "The live contention owner is the reviewed Binding replacement.",
            "Connect and Disconnect siblings share ClockWidget.qml with the owner.",
            "Literal uses the isolated ApplyTarget fixture and proves global start serialization.",
            "No mutation allowlist is broadened by this acceptance harness.",
        ],
    }

    probe = Probe(work_dir, report, pointer=None, sway=sway)
    probe.env["HADALIS_WORKFLOW_GRAMMAR"] = str(grammar)
    probe.env["QT_QUICK_BACKEND"] = "software"
    try:
        probe.launch()
        run_contention(probe, clock_path, report)
    except Exception as exc:
        report["failure"] = repr(exc)
        try:
            report["failureSnapshot"] = probe.snapshot()
        except Exception:
            pass
    finally:
        probe.close()
        (work_dir / "mutation-contention-report.json").write_text(
            json.dumps(report, indent=2) + "\n",
            encoding="utf-8",
        )

    print(json.dumps({
        "report": str(work_dir / "mutation-contention-report.json"),
        "checks": len(report["checks"]),
        "failure": report.get("failure"),
    }, indent=2))
    return int(bool(report.get("failure")))


if __name__ == "__main__":
    raise SystemExit(main())
