#!/usr/bin/env python3
"""Exercise worker health across a failed discovery and a recovered poll."""
from concurrent.futures import Future
import json
import os
from pathlib import Path
import sys
import tempfile
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from automation.worker import daemon as worker


class StopLoop(BaseException):
    pass


class ImmediateExecutor:
    def __init__(self, max_workers):
        assert 1 <= max_workers <= 4

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return False

    def submit(self, fn, *args, **kwargs):
        future = Future()
        try:
            future.set_result(fn(*args, **kwargs))
        except Exception as exc:
            future.set_exception(exc)
        return future


def run_case(metadata_failure=False):
    with tempfile.TemporaryDirectory() as tmp, patch.dict(os.environ, {"XDG_STATE_HOME": tmp}):
        clock = [1000]
        fetches = []
        observed = []
        private_canary = "private-network-credential-canary"
        original_write = worker._write

        def write(path, data):
            original_write(path, data)
            if path.name == "pool.json":
                observed.append(json.loads(path.read_text()))

        def fetch():
            index = len(fetches)
            fetches.append(index)
            if index == (1 if metadata_failure else 0):
                raise RuntimeError(private_canary)

        def sleep(_seconds):
            clock[0] += 1
            if len(observed) == 4:
                raise StopLoop()

        with patch.object(sys, "argv", ["worker"]), \
             patch.object(worker, "POLL", 1), \
             patch.object(worker, "ThreadPoolExecutor", ImmediateExecutor), \
             patch.object(worker, "_write", side_effect=write), \
             patch.object(worker.time, "time", side_effect=lambda: clock[0]), \
             patch.object(worker.time, "sleep", side_effect=sleep), \
             patch.object(worker, "fetch_dev", side_effect=fetch), \
             patch.object(worker, "pending_paths", return_value=[worker.QUEUE + "/JOB-failed.json"] if metadata_failure else []), \
             patch.object(worker, "result_exists", return_value=False), \
             patch.object(worker, "process_job", side_effect=RuntimeError(private_canary)) as process:
            try:
                worker.main()
            except StopLoop:
                pass
            else:
                raise AssertionError("worker loop did not stop at the bounded test boundary")
        assert len(fetches) == 4
        assert private_canary not in json.dumps(observed)
        errors = [p["last_error"] for p in observed]
        if metadata_failure:
            assert "metadata" in errors[1] and "Git discovery" in errors[2]
            assert "metadata" in errors[3], "Git recovery erased an unrelated job failure"
        else:
            assert errors[0] is None and "Git discovery" in errors[1]
            assert errors[2:] == [None, None], "recovered discovery kept a stale error"
            process.assert_not_called()


if __name__ == "__main__":
    run_case()
    run_case(metadata_failure=True)
    print("PASS: recovered worker discovery clears its stale health error, retains independent metadata failures and protects private exception details")
