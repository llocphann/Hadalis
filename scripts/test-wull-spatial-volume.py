#!/usr/bin/env python3
"""Owned GPU volume silhouettes: falling must rotate rather than flatten."""
import os
from pathlib import Path
import runpy
import signal
import subprocess
import tempfile
ROOT=Path(__file__).resolve().parents[1]
subprocess.run(['node','scripts/test-wull-spatial.cjs'],cwd=ROOT,check=True)
if not os.environ.get('WAYLAND_DISPLAY'):
    print('SKIP: Wull spatial GPU proof requires Wayland');raise SystemExit(0)
core=runpy.run_path(str(ROOT/'scripts/wull-manual-visual-matrix.py'))
decode=runpy.run_path(str(ROOT/'scripts/wull-private-painted-alpha-model.py'))['png_alpha']
with tempfile.TemporaryDirectory(prefix='wull-volume-') as temporary:
    private=Path(temporary);shell,xdg=core['staged'](private)
    (shell/'shell.qml').write_text('import Quickshell\nimport "scripts/wull-fixtures/alive"\nShellRoot {WullVolumeProof {}}\n')
    env=core['private_env'](xdg,private/'unused.json')
    env.update(QT_QPA_PLATFORM='wayland',WAYLAND_DISPLAY=os.environ['WAYLAND_DISPLAY'],
        XDG_RUNTIME_DIR=os.environ['XDG_RUNTIME_DIR'],QT_QUICK_BACKEND='rhi',QSG_RHI_BACKEND='opengl',
        QT_QUICK_CONTROLS_STYLE='Basic',QT_QPA_PLATFORMTHEME='generic',QT_NO_XDG_DESKTOP_PORTAL='1',WULL_VOLUME_OUTPUT=str(private))
    with (private/'test.log').open('w') as log:
        p=subprocess.Popen(['dbus-run-session','--','qs','--path',str(shell/'shell.qml')],env=env,cwd=ROOT,
            stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
        try:code=p.wait(timeout=15)
        except subprocess.TimeoutExpired:code=-1
        finally:
            if p.poll() is None:os.killpg(p.pid,signal.SIGTERM);p.wait(timeout=3)
    log=(private/'test.log').read_text()
    if code or 'WULL_VOLUME=PASS' not in log or any(s in log for s in ('WULL_VOLUME=FAIL','ReferenceError:','TypeError:','Binding loop','Unable to assign')):
        print(log[-5000:]);raise SystemExit('Wull spatial volume GPU proof failed')
    areas=[];raws=[]
    for i in range(4):
        raw=(private/f'pose-{i}.png').read_bytes();raws.append(raw);w,h,alpha=decode(raw)
        assert (w,h)==(304,304)
        painted=[(j%w,j//w) for j,a in enumerate(alpha) if a>=128];assert len(painted)>12000
        width=max(x for x,y in painted)-min(x for x,y in painted)+1
        height=max(y for x,y in painted)-min(y for x,y in painted)+1
        assert .70<width/height<1.45,'falling liquid lost its round 3D silhouette'
        areas.append(len(painted))
    assert min(areas[1:])>=areas[0]*.72,'fall flattened the painted volume'
    assert len(set(raws))==4,'spatial poses did not change material geometry/light'
    print('WULL_SPATIAL_GPU_VOLUME_PASS areas='+str(areas))
