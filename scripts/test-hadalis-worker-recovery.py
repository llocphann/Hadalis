#!/usr/bin/env python3
"""Real child processes: concurrency, durable execution, cancellation and privacy."""
import json
import os
from pathlib import Path
import sys
import tempfile
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from automation.worker import daemon as w
from automation.worker.process import bounded_run, process_identity
from automation.worker.privacy import public_result
from automation.worker.diagnostics import collect, validate
from automation.manager.store import _write


def main():
    with tempfile.TemporaryDirectory() as tmp, patch.dict(os.environ, {"XDG_STATE_HOME":tmp}):
        base=Path(tmp);workspace=base/"source";workspace.mkdir()
        def clone(commit,job):
            p=w.state_root()/"runs"/job;p.mkdir(parents=True);return p
        jobs={}
        def submit(job,script,timeout=5):
            jobs[job]=json.dumps({"id":job,"base_sha":"a"*40,"profile_id":"profile-a",
                "actions":[{"exec":{"argv":[sys.executable,"-c",script],"timeout_seconds":timeout}}]})
            return w.process_job(f"{w.QUEUE}/{job}.json",publish_now=False)
        with patch.object(w,"remote_text",side_effect=lambda p:jobs[Path(p).stem]), \
             patch.object(w,"introducing_commit",return_value="b"*40), \
             patch.object(w,"first_parent",return_value="a"*40),patch.object(w,"workspace_for",side_effect=clone):
            counter=base/"counter"
            submit("JOB-once",f"from pathlib import Path; p=Path({str(counter)!r}); p.write_text(p.read_text()+'x' if p.exists() else 'x')")
            with patch.object(w,"publish",side_effect=RuntimeError("network down")):
                w.publish_receipt("JOB-once")
            assert counter.read_text()=="x"
            assert w.load_receipt("JOB-once")["phase"]=="finished"
            w.process_job(f"{w.QUEUE}/JOB-once.json",publish_now=False)
            w.cleanup()
            assert counter.read_text()=="x", "publish/restart must not repeat execution"
            saved=w.load_receipt("JOB-once");saved["publish_after_unix"]=0;w.save_receipt("JOB-once",saved)
            with patch.object(w,"publish") as publish:
                w.publish_receipt("JOB-once");assert publish.call_count==1
            assert counter.read_text()=="x"
            # Two independent jobs reach the same barrier before either finishes.
            def task(name):
                script=f"from pathlib import Path; import time; p=Path({str(base)!r}); (p/{name!r}).touch(); deadline=time.monotonic()+4\nwhile not ((p/'A').exists() and (p/'B').exists()):\n if time.monotonic()>deadline: raise SystemExit(3)\n time.sleep(.02)"
                return submit("JOB-parallel-"+name,script)
            with ThreadPoolExecutor(max_workers=2) as pool:
                results=list(pool.map(task,["A","B"]))
            assert all(r[1]=="passed" for r in results), results
            assert not list((w.state_root()/"runs").iterdir())
            cancel=w.state_root()/"cancellations"/"JOB-cancel";cancel.parent.mkdir();cancel.touch()
            submit("JOB-cancel",f"from pathlib import Path;Path({str(base/'unexpected')!r}).touch()")
            assert w.load_receipt("JOB-cancel")["result"]["status"]=="cancelled"
            assert not (base/"unexpected").exists()
        # Crash gap: dispatch intent survives; recovery reports ambiguity, never retries.
        orphan=w.state_root()/"runs"/"orphan";orphan.mkdir()
        w.save_receipt("JOB-crash",{"job":"JOB-crash","phase":"executing","workspace":str(orphan),"input_sha256":"digest"})
        w.cleanup();assert not orphan.exists()
        assert w.load_receipt("JOB-crash")["result"]["status"]=="indeterminate"
        # Shared resource lease protects only that resource, not unrelated jobs.
        busy=[]
        with w.resource_leases(["shell:inir"]):
            def conflict():
                try:
                    with w.resource_leases(["shell:inir"]): pass
                except RuntimeError: busy.append(True)
            t=threading.Thread(target=conflict);t.start();t.join()
            with w.resource_leases(["independent"]): pass
        assert busy
        output=bounded_run([sys.executable,"-c","import sys,time;sys.stdout.write('x'*500000);sys.stdout.flush();time.sleep(10)"],cwd=base,timeout=.2,capture=4096)
        assert output["timed_out"] and output["stdout_truncated"] and len(output["stdout"])==4096
        # Child that retains inherited pipes cannot keep a finished job alive.
        pidfile=base/"pid"
        script=f"import subprocess;from pathlib import Path;p=subprocess.Popen(['sleep','30']);Path({str(pidfile)!r}).write_text(str(p.pid))"
        started=time.monotonic();bounded_run([sys.executable,"-c",script],cwd=base,timeout=3)
        assert time.monotonic()-started<3
        pid=int(pidfile.read_text());identity=process_identity(pid)
        if identity:
            assert Path(f"/proc/{pid}/stat").read_text().rsplit(')',1)[1].split()[0]=='Z', "child escaped cleanup"
        observations=collect({"checks":["services","resources","runtime"],"units":["quickshell.service"]},workspace,base/"evidence")
        assert observations["safe_observations"] and (base/"evidence/observations.json").exists()
        public=public_result({"job":"JOB-private","status":"passed","actions":[{"stdout":"password=bad", "safe_observations":[{"content":"private"}],"evidence_id":"JOB-private:0"}]})
        assert set(public["actions"][0])=={"evidence_id"} and "password" not in json.dumps(public)
        for spec in ({"checks":["unknown"]},{"checks":["config"],"config_paths":["../etc/passwd"]}):
            try:validate(spec)
            except ValueError:pass
            else:raise AssertionError("unbounded private diagnostic allowed")
    print("PASS: worker parallel processes, publish-only retry, crash receipts, cancellation, bounded capture, cleanup, shell-down diagnostics and privacy")


if __name__=="__main__":main()
