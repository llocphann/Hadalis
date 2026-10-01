#!/usr/bin/env python3
"""Manual, isolated offscreen geometry diagnostic for unmodified Wull QML.

The current compositor mask covers the host item; this diagnostic maps the
actual clickable WaterDropletBody across all four edges before any mask edit.
It does NOT validate physical pointer passthrough or rendered appearance.
"""
import datetime as dt
import json
import os
from pathlib import Path
import secrets
import shutil
import signal
import subprocess
import sys

BASE = "c763d908d060b294f592536d6fd0dff277afe7ee"
SELF = "scripts/wull-manual-footprint.py"
CONTRACT = "scripts/test-wull-footprint-contract.py"
FIXTURE = "scripts/wull-fixtures/footprint/shell.qml"
FIXTURE_BLOB = "14ff7be2fbf1a9c9cd03ce957d1d5e8a695479d0"
REMOTES = {
    "https://github.com/llocphann/Hadalis",
    "https://github.com/llocphann/Hadalis.git",
    "git@github.com:llocphann/Hadalis",
    "git@github.com:llocphann/Hadalis.git",
    "ssh://git@github.com/llocphann/Hadalis",
    "ssh://git@github.com/llocphann/Hadalis.git",
}
SENSITIVE = {
    "modules/abyss/AbyssPerimeter.qml",
    "modules/abyss/companion/AbyssCompanion.qml",
    "modules/abyss/companion/WaterDropletBody.qml",
    "modules/abyss/looks/AbyssStyle.qml",
    "modules/common/Config.qml",
    "defaults/config.json",
}
MAX_LOG = 1048576


def git(*args):
    result = subprocess.run(["git", *args], capture_output=True, text=True,
                            timeout=45)
    if result.returncode:
        raise RuntimeError("Git operation failed: " + " ".join(args))
    return result.stdout.strip()


def clean():
    return git("status", "--porcelain=v1", "--untracked-files=all") == ""


def fetch():
    git("fetch", "--quiet", "origin", "refs/heads/dev:refs/remotes/origin/dev")
    return git("rev-parse", "refs/remotes/origin/dev")


def audit(target):
    if subprocess.run(["git", "merge-base", "--is-ancestor", BASE, target],
                      capture_output=True, timeout=10).returncode:
        raise RuntimeError("Remote does not descend from geometry baseline")
    if git("rev-parse", target + ":" + FIXTURE) != FIXTURE_BLOB:
        raise RuntimeError("Geometry fixture differs from reviewed version")
    modified = set(git("diff", "--name-only", BASE, target).splitlines())
    if SENSITIVE & modified:
        raise RuntimeError("Wull geometry source changed; review required")
    for path in (SELF, CONTRACT):
        revisions = git("log", "--format=%H", BASE + ".." + target,
                        "--", path).splitlines()
        if len(revisions) != 1 or (
            git("rev-parse", revisions[0] + ":" + path)
            != git("rev-parse", target + ":" + path)
        ):
            raise RuntimeError("Unreviewed geometry diagnostic revision")


def truncated_log(path):
    if path.exists() and path.stat().st_size > MAX_LOG:
        with path.open("rb") as stream:
            first = stream.read(MAX_LOG // 2)
            stream.seek(-MAX_LOG // 2, os.SEEK_END)
            last = stream.read()
        path.write_bytes(first + b"\n[PRIVATE LOG MIDDLE OMITTED]\n" + last)


def summarize(rows):
    if not isinstance(rows, list) or len(rows) != 4:
        raise ValueError("missing_edge_samples")
    names = {"top", "right", "bottom", "left"}
    if {row.get("edge") for row in rows if isinstance(row, dict)} != names:
        raise ValueError("wrong_edge_set")
    result = []
    for row in rows:
        if not isinstance(row, dict) or row.get("valid") is not True:
            raise ValueError("invalid_edge_geometry")
        for field in ("host_width", "host_height", "body_width",
                      "body_height", "mapped_x", "mapped_y",
                      "mapped_width", "mapped_height"):
            number = row.get(field)
            if not isinstance(number, (int, float)) or isinstance(number, bool):
                raise ValueError("invalid_numeric_geometry")
            if field.endswith(("width", "height")) and number <= 0:
                raise ValueError("nonpositive_geometry")
            if abs(number) > 100000:
                raise ValueError("geometry_outside_reasonable_bound")
        if not isinstance(row.get("within_host"), bool):
            raise ValueError("missing_within_host_flag")
        host_area = row["host_width"] * row["host_height"]
        body_bbox = row["mapped_width"] * row["mapped_height"]
        result.append({
            "edge": row["edge"],
            "host_area": round(host_area, 1),
            "mapped_body_bbox_area": round(body_bbox, 1),
            "bbox_to_host_ratio": round(body_bbox / host_area, 3),
            "body_stays_within_host": row["within_host"],
            "mapped_body_x": row["mapped_x"],
            "mapped_body_y": row["mapped_y"],
            "mapped_body_width": row["mapped_width"],
            "mapped_body_height": row["mapped_height"],
        })
    return sorted(result, key=lambda entry:
                  ("top", "right", "bottom", "left").index(entry["edge"]))


def probe(folder, qs, dbus):
    result = {
        "status": "inconclusive", "reason": None,
        "scope": "offscreen_actual_AbyssCompanion_geometry_only",
        "four_edges_observed": False,
        "edge_geometry": [],
        "edges_protruding_past_host": [],
        "compositor_pointer_passthrough": "not_tested",
        "visual_appearance": "not_tested",
        "production_mask_modified": False,
    }
    shell = folder / "shell"
    shell.mkdir()
    source = Path.cwd()
    for item in ("modules", "services", "GlobalStates.qml", "qmldir",
                 "assets", "scripts", "defaults", "translations"):
        (shell / item).symlink_to(source / item)
    shutil.copyfile(FIXTURE, shell / "shell.qml")
    xdg = folder / "xdg"
    for item in ("config", "data", "cache", "state"):
        (xdg / item).mkdir(parents=True)
    config = xdg / "config" / "illogical-impulse"
    config.mkdir()
    shutil.copyfile("defaults/config.json", config / "config.json")
    environment = dict(os.environ)
    for variable in ("QS_CONFIG_PATH", "QS_CONFIG_NAME", "QS_MANIFEST",
                     "INIR_COMPANIOND"):
        environment.pop(variable, None)
    environment.update({
        "QT_QPA_PLATFORM": "offscreen",
        "XDG_CONFIG_HOME": str(xdg / "config"),
        "XDG_DATA_HOME": str(xdg / "data"),
        "XDG_CACHE_HOME": str(xdg / "cache"),
        "XDG_STATE_HOME": str(xdg / "state"),
        "QS_NO_RELOAD_POPUP": "1",
    })
    log = folder / "quickshell.private.log"
    proc = None
    try:
        with log.open("wb") as out:
            proc = subprocess.Popen(
                [dbus, "--", qs, "--path", str(shell / "shell.qml")],
                env=environment, stdout=out, stderr=subprocess.STDOUT,
                stdin=subprocess.DEVNULL, start_new_session=True
            )
            try:
                code = proc.wait(timeout=15)
            except subprocess.TimeoutExpired:
                result["reason"] = "offscreen_qml_timeout"
                if proc.poll() is None:
                    try:
                        os.killpg(proc.pid, signal.SIGTERM)
                    except ProcessLookupError:
                        pass
                proc.wait(timeout=3)
                return result
        truncated_log(log)
        text = log.read_text(encoding="utf-8", errors="replace")
        lines = [part.split("WULL_FOOTPRINT_GEOMETRY ", 1)[1]
                 for part in text.splitlines()
                 if "WULL_FOOTPRINT_GEOMETRY " in part]
        if code != 0 or "WULL_FOOTPRINT_TIMEOUT" in text or len(lines) != 1:
            result["reason"] = "offscreen_qml_load_or_marker_failed"
            return result
        rows = json.loads(lines[0])
        result["edge_geometry"] = summarize(rows)
        result["four_edges_observed"] = True
        result["edges_protruding_past_host"] = [
            part["edge"] for part in result["edge_geometry"]
            if not part["body_stays_within_host"]
        ]
        result["status"] = "pass"
        return result
    except (OSError, ValueError, json.JSONDecodeError,
            subprocess.TimeoutExpired):
        result["reason"] = "private_geometry_measurement_unavailable"
        return result
    finally:
        truncated_log(log)


def publish(report, path):
    for attempt in range(4):
        pushed = subprocess.run(
            ["git", "push", "origin", "HEAD:refs/heads/dev"],
            capture_output=True, timeout=50
        )
        if pushed.returncode == 0:
            return
        if attempt == 3:
            raise RuntimeError("Report push refused; unpublished report stays local")
        if not clean() or git("diff-tree", "--no-commit-id", "--name-only",
                              "-r", "HEAD") != str(path):
            raise RuntimeError("Only the own unpublished report may be rebased")
        parent = git("rev-parse", "HEAD^")
        remote = fetch()
        audit(remote)
        if subprocess.run(["git", "merge-base", "--is-ancestor", parent, remote],
                          capture_output=True, timeout=10).returncode:
            raise RuntimeError("Unexpected remote history during publication")
        git("rebase", "--onto", remote, parent)
        if not clean() or git("diff-tree", "--no-commit-id", "--name-only",
                              "-r", "HEAD") != str(path):
            raise RuntimeError("Rebased geometry report changed unexpectedly")
        report["publication_parent_sha"] = git("rev-parse", "HEAD^")
        path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        git("add", "--", str(path))
        if git("diff", "--cached", "--name-only") != str(path):
            raise RuntimeError("Unexpected staged files during report amend")
        git("commit", "--amend", "--no-edit")


def main():
    os.umask(0o077)
    if sys.argv[1:] != ["--observe-footprint"]:
        raise RuntimeError("Explicit diagnostic opt-in: --observe-footprint")
    root = Path(git("rev-parse", "--show-toplevel")).resolve()
    if (Path.cwd().resolve() != root
            or git("symbolic-ref", "--quiet", "--short", "HEAD") != "dev"
            or not clean()):
        raise RuntimeError("A clean dev checkout at repository root is required")
    remote_url = git("remote", "get-url", "origin")
    push_urls = git("remote", "get-url", "--push", "--all", "origin").splitlines()
    if remote_url not in REMOTES or len(push_urls) != 1 or push_urls[0] not in REMOTES:
        raise RuntimeError("Unexpected Git origin remote")
    remote = fetch()
    audit(remote)
    git("merge", "--ff-only", remote)
    if not clean():
        raise RuntimeError("Fast-forward changed the working tree unexpectedly")
    source = git("rev-parse", "HEAD")
    identifier = (dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
                  + "-" + secrets.token_hex(4))
    state = Path(os.environ.get(
        "XDG_STATE_HOME", str(Path.home() / ".local/state")
    )).resolve()
    private = state / "hadalis" / ("wull-footprint-" + identifier)
    if private == root or root in private.parents:
        raise RuntimeError("Private diagnostics must be outside the checkout")
    private.mkdir(parents=True, mode=0o700, exist_ok=False)
    print("EXACT_SOURCE_SHA:", source, flush=True)
    print("PRIVATE_LOG_DIRECTORY:", private, flush=True)
    qs = shutil.which("qs")
    dbus = shutil.which("dbus-run-session")
    if qs is None or dbus is None:
        measured = {
            "status": "inconclusive",
            "reason": "quickshell_or_isolated_session_unavailable",
            "scope": "offscreen_actual_AbyssCompanion_geometry_only",
            "edge_geometry": [],
        }
    else:
        measured = probe(private, qs, dbus)
    report = {
        "kind": "wull_manual_offscreen_clickable_body_geometry",
        "source_sha": source, "status": measured["status"],
        "measurement": measured,
        "physical_pointer_mask": "not_tested",
        "current_production_mask": "whole_companion_host",
        "canonical_validation": "not_run",
        "private_logs": "local_only",
    }
    print("WULL_FOOTPRINT_RESULT:", report["status"], flush=True)
    print("FOOTPRINT_OVERHANG_EDGES:",
          measured.get("edges_protruding_past_host", []), flush=True)
    if not clean() or git("rev-parse", "HEAD") != source:
        raise RuntimeError("Working tree changed during geometry diagnostic")
    updated = fetch()
    audit(updated)
    git("merge", "--ff-only", updated)
    if not clean():
        raise RuntimeError("Checkout changed before report publication")
    report["publication_parent_sha"] = git("rev-parse", "HEAD")
    path = Path("docs") / (
        "wull-footprint-" + identifier + "-" + source[:12] + ".json"
    )
    if path.exists():
        raise RuntimeError("Refusing to overwrite geometry receipt")
    path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    git("add", "--", str(path))
    if (git("diff", "--cached", "--name-only") != str(path)
            or git("diff", "--name-only")
            or git("ls-files", "--others", "--exclude-standard")):
        raise RuntimeError("Unexpected files before report publication")
    git("commit", "-m", "test(wull): publish bounded four-edge clickable geometry",
        "--", str(path))
    publish(report, path)
    print("REPORT_PUBLISHED:", path, flush=True)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, ValueError, subprocess.TimeoutExpired) as exc:
        print("STOP:", exc, file=sys.stderr)
        sys.exit(1)
