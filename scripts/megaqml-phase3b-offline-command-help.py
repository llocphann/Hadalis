#!/usr/bin/env python3
"""Owner-only opt-in offline help fingerprints; NEVER run account operations."""
import json
import os
from pathlib import Path
import runpy
import subprocess
import sys

HERE = Path(__file__).resolve().parent
CATALOG = runpy.run_path(str(HERE / "megaqml-phase3b-offline-help-catalog.py"),
                         run_name="command_help_import")
BOUNDARY = CATALOG["BOUNDARY"]
PRIVATE = CATALOG["PRIVATE"]
FIELDS = {
    "df": ("usage", "short_h"),
    "sync": ("usage", "output_cols", "col_separator", "show_handles"),
    "transfers": ("usage", "output_cols", "col_separator", "summary"),
}
REASONS = frozenset({
    "explicit_acknowledgment_required", "do_not_run_as_root",
    "missing_host_dependency", "vendor_binary_mismatch",
    "private_lib_mount_validation_failed", "executor_not_package_owned",
    "sandbox_setup_unavailable", "sandbox_process_unavailable",
    "bounded_timeout", "bounded_output_cap", "sandbox_supervisor_error",
    "sandbox_supervisor_output_invalid", "command_help_nonzero",
    "command_help_unrecognized", "help_surface_partial",
    "help_surface_observed",
})

def empty():
    return {name: {flag: False for flag in flags}
            for name, flags in FIELDS.items()}

def valid(commands):
    return (type(commands) is dict and set(commands) == set(FIELDS)
            and all(type(commands[name]) is dict
                    and set(commands[name]) == set(flags)
                    and all(type(v) is bool for v in commands[name].values())
                    and (commands[name]["usage"]
                         or not any(commands[name].values()))
                    for name, flags in FIELDS.items()))

def summary(reason, commands=None):
    if commands is None:
        commands = empty()
    assert reason in REASONS and valid(commands)
    if reason == "help_surface_observed":
        assert all(row["usage"] for row in commands.values())
        state = "HELP_SURFACES_OBSERVED_OFFLINE"
    elif reason == "help_surface_partial":
        assert any(row["usage"] for row in commands.values())
        state = "HELP_PARTIAL_OFFLINE"
    elif reason in {
            "command_help_nonzero", "command_help_unrecognized",
            "bounded_timeout", "bounded_output_cap",
            "sandbox_supervisor_error", "sandbox_supervisor_output_invalid"}:
        state = "UNQUALIFIED"
    else:
        state = "BLOCKED"
    return json.dumps({
        "phase": "megaqml_phase3b_offline_command_help",
        "state": state, "reason": reason, "commands": commands,
        "network_available": False, "account_used": False,
        "command_options_qualified": False, "help_parsers_qualified": False,
        "server_identity_qualified": False, "live_capabilities_unlocked": False,
    }, sort_keys=True, separators=(",", ":"))

INNER = r'''
import json,os,re,selectors,signal,subprocess,sys,time
FIELDS={
 "df":("usage","short_h"),
 "sync":("usage","output_cols","col_separator","show_handles"),
 "transfers":("usage","output_cols","col_separator","summary")}
TOKENS={
 "df":{"short_h":"-h"},
 "sync":{"output_cols":"--output-cols","col_separator":"--col-separator",
         "show_handles":"--show-handles"},
 "transfers":{"output_cols":"--output-cols","col_separator":"--col-separator",
              "summary":"--summary"}}
def empty():
 return {n:dict.fromkeys(fields,False) for n,fields in FIELDS.items()}
def inspect(name,raw):
 lines=[s.strip() for s in raw.decode("utf-8","replace").splitlines()
        if len(s)<=256]
 if not any(re.fullmatch(r"Usage:\s*"+name+r"(?:\s+.*)?",s,re.I) for s in lines):
  return dict.fromkeys(FIELDS[name],False)
 result=dict.fromkeys(FIELDS[name],False)
 result["usage"]=True
 for key,token in TOKENS[name].items():
  pat=re.compile(r"(?<![\w-])"+re.escape(token)+r"(?![\w-])")
  result[key]=any(pat.search(s) is not None for s in lines)
 return result
def bounded(args,until):
 p=subprocess.Popen(args,stdin=subprocess.DEVNULL,stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,close_fds=True,
                    start_new_session=True)
 sel=selectors.DefaultSelector()
 data={p.stdout.fileno():bytearray(),p.stderr.fileno():bytearray()}
 for stream in (p.stdout,p.stderr):
  os.set_blocking(stream.fileno(),False)
  sel.register(stream,selectors.EVENT_READ)
 reason=None
 try:
  while sel.get_map() or p.poll() is None:
   if time.monotonic()>=until:
    reason="bounded_timeout";break
   for item,_ in sel.select(timeout=.06):
    block=os.read(item.fileobj.fileno(),1024)
    if not block:sel.unregister(item.fileobj)
    else:
     data[item.fileobj.fileno()].extend(block)
     if sum(map(len,data.values()))>12288:
      reason="bounded_output_cap";break
   if reason:break
  if reason:
   if p.poll() is None:
    try:os.killpg(p.pid,signal.SIGKILL)
    except ProcessLookupError:pass
   p.wait(timeout=1)
   return None,b"",reason
  return p.wait(timeout=1),bytes(data[p.stdout.fileno()]),None
 finally:
  sel.close()
  for stream in (p.stdout,p.stderr):stream.close()
  if p.poll() is None:
   try:os.killpg(p.pid,signal.SIGKILL)
   except ProcessLookupError:pass
   p.wait(timeout=1)
def emit(reason,commands):
 assert reason in {"help_surface_observed","help_surface_partial",
                   "command_help_nonzero","command_help_unrecognized",
                   "bounded_timeout","bounded_output_cap",
                   "sandbox_supervisor_error"}
 print(json.dumps({"reason":reason,"commands":commands},sort_keys=True))
def main():
 result=empty()
 try:
  if sys.argv[1:]==["--self-test"]:
   assert inspect("df",b"Usage: df [-h]\n -h Human readable\n")=={
      "usage":True,"short_h":True}
   assert inspect("sync",b"Usage: sync [x]\n --output-cols=X\n"
       b" --col-separator=X\n --show-handles\n")=={
       "usage":True,"output_cols":True,"col_separator":True,"show_handles":True}
   assert inspect("transfers",b"Usage: transfers [-a]\n --summary\n"
       b" --output-cols=X\n --col-separator=X\n")=={
       "usage":True,"output_cols":True,"col_separator":True,"summary":True}
   assert not any(inspect("df",b"NOT Usage: df [-h]\n").values())
   assert not any(inspect("sync",b"Usage: df --output-cols=X\n").values())
   emit("help_surface_observed",{
      name:dict.fromkeys(fields,True) for name,fields in FIELDS.items()})
   return
  if (len(sys.argv)!=2 or
      not sys.argv[1].startswith(("/usr/","/nix/store/")) or
      not sys.argv[1].endswith("/mega-exec")):
   raise ValueError("unapproved binary")
  executor=sys.argv[1]
  deadline=time.monotonic()+8.5
  # Only the three upstream --help branches. No df/sync/transfers actions.
  for name in FIELDS:
   rc,raw,reason=bounded([executor,name,"--help"],deadline)
   if reason:emit(reason,result);return
   if rc!=0:emit("command_help_nonzero",result);return
   result[name]=inspect(name,raw)
  if all(row["usage"] for row in result.values()):
   emit("help_surface_observed",result)
  elif any(row["usage"] for row in result.values()):
   emit("help_surface_partial",result)
  else:emit("command_help_unrecognized",result)
 except BaseException:
  emit("sandbox_supervisor_error",empty())
main()
'''
def accept_inner(raw):
    try:
        value=json.loads(raw.decode("utf-8"))
        if (type(value) is not dict or set(value)!={"reason","commands"}
                or value["reason"] not in REASONS
                or not valid(value["commands"])):
            return None
        reason=value["reason"]
        usages=[row["usage"] for row in value["commands"].values()]
        if reason=="help_surface_observed" and not all(usages):
            return None
        if reason=="help_surface_partial" and (
                not any(usages) or all(usages)):
            return None
        if reason=="command_help_unrecognized" and any(usages):
            return None
        if reason=="sandbox_supervisor_error" and any(
                any(row.values()) for row in value["commands"].values()):
            return None
        return value
    except (UnicodeDecodeError,ValueError,TypeError):
        return None

def self_test():
    p=subprocess.run([sys.executable,"-I","-S","-c",INNER,"--self-test"],
                     stdin=subprocess.DEVNULL,capture_output=True,
                     timeout=4,check=True)
    event=accept_inner(p.stdout)
    assert event and event["reason"]=="help_surface_observed"
    assert accept_inner(b"PRIVATE_CANARY") is None
    assert accept_inner(p.stdout+b"PRIVATE_CANARY") is None
    print("PASS MegaQML isolated command-help inert self-test")

def main():
    if sys.argv[1:]==["--self-test"]:
        self_test();return 0
    if sys.argv[1:]!=["--acknowledge-disposable-offline-command-help"]:
        print(summary("explicit_acknowledgment_required"));return 20
    if os.geteuid()==0:
        print(summary("do_not_run_as_root"));return 20
    allowed=BOUNDARY["allowed_binary"]
    version,server,executor,bwrap,python,true=(
        allowed("mega-version"),allowed("mega-cmd-server"),
        allowed("mega-exec"),allowed("bwrap"),allowed("python3"),
        allowed("true"))
    if not all((version,server,executor,bwrap,python,true)):
        print(summary("missing_host_dependency"));return 20
    pair=[(version[0],version[1]),(server[0],server[1])]
    if (version[0].parent!=server[0].parent or
            version[1].parent!=server[1].parent):
        print(summary("vendor_binary_mismatch"));return 20
    # A failed metadata reader must NEVER fall through to vendor execution.
    try:
        private_ok=PRIVATE["verify_private_lib_mount"](pair)
    except (OSError,ValueError,RuntimeError):
        private_ok=False
    if not private_ok:
        print(summary("private_lib_mount_validation_failed"));return 20
    try:
        executor_ok=CATALOG["package_executor_owned"](pair,executor)
    except (OSError,ValueError,RuntimeError):
        executor_ok=False
    if not executor_ok:
        print(summary("executor_not_package_owned"));return 20
    def sandbox(payload):
        return BOUNDARY["bwrap_command"](
            bwrap[0],payload,version[0].parent,private_megacmd_lib=True)
    try:
        bounded=BOUNDARY["bounded_process"]
        rc,_,_,blocked=bounded(sandbox([true[0]]))
        if blocked or rc!=0:
            print(summary("sandbox_setup_unavailable"));return 20
        rc,out,_,blocked=bounded(sandbox([
            python[0],"-I","-S","-c",INNER,str(executor[0])]))
    except (OSError,ValueError,RuntimeError,subprocess.TimeoutExpired):
        print(summary("sandbox_process_unavailable"));return 20
    if blocked:
        print(summary(blocked));return 21
    if rc!=0:
        print(summary("sandbox_supervisor_error"));return 21
    event=accept_inner(out)
    if event is None:
        print(summary("sandbox_supervisor_output_invalid"));return 21
    print(summary(event["reason"],event["commands"]))
    return 0 if event["reason"]=="help_surface_observed" else 21
if __name__=="__main__":
    sys.exit(main())
