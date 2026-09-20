#!/usr/bin/env python3
"""Live isolated acceptance for user-facing reviewed Signal/Action Apply.

The Settings controls are statically bound to the same authorized transaction
wrapper already qualified by 2K-W-C. This gate re-runs the success and forced
postcondition rollback scenarios through that wrapper without adding a second
write engine.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
prod_spec = importlib.util.spec_from_file_location(
    "signal_action_production",
    HERE / "run-signal-action-production-lifecycle.py",
)
prod = importlib.util.module_from_spec(prod_spec)
prod_spec.loader.exec_module(prod)

Probe = prod.Probe
prepare_module = prod.prepare_module


def run_user_apply_success(
    probe: Probe,
    work_dir: Path,
    media_path: Path,
    report: dict,
) -> None:
    before = len(report["checks"])
    prod.run_success(probe, work_dir, media_path, report)
    if len(report["checks"]) != before + 1:
        raise AssertionError("2K-W-D success proof did not record exactly once")
    report["checks"][-1]["name"] = (
        "2K-W-D authorized Settings Signal/Action Apply starts once "
        "and proves exact handler rebind"
    )


def run_user_apply_rollback(
    probe: Probe,
    media_path: Path,
    report: dict,
) -> None:
    before = len(report["checks"])
    prod.run_postcondition_failure(probe, media_path, report)
    if len(report["checks"]) != before + 1:
        raise AssertionError("2K-W-D rollback proof did not record exactly once")
    report["checks"][-1]["name"] = (
        "2K-W-D failed Settings Signal/Action Apply rolls back exact base"
    )


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
        "gate": "Phase 2K-W-D",
        "manifest": manifest,
        "grammar": str(grammar),
        "grammarSha256": prod.file_sha(grammar),
        "sway": str(sway),
        "checks": [],
        "environment":
            "headless Sway, isolated XDG/private bus, production "
            "Signal/Action preview/preparation/authorization/user-Apply wrapper",
        "limitations": [
            "Settings control wiring is locked by static contract; live start "
            "uses ProbeShell IPC bound to the same authorized transaction wrapper.",
            "Only media.signal.doubleClickToggle is user-selectable.",
            "The source tree under test is a temporary exported runtime.",
        ],
    }

    probe = Probe(work_dir, report, pointer=None, sway=sway)
    probe.env["HADALIS_WORKFLOW_GRAMMAR"] = str(grammar)
    probe.env["QT_QUICK_BACKEND"] = "software"
    try:
        probe.launch()
        run_user_apply_success(probe, work_dir, media_path, report)
        run_user_apply_rollback(probe, media_path, report)
    except Exception as exc:
        report["failure"] = repr(exc)
        try:
            report["failureSnapshot"] = probe.snapshot()
        except Exception:
            pass
    finally:
        probe.close()
        (work_dir / "signal-action-user-apply-report.json").write_text(
            json.dumps(report, indent=2) + "\n",
            encoding="utf-8",
        )

    print(json.dumps({
        "report": str(work_dir / "signal-action-user-apply-report.json"),
        "checks": len(report["checks"]),
        "failure": report.get("failure"),
    }, indent=2))
    return int(bool(report.get("failure")))


if __name__ == "__main__":
    raise SystemExit(main())
