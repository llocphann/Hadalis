#!/usr/bin/env python3
"""Fake-only opt-in help contract: no bwrap/vendor execution."""
import ast,contextlib,io,json,os,runpy,sys
from pathlib import Path
from unittest.mock import patch
root=Path(__file__).resolve().parents[1]
path=root/"scripts/megaqml-phase3b-offline-command-help.py"
source=path.read_text()
ast.parse(source)
m=runpy.run_path(str(path),run_name="command_help_fake_test")
m["self_test"]()
assert '"--acknowledge-disposable-offline-command-help"' in source
assert "private_megacmd_lib=True" in source
assert '"--help"' in m["INNER"]
assert 'bounded([executor,name,"--help"],deadline)' in m["INNER"]
assert '"mega-login"' not in source and '"mega-whoami"' not in source
assert "git push" not in source
good={"reason":"help_surface_observed","commands":{
 "df":{"usage":True,"short_h":True},
 "sync":{"usage":True,"output_cols":True,"col_separator":True,
         "show_handles":True},
 "transfers":{"usage":True,"output_cols":True,"col_separator":True,
              "summary":True}}}
enc=lambda x:json.dumps(x).encode()
assert m["accept_inner"](enc(good))==good
for case in (dict(good,raw="PRIVATE"),
             dict(good,reason="PRIVATE"),
             dict(good,commands={"df":{"usage":True}}),
             dict(good,commands={**good["commands"],
                 "df":{"usage":False,"short_h":True}}),
             dict(good,commands={**good["commands"],
                 "df":{"usage":1,"short_h":True}})):
 assert m["accept_inner"](enc(case)) is None
fake={n:(Path("/usr/bin/"+n),Path("/usr/bin/"+n))
      for n in ("mega-version","mega-cmd-server","mega-exec",
                "bwrap","python3","true")}
calls=[]
def wrap(_,payload,__ ,**kw):
 assert kw=={"private_megacmd_lib":True}
 calls.append(list(payload))
 return ["FAKE_SANDBOX"]
results=iter([(0,b"",b"",None),
              (0,enc(good),b"PRIVATE_STDERR_CANARY",None)])
def bounded(cmd):
 assert cmd==["FAKE_SANDBOX"]
 return next(results)
with patch.object(os,"geteuid",return_value=1000), \
     patch.dict(m["main"].__globals__["BOUNDARY"],{
       "allowed_binary":fake.get,"bwrap_command":wrap,
       "bounded_process":bounded}), \
     patch.dict(m["main"].__globals__["PRIVATE"],{
       "verify_private_lib_mount":lambda pair:True}), \
     patch.dict(m["main"].__globals__["CATALOG"],{
       "package_executor_owned":lambda pair,exe:True}), \
     patch.object(sys,"argv",[
       str(path),"--acknowledge-disposable-offline-command-help"]):
 out=io.StringIO()
 with contextlib.redirect_stdout(out):
  assert m["main"]()==0
 item=json.loads(out.getvalue())
 assert item["state"]=="HELP_SURFACES_OBSERVED_OFFLINE"
 assert item["commands"]==good["commands"]
 assert all(item[key] is False for key in (
  "network_available","account_used","command_options_qualified",
  "help_parsers_qualified","server_identity_qualified",
  "live_capabilities_unlocked"))
 assert "PRIVATE_STDERR_CANARY" not in out.getvalue()
assert len(calls)==2
assert calls[0]==[Path("/usr/bin/true")]
assert calls[1][:5]==[Path("/usr/bin/python3"),"-I","-S","-c",m["INNER"]]
never=[]
with patch.object(os,"geteuid",return_value=1000), \
     patch.dict(m["main"].__globals__["BOUNDARY"],{
       "allowed_binary":fake.get,"bwrap_command":wrap,
       "bounded_process":lambda x:never.append(x)}), \
     patch.dict(m["main"].__globals__["PRIVATE"],{
       "verify_private_lib_mount":lambda pair:False}), \
     patch.object(sys,"argv",[
       str(path),"--acknowledge-disposable-offline-command-help"]):
 out=io.StringIO()
 with contextlib.redirect_stdout(out):
  assert m["main"]()==20
 assert json.loads(out.getvalue())["reason"]=="private_lib_mount_validation_failed"
assert never==[]
print("PASS MegaQML isolated command-help fake-only contract")
