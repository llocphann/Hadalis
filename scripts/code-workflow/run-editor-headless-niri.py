#!/usr/bin/env python3
"""Run real Settings Source Editor input in Niri hosted by owned headless Sway."""
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
    parser.add_argument('--revision', default='HEAD')
    parser.add_argument('--surface', choices=('rail', 'focus'), default='rail')
    args = parser.parse_args()
    directory = args.work_dir.resolve()
    # The nested probe also creates Quickshell's by-id IPC socket below its
    # XDG_RUNTIME_DIR. Linux sockaddr_un.sun_path allows only 107 pathname
    # bytes plus NUL; a longer CI work-directory silently disables IPC.
    probe_dir = directory / 'p'
    projected_ipc = probe_dir / 'runtime/quickshell/by-id/123456789/ipc.sock'
    if len(os.fsencode(projected_ipc)) > 107:
        raise ValueError('Nested Quickshell IPC path exceeds Unix socket limit: '
                         + str(projected_ipc))
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
    mesa = env.get('HADALIS_WORKFLOW_MESA_DRIVERS', '')
    if not mesa:
        raise RuntimeError('Nix Mesa driver path is required for nested EGL')
    graphics_env = {
        '__EGL_VENDOR_LIBRARY_FILENAMES':
            str(Path(mesa)/'share/glvnd/egl_vendor.d/50_mesa.json'),
        'LIBGL_DRIVERS_PATH': str(Path(mesa)/'lib/dri'),
        'LIBGL_ALWAYS_SOFTWARE': '1',
        'MESA_LOADER_DRIVER_OVERRIDE': 'llvmpipe',
    }
    env.update(graphics_env)
    report = {'driver_sha256':sha256(Path(__file__).read_bytes()).hexdigest(),
              'sway_binary_sha256':sha256(args.sway.read_bytes()).hexdigest(),
              'inner_report':'p/editor-live-report.json',
              'input_isolation':'Niri winit backend in an owned headless Sway; no desktop pointer ingress',
              'failure':None}
    with (directory/'host.log').open('w') as log:
        # Match Probe.dbus_session(): Nix provides an explicit session config
        # and daemon, whereas /etc/dbus-1/session.conf is absent on CI hosts.
        bus_command = [env.get('HADALIS_WORKFLOW_DBUS_RUN_SESSION',
                               'dbus-run-session')]
        if env.get('HADALIS_WORKFLOW_DBUS_SESSION_CONFIG'):
            bus_command.append('--config-file='
                + env['HADALIS_WORKFLOW_DBUS_SESSION_CONFIG'])
        if env.get('HADALIS_WORKFLOW_DBUS_DAEMON'):
            bus_command.append('--dbus-daemon='
                + env['HADALIS_WORKFLOW_DBUS_DAEMON'])
        bus_command += ['--', str(args.sway.resolve()), '-c', str(config)]
        process = subprocess.Popen(bus_command,
                                   env=env,stdout=log,stderr=log,start_new_session=True)
        try:
            deadline = time.monotonic()+20
            while not display.exists():
                if process.poll() is not None or time.monotonic()>deadline:
                    raise RuntimeError('Headless host startup failed')
                time.sleep(.1)
            child_env = os.environ.copy()
            child_env.update(json.loads(display.read_text()))
            child_env.update(graphics_env)
            command = [sys.executable,str(Path(__file__).with_name('run-editor-live.py')),
                       '--work-dir',str(probe_dir), '--revision', args.revision,
                       '--surface', args.surface,
                       '--pointer',str(args.pointer.resolve())]
            report['command'] = command
            completed = subprocess.run(command,env=child_env,timeout=420)
            if completed.returncode:
                raise RuntimeError('Niri Source Editor probe failed; retain inner report')
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
    if report['failure']:
        print(json.dumps(report, indent=2), flush=True)
        for name in ('host.log', 'p/niri.log', 'p/quickshell.log'):
            path = directory/name
            if path.exists():
                print('--- ' + name + ' ---', flush=True)
                print(path.read_text(errors='replace')[-3500:], flush=True)
    return int(report['failure'] is not None)


if __name__ == '__main__':
    raise SystemExit(main())
