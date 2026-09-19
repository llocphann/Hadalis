#!/usr/bin/env python3
"""Run opt-in real Quickshell lifecycle probes on an isolated compositor.

The current desktop and installed shell are never IPC targets. This is a local
desktop test, not a replacement for the canonical maintainer validator.
"""
import argparse
import hashlib
import importlib.util
import json
import os
import re
from pathlib import Path
import signal
import selectors
import subprocess
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
    def __init__(self, directory, report, pointer=None, sway=None):
        self.directory = directory
        self.report = report
        self.processes = []
        self.logs = []
        self.env = os.environ.copy()
        self.pointer = pointer
        self.sway = sway
        self.pointer_process = None

    def start(self, command, env, name):
        log = open(self.directory/f'{name}.log','w')
        self.logs.append(log)
        process = subprocess.Popen(command, env=env, stdout=log, stderr=log, start_new_session=True)
        self.processes.append(process)
        return process

    def launch(self):
        runtime = self.directory/'runtime'
        runtime.mkdir(mode=0o700)
        env = self.env.copy()
        env['XDG_RUNTIME_DIR'] = str(runtime)
        env.pop('NIRI_SOCKET',None)
        self.env.pop('NIRI_SOCKET',None)
        display_file = self.directory/'display.json'
        capture = f"import os,json;open({str(display_file)!r},'w').write(json.dumps({{k:os.environ[k] for k in ('WAYLAND_DISPLAY','NIRI_SOCKET','SWAYSOCK','XDG_RUNTIME_DIR') if k in os.environ}}))"
        if self.sway:
            import shlex
            env.pop('WAYLAND_DISPLAY',None)
            env['WLR_BACKENDS']='headless'
            env['WLR_HEADLESS_OUTPUTS']='2'
            env['WLR_RENDERER']='pixman'
            env['LD_LIBRARY_PATH']=str(self.sway.parent.parent/'lib')
            config=self.directory/'sway.conf'
            config.write_text('xwayland disable\noutput HEADLESS-1 resolution 1920x1200 position 0 0\n'
                'output HEADLESS-2 resolution 1920x1200 position 1920 0 scale 1.25\n'
                'seat seat0 fallback true\nexec python3 -c '+shlex.quote(capture)+'\n')
            self.start(['dbus-run-session','--',str(self.sway),'-c',str(config)],env,'sway')
            self.env['LD_LIBRARY_PATH']=env['LD_LIBRARY_PATH']
            self.env['XDG_CURRENT_DESKTOP']='sway'
        else:
            outer_display = self.env.get('WAYLAND_DISPLAY')
            if not outer_display: raise RuntimeError('Nested Niri requires a Wayland desktop')
            env['WAYLAND_DISPLAY'] = str(Path(self.env['XDG_RUNTIME_DIR'])/outer_display)
            config = self.directory/'niri.kdl'
            config.write_text('spawn-at-startup "python3" "-c" '+json.dumps(capture)+'\nprefer-no-csd\n')
            self.start(['dbus-run-session','--','niri','-c',str(config)],env,'niri')
        wait_for(lambda: display_file.exists() and display_file.stat().st_size,'isolated compositor startup')
        self.env.update(json.loads(display_file.read_text()))
        for key, name in [('XDG_CONFIG_HOME','xdg-config'),('XDG_CACHE_HOME','xdg-cache'),('XDG_STATE_HOME','xdg-state'),('XDG_DATA_HOME','xdg-data')]:
            self.env[key] = str(self.directory/name)
        self.env['QS_NO_RELOAD_POPUP']='1'
        self.env['DBUS_SYSTEM_BUS_ADDRESS']='unix:path='+str(self.directory/'no-system-bus')
        self.env['QT_QUICK_CONTROLS_STYLE']='Basic'
        self.env['WAYLAND_DEBUG']='client'
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

    def wait_snapshot(self, condition, description):
        def observe():
            snapshot = self.snapshot()
            return snapshot if condition(snapshot) else None
        return wait_for(observe,description)

    def outputs(self):
        if self.sway:
            items=json.loads(self.sway_command('-t','get_outputs','-r'))
            return {o['name']:{'logical':dict(o['rect'],scale=o['scale'])} for o in items if o['active']}
        return json.loads(subprocess.check_output(['niri','msg','-j','outputs'],env=self.env,text=True))

    def layers(self):
        if self.sway: return {'backend':'sway','outputs':self.outputs(),'layer_evidence':'Wayland protocol trace'}
        return json.loads(subprocess.check_output(['niri','msg','-j','layers'],env=self.env,text=True))

    def sway_command(self,*args):
        return subprocess.check_output([str(self.sway.with_name('swaymsg')),'-s',self.env['SWAYSOCK'],*args],env=self.env,text=True,timeout=8)

    def move(self, x, y, button='move', output=None):
        outputs = self.outputs()
        output=output or self.snapshot()['outputs'][0]
        x+=outputs[output]['logical']['x']
        y+=outputs[output]['logical']['y']
        width=max(o['logical']['x']+o['logical']['width'] for o in outputs.values())
        height=max(o['logical']['y']+o['logical']['height'] for o in outputs.values())
        socket=str(Path(self.env['XDG_RUNTIME_DIR'])/self.env['WAYLAND_DISPLAY'])
        if Path(socket).parent != self.directory/'runtime':
            raise RuntimeError('refusing input outside isolated runtime directory')
        self.report['last_pointer_command']={'x':x,'y':y,'width':width,'height':height,'button':button}
        input_env=self.env.copy()
        input_env.pop('WAYLAND_DEBUG',None)
        if self.pointer_process is None:
            log=open(self.directory/'pointer.log','w');self.logs.append(log)
            self.pointer_process=subprocess.Popen([str(self.pointer),socket],env=input_env,
                stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=log,text=True,start_new_session=True)
            self.processes.append(self.pointer_process)
        self.pointer_process.stdin.write(f'{round(x)} {round(y)} {width} {height} {button}\n')
        self.pointer_process.stdin.flush()
        with selectors.DefaultSelector() as selector:
            selector.register(self.pointer_process.stdout,selectors.EVENT_READ)
            if not selector.select(timeout=8) or self.pointer_process.stdout.readline().strip()!='ok':
                raise RuntimeError('isolated pointer did not acknowledge input')

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

    def spike_d(self):
        if not self.pointer: raise RuntimeError('--pointer is required for D')
        # C intentionally disrupts a module Loader. D starts with a fresh actual
        # Bar; a resident-but-hidden module must never become a picker candidate.
        self.ipc('bar',False)
        self.wait_target('bar','unloaded')
        self.ipc('bar',True)
        self.ipc('autoHide',False)
        shown=self.wait_snapshot(lambda s:(r:=self.target(s,'bar/media'))['state']=='resident' and r['rect']['eligible'] and r['rect']['y']>=0,'Bar shown')
        self.ipc('settingsOpen',0)
        settings=self.wait_snapshot(lambda s:s['settingsOpen'] and s['settingsLoaded'] and s['settingsPage']==0,'actual Settings page ready')
        self.record('D actual Settings overlay loaded',settings['settingsLoaded'])
        self.record('D begin picker succeeds',self.ipc('pick')=='true')
        picking=self.wait_snapshot(lambda s:s['picker']['phase']=='picking' and s['picker']['overlays']==len(s['outputs']),'picker surfaces live')
        self.record('D Settings fully unloaded before picker activates',not picking['settingsOpen'] and not picking['settingsLoaded'])
        self.report['D_layers']=self.layers()
        self.report['D_picking']=picking
        self.record('D transient full-output layer surfaces exist',picking['picker']['overlays']==len(picking['outputs']))
        self.record('D pointer-first picker never takes keyboard focus',picking['picker']['keyboardFocus']=='None')
        self.record('D only registered shell targets can be inspected',all(r['targetId'].startswith('bar') for r in picking['records']))
        self.record('D a second pick session is rejected',self.ipc('pick')=='false')
        media=self.target(picking,'bar/media');g=media['rect'];actions=picking['mediaActions']
        self.move(g['x']+g['width']/2,g['y']+g['height']/2,'left')
        selected=self.wait_snapshot(lambda s:s['picker']['phase']=='idle' and s['picker']['lastReason']=='selected','pick selection and Settings restoration')
        self.record('D most specific target selected through compositor input',selected['selectedInstanceId']==media['instanceId'])
        self.record('D selection press/release never activates underlying Media',selected['mediaActions']==actions)
        self.record('D picker surfaces destroyed and hold released',selected['picker']['overlays']==0 and not selected['pickHold'])
        self.record('D Settings page and viewport restored',selected['settingsOpen'] and selected['settingsPage']==settings['settingsPage'] and selected['viewport']==settings['viewport'])
        self.ipc('settingsClose')
        self.wait_snapshot(lambda s:not s['settingsLoaded'],'Settings closed')
        self.move(g['x']+g['width']/2,g['y']+g['height']/2,'left')
        clicked=self.wait_snapshot(lambda s:s['mediaActions']>actions,'underlying Media click positive control')
        self.record('D ordinary Media click works after picker removal',clicked['mediaActions']==actions+1)
        # End the positive-control popup before the independent auto-hide case.
        # Existing popup catcher/focus behavior is outside the picker milestone.
        self.ipc('resetMediaPopups')
        self.wait_snapshot(lambda s:not s['mediaPopupsOpen'],'Media popup dismissed')
        self.ipc('autoHide',True)
        self.wait_snapshot(lambda s:self.target(s,'bar')['rect']['barAutoHide'],'auto-hide configuration applied')
        self.move(20,1)
        self.wait_snapshot(lambda s:self.target(s,'bar')['rect']['y']>=0,'auto-hide Bar revealed by pointer')
        self.ipc('pick')
        self.wait_snapshot(lambda s:s['picker']['phase']=='picking','hold pick')
        self.move(300,300)
        time.sleep(.7)
        held=self.snapshot()
        self.record('D presentation hold survives pointer leaving Bar',held['pickHold'] and self.target(held,'bar')['rect']['barAutoHide'] and self.target(held,'bar')['rect']['y']>=0 and held['dormantCreations']==0)
        before=held['selectedInstanceId']
        self.move(300,300,'right')
        cancelled=self.wait_snapshot(lambda s:s['picker']['phase']=='idle','right-click cancel')
        self.record('D right-click cancel preserves selection',cancelled['picker']['lastReason']=='cancelled' and cancelled['selectedInstanceId']==before and cancelled['picker']['overlays']==0)
        self.move(400,400)
        self.wait_snapshot(lambda s:self.target(s,'bar')['rect']['y']<0,'auto-hide resumes after cancellation')
        self.record('D presentation hold ends immediately',not self.snapshot()['pickHold'])
        self.ipc('autoHide',False)
        self.ipc('bottom',True)
        bottom=self.wait_snapshot(lambda s:self.target(s,'bar/media')['rect']['y']>100,'bottom Bar geometry')
        self.ipc('pick')
        bottom=self.wait_snapshot(lambda s:s['picker']['phase']=='picking','bottom pick')
        b=self.target(bottom,'bar/media')['rect']
        self.move(b['x']+b['width']/2,b['y']+b['height']/2,'left')
        bottom_selected=self.wait_snapshot(lambda s:s['picker']['phase']=='idle','bottom target click')
        self.record('D QML geometry follows Bar top-to-bottom movement',bottom_selected['picker']['lastReason']=='selected' and bottom_selected['selectedTargetId']=='bar/media')
        self.ipc('pick')
        self.wait_snapshot(lambda s:s['picker']['phase']=='picking','lock cancellation pick')
        self.ipc('lock',True)
        locked=self.wait_snapshot(lambda s:s['picker']['phase']=='idle','lock state cancels picker')
        self.record('D shell lock signal cancels surfaces without restoring Settings',locked['picker']['lastReason']=='locked' and locked['picker']['overlays']==0 and not locked['settingsOpen'] and not locked['pickHold'])
        self.record('D locked shell rejects new picker',self.ipc('pick')=='false')
        self.ipc('lock',False)
        self.wait_target('bar/media','resident')
        self.ipc('bar',False)
        self.wait_target('bar','unloaded')
        self.ipc('pick')
        hidden=self.wait_snapshot(lambda s:s['picker']['phase']=='picking','picker with unloaded Bar')
        self.record('D picker does not load a closed Bar',all(r['state']=='unloaded' for r in hidden['records']) and hidden['dormantCreations']==0 and not hidden['heldOutputs'])
        self.ipc('cancel')
        self.wait_snapshot(lambda s:s['picker']['phase']=='idle','end hidden pick')
        self.ipc('bar',True)
        self.ipc('bottom',False)
        if self.sway:
            self.wait_target('bar/media','resident')
            self.ipc('autoHide',False)
            self.ipc('pick')
            multi=self.wait_snapshot(lambda s:s['picker']['phase']=='picking' and s['picker']['overlays']==2,'two output picker')
            secondary=next(r for r in multi['records'] if r['targetId']=='bar/media' and r['output']=='HEADLESS-2')
            g=secondary['rect']
            self.move(g['x']+g['width']/2,g['y']+g['height']/2,'left',output='HEADLESS-2')
            picked=self.wait_snapshot(lambda s:s['picker']['phase']=='idle','fractional output click')
            self.record('D compositor-native 1.25 scale selects correct output instance',picked['selectedInstanceId']==secondary['instanceId'] and g['dpr']==1.25)
            self.ipc('pick')
            self.wait_snapshot(lambda s:s['picker']['overlays']==2,'two surfaces before output removal')
            self.sway_command('output','HEADLESS-2','disable')
            removed=self.wait_snapshot(lambda s:s['picker']['phase']=='idle' and len(s['outputs'])==1,'real wl_output removal')
            self.record('D compositor output removal cancels all picker surfaces',removed['picker']['overlays']==0 and removed['picker']['lastReason']=='output-removed')
            self.record('D removed selected output has explicit stale state',removed['selectedInstanceId']==secondary['instanceId'] and removed['selectionState']=='stale/output-removed')
            self.sway_command('output','HEADLESS-2','enable')
            restored=self.wait_snapshot(lambda s:len(s['outputs'])==2 and s['selectionState']=='resident','output reconnect rebind')
            self.record('D reconnect binds selected instance to replacement QObject',next(r for r in restored['records'] if r['instanceId']==secondary['instanceId'])['runtimeToken']!=secondary['runtimeToken'])
            self.report['D_removed']=removed
            self.report['D_reconnected']=restored
        self.report['D_selected']=selected
        self.report['D_held']=held
        self.report['D_locked']=locked

    def spike_e(self):
        self.ipc('settingsClose')
        self.ipc('bar',True)
        self.ipc('media',True)
        current=self.wait_target('bar/media','resident')
        media=self.target(current,'bar/media')
        self.ipc('select',media['instanceId'])
        current=self.snapshot()
        shell_file=self.directory/'config/shell.qml'
        snapshots=[]
        for revision in (2,3):
            old=self.target(current,'bar/media')
            text=shell_file.read_text()
            text=prepare_module.replace_once(text,f'property int sourceRevision: {revision-1}',f'property int sourceRevision: {revision}')
            shell_file.write_text(text)
            reloaded=self.wait_snapshot(lambda s:s['sourceRevision']==revision and s['epoch']!=current['epoch'] and s['selectionState']=='resident','ordinary source-triggered Quickshell reload')
            new=self.target(reloaded,'bar/media')
            self.record(f'E reload {revision-1} preserves semantic selection and viewport',reloaded['selectedInstanceId']==current['selectedInstanceId'] and reloaded['selectedTargetId']==current['selectedTargetId'] and reloaded['viewport']==current['viewport'])
            self.record(f'E reload {revision-1} replaces actual QObject and runtime generation',new['runtimeToken']!=old['runtimeToken'] and new['objectIdentity']!=old['objectIdentity'])
            wait_for(lambda: 'WORKFLOW_MEDIA_DESTROYED '+old['objectIdentity'] in (self.directory/'quickshell.log').read_text(),'old Media QObject destruction')
            self.record(f'E reload {revision-1} emits actual old QObject destruction',True,old['objectIdentity'])
            snapshots.append(reloaded)
            current=reloaded
        self.ipc('media',False)
        unloaded=self.wait_target('bar/media','unloaded')
        self.record('E unloading selected target enters static mode',unloaded['selectedInstanceId']==current['selectedInstanceId'] and unloaded['selectionState']=='unloaded' and self.target(unloaded,'bar/media')['values'] is None)
        shell_file.write_text(prepare_module.replace_once(shell_file.read_text(),'property int sourceRevision: 3','property int sourceRevision: 4'))
        static=self.wait_snapshot(lambda s:s['sourceRevision']==4 and s['epoch']!=unloaded['epoch'] and s['ready'],'reload while target is unloaded')
        self.record('E ordinary reload does not force selected unloaded module resident',static['selectionState']=='unloaded' and static['selectedInstanceId']==unloaded['selectedInstanceId'] and static['dormantCreations']==0 and self.target(static,'bar/media')['runtimeToken'] is None)
        self.ipc('media',True)
        rebound=self.wait_target('bar/media','resident')
        self.record('E selected static target rebinds when module returns',rebound['selectedInstanceId']==static['selectedInstanceId'] and rebound['selectionState']=='resident')
        self.report['E_reloads']=snapshots
        self.report['E_static_after_reload']=static
        self.report['E_rebound']=rebound

    def verify_protocol(self):
        # Object IDs are reused by Settings/popups; associate requests with each
        # layer-surface lifetime instead of searching the entire log for a mode.
        lifetimes=[]
        active={}
        for line in (self.directory/'quickshell.log').read_text().splitlines():
            match=re.search(r'get_layer_surface\(new id zwlr_layer_surface_v1#(\d+),.*?, (\d+), "([^"]+)"\)',line)
            if match:
                sid,layer,namespace=match.groups()
                item={'id':sid,'layer':int(layer),'namespace':namespace,'keyboard':[], 'zones':[], 'anchors':[], 'destroyed':False}
                active[sid]=item
                if namespace=='quickshell:code-workflow-picker': lifetimes.append(item)
            match=re.search(r'zwlr_layer_surface_v1#(\d+)\.(\w+)\((-?\d*)\)',line)
            if not match or match[1] not in active: continue
            item=active[match[1]]
            key={'set_keyboard_interactivity':'keyboard','set_exclusive_zone':'zones','set_anchor':'anchors'}.get(match[2])
            if key: item[key].append(int(match[3]))
            elif match[2]=='destroy':
                item['destroyed']=True
                del active[match[1]]
        self.report['D_protocol_lifetimes']=lifetimes
        self.record('D protocol confirms Overlay, full anchors, no keyboard grab or reservation',bool(lifetimes) and all(x['layer']==3 and x['keyboard'] and set(x['keyboard'])=={0} and 15 in x['anchors'] and x['zones'] and set(x['zones'])<={-1,0} for x in lifetimes))
        self.record('D every picker layer-surface was destroyed before test cleanup',bool(lifetimes) and all(x['destroyed'] for x in lifetimes))

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
    parser.add_argument('--spikes',default='C',choices=['C','CD','CE','CDE'])
    parser.add_argument('--pointer',type=Path)
    parser.add_argument('--sway',type=Path,help='Optional headless multi-output Sway executable')
    args=parser.parse_args()
    directory=args.work_dir.resolve()
    manifest=prepare_module.prepare(directory,args.revision)
    report={'schema':1,'spikes':list(args.spikes),'manifest':manifest,'checks':[],
            'quickshell':subprocess.check_output(['quickshell','--version'],text=True).strip(),
            'niri':subprocess.check_output(['niri','--version'],text=True).strip(),
            'environment':'nested Niri, actual Hadalis Bar, isolated XDG and private session bus',
            'limitations':['No hardware hotplug or physical input claim.','System services/audio deliberately unavailable in isolated session.']}
    if args.sway:
        report['environment']='headless Sway, two real wl_outputs at scale 1/1.25, actual Hadalis Bar, isolated XDG and private session bus'
        report['sway']=str(args.sway)
    if args.pointer:
        report['pointer_binary_sha256']=hashlib.sha256(args.pointer.read_bytes()).hexdigest()
    probe=Probe(directory,report,args.pointer,args.sway)
    try:
        probe.launch()
        probe.spike_c()
        if 'D' in args.spikes: probe.spike_d()
        if 'E' in args.spikes: probe.spike_e()
        if 'D' in args.spikes: probe.verify_protocol()
    except Exception as exc:
        report['failure']=str(exc)
        try: report['failure_snapshot']=probe.snapshot()
        except Exception: pass
    finally:
        probe.close()
        (directory/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({'report':str(directory/'report.json'),'checks':len(report['checks']),'failure':report.get('failure')},indent=2))
    return int(bool(report.get('failure')))


if __name__=='__main__':
    raise SystemExit(main())
