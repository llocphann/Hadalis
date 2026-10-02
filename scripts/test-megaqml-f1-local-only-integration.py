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
    assert run("git", "init", "-q", "-b", "dev", str(checkout)).returncode == 0
    assert run("git", "init", "--bare", "-q", str(remote)).returncode == 0
    assert run("git", "add", ".", cwd=checkout).returncode == 0
    assert run("git", "-c", "user.name=Fixture", "-c",
               "user.email=fixture@example.invalid", "commit",
               "-qm", "fake-only", cwd=checkout).returncode == 0
    assert run("git", "remote", "add", "origin", str(remote),
               cwd=checkout).returncode == 0
    assert run("git", "push", "-q", "origin", "dev", cwd=checkout).returncode == 0
    pin = run("git", "rev-parse", "HEAD", cwd=checkout).stdout.decode().strip()

    # Mock all test commands but run the REAL final local report classifier.
    # In this minimal checkout, optional Qt/Quickshell tests are SKIPPED or
    # unqualified, and no fake race repeat emits an 8/8 evidence marker.
    (fake / "python3").write_text(
        "#!/bin/sh\n"
        'if [ "$1" = "-B" ] && '
        '[ "$2" = "scripts/megaqml-f1-local-matrix-classify.py" ]; then\n'
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
print("PASS local-only rejects synthetic skipped/missing-race matrix without git writes")
