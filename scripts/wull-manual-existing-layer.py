#!/usr/bin/env python3
"""Bounded read-only inventory of an existing Niri Abyss production layer.

Never starts Quickshell, sends input, reads user shell configuration, or
enables Wull. Publishing only a sanitized summary is its sole repository edit.
"""
import datetime as dt
import json
from pathlib import Path
import secrets
import shutil
import subprocess
import sys
import time

BASE = "a42dfc4b9cdb9da5c066868f9959da591cb4a221"
SELF = "scripts/wull-manual-existing-layer.py"
CONTRACT = "scripts/test-wull-existing-layer-contract.py"
NAMESPACE = "hadalis:abyss-perimeter"
ALLOWED_ORIGINS = {
    "https://github.com/llocphann/Hadalis",
    "https://github.com/llocphann/Hadalis.git",
    "git@github.com:llocphann/Hadalis",
    "git@github.com:llocphann/Hadalis.git",
    "ssh://git@github.com/llocphann/Hadalis",
    "ssh://git@github.com/llocphann/Hadalis.git",
}


def git(*args):
    done = subprocess.run(["git", *args], capture_output=True, text=True,
                          timeout=40)
    if done.returncode:
        raise RuntimeError("Git operation failed: " + " ".join(args))
    return done.stdout.strip()


def clean():
    return git("status", "--porcelain=v1", "--untracked-files=all") == ""


def fetch():
    git("fetch", "--quiet", "origin", "refs/heads/dev:refs/remotes/origin/dev")
    return git("rev-parse", "refs/remotes/origin/dev")


def audit(remote):
    if subprocess.run(
        ["git", "merge-base", "--is-ancestor", BASE, remote],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        timeout=10
    ).returncode:
        raise RuntimeError("Remote dev does not descend from the reviewed baseline")
    for path in (SELF, CONTRACT):
        # A single reviewed introduction; any subsequent edit requires
        # an explicit baseline review, not a silent acceptance.
        revisions = git("log", "--format=%H", BASE + ".." + remote,
                        "--", path).splitlines()
        if len(revisions) != 1 or (
            git("rev-parse", revisions[0] + ":" + path)
            != git("rev-parse", remote + ":" + path)
        ):
            raise RuntimeError("Read-only observer changed after reviewed addition")


def niri_json(binary, command):
    done = subprocess.run([binary, "msg", "-j", command],
                          capture_output=True, text=True, timeout=5)
    if done.returncode:
        raise RuntimeError("niri_" + command + "_unavailable")
    data = json.loads(done.stdout)
    # Accept either unwrapped CLI output or tagged IPC replies.
    if isinstance(data, dict) and "Ok" in data:
        data = data["Ok"]
    if command == "layers":
        if isinstance(data, dict):
            data = data.get("Layers", data.get("layers"))
        if not isinstance(data, list):
            raise RuntimeError("niri_layers_unexpected_schema")
    elif command == "outputs":
        if isinstance(data, dict):
            data = data.get("Outputs", data.get("outputs", data))
        if not isinstance(data, dict):
            raise RuntimeError("niri_outputs_unexpected_schema")
    return data


def evaluate(outputs, layers):
    """Return sanitized inventory counts; never store monitor identifiers."""
    active = {name for name, item in outputs.items()
              if isinstance(item, dict) and item.get("logical") is not None}
    relevant = [item for item in layers
                if isinstance(item, dict)
                and item.get("namespace") == NAMESPACE]
    counts = {name: 0 for name in active}
    orphan = 0
    modes = {"none": 0, "ondemand": 0, "exclusive": 0, "unknown": 0}
    for item in relevant:
        name = item.get("output")
        if name in counts:
            counts[name] += 1
        else:
            orphan += 1
        keyboard = str(item.get("keyboard_interactivity", "")).lower()
        modes[keyboard if keyboard in modes else "unknown"] += 1
    return {
        "active_output_count": len(active),
        "observed_production_layer_count": len(relevant),
        "outputs_with_exactly_one_layer": sum(v == 1 for v in counts.values()),
        "outputs_missing_layer": sum(v == 0 for v in counts.values()),
        "outputs_with_duplicate_layers": sum(v > 1 for v in counts.values()),
        "layers_on_unrecognized_or_inactive_outputs": orphan,
        "observed_keyboard_mode_counts": modes,
    }


def observe(binary):
    result = {
        "status": "inconclusive",
        "reason": None,
        "scope": "existing_production_layer_inventory_only",
        "samples": [],
        "sample_interval_milliseconds": 500,
        "production_binary_identity": "not_verified",
        "wull_enabled_state": "not_read",
        "pointer_input_mask": "not_observable_via_niri_ipc",
        "rendered_visuals": "not_observed",
        "live_multioutput_hotplug": "not_run",
    }
    for index in range(4):
        try:
            outs = niri_json(binary, "outputs")
            layers = niri_json(binary, "layers")
            sample = evaluate(outs, layers)
        except (RuntimeError, ValueError, subprocess.TimeoutExpired):
            result["reason"] = "niri_inventory_unavailable_or_changed"
            return result
        result["samples"].append(sample)
        if index < 3:
            time.sleep(0.5)

    samples = result["samples"]
    if any(s["active_output_count"] == 0 for s in samples):
        result["reason"] = "no_active_outputs"
    elif any(s["observed_production_layer_count"] == 0 for s in samples):
        result["reason"] = "existing_production_layer_not_observed_consistently"
    elif len({s["active_output_count"] for s in samples}) != 1:
        result["reason"] = "active_outputs_changed_during_observation"
    elif any(s["observed_keyboard_mode_counts"]["unknown"] for s in samples):
        result["reason"] = "unrecognized_keyboard_mode"
    elif all(
        s["outputs_with_exactly_one_layer"] == s["active_output_count"]
        and s["outputs_missing_layer"] == 0
        and s["outputs_with_duplicate_layers"] == 0
        and s["layers_on_unrecognized_or_inactive_outputs"] == 0
        for s in samples
    ):
        result["status"] = "pass"
    elif all(
        s["outputs_with_duplicate_layers"] > 0
        or s["layers_on_unrecognized_or_inactive_outputs"] > 0
        for s in samples
    ):
        result["status"] = "failed"
        result["reason"] = "stable_duplicate_or_unexpected_layer_inventory"
    else:
        result["reason"] = "production_layer_inventory_unstable"
    return result


def publish(report, path):
    for attempt in range(4):
        pushed = subprocess.run(
            ["git", "push", "origin", "HEAD:refs/heads/dev"],
            capture_output=True, timeout=50
        )
        if pushed.returncode == 0:
            return
        if attempt == 3:
            raise RuntimeError("Report push rejected; unpublished local report remains")
        if not clean() or git("diff-tree", "--no-commit-id", "--name-only",
                              "-r", "HEAD") != str(path):
            raise RuntimeError("Only one unpublished sanitized report may be rebased")
        old_parent = git("rev-parse", "HEAD^")
        remote = fetch()
        audit(remote)
        if subprocess.run(
            ["git", "merge-base", "--is-ancestor", old_parent, remote],
            capture_output=True, timeout=10
        ).returncode:
            raise RuntimeError("Unrelated remote history; report remains local")
        git("rebase", "--onto", remote, old_parent)
        if not clean() or git("diff-tree", "--no-commit-id", "--name-only",
                              "-r", "HEAD") != str(path):
            raise RuntimeError("Unexpected changes to unpublished report")
        report["publication_parent_sha"] = git("rev-parse", "HEAD^")
        path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        git("add", "--", str(path))
        if git("diff", "--cached", "--name-only") != str(path):
            raise RuntimeError("Unexpected staged files before report amend")
        git("commit", "--amend", "--no-edit")


def main():
    if sys.argv[1:] != ["--observe-current-session"]:
        raise RuntimeError("Usage: ... --observe-current-session (read-only desktop)")
    if Path.cwd().resolve() != Path(git("rev-parse", "--show-toplevel")).resolve():
        raise RuntimeError("Run at the root of the Hadalis checkout")
    if git("symbolic-ref", "--quiet", "--short", "HEAD") != "dev" or not clean():
        raise RuntimeError("Requires a clean dev checkout")
    read_url = git("remote", "get-url", "origin")
    push_urls = git("remote", "get-url", "--push", "--all", "origin").splitlines()
    if read_url not in ALLOWED_ORIGINS or (
        len(push_urls) != 1 or push_urls[0] not in ALLOWED_ORIGINS
    ):
        raise RuntimeError("Unexpected origin remote")
    remote = fetch()
    audit(remote)
    git("merge", "--ff-only", remote)
    if not clean():
        raise RuntimeError("Working tree changed before observation")
    source = git("rev-parse", "HEAD")
    niri = shutil.which("niri")
    if not niri:
        measured = {
            "status": "inconclusive", "reason": "niri_cli_unavailable",
            "scope": "existing_production_layer_inventory_only",
            "samples": [],
        }
    else:
        measured = observe(niri)
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    slug = secrets.token_hex(4)
    report = {
        "kind": "wull_existing_production_layer_read_only",
        "source_sha": source,
        "status": measured["status"],
        "observation": measured,
        "existing_running_shell_source": "unverified",
        "wull_runtime_and_pointer_pass_through": "not_tested",
        "canonical_validation": "not_run",
        "user_configuration": "not_read_or_modified",
    }
    print("EXACT_SOURCE_SHA:", source, flush=True)
    print("EXISTING_LAYER_RESULT:", report["status"], flush=True)
    print("EXISTING_LAYER_REASON:", measured.get("reason"), flush=True)
    if git("rev-parse", "HEAD") != source or not clean():
        raise RuntimeError("Working tree changed during read-only observation")
    latest = fetch()
    audit(latest)
    git("merge", "--ff-only", latest)
    if not clean():
        raise RuntimeError("Working tree changed before report publication")
    report["publication_parent_sha"] = git("rev-parse", "HEAD")
    path = Path("docs") / (
        "wull-existing-layer-" + stamp + "-" + slug
        + "-" + source[:12] + ".json"
    )
    if path.exists():
        raise RuntimeError("Refusing to overwrite a prior report")
    path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    git("add", "--", str(path))
    if (git("diff", "--cached", "--name-only") != str(path)
            or git("diff", "--name-only")
            or git("ls-files", "--others", "--exclude-standard")):
        raise RuntimeError("Unexpected local changes before report commit")
    git("commit", "-m", "test(wull): publish read-only live layer inventory",
        "--", str(path))
    publish(report, path)
    print("REPORT_PUBLISHED:", path, flush=True)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, ValueError, OSError, subprocess.TimeoutExpired) as error:
        print("STOP:", error, file=sys.stderr)
        sys.exit(1)
