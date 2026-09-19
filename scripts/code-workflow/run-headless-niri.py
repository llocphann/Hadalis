#!/usr/bin/env python3
"""Run the unchanged CDE probe in Niri hosted by an owned headless Sway."""
import argparse
from hashlib import sha256
import json
import os
from pathlib import Path
import shlex
import signal
import subprocess
import sys
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--work-dir', type=Path, required=True)
    parser.add_argument('--sway', type=Path, required=True)
    parser.add_argument('--pointer', type=Path, required=True)
    args = parser.parse_args()
    directory = args.work_dir.resolve()
    directory.mkdir(parents=True, exist_ok=False)
    runtime = directory/'runtime'
    runtime.mkdir(mode=0o700)
    display = directory/'display.json'
    capture = 'import os,json;open('+repr(str(display))+',"w").write(json.dumps({k:os.environ[k] for k in ("WAYLAND_DISPLAY","XDG_RUNTIME_DIR") if k in os.environ}))'
    config = directory/'sway.conf'
    config.write_text('xwayland disable\noutput HEADLESS-1 resolution 1920x1200\nseat seat0 fallback true\nexec python3 -c '+shlex.quote(capture)+'\n')
    env = os.environ.copy()
    for name in ('WAYLAND_DISPLAY','DISPLAY','SWAYSOCK','NIRI_SOCKET'):
        env.pop(name,None)
    env.update(XDG_RUNTIME_DIR=str(runtime), WLR_BACKENDS='headless',
               WLR_HEADLESS_OUTPUTS='1', WLR_RENDERER='pixman',
               XDG_CONFIG_HOME=str(directory/'config'), XDG_CACHE_HOME=str(directory/'cache'),
               LD_LIBRARY_PATH=str(args.sway.resolve().parent.parent/'lib'))
    report = {'driver_sha256':sha256(Path(__file__).read_bytes()).hexdigest(),
              'sway_binary_sha256':sha256(args.sway.read_bytes()).hexdigest(),
              'inner_report':'probe/report.json',
              'input_isolation':'Niri winit backend in an owned headless Sway; no desktop pointer ingress',
              'failure':None}
    with (directory/'host.log').open('w') as log:
        process = subprocess.Popen(['dbus-run-session','--',str(args.sway.resolve()),'-c',str(config)],
                                   env=env,stdout=log,stderr=log,start_new_session=True)
        try:
            deadline = time.monotonic()+20
            while not display.exists():
                if process.poll() is not None or time.monotonic()>deadline:
                    raise RuntimeError('Headless host startup failed')
                time.sleep(.1)
            child_env = os.environ.copy()
            child_env.update(json.loads(display.read_text()))
            command = [sys.executable,str(Path(__file__).with_name('run-runtime.py')),
                       '--work-dir',str(directory/'probe'),'--spikes','CDE','--pointer',str(args.pointer.resolve())]
            report['command'] = command
            completed = subprocess.run(command,env=child_env,timeout=240)
            if completed.returncode:
                raise RuntimeError('CDE probe failed; retain inner report')
        except Exception as exc:
            report['failure'] = repr(exc)
        finally:
            if process.poll() is None:
                os.killpg(process.pid,signal.SIGTERM)
                try: process.wait(timeout=8)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid,signal.SIGKILL)
                    process.wait(timeout=5)
    (directory/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    return int(report['failure'] is not None)


if __name__ == '__main__':
    raise SystemExit(main())
