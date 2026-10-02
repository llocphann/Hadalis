#!/usr/bin/env node
// Real production JS geometry against synthetic OWNED output sizes and the
// actual shipped bar configuration. No compositor, screenshots, host files,
// native daemon, private configuration reads, network, or Git mutations.
"use strict";
const fs = require("node:fs");
const vm = require("node:vm");
const path = require("node:path");
const assert = require("node:assert/strict");
const root = path.resolve(__dirname, "..");
const read = p => fs.readFileSync(path.join(root, p), "utf8");
function load(p) {
    const cx = vm.createContext(Object.create(null), {
        codeGeneration: {strings: false, wasm: false}
    });
    vm.runInContext(read(p), cx, {timeout: 2000, filename: p});
    return cx;
}
const layout = load("modules/abyss/looks/AbyssLayout.js");
const geo = load("modules/abyss/looks/AbyssGeometry.js");
const slot = load("modules/abyss/companion/WullSurfacePlacement.js");
const host = load("modules/abyss/companion/WullHostPolicy.js");
const config = JSON.parse(read("defaults/config.json"));
const perimeter = read("modules/abyss/AbyssPerimeter.qml");
const barQml = read("modules/abyss/bar/AbyssBar.qml");
assert.equal(typeof layout.geometry, "function");
assert.equal(typeof layout.clearanceInsets, "function");
assert.equal(typeof layout.localSurfaces, "function");
assert.equal(typeof slot.slot, "function");
assert.equal(typeof geo.barZones, "function");
assert.equal(typeof host.alongPosition, "function");
for (const contract of [
    "bar.layoutRecords.map(record => ({",
    "ModuleLayout.clearanceInsets(nativeInsets,bar.visible ? bar.deformations : [],edge,along,span)",
    "window.companionFieldDepth()",
    "WullSurfacePlacement.slot({"
]) assert.ok(perimeter.includes(contract), contract);
for (const contract of [
    "Layout.resolve(", "Layout.seed(zones,edge,width,height)",
    "Layout.geometry(placements,width,height,layoutOptions,Appearance.fontSizeScale)",
    "Layout.localSurfaces(layoutRecords,width,height,layoutOptions,Appearance.fontSizeScale,AbyssStyle.barThickness)"
]) assert.ok(barQml.includes(contract), contract);
assert.equal(config.abyss.companion.enabled, false);

let checked = 0;
function caseFor(edge, height, local) {
    const width = 512, thickness = config.abyss.perimeter.thickness;
    const barHeight = Math.max(48, config.bar.height);
    const base = config.abyss.modules;
    // The local case uses a *single valid production-layout clock module*
    // so localSurfaces/clearanceInsets run on an actual layout record.
    const modules = local ?
        {...base, singleModuleExpansion: {[edge]: "local"}} : base;
    const options = {...layout.optionsForOutput(modules, "synthetic-output"),
                     edgeThickness: thickness};
    const source = local ?
        layout.normalize([{id: "clock", kind: "clock", edge,
                           position: .26, enabled: true, depth: 1}], edge) :
        layout.resolve(modules, "synthetic-output", layout.seed(
            geo.barZones(config.bar.verticalLayout, true,
                         config.bar.modules), edge, width, height));
    const records = layout.geometry(source, width, height, options, 1);
    const localRecords = layout.localSurfaces(
        records, width, height, options, 1, barHeight);
    const insets = layout.edgeInsetsForModules(
        source, options, 1, thickness, barHeight, false);
    const span = 112; // actual side companion implicitHeight at scale 1
    const rawDesired = host.alongPosition(height, span, .72);
    const chosen = slot.slot({
        edge, extent: height, footprint: span + 16,
        desired: rawDesired, clearance: 18, sideGuard: 16,
        cornerStart: insets.top + 32,
        cornerEnd: insets.bottom + 32,
        maxShift: Math.min(360, height * .28),
        records: records.map(r => ({
            edge: r.edge, along: r.along, span: r.span
        })), reservations: []
    });
    const sameEdge = records.filter(r => r.edge === edge);
    for (const r of sameEdge) {
        assert.ok(Number.isFinite(r.along) && Number.isFinite(r.span));
        assert.ok(r.span > 0 && r.along >= 0 &&
                  r.along + r.span <= height + 1e-5);
        checked++;
    }
    if (local) {
        assert.equal(sameEdge.length, 1);
        assert.equal(localRecords.length, 1);
        assert.equal(insets[edge], thickness);
        const near = layout.clearanceInsets(
            insets, localRecords, edge, sameEdge[0].along,
            sameEdge[0].span);
        assert.ok(near[edge] >= localRecords[0].depth,
                  "local module expands only intersecting field depth");
        const far = layout.clearanceInsets(
            insets, localRecords, edge,
            height + 50, span);
        assert.equal(far[edge], thickness);
        checked += 4;
    } else {
        assert.ok(sameEdge.length > 1, "real vertical default has modules");
        assert.ok(insets[edge] >= thickness);
        checked += 2;
    }
    if (chosen.qualified) {
        assert.ok(Number.isFinite(chosen.center));
        const half = (span + 16) / 2;
        const along = chosen.center - span / 2;
        const actualInsets = layout.clearanceInsets(
            insets, localRecords, edge, along, span);
        const depth = Math.max(thickness, actualInsets[edge]);
        // These are the same production constraints for the floating host.
        assert.ok(depth >= thickness && depth <= height);
        for (const record of sameEdge) {
            assert.ok(chosen.center + half + 18 <= record.along + 1e-6 ||
                      chosen.center - half - 18 >= record.along + record.span - 1e-6,
                      "Wull may not intersect actual measured module record");
        }
        assert.ok(chosen.center >= insets.top + 32 + half + 16);
        assert.ok(chosen.center <= height - insets.bottom - 32 - half - 16);
        checked += 4;
    } else {
        assert.ok(["NO_FREE_SEGMENT", "NO_NEARBY_CLEARANCE",
                   "INSUFFICIENT_EDGE"].includes(chosen.reason),
                   "dense layout hides Wull instead of overlapping");
        checked++;
    }
    return {edge, local, height, moduleCount: sameEdge.length,
            slotQualified: chosen.qualified,
            depthCategory: chosen.qualified ? "SOURCE_LAYOUT_APPLIED" :
                           "HOST_HIDDEN_NO_SAFE_SLOT"};
}
const observations = [];
for (const edge of ["left", "right"]) {
    for (const height of [512, 960]) {
        for (const local of [false, true])
            observations.push(caseFor(edge, height, local));
    }
}
assert.equal(observations.length, 8);
assert.ok(checked >= 30);
const a = observations.filter(x => x.edge === "left");
const b = observations.filter(x => x.edge === "right");
for (let i=0; i<a.length; i++) {
    assert.equal(a[i].moduleCount, b[i].moduleCount);
    assert.equal(a[i].slotQualified, b[i].slotQualified);
}
console.log("WULL_ACTUAL_PANEL_LAYOUT_GATE=PASS");
console.log("REAL_SOURCE_CASES=8");
console.log("REAL_SOURCE_ASSERTIONS=" + checked);
console.log("HOST_DESKTOP_OR_CAPTURE=NOT_ACCESSED");
console.log("LIVE_BAR_MODULES_AND_NATIVE_INPUT=NOT_TESTED");
