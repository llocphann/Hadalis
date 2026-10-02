#!/usr/bin/env python3
"""No-vendor black-box regression: local runner cannot call SKIPs a 40/40 PASS."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
RUNNER = HERE / "test-megaqml-phase2-local.sh"
CLASSIFIER = HERE / "megaqml-f1-local-matrix-classify.py"


def run(*cmd, cwd=None, env=None):
    return subprocess.run(cmd, cwd=cwd, env=env, capture_output=True,
                          timeout=80, check=False)


with tempfile.TemporaryDirectory(prefix="megaqml-f1-local-only-fake-") as raw:
    root = Path(raw)
    checkout, remote, fake = root / "source", root / "origin.git", root / "fakebin"
    checkout.mkdir()
    fake.mkdir()
    scripts = checkout / "scripts"
    scripts.mkdir()
    shutil.copyfile(RUNNER, scripts / RUNNER.name)
    shutil.copyfile(CLASSIFIER, scripts / CLASSIFIER.name)
    shutil.copyfile(HERE / "megaqml-f1-worker-descendant-guard.py",
                    scripts / "megaqml-f1-worker-descendant-guard.py")
    assert run("git", "init", "-q", "-b", "dev", str(checkout)).returncode == 0
    assert run("git", "init", "--bare", "-q", str(remote)).returncode == 0
    assert run("git", "add", ".", cwd=checkout).returncode == 0
    assert run("git", "-c", "user.name=Fixture", "-c",
               "user.email=fixture@example.invalid", "commit",
               "-qm", "fake-only", cwd=checkout).returncode == 0
    assert run("git", "remote", "add", "origin", str(remote),
               cwd=checkout).returncode == 0
    assert run("git", "push", "-q", "origin", "dev", cwd=checkout).returncode == 0
    # The worker's upstream-tracking ref is independently maintained by
    # the daemon: model it explicitly, not merely the local dev branch.
    assert run("git", "fetch", "-q", "origin",
               "refs/heads/dev:refs/remotes/origin/dev",
               cwd=checkout).returncode == 0
    pin = run("git", "rev-parse", "HEAD", cwd=checkout).stdout.decode().strip()
    # Emulate the worker's deliberate exact-SHA detached checkout. It has
    # its own private clone and never changes the fixture's dev branch.
    detached = root / "detached"
    assert run("git", "clone", "-q", str(checkout), str(detached)).returncode == 0
    assert run("git", "checkout", "-q", "--detach", pin,
               cwd=detached).returncode == 0
    assert run("git", "branch", "--show-current",
               cwd=detached).stdout == b""

    # Mock all test commands but run the REAL final local report classifier.
    # In this minimal checkout, optional Qt/Quickshell tests are SKIPPED or
    # unqualified, and no fake race repeat emits an 8/8 evidence marker.
    (fake / "python3").write_text(
        "#!/bin/sh\n"
        'if [ "$1" = "-B" ] && '
        '( [ "$2" = "scripts/megaqml-f1-local-matrix-classify.py" ] || '
        '  [ "$2" = "scripts/megaqml-f1-worker-descendant-guard.py" ] ); then\n'
        '  exec "' + sys.executable + '" "$@"\n'
        "fi\nexit 0\n"
    )
    for binary in ("bash", "node"):
        (fake / binary).write_text("#!/bin/sh\nexit 0\n")
    for binary in ("python3", "bash", "node"):
        (fake / binary).chmod(0o700)
    env = {**os.environ, "PATH": str(fake) + os.pathsep +
           os.environ.get("PATH", "")}
    result = run("/bin/bash", "scripts/test-megaqml-phase2-local.sh",
                 pin, "--local-only", cwd=checkout, env=env)
    output = result.stdout.decode("ascii", "replace")
    assert result.returncode == 21, (result.returncode, "not fail closed")
    assert "PUBLICATION=LOCAL_ONLY_NO_GIT_WRITE\n" in output
    assert "REPORT_CONTRACT_PASS=FALSE\n" in output
    assert "F1_MATRIX=UNQUALIFIED\n" in output
    assert "F1_MATRIX=QUALIFIED_SYNTHETIC_REPORT" not in output
    assert run("git", "rev-parse", "HEAD", cwd=checkout).stdout.decode().strip() == pin
    changed = run("git", "status", "--porcelain", "--untracked-files=all",
                  cwd=checkout).stdout.decode()
    assert changed.splitlines() and all(
        line.startswith("?? docs/evidence/megaqml/phase2p-")
        for line in changed.splitlines()
    ), "private report must be the only new untracked file"
    # Detached workers may run a pinned private matrix but MUST NOT use the
    # public publication path or report a skipped matrix as qualified.
    public = run("/bin/bash", "scripts/test-megaqml-phase2-local.sh",
                 pin, cwd=detached, env=env)
    assert public.returncode == 65 and public.stdout == b"WRONG_BRANCH\n"
    private = run("/bin/bash", "scripts/test-megaqml-phase2-local.sh",
                  pin, "--local-only", cwd=detached, env=env)
    private_output = private.stdout.decode("ascii", "replace")
    assert private.returncode == 21, (private.returncode, "detached false PASS")
    assert "PUBLICATION=LOCAL_ONLY_NO_GIT_WRITE\n" in private_output
    assert "REPORT_CONTRACT_PASS=FALSE\n" in private_output
    assert "F1_MATRIX=UNQUALIFIED\n" in private_output
    assert "F1_MATRIX=QUALIFIED_SYNTHETIC_REPORT" not in private_output
    assert run("git", "rev-parse", "HEAD",
               cwd=detached).stdout.decode().strip() == pin
    detached_status = run("git", "status", "--porcelain",
                          "--untracked-files=all", cwd=detached).stdout.decode()
    assert detached_status.splitlines() and all(
        line.startswith("?? docs/evidence/megaqml/phase2p-")
        for line in detached_status.splitlines()
    ), "detached private report must not be published"

    # A non-dev NAMED branch remains prohibited, even in local-only mode.
    assert run("git", "switch", "-q", "-c", "fixture-other",
               cwd=detached).returncode == 0
    named = run("/bin/bash", "scripts/test-megaqml-phase2-local.sh",
                pin, "--local-only", cwd=detached, env=env)
    assert named.returncode == 65 and named.stdout == b"WRONG_BRANCH\n"

    # A new queue/receipt after the SHA-pinned clone is allowed by the
    # actual descendant guard, without allowing false 40/40 acceptance.
    assert run("git", "switch", "-q", "--detach", pin,
               cwd=detached).returncode == 0
    queued = checkout / "automation/queue/pending/JOB-MEGAQML-FAKE-001.json"
    queued.parent.mkdir(parents=True, exist_ok=True)
    queued.write_text("{}")
    assert run("git", "add", "--", str(queued.relative_to(checkout)),
               cwd=checkout).returncode == 0
    assert run("git", "-c", "user.name=Fixture", "-c",
               "user.email=fixture@example.invalid", "commit", "-qm",
               "fake-only queue", cwd=checkout).returncode == 0
    queued_sha = run("git", "rev-parse", "HEAD",
                     cwd=checkout).stdout.decode().strip()
    assert run("git", "update-ref", "refs/remotes/origin/dev", queued_sha,
               cwd=checkout).returncode == 0
    # In the worker clone, local dev remains stale even when root's
    # origin/dev tracks the later SHA containing a fake queue addition.
    assert run("git", "rev-parse", "refs/heads/dev",
               cwd=detached).stdout.decode().strip() == pin
    reports = list((detached / "docs/evidence/megaqml").glob("phase2p-*.md"))
    assert len(reports) == 1
    reports[0].unlink()  # Only the disposable private fixture report.
    advanced = run("/bin/bash", "scripts/test-megaqml-phase2-local.sh",
                   pin, "--local-only", cwd=detached, env=env)
    assert advanced.returncode == 21, (advanced.returncode, "unexpected advancement")
    assert "F1_MATRIX=UNQUALIFIED\n" in advanced.stdout.decode()
    assert run("git", "rev-parse", "FETCH_HEAD",
               cwd=detached).stdout.decode().strip() == queued_sha

    # Even a legitimate descendant becomes unreviewed when it edits source.
    changed = checkout / "services/deferred/CloudStorageService.qml"
    changed.parent.mkdir(parents=True, exist_ok=True)
    changed.write_text("FAKE-ONLY source changed")
    assert run("git", "add", "--", str(changed.relative_to(checkout)),
               cwd=checkout).returncode == 0
    assert run("git", "-c", "user.name=Fixture", "-c",
               "user.email=fixture@example.invalid", "commit", "-qm",
               "unreviewed fake source", cwd=checkout).returncode == 0
    changed_sha = run("git", "rev-parse", "HEAD",
                      cwd=checkout).stdout.decode().strip()
    assert run("git", "update-ref", "refs/remotes/origin/dev", changed_sha,
               cwd=checkout).returncode == 0
    reports = list((detached / "docs/evidence/megaqml").glob("phase2p-*.md"))
    assert len(reports) == 1
    reports[0].unlink()
    rejected = run("/bin/bash", "scripts/test-megaqml-phase2-local.sh",
                   pin, "--local-only", cwd=detached, env=env)
    assert rejected.returncode == 68
    assert rejected.stdout == b"REMOTE_MISMATCH_UNREVIEWED\n"
    assert run("git", "rev-parse", "FETCH_HEAD",
               cwd=detached).stdout.decode().strip() == changed_sha

print("PASS local-only branch/descendant rejects unqualified and unreviewed inputs")
