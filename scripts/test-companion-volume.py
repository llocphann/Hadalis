#!/usr/bin/env python3
"""Real GPU cast volumes, preserved round falls and clearer four-arm Octo."""
import os
from pathlib import Path
import runpy
import shutil
import signal
import subprocess
import tempfile
ROOT=Path(__file__).resolve().parents[1]
if not os.environ.get('WAYLAND_DISPLAY'):
    print('SKIP: Companion GPU proof requires Wayland');raise SystemExit(0)
core=runpy.run_path(str(ROOT/'scripts/wull-manual-visual-matrix.py'))
decode=runpy.run_path(str(ROOT/'scripts/wull-private-painted-alpha-model.py'))['png_alpha']
with tempfile.TemporaryDirectory(prefix='companion-volume-') as temporary:
    private=Path(temporary);shell,xdg=core['staged'](private)
    for name in ('modules','services','scripts'):
        (shell/name).unlink();shutil.copytree(ROOT/name,shell/name)
    (shell/'shell.qml').write_text('import Quickshell\nimport "scripts/wull-fixtures/companions"\nShellRoot {CompanionVolumeProof {}}\n')
    env=core['private_env'](xdg,private/'unused.json')
    env.update(QT_QPA_PLATFORM='wayland',WAYLAND_DISPLAY=os.environ['WAYLAND_DISPLAY'],
        XDG_RUNTIME_DIR=os.environ['XDG_RUNTIME_DIR'],QT_QUICK_BACKEND='rhi',QSG_RHI_BACKEND='opengl',
        QT_QUICK_CONTROLS_STYLE='Basic',QT_QPA_PLATFORMTHEME='generic',QT_NO_XDG_DESKTOP_PORTAL='1',COMPANION_VOLUME_OUTPUT=str(private))
    with (private/'test.log').open('w') as log:
        p=subprocess.Popen(['dbus-run-session','--','qs','--path',str(shell/'shell.qml')],cwd=ROOT,env=env,
            stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
        try:code=p.wait(timeout=20)
        except subprocess.TimeoutExpired:code=-1
        finally:
            if p.poll() is None:os.killpg(p.pid,signal.SIGTERM);p.wait(timeout=3)
    log=(private/'test.log').read_text()
    if code or 'COMPANION_VOLUME=PASS' not in log or any(s in log for s in ('COMPANION_VOLUME=FAIL','ReferenceError:','TypeError:','Binding loop','Unable to assign')):
        print(log[-5000:]);raise SystemExit('Companion GPU volume proof failed')
    counts=[]
    for actor in range(2):
        areas=[];raws=[]
        for pose in range(5):
            raw=(private/f'pose-{actor*5+pose}.png').read_bytes();raws.append(raw)
            w,h,alpha=decode(raw);assert (w,h)==(304,304)
            painted=[(j%w,j//w) for j,a in enumerate(alpha) if a>=128];assert len(painted)>12000
            width=max(x for x,y in painted)-min(x for x,y in painted)+1
            height=max(y for x,y in painted)-min(y for x,y in painted)+1
            assert .70<width/height<1.45,'fall lost its round 3D silhouette'
            if actor==1:
                assert sum(a>=220 for a in alpha)>=len(painted)*.87,'Octo head remains overly faint'
            areas.append(len(painted))
        assert min(areas[1:3])>=areas[0]*.72,'fall flattened the liquid volume'
        assert len(set(raws))==5,'poses, quality tiers or live theme failed to change the material'
        counts.append(areas)
    for index in range(4):
        w,h,alpha=decode((private/f'arm-{index}.png').read_bytes())
        painted=sum(a>=128 for a in alpha);opaque=sum(a==255 for a in alpha)
        assert painted>1000 and opaque>=painted*.95,'front tentacle exposes the one behind it'
    print('COMPANION_GPU_VOLUME_PASS Aqua/Octo roundFalls clearOcto opaqueTentacles liveReflection twoTiers themeRetint areas='+str(counts))
