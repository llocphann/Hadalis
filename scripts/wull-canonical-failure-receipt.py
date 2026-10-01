#!/usr/bin/env python3
"""Publish only allowlisted failed-check names from the previous local Wull run."""
import datetime as dt
import json
import os
from pathlib import Path
import re
import secrets
import subprocess
import sys

TEST_SOURCE = "6d7eb8d2a83143b5437c4e1d0a2a0570f7048870"
RUN_STARTED = "2026-10-01T11:57:41+00:00"
REQUIRED_FIX = "7bb1f99b0cd932c7bb0e50888ae19c982d7e1ec3"
ORIGINAL_RECEIPT = (
    "docs/wull-manual-qualification-"
    "20261001T115741Z-f9da4543-6d7eb8d2a831.json"
)
ALLOWED_CHECKS = {
    "host tool preflight",
    "build and baseline shell syntax",
    "tracked shell/package syntax",
    "tracked Python syntax",
    "tracked JSON syntax",
    "tracked JavaScript syntax",
    "tracked Fish syntax",
    "translation catalog structure",
    "translation source parity",
    "IPC registry freshness",
    "documentation contracts",
    "QML parser capability",
    "QML/startup project guards",
    "Make contract: prefix/path relocation",
    "Make contract: package metadata",
    "Make contract: package lifecycle hooks",
    "source tree remains clean after validation",
}
ALLOWED_GROUPS = {
    "translations / documentation drift",
    "QML / module resolution / Connected Perimeter",
    "install / relocation / packaging",
    "service lifecycle / timeout / recovery",
    "tracked source syntax",
    "other regression contracts",
}
ALLOWED_URLS = {
    "https://github.com/llocphann/Hadalis",
    "https://github.com/llocphann/Hadalis.git",
    "git@github.com:llocphann/Hadalis",
    "git@github.com:llocphann/Hadalis.git",
    "ssh://git@github.com/llocphann/Hadalis",
    "ssh://git@github.com/llocphann/Hadalis.git",
}


def git(*args):
    result = subprocess.run(["git", *args], text=True, capture_output=True)
    if result.returncode:
        raise RuntimeError("Git operation failed: " + " ".join(args))
    return result.stdout.strip()


def clean():
    return not git("status", "--porcelain=v1", "--untracked-files=all")


def safe_label(label):
    if label in ALLOWED_CHECKS:
        return label
    match = re.fullmatch(
        r"(Python regression|shell regression): "
        r"((?:[a-zA-Z0-9_-]+/)*test-[a-zA-Z0-9_.-]+\.(?:py|sh))",
        label,
    )
    if not match:
        return None
    file_path = match.group(2)
    if ".." in file_path or file_path.startswith("/"):
        return None
    return label


def read_summary(log_file):
    # Read only the bounded tail containing the validator's final summary;
    # raw log bytes never leave this machine or enter the Git report.
    with log_file.open("rb") as source:
        source.seek(0, os.SEEK_END)
        size = source.tell()
        source.seek(max(0, size - 262144))
        tail = source.read(262144).decode("utf-8", errors="replace")
    if "HADALIS VALIDATION SUMMARY" not in tail:
        raise RuntimeError("Validator log does not contain a final summary")
    lines = [line.strip() for line in tail.rsplit(
        "HADALIS VALIDATION SUMMARY", 1
    )[-1].splitlines()]
    if "Result: FAIL" not in lines:
        raise RuntimeError("Previous validator summary does not say FAIL")
    if "Exact SHA: " + TEST_SOURCE not in lines:
        raise RuntimeError("Validator log SHA differs from the published report")

    numeric = {}
    for field in ("Checks run", "Passed", "Failed", "Skipped"):
        matches = [
            int(line.removeprefix(field + ": "))
            for line in lines
            if re.fullmatch(re.escape(field) + r": [0-9]{1,5}", line)
        ]
        if len(matches) != 1:
            raise RuntimeError("Missing or ambiguous validator summary counters")
        numeric[field.lower().replace(" ", "_")] = matches[0]

    failed_checks = []
    unknown_count = 0
    groups = []
    section = ""
    for line in lines:
        if line == "Failed checks:":
            section = "checks"
            continue
        if line == "Primary failure groups:":
            section = "groups"
            continue
        if line in ("Skipped checks:", "Skipped checks: none"):
            section = ""
        if not line.startswith("- "):
            continue
        entry = line[2:]
        if section == "checks":
            match = re.fullmatch(r"(.{1,190}) \(exit ([0-9]{1,3})\)", entry)
            if match:
                label = safe_label(match.group(1))
                if label is not None:
                    failed_checks.append({
                        "check": label, "exit_code": int(match.group(2))
                    })
                    continue
            unknown_count += 1
        elif section == "groups" and entry in ALLOWED_GROUPS:
            groups.append(entry)

    if numeric["failed"] == 0:
        raise RuntimeError("Previous validator summary does not record failures")
    if len(failed_checks) + unknown_count != numeric["failed"]:
        raise RuntimeError("Validator summary check counts do not reconcile")
    return {
        "validator_result": "failed",
        "validator_source_sha": TEST_SOURCE,
        "checks_run": numeric["checks_run"],
        "checks_passed": numeric["passed"],
        "checks_failed": numeric["failed"],
        "checks_skipped": numeric["skipped"],
        "failed_checks": failed_checks,
        "redacted_failed_check_count": unknown_count,
        "failure_groups": groups,
    }


def select_log():
    home = Path(os.environ.get(
        "XDG_STATE_HOME", str(Path.home() / ".local/state")
    )) / "hadalis"
    matches = []
    for summary_file in home.glob(
        "wull-qualification-*/sanitized-summary.json"
    ):
        try:
            payload = json.loads(summary_file.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            continue
        if (
            payload.get("source_sha") != TEST_SOURCE
            or payload.get("started_utc") != RUN_STARTED
            or not any(
                check.get("check") == "canonical-maintainer-validator"
                and check.get("exit_code") == 1
                for check in payload.get("checks", [])
            )
        ):
            continue
        validator_log = summary_file.parent / "maintainer-validation.private.log"
        if validator_log.is_file():
            matches.append(validator_log)
    if len(matches) != 1:
        raise RuntimeError(
            "Matching prior private Wull validator log unavailable or ambiguous"
        )
    return matches[0]


def verify_remote():
    remote = git("ls-remote", "origin", "refs/heads/dev")
    fields = remote.split()
    if len(fields) != 2 or fields[1] != "refs/heads/dev":
        raise RuntimeError("Cannot verify origin/dev")
    return fields[0]


def main():
    os.umask(0o077)
    if Path.cwd().resolve() != Path(git("rev-parse", "--show-toplevel")).resolve():
        raise RuntimeError("Run from the Hadalis repository root")
    if git("symbolic-ref", "--quiet", "--short", "HEAD") != "dev" or not clean():
        raise RuntimeError("Require a clean checkout on dev")
    urls = git("remote", "get-url", "--push", "--all", "origin").splitlines()
    if git("remote", "get-url", "origin") not in ALLOWED_URLS or (
        len(urls) != 1 or urls[0] not in ALLOWED_URLS
    ):
        raise RuntimeError("Unexpected origin URL")
    # The historical source is intentionally older than the current code.
    if subprocess.run(
        ["git", "merge-base", "--is-ancestor", REQUIRED_FIX, "HEAD"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    ).returncode:
        raise RuntimeError("Local dev does not contain the reviewed lifecycle fix")

    data = read_summary(select_log())
    data.update({
        "kind": "wull_prior_canonical_failure_classification",
        "original_receipt": ORIGINAL_RECEIPT,
        "diagnostic_method": "allowlisted_previous_validator_summary_only",
        "runtime_lifecycle_fix_not_revalidated": True,
        "private_logs": "retained_locally",
        "created_utc": dt.datetime.now(
            dt.timezone.utc
        ).isoformat(timespec="seconds"),
    })
    remote = verify_remote()
    git("fetch", "--quiet", "origin",
        "refs/heads/dev:refs/remotes/origin/dev")
    if git("rev-parse", "refs/remotes/origin/dev") != remote:
        raise RuntimeError("Remote changed during verification")
    git("merge", "--ff-only", remote)
    if not clean():
        raise RuntimeError("Checkout changed; refusing report publication")

    identifier = dt.datetime.now(dt.timezone.utc).strftime(
        "%Y%m%dT%H%M%SZ"
    ) + "-" + secrets.token_hex(4)
    target = Path("docs") / (
        "wull-canonical-failures-" + identifier + "-"
        + TEST_SOURCE[:12] + ".json"
    )
    if target.exists():
        raise RuntimeError("Refusing to overwrite an existing report")
    target.write_text(
        json.dumps(data, indent=2) + "\n", encoding="utf-8"
    )
    git("add", "--", str(target))
    if git("diff", "--cached", "--name-only") != str(target):
        raise RuntimeError("Unexpected staged changes")
    if git("diff", "--name-only") or git(
        "ls-files", "--others", "--exclude-standard"
    ):
        raise RuntimeError("Unexpected local changes; refusing commit")
    if verify_remote() != remote:
        raise RuntimeError("Remote moved; report remains local")
    git("commit", "-m", "test(wull): classify prior canonical failure safely",
        "--", str(target))
    git("push", "origin", "HEAD:refs/heads/dev")
    print("REPORT_PUBLISHED:", target)
    print("TEST_SOURCE_SHA:", TEST_SOURCE)
    print("FAILED_CHECKS_COUNT:", data["checks_failed"])
    print("REPORT_COMMIT:", git("rev-parse", "HEAD"))


if __name__ == "__main__":
    try:
        if len(sys.argv) == 2 and sys.argv[1] == "--self-test":
            fixture = (
                "HADALIS VALIDATION SUMMARY\n"
                "Exact SHA: " + TEST_SOURCE + "\n"
                "Result: FAIL\nChecks run: 4\nPassed: 2\nFailed: 2\n"
                "Skipped: 0\nFailed checks:\n"
                "  - QML/startup project guards (exit 1)\n"
                "  - Python regression: scripts/test-wull-production-contract.py"
                " (exit 1)\nPrimary failure groups:\n"
                "  - QML / module resolution / Connected Perimeter\n"
                "Skipped checks: none\n"
            )
            import tempfile
            with tempfile.TemporaryDirectory() as folder:
                sample = Path(folder) / "sample.log"
                sample.write_text(fixture)
                found = read_summary(sample)
                assert found["checks_failed"] == 2
                assert len(found["failed_checks"]) == 2
            print("PASS: bounded allowlist classifier self-test")
        elif len(sys.argv) != 1:
            raise RuntimeError("Usage: python3 scripts/wull-canonical-failure-receipt.py")
        else:
            main()
    except (RuntimeError, OSError, ValueError, subprocess.CalledProcessError) as error:
        print("STOP:", error, file=sys.stderr)
        sys.exit(1)
