#!/usr/bin/env python3
"""Blender-authored cast contracts and owned four-rim paired handoffs."""
import os
from pathlib import Path
import runpy
import signal
import shutil
import subprocess
import tempfile
ROOT=Path(__file__).resolve().parents[1]
subprocess.run(['node','scripts/test-companion-cast.cjs'],cwd=ROOT,check=True,timeout=30)
core=runpy.run_path(str(ROOT/'scripts/wull-manual-visual-matrix.py'))
with tempfile.TemporaryDirectory(prefix='companion-cast-') as temporary:
    private=Path(temporary);shell,xdg=core['staged'](private)
    # A long animation proof must not reload halfway through when another
    # authorized checkout edit lands. The owned shell uses a frozen snapshot.
    for name in ('modules','services','scripts'):
        target=shell/name
        target.unlink()
        shutil.copytree(ROOT/name,target)
    (shell/'shell.qml').write_text('import Quickshell\nimport "scripts/wull-fixtures/companions"\nShellRoot {CompanionTurnsProof {}}\n')
    env=core['private_env'](xdg,private/'unused.json')
    env.update(QT_QUICK_BACKEND='software',QT_QUICK_CONTROLS_STYLE='Basic',QT_QPA_PLATFORMTHEME='generic',QT_NO_XDG_DESKTOP_PORTAL='1')
    with (private/'test.log').open('w') as log:
        p=subprocess.Popen(['dbus-run-session','--','qs','--path',str(shell/'shell.qml')],cwd=ROOT,env=env,
            stdin=subprocess.DEVNULL,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
        try:code=p.wait(timeout=75)
        except subprocess.TimeoutExpired:code=-1
        finally:
            if p.poll() is None:os.killpg(p.pid,signal.SIGTERM);p.wait(timeout=3)
    log=(private/'test.log').read_text()
    bad=('COMPANION_TURNS=FAIL','ReferenceError:','TypeError:','Binding loop','Unable to assign','Failed to load configuration','FAIL!')
    if code or 'COMPANION_TURNS=PASS' not in log or any(m in log for m in bad):
        print('\n'.join(line for line in log.splitlines() if any(s in line for s in (*bad,'ERROR','COMPANION_TURNS','Reloading'))));raise SystemExit('Companion cast behavior failed')
    print(next(line.split('COMPANION_TURNS=',1)[1] for line in log.splitlines() if 'COMPANION_TURNS=PASS' in line))
