#!/usr/bin/env python3
"""Standalone Spike B. Requires PySide6; never imports or launches Hadalis."""

import argparse
from collections import deque
from hashlib import sha256
import json
import math
import os
from pathlib import Path
import platform
import statistics
import subprocess
import time


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--test", action="store_true", help="Deliver real Qt pointer/key/touch events, then exit")
    ap.add_argument("--benchmark", type=float, default=0, metavar="SECONDS")
    ap.add_argument("--nodes", type=int, default=20)
    ap.add_argument("--renderer", choices=["curve", "geometry"], default="curve")
    ap.add_argument("--screenshot", type=Path)
    ap.add_argument("--output", type=Path)
    ap.add_argument("--qml-source", type=Path, default=Path(__file__).with_name("GraphSandbox.qml"),
                    help="Replay an immutable baseline QML file with this same measurement harness")
    ap.add_argument("--warmup", type=float, default=.5)
    ap.add_argument("--rebuild-every", type=float, default=0, metavar="SECONDS")
    ap.add_argument("--sample-every", type=float, default=10, metavar="SECONDS")
    ap.add_argument("--screen", help="Explicit compositor output name; fail if absent")
    args, qt_args = ap.parse_known_args()
    if any(not arg.startswith("-qmljsdebugger=") for arg in qt_args):
        ap.error("Unknown arguments: " + repr(qt_args))
    if not 20 <= args.nodes <= 500 or min(args.benchmark, args.warmup, args.rebuild_every) < 0 or args.sample_every <= 0:
        ap.error("Use 20..500 nodes and a nonnegative benchmark duration")
    from PySide6.QtCore import QEvent, QPoint, QPointF, Qt, QTimer, QUrl, qVersion
    from PySide6.QtGui import QGuiApplication, QMouseEvent
    from PySide6.QtQuick import QQuickItem, QQuickView
    from PySide6.QtTest import QTest

    if qt_args:
        from PySide6.QtQml import QQmlDebuggingEnabler
        QQmlDebuggingEnabler.enableDebugging(True)
    app = QGuiApplication(["workflow-sandbox", *qt_args])
    view = QQuickView()
    if args.screen:
        screens = {screen.name(): screen for screen in app.screens()}
        if args.screen not in screens:
            raise RuntimeError(f"Missing output {args.screen}; available: {list(screens)}")
        view.setScreen(screens[args.screen])
    view.setResizeMode(QQuickView.ResizeMode.SizeRootObjectToView)
    view.resize(1160,760)
    view.setTitle("Hadalis Phase 0 graph sandbox")
    warnings = []
    view.engine().warnings.connect(lambda items: warnings.extend(e.toString() for e in items))
    view.setSource(QUrl.fromLocalFile(str(args.qml_source.resolve())))
    if view.errors():
        raise RuntimeError([e.toString() for e in view.errors()])
    root = view.rootObject()
    root.setProperty("curveRenderer", args.renderer == "curve")
    root.resetGraph(args.nodes)
    view.show()
    QTest.qWait(350)

    def state():
        return json.loads(root.snapshot())

    def object_count():
        # QML delegates can have a visual parent distinct from QObject parent.
        seen, pending = set(), [root]
        while pending:
            obj = pending.pop()
            if obj in seen:
                continue
            seen.add(obj)
            pending.extend(obj.children())
            if isinstance(obj, QQuickItem):
                pending.extend(obj.childItems())
        return len(seen)

    def pos(method, index):
        p = json.loads(getattr(root, method)(index))
        return QPoint(round(p["x"]), round(p["y"]))

    def click(index, modifiers=Qt.KeyboardModifier.NoModifier):
        QTest.mouseClick(view, Qt.MouseButton.LeftButton, modifiers, pos("nodeScreen", index))
        QTest.qWait(25)

    def drag(start, end, button, modifiers=Qt.KeyboardModifier.NoModifier):
        QTest.mousePress(view, button, modifiers, start)
        for step in range(1, 9):
            # QTest.mouseMove drops modifiers on this Qt build. Deliver complete
            # pointer state so Shift-lasso is tested as an actual held gesture.
            point = start + (end-start)*step/8
            app.sendEvent(view, QMouseEvent(QEvent.Type.MouseMove, QPointF(point),
                QPointF(view.mapToGlobal(point)), Qt.MouseButton.NoButton, button, modifiers))
            QTest.qWait(15)
        QTest.mouseRelease(view, button, modifiers, end)
        QTest.qWait(25)

    def expect(condition, label):
        if not condition:
            raise AssertionError(label + ": " + root.snapshot())
        checks.append(label)

    checks, failure = [], None
    try:
        if args.test:
            root.resetGraph(250)
            routes_before = json.loads(root.routeSnapshot())
            root.setNodePosition(120, 641, 329)
            routes_after = json.loads(root.routeSnapshot())
            nodes_after = state()["nodes"]
            affected = 0
            for before, after in zip(routes_before, routes_after):
                affected += 120 in (after["fromNode"], after["toNode"])
                node_a, node_b = nodes_after[after["fromNode"]], nodes_after[after["toNode"]]
                assert (after["fromX"], after["fromY"], after["toX"], after["toY"]) == (
                    node_a["px"]+156, node_a["py"]+35, node_b["px"], node_b["py"]+35)
                assert after["updates"]-before["updates"] == int(120 in (after["fromNode"], after["toNode"]))
            expect(0 < affected < len(routes_after) and state()["lastRoutedPaths"] == affected,
                   "dense node move updates exactly its incident routes with correct endpoints")
            root.fitGraph()
            root.zoomAround(500,300,.6)
            expect(json.loads(root.routeSnapshot()) == routes_after, "view transforms do not reroute geometry")
            root.resetGraph(args.nodes)
            expect(state()["pathCount"] == state()["edgeCount"] > 0, "one Shape contains all routed paths")
            click(0)
            expect(state()["selected"] == [0], "node tap selects without background clearing it")
            click(1, Qt.KeyboardModifier.ControlModifier)
            expect(state()["selected"] == [0, 1], "Ctrl-click adds to selection")
            QTest.keyClick(view, Qt.Key.Key_Right)
            expect(state()["selected"] == [1] and view.activeFocusItem().objectName() == "node-1", "arrow navigation moves node focus")
            QTest.keyClick(view, Qt.Key.Key_Tab)
            expect(view.activeFocusItem().objectName() == "node-2", "Tab moves keyboard focus")
            before = state()
            QTest.keyClick(view, Qt.Key.Key_Return)
            expect(state()["scopeDepth"] == 1 and len(state()["nodes"]) == 20, "Enter navigates into subflow")
            QTest.keyClick(view, Qt.Key.Key_Escape)
            expect(state()["scopeDepth"] == 0 and state()["nodes"] == before["nodes"], "Escape restores parent graph and layout")
            before = state()
            pan_start = QPoint(view.width()-150,view.height()-140)
            drag(pan_start, pan_start+QPoint(80,30), Qt.MouseButton.MiddleButton)
            after = state()
            expect(abs(after["panX"]-before["panX"]-80)<2 and after["nodes"] == before["nodes"], "middle drag pans without moving graph metadata")
            point = QPointF(view.width()*0.7,view.height()*0.75)
            # QtTest 6.11 forwards wheel positions through the window-system
            # interface in device pixels on this host. QML stays in logical
            # coordinates; the pivot assertion detects any future API change.
            wheel_point = point*view.devicePixelRatio()
            before = state()
            graph_point = ((point.x()-before["panX"])/before["zoom"], (point.y()-68-before["panY"])/before["zoom"])
            QTest.wheelEvent(view,wheel_point,QPoint(0,120))
            QTest.qWait(25)
            after = state()
            mapped = (after["panX"]+graph_point[0]*after["zoom"], 68+after["panY"]+graph_point[1]*after["zoom"])
            expect(after["zoom"] > before["zoom"] and math.dist(mapped, (point.x(),point.y())) < 0.1
                   and after["nodes"] == before["nodes"], "wheel zoom preserves cursor pivot and layout")
            before = state()
            QTest.wheelEvent(view,wheel_point,QPoint(),QPoint(0,24))
            QTest.qWait(25)
            expect(state()["zoom"] > before["zoom"] and state()["nodes"] == before["nodes"], "pixel-only touchpad scroll changes zoom")
            root.resetGraph(20)
            before, start = state(), pos("nodeScreen", 0)
            drag(start, start+QPoint(64,40), Qt.MouseButton.LeftButton)
            after = state()
            expect(abs(after["nodes"][0]["px"]-80)<2 and abs(after["nodes"][0]["py"]-50)<2
                   and after["panX"] == before["panX"], "node drag changes only node layout in graph units")
            root.resetGraph(20)
            QTest.mouseClick(view, Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier, pos("edgeScreen",0))
            expect(state()["selectedEdge"] == 0, "wire is picked independently of Shape containment")
            for scale in (0.5, 1.0, 2.0):
                root.setProperty("zoom", scale)
                point = pos("edgeScreen",0)
                expect(root.hitEdge(point.x(),point.y()-68+5) == 0, f"wire hit tolerance remains in screen pixels at zoom {scale}")
            root.resetGraph(20)
            drag(QPoint(22,86),QPoint(352,162),Qt.MouseButton.LeftButton,Qt.KeyboardModifier.ShiftModifier)
            expect(state()["selected"] == [0,1], "Shift-drag lasso selects the enclosed nodes")
            device = QTest.createTouchDevice()
            before = state()
            center = QPoint(view.width()//2,view.height()-70)
            QTest.touchEvent(view,device).press(0,center-QPoint(50,0),view).press(1,center+QPoint(50,0),view).commit()
            for delta in (10,20,35,50):
                QTest.touchEvent(view,device).move(0,center-QPoint(50+delta,0),view).move(1,center+QPoint(50+delta,0),view).commit()
                QTest.qWait(20)
            QTest.touchEvent(view,device).release(0,center-QPoint(100,0),view).release(1,center+QPoint(100,0),view).commit()
            expect(state()["zoom"] > before["zoom"] and state()["nodes"] == before["nodes"], "synthetic two-point pinch zoom preserves graph layout")
            root.resetGraph(args.nodes)
            QTest.qWait(50)
            count = object_count()
            for _ in range(5):
                root.resetGraph(args.nodes)
                QTest.qWait(30)
            expect(object_count() == count, "rebuilding graph does not accumulate QObject delegates")
        if warnings:
            raise AssertionError("QML warnings: " + repr(warnings))
    except Exception as exc:
        failure = repr(exc)

    def rss_kib():
        for line in Path("/proc/self/status").read_text().splitlines():
            if line.startswith("VmRSS:"):
                return int(line.split()[1])
        return None

    # Fixed-size timing buffers cannot masquerade as a leak during a long soak.
    sample_capacity = 16384
    intervals, heartbeat, mutation = (deque(maxlen=sample_capacity) for _ in range(3))
    sample_totals = {"frames":0, "heartbeat":0}
    last_frame, last_tick = [time.perf_counter()], [time.perf_counter()]

    def frame():
        now = time.perf_counter()
        intervals.append((now-last_frame[0])*1000)
        sample_totals["frames"] += 1
        last_frame[0] = now

    def pulse():
        now = time.perf_counter()
        heartbeat.append((now-last_tick[0])*1000)
        sample_totals["heartbeat"] += 1
        last_tick[0] = now
        mutation.append(root.property("mutationMs"))

    before_rss = rss_kib()
    timer = QTimer()
    memory_timer, rebuild_timer = QTimer(), QTimer()
    memory_samples, rebuild_samples = [], []
    started = time.perf_counter()
    def sample_memory():
        memory_samples.append({"seconds":round(time.perf_counter()-started,3),
            "rss_kib":rss_kib(), "qobjects":object_count(),
            "paths":state()["pathCount"], "trace_retained":state()["traceCount"]})
    def rebuild():
        began = time.perf_counter()
        root.resetGraph(args.nodes)
        root.fitGraph()
        rebuild_samples.append({"seconds":round(began-started,3),
            "reset_ms":round((time.perf_counter()-began)*1000,3)})
    if args.benchmark and not failure:
        root.fitGraph()
        root.setProperty("benchmarkRunning", True)
        QTest.qWait(round(args.warmup*1000))
        before_rss = rss_kib()
        started = time.perf_counter()
        sample_memory()
        memory_timer.timeout.connect(sample_memory)
        memory_timer.start(round(args.sample_every*1000))
        if args.rebuild_every:
            rebuild_timer.timeout.connect(rebuild)
            rebuild_timer.start(round(args.rebuild_every*1000))
        last_frame[0] = last_tick[0] = time.perf_counter()
        view.frameSwapped.connect(frame)
        timer.timeout.connect(pulse)
        timer.start(10)
        QTest.qWait(round(args.benchmark*1000))
        root.setProperty("benchmarkRunning", False)
        timer.stop()
        memory_timer.stop()
        rebuild_timer.stop()
        view.frameSwapped.disconnect(frame)
        QTest.qWait(100)
        sample_memory()
    if args.screenshot:
        if not view.grabWindow().save(str(args.screenshot)):
            failure = failure or "Could not save screenshot"
    if warnings:
        failure = failure or ("QML warnings: " + repr(warnings))

    def stats(values):
        values = sorted(list(values)[3:])  # Ignore startup samples.
        return {"samples":len(values), "p50":round(statistics.median(values),3),
                "p95":round(values[min(len(values)-1,math.ceil(len(values)*0.95)-1)],3),
                "max":round(max(values),3)} if values else None

    try:
        source_revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=Path(__file__).parent, text=True).strip()
    except (OSError, subprocess.CalledProcessError):
        source_revision = None
    result = {"spike":"B", "qt":qVersion(), "platform":platform.platform(),
              "source_revision":source_revision, "qml_source":str(args.qml_source),
              "qml_sha256":sha256(args.qml_source.read_bytes()).hexdigest(),
              "harness_sha256":sha256(Path(__file__).read_bytes()).hexdigest(),
              "qpa":app.platformName(), "device_pixel_ratio":view.devicePixelRatio(),
              "window_logical_size":[view.width(),view.height()],
              "graphics_api":str(view.rendererInterface().graphicsApi()),
              "render_loop":os.environ.get("QSG_RENDER_LOOP", "Qt default"),
              "screen_name":view.screen().name(),
              "screens":[{"name":s.name(), "dpr":s.devicePixelRatio(), "size":[s.size().width(),s.size().height()]} for s in app.screens()],
              "requested_renderer":args.renderer, "actual_renderer":state()["renderer"],
              "renderer_request_honored":args.renderer == state()["renderer"],
              "nodes":len(state()["nodes"]), "edges":state()["edgeCount"],
              "visible_nodes_at_end":state()["visibleNodes"],
              "qobjects":object_count(), "input_checks":checks,
              "failure":failure, "qml_warnings":warnings,
              "benchmark_seconds":args.benchmark, "frame_intervals_ms":stats(intervals),
              "gui_timer_intervals_ms":stats(heartbeat), "model_mutation_ms":stats(mutation),
              "rss_before_kib":before_rss, "rss_after_kib":rss_kib(), "trace_retained":state()["traceCount"],
              "warmup_seconds":args.warmup, "last_routed_paths":state().get("lastRoutedPaths"),
              "timing_sample_capacity":sample_capacity, "timing_sample_totals":sample_totals,
              "timing_window":"last 16384 samples, excluding first three retained samples",
              "memory_samples":memory_samples, "rebuild_every_seconds":args.rebuild_every,
              "rebuild_samples":rebuild_samples,
              "limitations":["Synthetic graph shaped after Bar/Media categories; no resolved production IR.",
                             "Combined node/wire mutation, pan/zoom, multi-selection, runtime values and bounded trace bursts.",
                             "Frame-swapped intervals are cadence observations, not GPU duration or a visible-node budget.",
                             "Synthetic touch events do not prove hardware touchpad gesture arbitration.",
                             "No live shell, multiple-output/hotplug/lock/reload integration."]}
    if args.output:
        args.output.write_text(json.dumps(result,indent=2)+"\n")
    print(json.dumps(result,indent=2))
    if not args.test and not args.benchmark and not args.screenshot:
        return app.exec()
    view.close()
    return int(failure is not None)


if __name__ == "__main__":
    raise SystemExit(main())
