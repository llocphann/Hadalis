#!/usr/bin/env python3
"""Run opt-in real Quickshell lifecycle probes on an isolated compositor.

The current desktop and installed shell are never IPC targets. This is a local
desktop test, not a replacement for the canonical maintainer validator.
"""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import time

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('prepare_runtime', HERE/'prepare-runtime.py')
prepare_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prepare_module)


def wait_for(callback, description, timeout=35):
    deadline = time.monotonic() + timeout
    last = None
    while time.monotonic() < deadline:
        try:
            last = callback()
            if last:
                return last
        except (subprocess.SubprocessError, OSError, ValueError) as exc:
            last = str(exc)
        time.sleep(.15)
    raise AssertionError(f'timeout: {description}; last={last}')


class Probe:
    def __init__(self, directory, report):
        self.directory = directory
        self.report = report
        self.processes = []
        self.logs = []
        self.env = os.environ.copy()

    def start(self, command, env, name):
        log = open(self.directory/f'{name}.log','w')
        self.logs.append(log)
        process = subprocess.Popen(command, env=env, stdout=log, stderr=log, start_new_session=True)
        self.processes.append(process)
        return process

    def launch(self):
        runtime = self.directory/'runtime'
        runtime.mkdir(mode=0o700)
        parent_runtime = self.env['XDG_RUNTIME_DIR']
        outer_display = self.env.get('WAYLAND_DISPLAY')
        if not outer_display:
            raise RuntimeError('Nested Niri requires a Wayland desktop')
        env = self.env.copy()
        env['WAYLAND_DISPLAY'] = str(Path(parent_runtime)/outer_display)
        env['XDG_RUNTIME_DIR'] = str(runtime)
        env.pop('NIRI_SOCKET',None)
        display_file = self.directory/'display.json'
        capture = f"import os,json;open({str(display_file)!r},'w').write(json.dumps({{k:os.environ.get(k) for k in ('WAYLAND_DISPLAY','NIRI_SOCKET','XDG_RUNTIME_DIR')}}))"
        config = self.directory/'niri.kdl'
        config.write_text('spawn-at-startup "python3" "-c" '+json.dumps(capture)+'\nprefer-no-csd\n')
        self.start(['dbus-run-session','--','niri','-c',str(config)],env,'niri')
        wait_for(lambda: display_file.exists() and display_file.stat().st_size,'nested Niri startup')
        self.env.update(json.loads(display_file.read_text()))
        for key, name in [('XDG_CONFIG_HOME','xdg-config'),('XDG_CACHE_HOME','xdg-cache'),('XDG_STATE_HOME','xdg-state'),('XDG_DATA_HOME','xdg-data')]:
            self.env[key] = str(self.directory/name)
        self.env['QS_NO_RELOAD_POPUP']='1'
        self.env['DBUS_SYSTEM_BUS_ADDRESS']='unix:path='+str(self.directory/'no-system-bus')
        self.env['QT_QUICK_CONTROLS_STYLE']='Basic'
        self.env.pop('HYPRLAND_INSTANCE_SIGNATURE',None)
        self.start(['dbus-run-session','--','quickshell','-p',str(self.directory/'config'),'--no-color'],self.env,'quickshell')
        wait_for(lambda: self.snapshot().get('ready'),'Quickshell Bar ready')

    def ipc(self, method, *args):
        command = ['quickshell','ipc','-p',str(self.directory/'config'),'call','workflowProbe',method]
        command += [str(v).lower() if isinstance(v,bool) else str(v) for v in args]
        return subprocess.check_output(command,env=self.env,text=True,stderr=subprocess.PIPE,timeout=8).strip()

    def snapshot(self):
        return json.loads(self.ipc('snapshot'))

    def record(self, name, condition, evidence=None):
        self.report['checks'].append({'name':name,'passed':bool(condition),'evidence':evidence})
        if not condition:
            raise AssertionError(name)

    def target(self, snapshot, name):
        return next(r for r in snapshot['records'] if r['targetId']==name and r['output']==snapshot['outputs'][0])

    def wait_target(self, name, state):
        def observe():
            snapshot = self.snapshot()
            return snapshot if self.target(snapshot,name)['state']==state else None
        return wait_for(observe, name+' '+state)

    def spike_c(self):
        initial = self.wait_target('bar/media','resident')
        self.report['C_initial'] = initial
        self.record('C actual Bar, Media and Clock objects resident',all(self.target(initial,t)['state']=='resident' for t in ('bar','bar/media','bar/clock')))
        self.record('C static unloaded Resources available',self.target(initial,'bar/resources')['state']=='unloaded')
        self.record('C semantic IDs distinct from per-output instance IDs',all(r['instanceId']==r['targetId']+'@'+r['output'] for r in initial['records']))
        for _ in range(20):
            observed = self.snapshot()
        self.record('C repeated inspection never activates dormant LazyLoader',not observed['dormantActive'] and not observed['dormantLoading'] and observed['dormantCreations']==0)
        self.record('C snapshots contain only allowlisted runtime values',all(r['values'] is None or set(r['values'])=={'width','height','visible','enabled'} for r in observed['records']))
        self.record('C sensitive property sentinel excluded','DO_NOT_EXPORT_PRIVATE_VALUE' not in json.dumps(observed) and 'probeSensitiveSentinel' not in json.dumps(observed))
        media = self.target(initial,'bar/media')
        self.ipc('select',media['instanceId'])
        self.ipc('media',False)
        unloaded = self.wait_target('bar/media','unloaded')
        self.record('C unload clears QObject reference and preserves static source',self.target(unloaded,'bar/media')['objectIdentity'] is None and unloaded['selectionState']=='unloaded' and self.target(unloaded,'bar/media')['sourcePath']==media['sourcePath'])
        self.record('C explicit stale/unloading event',any(e['kind']=='stale/unloading' and e['instanceId']==media['instanceId'] for e in unloaded['events']))
        self.ipc('media',True)
        rebound = self.wait_target('bar/media','resident')
        new_media = self.target(rebound,'bar/media')
        self.record('C stable selection rebinds to a new runtime generation',rebound['selectedInstanceId']==media['instanceId'] and new_media['runtimeToken']!=media['runtimeToken'])
        self.record('C registry has no duplicate instance IDs',len({r['instanceId'] for r in rebound['records']})==len(rebound['records']))
        self.report['C_unloaded']=unloaded
        self.report['C_rebound']=rebound

    def close(self):
        for process in reversed(self.processes):
            try:
                os.killpg(process.pid,signal.SIGTERM)
                process.wait(timeout=5)
            except (ProcessLookupError,subprocess.TimeoutExpired):
                try: os.killpg(process.pid,signal.SIGKILL)
                except ProcessLookupError: pass
        for log in self.logs: log.close()


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--work-dir',type=Path,required=True,help='New directory; retained for evidence')
    parser.add_argument('--revision',default='HEAD')
    args=parser.parse_args()
    directory=args.work_dir.resolve()
    manifest=prepare_module.prepare(directory,args.revision)
    report={'schema':1,'spikes':['C'],'manifest':manifest,'checks':[],
            'quickshell':subprocess.check_output(['quickshell','--version'],text=True).strip(),
            'niri':subprocess.check_output(['niri','--version'],text=True).strip(),
            'environment':'nested Niri, actual Hadalis Bar, isolated XDG and private session bus',
            'limitations':['No hardware hotplug or physical input claim.','System services/audio deliberately unavailable in isolated session.']}
    probe=Probe(directory,report)
    try:
        probe.launch()
        probe.spike_c()
    except Exception as exc:
        report['failure']=str(exc)
    finally:
        probe.close()
        (directory/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({'report':str(directory/'report.json'),'checks':len(report['checks']),'failure':report.get('failure')},indent=2))
    return int(bool(report.get('failure')))


if __name__=='__main__':
    raise SystemExit(main())
