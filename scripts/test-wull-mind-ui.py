#!/usr/bin/env python3
"""Owned QML + real one-shot helper against a controlled local HTTP fixture."""
import importlib.util
import os
from pathlib import Path
import runpy
import signal
import subprocess
import tempfile
import threading
import time
from datetime import datetime
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('mind_test',ROOT/'scripts/test-wull-local-mind.py')
fixture=importlib.util.module_from_spec(spec);spec.loader.exec_module(fixture)
class Handler(fixture.Handler):
    def respond(self,value,status=200):
        if self.path=='/api/chat' and 'slow' in self.calls[-1][1]['messages'][-1]['content']:time.sleep(.3)
        try:super().respond(value,status)
        except BrokenPipeError:pass
server=fixture.ThreadingHTTPServer(('127.0.0.1',0),Handler)
thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
core=runpy.run_path(str(ROOT/'scripts/wull-manual-visual-matrix.py'))
try:
    with tempfile.TemporaryDirectory(prefix='wull-mind-ui-') as temporary:
        private=Path(temporary);shell,xdg=core['staged'](private)
        journal=private/'vault'/fixture.mind.daily._render_daily_path('00_Capture/01_Journal',fixture.mind.daily.DEFAULT_FORMAT,datetime.now().date())
        journal.parent.mkdir(parents=True)
        journal.write_text('---\nmood:\nenergy:\nprivate: preserved\n---\n## Day Planner\n')
        (shell/'shell.qml').write_text('import Quickshell\nimport "scripts/wull-fixtures/mind"\nShellRoot {WullMindProof {}}\n')
        env=core['private_env'](xdg,private/'result.json')
        # The settings text field imports its dormant native context menu.
        # All input still targets this test's own ordinary Qt window.
        if not os.environ.get('WAYLAND_DISPLAY'):
            print('SKIP: Wull mind UI proof requires Wayland');raise SystemExit(0)
        env.update(QT_QPA_PLATFORM='wayland',WAYLAND_DISPLAY=os.environ['WAYLAND_DISPLAY'],
                   XDG_RUNTIME_DIR=os.environ['XDG_RUNTIME_DIR'])
        env.update(QT_QUICK_BACKEND='software',QT_QUICK_CONTROLS_STYLE='Basic',QT_QPA_PLATFORMTHEME='generic',
                   QT_NO_XDG_DESKTOP_PORTAL='1',WULL_TEST_ENDPOINT=f'http://127.0.0.1:{server.server_port}')
        env['WULL_TEST_VAULT']=str(private/'vault')
        env['INIR_GGUF_ROOTS']='[]'
        with (private/'test.log').open('w') as output:
            p=subprocess.Popen(['dbus-run-session','--','qs','--path',str(shell/'shell.qml')],env=env,cwd=ROOT,
                               stdout=output,stderr=subprocess.STDOUT,start_new_session=True)
            try:code=p.wait(timeout=35)
            except subprocess.TimeoutExpired:code=-1
            finally:
                if p.poll() is None:os.killpg(p.pid,signal.SIGTERM);p.wait(timeout=3)
        log=(private/'test.log').read_text()
        bad=('WULL_MIND=FAIL','ReferenceError:','TypeError:','SyntaxError:','Unable to assign','Binding loop','Failed to load configuration','FAIL!')
        if code or 'WULL_MIND=PASS' not in log or any(m in log for m in bad):
            print(log[-14000:]);raise SystemExit('Wull mind UI/helper proof failed')
        print(next(line for line in log.splitlines() if 'WULL_MIND=PASS' in line))
        saved=journal.read_text()
        assert 'mood: good\n' in saved and 'energy: high\n' in saved and 'private: preserved\n' in saved
finally:server.shutdown();server.server_close();thread.join(timeout=2)
