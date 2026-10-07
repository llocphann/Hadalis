#!/usr/bin/env python3
"""Four-edge orbital geometry and real owned-item hover/paint, no model inference."""
import argparse
import os
from pathlib import Path
import runpy
import shutil
import signal
import struct
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--capture-dir',type=Path,help='retain owned fixture frames in a new directory')
args=parser.parse_args()
subprocess.run(['node','scripts/test-wull-cloud-orbit.cjs'],cwd=ROOT,check=True,timeout=15)
if not os.environ.get('WAYLAND_DISPLAY'):
    print('SKIP: Cloud orbit paint/input requires Wayland');raise SystemExit(0)
core=runpy.run_path(str(ROOT/'scripts/wull-manual-visual-matrix.py'))
with tempfile.TemporaryDirectory(prefix='wull-cloud-orbit-') as temporary:
    private=Path(temporary);shell,xdg=core['staged'](private)
    for name in ('modules','services','scripts'):
        (shell/name).unlink();shutil.copytree(ROOT/name,shell/name)
    (shell/'shell.qml').write_text('import Quickshell\nimport "scripts/wull-fixtures/mind"\nShellRoot {WullCloudOrbitProof {}}\n')
    env=core['private_env'](xdg,private/'unused.json')
    env.update(QT_QPA_PLATFORM='wayland',WAYLAND_DISPLAY=os.environ['WAYLAND_DISPLAY'],
        XDG_RUNTIME_DIR=os.environ['XDG_RUNTIME_DIR'],QT_QUICK_BACKEND='rhi',QSG_RHI_BACKEND='opengl',
        QT_QUICK_CONTROLS_STYLE='Basic',QT_QPA_PLATFORMTHEME='generic',QT_NO_XDG_DESKTOP_PORTAL='1',
        INIR_GGUF_ROOTS='[]',INIR_WULL_HISTORY_DB=str(private/'history.sqlite3'),WULL_CLOUD_ORBIT_OUTPUT=str(private))
    with (private/'test.log').open('w') as output:
        process=subprocess.Popen(['dbus-run-session','--','qs','--path',str(shell/'shell.qml')],cwd=ROOT,
            env=env,stdout=output,stderr=subprocess.STDOUT,start_new_session=True)
        try:code=process.wait(timeout=25)
        except subprocess.TimeoutExpired:code=-1
        finally:
            if process.poll() is None:os.killpg(process.pid,signal.SIGTERM);process.wait(timeout=3)
    log=(private/'test.log').read_text()
    bad=('WULL_CLOUD_ORBIT=FAIL','ReferenceError:','TypeError:','Unable to assign','Binding loop','FAIL!')
    if code or 'WULL_CLOUD_ORBIT=PASS' not in log or any(m in log for m in bad):
        print(log[-6500:]);raise SystemExit('Cloud orbit Qt proof failed')
    assert all((private/(edge+'.png')).stat().st_size>1000 for edge in ('bottom','top','left','right','chat'))
    for edge in ('bottom','top','left','right','chat'):
        raw=(private/(edge+'.png')).read_bytes()
        assert raw.startswith(b'\x89PNG\r\n\x1a\n')
        width,height=struct.unpack('>II',raw[16:24])
        assert (width,height)==(480,640 if edge=='chat' else 320),'compositor resized the owned proof viewport'
    if args.capture_dir:
        args.capture_dir.mkdir(mode=0o700,parents=True,exist_ok=False)
        for edge in ('bottom','top','left','right','chat'):
            shutil.copyfile(private/(edge+'.png'),args.capture_dir/(edge+'.png'))
    print(next(line for line in log.splitlines() if 'WULL_CLOUD_ORBIT=PASS' in line))
