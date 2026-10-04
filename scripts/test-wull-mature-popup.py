#!/usr/bin/env python3
"""Real clock module + StyledPopup: Wull borrow, real hover, stable content/slot."""
import os
from pathlib import Path
import runpy
import signal
import subprocess
import tempfile
ROOT=Path(__file__).resolve().parents[1]
core=runpy.run_path(str(ROOT/'scripts/wull-manual-visual-matrix.py'))
with tempfile.TemporaryDirectory(prefix='wull-mature-popup-') as temporary:
    private=Path(temporary);shell,xdg=core['staged'](private)
    (shell/'shell.qml').write_text('import Quickshell\nimport "scripts/wull-fixtures/mature-popup"\nShellRoot {WullPopupProof {}}\n')
    env=core['private_env'](xdg,private/'result.json')
    # StyledPopup's dormant native path still requires a Wayland backend at
    # type construction. Events/capture remain inside our own test window.
    if not os.environ.get('WAYLAND_DISPLAY'):
        print('SKIP: Wull mature-popup proof requires Wayland');raise SystemExit(0)
    env.update(QT_NO_XDG_DESKTOP_PORTAL='1',QT_QPA_PLATFORM='wayland',WAYLAND_DISPLAY=os.environ['WAYLAND_DISPLAY'],
               XDG_RUNTIME_DIR=os.environ['XDG_RUNTIME_DIR'])
    env.update(QT_QUICK_BACKEND='software',QT_QUICK_CONTROLS_STYLE='Basic',QT_QPA_PLATFORMTHEME='generic')
    with (private/'test.log').open('w') as output:
        p=subprocess.Popen(['dbus-run-session','--','qs','--path',str(shell/'shell.qml')],env=env,cwd=ROOT,
                           stdout=output,stderr=subprocess.STDOUT,start_new_session=True)
        try:code=p.wait(timeout=20)
        except subprocess.TimeoutExpired:code=-1
        finally:
            if p.poll() is None:os.killpg(p.pid,signal.SIGTERM);p.wait(timeout=3)
    log=(private/'test.log').read_text()
    bad=('WULL_POPUP=FAIL','ReferenceError:','TypeError:','SyntaxError:','Unable to assign','Binding loop','Failed to load configuration','FAIL!')
    if code or 'WULL_POPUP=PASS' not in log or any(m in log for m in bad):
        print(log[-15000:]);raise SystemExit('Wull mature-popup proof failed')
    print(next(line for line in log.splitlines() if 'WULL_POPUP=PASS' in line))
