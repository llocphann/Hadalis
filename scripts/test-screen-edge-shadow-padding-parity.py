#!/usr/bin/env python3
"""Require pixel-identical Screen Edge shadow with MultiEffect auto-padding disabled."""
from pathlib import Path
import os, shutil, subprocess, tempfile
from PIL import Image, ImageChops

if not shutil.which("qs"):
    raise SystemExit("qs is required for Screen Edge shadow pixel parity")

QML = r'''
//@ pragma UseQApplication
import QtQuick
import QtQuick.Window
import QtQuick.Shapes
import QtQuick.Effects
Window {
    id: root
    width: 420; height: 260; visible: true; color: "transparent"
    property bool optimized: false
    property int frames: 0
    property bool busy: false
    Item {
        id: host; anchors.fill: parent
        Shape {
            id: shape; anchors.fill: parent
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                blurMax: 15
                shadowBlur: 1.0
                autoPaddingEnabled: !root.optimized
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
                shadowColor: Qt.rgba(0,0,0,0.70)
            }
            ShapePath {
                id: path
                fillColor: "#172630"
                fillRule: ShapePath.OddEvenFill
                strokeColor: "transparent"; strokeWidth: -1
                readonly property real l: 10
                readonly property real t: 10
                readonly property real rgt: shape.width-10
                readonly property real b: shape.height-10
                readonly property real r: 25
                startX: -50; startY: -50
                PathLine { x: shape.width+50; y: -50 }
                PathLine { x: shape.width+50; y: shape.height+50 }
                PathLine { x: -50; y: shape.height+50 }
                PathLine { x: -50; y: -50 }
                PathMove { x: path.l+path.r; y: path.t }
                PathLine { x: path.rgt-path.r; y: path.t }
                PathArc { x: path.rgt; y: path.t+path.r; radiusX:path.r; radiusY:path.r; direction:PathArc.Clockwise }
                PathLine { x: path.rgt; y: path.b-path.r }
                PathArc { x: path.rgt-path.r; y: path.b; radiusX:path.r; radiusY:path.r; direction:PathArc.Clockwise }
                PathLine { x: path.l+path.r; y: path.b }
                PathArc { x: path.l; y: path.b-path.r; radiusX:path.r; radiusY:path.r; direction:PathArc.Clockwise }
                PathLine { x: path.l; y: path.t+path.r }
                PathArc { x: path.l+path.r; y: path.t; radiusX:path.r; radiusY:path.r; direction:PathArc.Clockwise }
            }
        }
    }
    Timer {
        interval: 50; repeat: true; running: true
        onTriggered: {
            if (root.busy || ++root.frames < 4) return
            root.busy = true
            host.grabToImage(function(result) {
                const dir=Qt.resolvedUrl(".").toString().replace("file://","")
                if (!result.saveToFile(dir+"/"+(root.optimized?"after.png":"before.png"))) {
                    console.error("EDGE_CAPTURE_SAVE_FAIL"); Qt.quit(); return
                }
                if (!root.optimized) {
                    root.optimized=true; root.frames=0; root.busy=false
                } else {
                    console.log("EDGE_CAPTURE_PASS"); Qt.quit()
                }
            })
        }
    }
}
'''

with tempfile.TemporaryDirectory(prefix="hadalis-edge-shadow-") as tmp:
    root=Path(tmp)
    (root/"shell.qml").write_text(QML, encoding="utf-8")
    env=os.environ.copy()
    env.update(QT_QPA_PLATFORM="offscreen", QSG_RHI_BACKEND="opengl", QT_QUICK_BACKEND="rhi")
    run=subprocess.run(["qs","-p",str(root),"--no-color"],env=env,text=True,
                       stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=15)
    assert run.returncode == 0 and "EDGE_CAPTURE_PASS" in run.stdout, run.stdout[-4000:]
    before=Image.open(root/"before.png").convert("RGBA")
    after=Image.open(root/"after.png").convert("RGBA")
    diff=ImageChops.difference(before,after)
    changed=sum(any(px) for px in diff.get_flattened_data())
    maximum=max(high for _,high in diff.getextrema())
    assert changed == 0 and maximum == 0, (changed,maximum)

print("SCREEN_EDGE_SHADOW_PADDING_PIXEL_PARITY_PASS")
