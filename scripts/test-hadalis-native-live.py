#!/usr/bin/env python3
"""Opt-in real Desktop acceptance. Never edits repository/profile production data."""
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))


def main():
    if os.environ.get("HADALIS_TEST_NATIVE_LIVE")!="1":
        print("SKIP: real Desktop acceptance requires HADALIS_TEST_NATIVE_LIVE=1");return
    from automation.manager import store,model
    outer=store.state_dir()/"acceptance"/f"live-{time.time_ns()}";outer.mkdir(parents=True,mode=0o700)
    os.environ.update(XDG_CONFIG_HOME=str(outer/"config"),XDG_STATE_HOME=str(outer/"state"))
    ids=["profile-native-a","profile-native-b"]
    def configure(c,s):
        c["profiles"]=[];s["profiles"]={};s["engine_version"]=2
        for pid in ids:
            p=model.new_profile(pid);p.update(id=pid,enabled=True,requires_github=False,
                project_name=os.environ.get("HADALIS_TEST_PROJECT","Hadalis Cloud"),stop_on_done=True,
                prompt="This is a harmless Automation concurrency acceptance probe. Do not call tools, edit files, access private data or perform any action. Write thirty short numbered sentences about arithmetic, then finish with HADALIS_LOOP:DONE. The objective is complete after that reply.")
            c["profiles"].append(p);s["profiles"][pid]=store.profile_state()
            if pid==ids[0] and os.environ.get("HADALIS_TEST_GITHUB")=="1":
                p.update(requires_github=True,prompt="This is a read-only connector acceptance probe. Explicitly use the GitHub connector to read the CURRENT dev HEAD of llocphann/Hadalis. Report its full SHA. Do not edit files, dispatch jobs, write comments or mutate any state. Finish with HADALIS_LOOP:DONE after verifying access.")
            s["profiles"][pid].update(desired="run",status="scheduled",request="initial")
    store.change(configure)
    script="""import {connectNative} from './automation/chat_bridge/native_adapter.mjs';
const c=await connectNative();try {console.log(JSON.stringify(await c.page.evaluate(ids=>({
title:document.title,heading:document.querySelector('h1')?.textContent,
receipts:ids.map(id=>{const r=window.__hadalisReceipts?.get(id);return r ? {
user_message_id:id,dispatched:r.dispatched,dispatched_at_ms:r.dispatched_at_ms,completed_at_ms:r.completed_at_ms,conversation_id:r.conversation_id} : null})}),JSON.parse(process.argv[1]))));}finally{await c.browser.close();}"""
    def observe(uids):
        r=subprocess.run(["node","--input-type=module","-e",script,json.dumps(uids)],cwd=ROOT,capture_output=True,text=True,timeout=20)
        if r.returncode:raise RuntimeError("Desktop observation unavailable")
        return json.loads(r.stdout)
    before=observe([])
    log=(outer/"scheduler.log").open("w")
    process=subprocess.Popen([sys.executable,"-m","automation.manager.daemon"],cwd=ROOT,stdout=log,stderr=log,start_new_session=True)
    restarted=False;uids=[];parallel=False;deadline=time.monotonic()+180
    try:
        while time.monotonic()<deadline:
            if process.poll() is not None:raise RuntimeError("Acceptance scheduler exited")
            _,state,_=store.read_snapshot();items=[state["profiles"][p] for p in ids]
            if not uids and all(i["pending"] for i in items):
                parallel=True;uids=[i["pending"]["user_message_id"] for i in items]
            if uids and not restarted:
                observations=observe(uids)
                if all(r and r.get("dispatched") for r in observations["receipts"]):
                    store._write(outer/"before-restart.json",state)
                    os.killpg(process.pid,signal.SIGTERM);process.wait(timeout=10)
                    process=subprocess.Popen([sys.executable,"-m","automation.manager.daemon"],cwd=ROOT,stdout=log,stderr=log,start_new_session=True)
                    restarted=True
            if all(i["status"]=="completed" for i in items):
                observations=observe(uids)
                assert parallel and restarted and len(set(uids))==2
                assert all(i["prompts_sent"]==1 and i["iterations"]==1 for i in items),items
                assert len({i["session"]["conversation_id"] for i in items})==2
                receipts=observations["receipts"]
                overlap=all(r and r.get("dispatched_at_ms") and r.get("completed_at_ms") for r in receipts) and max(r["dispatched_at_ms"] for r in receipts)<min(r["completed_at_ms"] for r in receipts)
                store._write(outer/"result.json",{"profiles":ids,"user_message_ids":uids,"parallel_pending":parallel,
                    "server_stream_overlap":bool(overlap),"restart_without_duplicate":restarted,"before_ui":before,
                    "after_ui":observations,"runtime":state,"source_sha":subprocess.check_output(["git","rev-parse","HEAD"],cwd=ROOT,text=True).strip()})
                print("PASS: two real independent profiles completed after scheduler restart with one prompt each")
                print("Server stream overlap:",bool(overlap));print("Private evidence:",outer)
                return
            time.sleep(.5)
        store._write(outer/"timeout.json",store.read_snapshot()[1]);raise RuntimeError("Acceptance timed out; pending receipts preserved")
    finally:
        if process.poll() is None:os.killpg(process.pid,signal.SIGTERM);process.wait(timeout=10)
        log.close()


if __name__=="__main__":main()
