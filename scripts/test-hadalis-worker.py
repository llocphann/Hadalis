#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from automation.worker.daemon import capture, safe_cwd, validate_job


def expect_error(fn) -> None:
    try:
        fn()
    except (ValueError, TypeError):
        return
    raise AssertionError("expected validation failure")


def main() -> None:
    raw = """{
      "id": "JOB-000001",
      "base_sha": "0123456789abcdef0123456789abcdef01234567",
      "actions": [
        {
          "exec": {
            "argv": ["bash", "scripts/validate-maintainer-local.sh"],
            "cwd": ".",
            "timeout_seconds": 30
          }
        }
      ]
    }"""
    job = validate_job("automation/queue/pending/JOB-000001.json", raw)
    assert job["id"] == "JOB-000001"

    expect_error(lambda: validate_job(
        "automation/queue/pending/../../escape.json", raw
    ))
    expect_error(lambda: validate_job(
        "automation/queue/pending/JOB-000001.json",
        raw.replace(
            '"argv": ["bash", "scripts/validate-maintainer-local.sh"]',
            '"argv": "bash scripts/validate-maintainer-local.sh"',
        ),
    ))

    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        (root / "inside").mkdir()
        assert safe_cwd(root, "inside") == (root / "inside").resolve()
        expect_error(lambda: safe_cwd(root, "../escape"))

    text, truncated = capture("hello")
    assert text == "hello"
    assert truncated is False

    print("PASS: Hadalis deterministic worker protocol")


if __name__ == "__main__":
    main()
