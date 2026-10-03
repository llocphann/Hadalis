#!/usr/bin/env python3
"""Compare own-item GPU pixels for a supplied pre-optimization Wull source.

The baseline is explicit and hashed. Both components render in one isolated
QML window with frozen equal inputs. First use --self-control to qualify the
capture path; a failed identical-source control is INCONCLUSIVE, never PASS.
This is pixel parity evidence, not FPS, desktop acceptance or a claim that
new locomotion equals old idle behavior. No differing-pixel tolerance is used.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import runpy
import shutil
import signal
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[1]
QML='''
//@ pragma UseQApplication
//@ pragma Env INIR_STANDALONE_WINDOW=1
import QtQuick
import QtQuick.Window
import Quickshell
import qs.modules.abyss.companion
import "baseline" as Before
Window {
    id: root
    width: 420; height: 220; visible: true; color: "transparent"
    property int index: 0
    property int waiting: 0
    property bool busy: false
    property bool after: false
    property var cases: CASES
    Before.WullBaseline { id: old; x: 60; y: 50; visible: !root.after; motionEnabled: false }
    // Equal world transforms remove position as a comparison variable.
    // Each capture is own-item and waits for its own visible render frames.
    WaterDropletBody { id: current; x: 60; y: 50; visible: root.after; motionEnabled: false }
    function find(item) {
        if(item.objectName === "wullLocomotion") return item
        for(const child of item.children) { const result=find(child); if(result) return result }
        return null
    }
    function apply() {
        const c=cases[index]
        for(const item of [old,current]) {
            item.expression=c.expression; item.viewYaw=c.yaw; item.renderQuality=c.quality
            item.translucency=c.translucency; item.shimmer=c.shimmer; item.shine=c.shine
            item.gazeX=c.gaze; item.walking=c.walk>=0
            const gait=find(item)
            gait.phase=Math.max(0,c.walk); gait.weight=c.walk>=0 ? 1 : 0
        }
    }
    Component.onCompleted: apply()
    Timer {
        interval: 70; repeat: true; running: true
        onTriggered: {
            if(root.busy || !old.materialReady || !current.materialReady) return
            if(root.waiting++<3) return
            root.busy=true
            const folder=Quickshell.env("WULL_LOSSLESS_FOLDER")
            const actor=root.after ? current : old
            actor.grabToImage(function(result) {
                const name=(root.after ? "after-" : "before-")+root.index+".png"
                if(!result.saveToFile(folder+"/"+name)) { Qt.quit(); return }
                if(!root.after) root.after=true
                else {
                    root.index++
                    if(root.index===root.cases.length) { console.log("WULL_LOSSLESS_CAPTURE=PASS"); Qt.quit(); return }
                    root.after=false; root.apply()
                }
                root.waiting=0; root.busy=false
            },Qt.size(304,368))
        }
    }
}
'''


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    source=parser.add_mutually_exclusive_group(required=True)
    source.add_argument('--baseline',type=Path)
    source.add_argument('--self-control',action='store_true',help='compare identical candidate source; qualify capture before attribution')
    parser.add_argument('--output',type=Path,required=True,help='new output directory')
    args=parser.parse_args()
    candidate=ROOT/'modules/abyss/companion/WaterDropletBody.qml'
    baseline=candidate if args.self_control else args.baseline.resolve()
    output=args.output.resolve()
    if not baseline.is_file() or output.exists(): parser.error('require an explicit existing baseline and a new output directory')
    baseline_digest=hashlib.sha256(baseline.read_bytes()).hexdigest()
    candidate_digest=hashlib.sha256(candidate.read_bytes()).hexdigest()
    from PIL import Image, ImageChops
    cases=[]
    for tier in ('performance','balanced','quality'):
        for yaw,expression in ((0,'idle'),(35,'excited'),(90,'working'),(180,'sleepy')):
            cases.append(dict(quality=tier,yaw=yaw,expression=expression,translucency=.16,shimmer=.41,shine=.5,gaze=.3,walk=-1))
    for phase in (0,.125,.25,.375,.5,.625,.75,.875):
        cases.append(dict(quality='quality',yaw=32,expression='idle',translucency=.28,shimmer=.73,shine=0,gaze=0,walk=phase))
    output.mkdir(parents=True)
    core=runpy.run_path(str(ROOT/'scripts/wull-manual-visual-matrix.py'))
    with tempfile.TemporaryDirectory(prefix='wull-lossless-') as temporary:
        shell,xdg=core['staged'](Path(temporary))
        component=shell/'baseline'; component.mkdir()
        (component/'WullBaseline.qml').write_bytes(baseline.read_bytes())
        for name in ('WullExpressions.js','WullPreferences.js','WullMotion.qml','WullMotionData.js','WaterDropletFace.qml','WaterDropletMaterial.frag.qsb','WaterDropletContact.frag.qsb'):
            shutil.copyfile(ROOT/'modules/abyss/companion'/name,component/name)
        (shell/'shell.qml').write_text(QML.replace('CASES',json.dumps(cases)))
        env=core['private_env'](xdg,output)
        env.pop('WULL_VISUAL_MATRIX_PRIVATE_FILE',None)
        env.update(QT_QPA_PLATFORM='wayland',QSG_RHI_BACKEND='opengl',QT_QUICK_BACKEND='rhi',
            XDG_RUNTIME_DIR=os.environ['XDG_RUNTIME_DIR'],WAYLAND_DISPLAY=os.environ['WAYLAND_DISPLAY'],
            WULL_LOSSLESS_FOLDER=str(output))
        with (output/'capture.log').open('w') as log:
            proc=subprocess.Popen(['dbus-run-session','--','qs','--path',str(shell/'shell.qml')],env=env,cwd=ROOT,
                stdout=log,stderr=subprocess.STDOUT,stdin=subprocess.DEVNULL,start_new_session=True)
            try: code=proc.wait(timeout=55)
            finally:
                if proc.poll() is None: os.killpg(proc.pid,signal.SIGTERM); proc.wait(timeout=3)
        log=(output/'capture.log').read_text()
        assert code==0 and 'WULL_LOSSLESS_CAPTURE=PASS' in log,log[-3000:]
        assert not any(marker in log for marker in ('TypeError:','ReferenceError:','Unable to assign','SyntaxError:'))
    results=[]
    for i,case in enumerate(cases):
        before=Image.open(output/f'before-{i}.png').convert('RGBA')
        after=Image.open(output/f'after-{i}.png').convert('RGBA')
        diff=ImageChops.difference(before,after)
        changed=sum(any(pixel) for pixel in diff.get_flattened_data())
        results.append(dict(case=case,changed_pixels=changed,maximum_channel_error=max(v[1] for v in diff.getextrema())))
    assert candidate_digest==hashlib.sha256(candidate.read_bytes()).hexdigest(), 'candidate changed during capture'
    report=dict(baseline_sha256=baseline_digest,
        candidate_sha256=candidate_digest,
        cases=results,all_pixels_identical=all(r['changed_pixels']==0 for r in results))
    report['status']='PASS' if report['all_pixels_identical'] else (
        'INCONCLUSIVE_SELF_CONTROL' if baseline_digest==candidate_digest else 'FAIL_PIXEL_DIFFERENCE')
    (output/'result.json').write_text(json.dumps(report,indent=2)+'\n')
    if not report['all_pixels_identical']:
        print('WULL_LOSSLESS_GPU_PIXELS_'+report['status'])
        raise SystemExit(2 if baseline_digest==candidate_digest else 1)
    print('WULL_LOSSLESS_GPU_PIXELS_PASS cases='+str(len(results)))


if __name__=='__main__': main()
