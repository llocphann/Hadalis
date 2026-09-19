pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

// Phase 0 only. Synthetic graph, no shell imports, Config, registry or source IO.
FocusScope {
    id: root
    width: 1160
    height: 760
    focus: true
    property bool curveRenderer: true
    property real zoom: 0.8
    property real panX: 32
    property real panY: 28
    property var selected: []
    property int selectedEdge: -1
    property int layoutRevision: 0
    property var edges: []
    property var paths: []
    property var history: []
    property int runtimeTick: 0
    property var trace: []
    property bool benchmarkRunning: false
    property int benchmarkFrame: 0
    property real benchmarkZoom: 0.8
    property real benchmarkPanX: 32
    property real benchmarkPanY: 28
    property int columns: 5
    property real mutationMs: 0
    readonly property int actualRenderer: wires.rendererType
    readonly property string rendererName: actualRenderer === Shape.CurveRenderer ? "curve" : actualRenderer === Shape.GeometryRenderer ? "geometry" : actualRenderer === Shape.SoftwareRenderer ? "software" : "unknown"
    readonly property int nodeCount: nodeModel.count
    readonly property int scopeDepth: history.length
    readonly property real nodeWidth: 156
    readonly property real nodeHeight: 70
    readonly property var edgeColors: ["#67c8f4", "#efbd68", "#d899ee", "#7ed5ad"]

    ListModel { id: nodeModel }

    function graphPoint(x, y) {
        return Qt.point((x - panX) / zoom, (y - panY) / zoom);
    }
    function zoomAround(x, y, nextZoom) {
        const point = graphPoint(x, y);
        zoom = Math.max(0.25, Math.min(2.5, nextZoom));
        panX = x - point.x * zoom;
        panY = y - point.y * zoom;
    }
    function endpoint(index, output) {
        layoutRevision;
        if (index < 0 || index >= nodeModel.count)
            return Qt.point(0, 0);
        const node = nodeModel.get(index);
        return Qt.point(node.px + (output ? nodeWidth : 0), node.py + nodeHeight / 2);
    }
    function curvePoint(edge, t) {
        const a = endpoint(edge.from, true), b = endpoint(edge.to, false);
        const bend = Math.max(55, Math.abs(b.x - a.x) / 2), u = 1 - t;
        return Qt.point(u*u*u*a.x + 3*u*u*t*(a.x+bend) + 3*u*t*t*(b.x-bend) + t*t*t*b.x,
                        u*u*u*a.y + 3*u*u*t*a.y + 3*u*t*t*b.y + t*t*t*b.y);
    }
    function segmentDistance(p, a, b) {
        const dx = b.x - a.x, dy = b.y - a.y, length2 = dx*dx + dy*dy;
        const t = length2 === 0 ? 0 : Math.max(0, Math.min(1, ((p.x-a.x)*dx + (p.y-a.y)*dy) / length2));
        return Math.hypot(p.x-a.x-t*dx, p.y-a.y-t*dy);
    }
    function hitEdge(x, y) {
        const p = graphPoint(x, y), tolerance = 7 / zoom;
        let best = tolerance, found = -1;
        for (let i = 0; i < edges.length; i++) {
            const e = edges[i], a = endpoint(e.from, true), b = endpoint(e.to, false);
            const bend = Math.max(55, Math.abs(b.x-a.x) / 2);
            if (p.x < Math.min(a.x, b.x-bend)-tolerance || p.x > Math.max(a.x+bend, b.x)+tolerance
                    || p.y < Math.min(a.y,b.y)-tolerance || p.y > Math.max(a.y,b.y)+tolerance)
                continue;
            let previous = a;
            for (let step = 1; step <= 32; step++) {
                const next = curvePoint(e, step/32), distance = segmentDistance(p, previous, next);
                if (distance < best) { best = distance; found = i; }
                previous = next;
            }
        }
        return found;
    }
    function setNodePosition(index, x, y) {
        nodeModel.setProperty(index, "px", x);
        nodeModel.setProperty(index, "py", y);
        layoutRevision++;
    }
    function nodeAt(x, y) {
        const p = graphPoint(x,y);
        for (let i=nodeCount-1; i>=0; i--) {
            const n=nodeModel.get(i);
            if (p.x>=n.px && p.x<=n.px+nodeWidth && p.y>=n.py && p.y<=n.py+nodeHeight) return i;
        }
        return -1;
    }
    function selectNode(index, additive) {
        const next = additive ? selected.slice() : [];
        const existing = next.indexOf(index);
        if (existing >= 0) next.splice(existing, 1); else next.push(index);
        selected = next;
        selectedEdge = -1;
        root.forceActiveFocus();
        if (nodeRepeater.itemAt(index)) nodeRepeater.itemAt(index).forceActiveFocus();
    }
    function selectRect(x1, y1, x2, y2) {
        const a = graphPoint(Math.min(x1,x2), Math.min(y1,y2));
        const b = graphPoint(Math.max(x1,x2), Math.max(y1,y2));
        const next = [];
        for (let i=0; i<nodeModel.count; i++) {
            const n = nodeModel.get(i);
            if (n.px <= b.x && n.px+nodeWidth >= a.x && n.py <= b.y && n.py+nodeHeight >= a.y)
                next.push(i);
        }
        selected = next;
    }
    function rebuildPaths() {
        wires.data = [];
        for (const path of paths) path.destroy();
        const next = [];
        for (let i=0; i<edges.length; i++) {
            const path = pathFactory.createObject(wires, {edgeIndex: i});
            wires.data.push(path);
            next.push(path);
        }
        paths = next;
    }
    function resetGraph(count: int): void {
        // Flush paths before replacing their model. All endpoints tolerate removal.
        edges = [];
        rebuildPaths();
        nodeModel.clear();
        columns=count>100 ? Math.ceil(Math.sqrt(count)) : 5;
        const labels = ["Config.bar", "Mpris.activePlayer", "Media.player", "Binding / title",
                        "Signal / clicked", "Action / play", "Connections", "Loader / popup",
                        "Condition", "Subflow"];
        for (let i=0; i<count; i++)
            nodeModel.append({stableId: "node-"+i, label: labels[i%labels.length], px: (i%columns)*230, py: Math.floor(i/columns)*115});
        const next = [];
        for (let i=0; i<count; i++) {
            if (i+1<count) next.push({from:i, to:i+1, kind:i%4});
            if (i+columns<count) next.push({from:i, to:i+columns, kind:(i+1)%4});
            if (count>100 && i+columns+2<count) next.push({from:i, to:i+columns+2, kind:(i+2)%4});
        }
        edges = next;
        rebuildPaths();
        selected = [];
        selectedEdge = -1;
        zoom = 0.8;
        panX = 32;
        panY = 28;
        layoutRevision++;
        root.forceActiveFocus();
    }
    function fitGraph(): void {
        const w=columns*230, h=Math.ceil(nodeCount/columns)*115;
        zoom=Math.min(viewport.width/w,viewport.height/h)*0.85;
        panX=(viewport.width-w*zoom)/2;
        panY=(viewport.height-h*zoom)/2;
        benchmarkZoom=zoom;
        benchmarkPanX=panX;
        benchmarkPanY=panY;
    }
    function visibleNodes(): int {
        let count=0;
        for (let i=0; i<nodeCount; i++) {
            const n=nodeModel.get(i), x=panX+n.px*zoom, y=panY+n.py*zoom;
            if (x<viewport.width && x+nodeWidth*zoom>0 && y<viewport.height && y+nodeHeight*zoom>0) count++;
        }
        return count;
    }
    function openSubflow(): void {
        if (selected.length === 0) return;
        const saved = [];
        for (let i=0; i<nodeModel.count; i++) saved.push(Object.assign({}, nodeModel.get(i)));
        history = history.concat([{nodes:saved, edges:edges, selected:selected, zoom:zoom, x:panX, y:panY, columns:columns}]);
        resetGraph(20);
    }
    function back(): void {
        if (history.length === 0) { selected = []; return; }
        const previous = history[history.length-1];
        history = history.slice(0,-1);
        edges = [];
        rebuildPaths();
        nodeModel.clear();
        for (const n of previous.nodes) nodeModel.append(n);
        edges = previous.edges;
        rebuildPaths();
        selected = previous.selected;
        columns = previous.columns;
        zoom = previous.zoom;
        panX = previous.x;
        panY = previous.y;
        layoutRevision++;
    }
    function snapshot(): string {
        const nodes = [];
        for (let i=0; i<nodeModel.count; i++) nodes.push(Object.assign({}, nodeModel.get(i)));
        return JSON.stringify({nodes:nodes, edgeCount:edges.length, selected:selected, selectedEdge:selectedEdge,
                               zoom:zoom, panX:panX, panY:panY, scopeDepth:scopeDepth, renderer:rendererName,
                               pathCount:paths.length, visibleNodes:visibleNodes(), runtimeTick:runtimeTick, traceCount:trace.length,
                               focus:root.activeFocus, mutationMs:mutationMs});
    }
    function nodeScreen(index: int): string {
        const n=nodeModel.get(index);
        return JSON.stringify({x:panX+(n.px+nodeWidth/2)*zoom, y:viewport.y+panY+(n.py+nodeHeight/2)*zoom});
    }
    function edgeScreen(index: int): string {
        const p=curvePoint(edges[index],0.5);
        return JSON.stringify({x:panX+p.x*zoom, y:viewport.y+panY+p.y*zoom});
    }

    Component {
        id: pathFactory
        ShapePath {
            id: edgePath
            required property int edgeIndex
            property var edge: root.edges[edgeIndex] || {from:-1,to:-1,kind:0}
            property point from: root.endpoint(edge.from,true)
            property point to: root.endpoint(edge.to,false)
            property real bend: Math.max(55,Math.abs(to.x-from.x)/2)
            strokeColor: root.selectedEdge === edgeIndex ? "white" : root.edgeColors[edge.kind]
            strokeWidth: root.selectedEdge === edgeIndex ? 3 : 1.5
            fillColor: "transparent"
            startX: from.x
            startY: from.y
            PathCubic {
                x: edgePath.to.x; y: edgePath.to.y
                control1X: edgePath.from.x+edgePath.bend; control1Y: edgePath.from.y
                control2X: edgePath.to.x-edgePath.bend; control2Y: edgePath.to.y
            }
        }
    }
    Rectangle { anchors.fill: parent; color: "#111821" }
    Text {
        x: 24; y: 15; color: "#e0e8f2"; font.pixelSize: 19
        text: "Workflow feasibility  /  " + root.nodeCount + " nodes  /  subflow " + root.scopeDepth
    }
    Text {
        x: 24; y: 42; color: "#9baec4"; font.pixelSize: 12
        text: "Drag node · Middle drag pan · Wheel/pinch zoom · Shift drag lasso · Ctrl click add · Arrows / Enter / Escape"
    }
    Item {
        id: viewport
        x: 0; y: 68; width: parent.width; height: parent.height-106
        clip: true
        TapHandler {
            acceptedButtons: Qt.LeftButton
            acceptedModifiers: Qt.NoModifier
            onTapped: {
                if (root.nodeAt(point.position.x,point.position.y)>=0) return;
                root.selectedEdge = root.hitEdge(point.position.x,point.position.y);
                root.selected = [];
                root.forceActiveFocus();
            }
        }
        DragHandler {
            id: pan
            target: null
            acceptedButtons: Qt.MiddleButton
            property real baseX: 0
            property real baseY: 0
            onActiveChanged: if (active) { baseX=root.panX; baseY=root.panY; }
            onActiveTranslationChanged: if (active) {
                root.panX=baseX+activeTranslation.x;
                root.panY=baseY+activeTranslation.y;
            }
        }
        DragHandler {
            id: lasso
            target: null
            acceptedModifiers: Qt.ShiftModifier
            acceptedButtons: Qt.LeftButton
            grabPermissions: PointerHandler.CanTakeOverFromAnything | PointerHandler.ApprovesTakeOverByAnything
            onActiveTranslationChanged: if (active)
                root.selectRect(centroid.pressPosition.x,centroid.pressPosition.y,centroid.position.x,centroid.position.y);
        }
        WheelHandler {
            target: null
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                const delta=event.pixelDelta.y !== 0 ? event.pixelDelta.y*3 : event.angleDelta.y;
                root.zoomAround(event.x,event.y,root.zoom*Math.pow(1.0015,delta));
                event.accepted=true;
            }
        }
        PinchHandler {
            id: pinch
            target: null
            property real baseZoom: 1
            property point pivot: Qt.point(0,0)
            onActiveChanged: if (active) { baseZoom=root.zoom; pivot=root.graphPoint(centroid.position.x,centroid.position.y); }
            function updateView() {
                if (!active) return;
                root.zoom=Math.max(0.25,Math.min(2.5,baseZoom*activeScale));
                root.panX=centroid.position.x-pivot.x*root.zoom;
                root.panY=centroid.position.y-pivot.y*root.zoom;
            }
            onActiveScaleChanged: updateView()
            onActiveTranslationChanged: updateView()
        }
        Item {
            id: world
            x: root.panX; y: root.panY; scale: root.zoom
            transformOrigin: Item.TopLeft
            Shape {
                id: wires
                preferredRendererType: root.curveRenderer ? Shape.CurveRenderer : Shape.GeometryRenderer
                asynchronous: false
            }
            Repeater {
                id: nodeRepeater
                model: nodeModel
                Rectangle {
                    id: nodeDelegate
                    required property int index
                    required property real px
                    required property real py
                    required property string label
                    required property string stableId
                    objectName: stableId
                    activeFocusOnTab: true
                    x: px; y: py; width: root.nodeWidth; height: root.nodeHeight; radius: 7
                    color: root.selected.indexOf(index)>=0 ? "#28465b" : "#1e2b3a"
                    border.color: root.selected.indexOf(index)>=0 ? "#b5ebff" : "#486078"
                    border.width: root.selected.indexOf(index)>=0 ? 2 : 1
                    Accessible.role: Accessible.Button
                    Accessible.name: label + " " + stableId
                    Accessible.description: "Synthetic workflow node. Enter opens a subflow."
                    Text { x:12; y:13; text:nodeDelegate.label; color:"#e0e8f2"; font.pixelSize:13 }
                    Text { x:12; y:40; text:nodeDelegate.stableId + "  ·  " + root.runtimeTick; color:"#91a7bc"; font.pixelSize:11 }
                    Rectangle { x:-4; y:31; width:8; height:8; radius:4; color:"#67c8f4" }
                    Rectangle { x:parent.width-4; y:31; width:8; height:8; radius:4; color:"#67c8f4" }
                    TapHandler {
                        acceptedModifiers: Qt.KeyboardModifierMask
                        onTapped: root.selectNode(nodeDelegate.index, (point.modifiers & Qt.ControlModifier) !== 0)
                    }
                    DragHandler {
                        id: moveNode
                        target: null
                        acceptedModifiers: Qt.NoModifier
                        acceptedButtons: Qt.LeftButton
                        grabPermissions: PointerHandler.CanTakeOverFromAnything | PointerHandler.ApprovesTakeOverByAnything
                        property real baseX: 0
                        property real baseY: 0
                        onActiveChanged: if (active) { baseX=nodeDelegate.px; baseY=nodeDelegate.py; }
                        onActiveTranslationChanged: if (active) {
                            const delta=Qt.point(centroid.scenePosition.x-centroid.scenePressPosition.x,centroid.scenePosition.y-centroid.scenePressPosition.y);
                            root.setNodePosition(nodeDelegate.index,baseX+delta.x/root.zoom,baseY+delta.y/root.zoom);
                        }
                    }
                }
            }
        }
        Rectangle {
            visible: lasso.active
            x: Math.min(lasso.centroid.pressPosition.x,lasso.centroid.position.x)
            y: Math.min(lasso.centroid.pressPosition.y,lasso.centroid.position.y)
            width: Math.abs(lasso.centroid.position.x-lasso.centroid.pressPosition.x)
            height: Math.abs(lasso.centroid.position.y-lasso.centroid.pressPosition.y)
            color: "#2244aadd"; border.color: "#85cbec"
        }
    }
    Text {
        x:24; y:parent.height-27; color:"#a7bacd"; font.pixelSize:12
        text: "Phase 0 sandbox · no source writes · renderer " + root.actualRenderer + " · zoom " + root.zoom.toFixed(2)
    }
    Keys.onPressed: event => {
        const index=selected.length ? selected[0] : 0;
        if (event.key===Qt.Key_Right) selectNode(Math.min(nodeCount-1,index+1),false);
        else if (event.key===Qt.Key_Left) selectNode(Math.max(0,index-1),false);
        else if (event.key===Qt.Key_Down) selectNode(Math.min(nodeCount-1,index+columns),false);
        else if (event.key===Qt.Key_Up) selectNode(Math.max(0,index-columns),false);
        else if (event.key===Qt.Key_Tab) selectNode((index+1)%nodeCount,false);
        else if (event.key===Qt.Key_Backtab) selectNode((index+nodeCount-1)%nodeCount,false);
        else if (event.key===Qt.Key_Return || event.key===Qt.Key_Enter) openSubflow();
        else if (event.key===Qt.Key_Escape) back();
        else if (event.key===Qt.Key_Plus || event.key===Qt.Key_Equal) zoomAround(viewport.width/2,viewport.height/2,zoom*1.2);
        else if (event.key===Qt.Key_Minus) zoomAround(viewport.width/2,viewport.height/2,zoom/1.2);
        else if (event.key===Qt.Key_0 && (event.modifiers & Qt.ControlModifier)) { zoom=0.8; panX=32; panY=28; }
        else { event.accepted=false; return; }
        event.accepted=true;
    }
    Timer {
        interval:16; repeat:true; running:root.benchmarkRunning
        onTriggered: {
            const start=Date.now(), t=root.benchmarkFrame++/30;
            root.setNodePosition(0,Math.sin(t)*25,Math.cos(t)*25);
            root.panX=root.benchmarkPanX+Math.sin(t/2)*20;
            root.panY=root.benchmarkPanY+Math.cos(t/2)*20;
            root.zoomAround(viewport.width/2,viewport.height/2,root.benchmarkZoom*(1+Math.sin(t/3)*0.1));
            root.selected=[0,1,5];
            root.runtimeTick++;
            root.trace=root.trace.concat(Array(16).fill(root.runtimeTick)).slice(-64);
            root.mutationMs=Date.now()-start;
        }
    }
    Component.onCompleted: resetGraph(20)
}
