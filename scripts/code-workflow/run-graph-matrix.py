#!/usr/bin/env python3
"""Opt-in Spike B matrix in an owned compositor; never starts the shell."""
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
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--work-dir', type=Path, required=True, help='Must not exist')
    ap.add_argument('--sway', type=Path, help='Optional headless Sway executable')
    ap.add_argument('--scale', type=float, choices=[1, 1.25], default=1)
    ap.add_argument('--baseline-revision', help='Optional committed GraphSandbox.qml for paired comparison')
    ap.add_argument('--seconds', type=float, default=8)
    ap.add_argument('--soak', type=float, default=0, help='Seconds per renderer, with rebuild every 15 seconds')
    ap.add_argument('--input-only', action='store_true')
    args = ap.parse_args()
    if args.seconds <= 0 or args.soak < 0:
        ap.error('Durations must be positive (soak may be zero)')
    directory = args.work_dir.resolve()
    directory.mkdir(parents=True, exist_ok=False)
    here = Path(__file__).resolve().parent
    repo = here.parent.parent
    report = {'schema':1, 'spike':'B', 'runs':[], 'failure':None,
              'matrix_driver_sha256':sha256(Path(__file__).read_bytes()).hexdigest(),
              'source_revision':subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip(),
              'source_status':subprocess.check_output(['git','status','--porcelain'],cwd=repo,text=True).strip(),
              'backend':'sway-headless' if args.sway else 'niri-nested', 'requested_scale':args.scale}
    baseline = None
    if args.baseline_revision:
        revision = subprocess.check_output(['git','rev-parse',args.baseline_revision+'^{commit}'],cwd=repo,text=True).strip()
        baseline = directory/'baseline.qml'
        baseline.write_bytes(subprocess.check_output(['git','show',revision+':scripts/code-workflow/GraphSandbox.qml'],cwd=repo))
        report['baseline_revision'] = revision
    runtime = directory/'runtime'
    runtime.mkdir(mode=0o700)
    display_file = directory/'display.json'
    capture = 'import os,json;open('+repr(str(display_file))+',"w").write(json.dumps({k:os.environ[k] for k in ("WAYLAND_DISPLAY","NIRI_SOCKET","SWAYSOCK","XDG_RUNTIME_DIR") if k in os.environ}))'
    env = os.environ.copy()
    outer_display = str(Path(env.get('XDG_RUNTIME_DIR','/nonexistent'))/env.get('WAYLAND_DISPLAY','missing'))
    for key in ('NIRI_SOCKET','SWAYSOCK','HYPRLAND_INSTANCE_SIGNATURE','QT_SCALE_FACTOR','WAYLAND_DEBUG','DISPLAY'):
        env.pop(key,None)
    env['XDG_RUNTIME_DIR'] = str(runtime)
    for key in ('CONFIG','CACHE','STATE','DATA'):
        env['XDG_'+key+'_HOME'] = str(directory/key.lower())
    if args.sway:
        env.pop('WAYLAND_DISPLAY',None)
        env.update(WLR_BACKENDS='headless', WLR_HEADLESS_OUTPUTS='1', WLR_RENDERER='pixman')
        env['LD_LIBRARY_PATH'] = str(args.sway.resolve().parent.parent/'lib')
        config = directory/'sway.conf'
        config.write_text(f'xwayland disable\noutput HEADLESS-1 resolution 1920x1200 scale {args.scale}\nseat seat0 fallback true\n'
                          'exec python3 -c '+shlex.quote(capture)+'\n')
        command = [str(args.sway.resolve()),'-c',str(config)]
        output = 'HEADLESS-1'
    else:
        if not Path(outer_display).exists():
            ap.error('Nested Niri requires a Wayland desktop socket')
        env['WAYLAND_DISPLAY'] = outer_display
        config = directory/'niri.kdl'
        config.write_text('spawn-at-startup "python3" "-c" '+json.dumps(capture)+'\nprefer-no-csd\n'
                          f'output "winit" {{ scale {args.scale}; }}\n')
        command = ['niri','-c',str(config)]
        output = 'winit'
    log = (directory/'compositor.log').open('w')
    process = subprocess.Popen(['dbus-run-session','--',*command],env=env,stdout=log,stderr=log,start_new_session=True)
    try:
        deadline = time.monotonic()+20
        while not display_file.exists():
            if process.poll() is not None or time.monotonic()>deadline:
                raise RuntimeError('Compositor startup failed; see compositor.log')
            time.sleep(.1)
        env.update(json.loads(display_file.read_text()))
        env.update(QT_QPA_PLATFORM='wayland', QT_QUICK_BACKEND='rhi', QSG_RHI_BACKEND='opengl')
        if args.sway:
            query = [str(args.sway.resolve().with_name('swaymsg')),'-s',env['SWAYSOCK'],'-t','get_outputs','-r']
        else:
            query = ['niri','msg','--json','outputs']
        report['outputs'] = json.loads(subprocess.check_output(query,env=env,text=True,timeout=10))

        def run(name, flags, expected_nodes):
            result_file = directory/(name+'.json')
            cmd = [sys.executable,str(here/'run-sandbox.py'),'--screen',output,'--output',str(result_file),*flags]
            with (directory/(name+'.log')).open('w') as stream:
                result = subprocess.run(cmd,env=env,stdout=stream,stderr=stream,
                                        timeout=max(args.soak,args.seconds)+90)
            data = json.loads(result_file.read_text()) if result_file.exists() else {'failure':'No JSON report'}
            report['runs'].append({'name':name,'command':cmd,'exit_code':result.returncode,'result':data})
            (directory/'report.json').write_text(json.dumps(report,indent=2)+'\n')
            if result.returncode or data.get('failure') or data.get('qml_warnings'):
                raise RuntimeError(name+': '+str(data.get('failure')))
            if not data['renderer_request_honored'] or data['nodes'] != expected_nodes:
                raise RuntimeError(name+': renderer/node workload mismatch')
            if abs(data['device_pixel_ratio']-args.scale)>.01:
                raise RuntimeError(name+': compositor scale not applied')
            if '--benchmark' in flags and data['visible_nodes_at_end'] != expected_nodes:
                raise RuntimeError(name+': benchmark did not retain all visible nodes')
            print(json.dumps({'completed':name,'checks':len(data['input_checks'])}),flush=True)

        for renderer in ('geometry','curve'):
            run('input-'+renderer,['--test','--nodes','60','--renderer',renderer],60)
        if not args.input_only:
            for i,nodes in enumerate((20,60,100,250)):
                for renderer in ('geometry','curve'):
                    variants = [('baseline',baseline),('candidate',None)] if baseline else [('candidate',None)]
                    # Fixed alternating order; keep every result, never choose the fastest run.
                    if i%2: variants.reverse()
                    for variant,source in variants:
                        flags = ['--nodes',str(nodes),'--renderer',renderer,'--benchmark',str(args.seconds),'--warmup','2']
                        if source: flags += ['--qml-source',str(source)]
                        run(f'{variant}-{renderer}-{nodes}',flags,nodes)
            if args.soak:
                for renderer in ('geometry','curve'):
                    run('soak-'+renderer,['--nodes','250','--renderer',renderer,'--benchmark',str(args.soak),
                        '--warmup','20','--sample-every','10','--rebuild-every','15'],250)
    except Exception as exc:
        report['failure'] = repr(exc)
    finally:
        if process.poll() is None:
            os.killpg(process.pid,signal.SIGTERM)
            try: process.wait(timeout=8)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid,signal.SIGKILL)
                process.wait(timeout=5)
        log.close()
        (directory/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({'report':str(directory/'report.json'),'runs':len(report['runs']),'failure':report['failure']}))
    return int(report['failure'] is not None)


if __name__ == '__main__':
    raise SystemExit(main())
