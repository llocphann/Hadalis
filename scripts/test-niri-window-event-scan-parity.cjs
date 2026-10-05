#!/usr/bin/env node
"use strict";

const fs = require("fs");
const src = fs.readFileSync("services/NiriService.qml", "utf8");

function requireShape(ok, code) {
  if (!ok) process.exit(code);
}

requireShape(src.includes("const firstIndexById = new Map()"), 90);
requireShape(src.includes("if (!firstIndexById.has(windowId))"), 91);
requireShape(src.includes("const windowIndex = firstIndexById.get(windowId)"), 92);
requireShape(!src.includes("updatedWindows.findIndex(w => w.id === windowId)"), 93);

const closeStart = src.indexOf("function handleWindowClosed");
const closeEnd = src.indexOf("function handleWindowOpenedOrChanged", closeStart);
requireShape(closeStart >= 0 && closeEnd > closeStart, 94);
const closeBlock = src.slice(closeStart, closeEnd);
requireShape(closeBlock.includes("const updatedWindows = []"), 95);
requireShape(closeBlock.includes("if (closedWin === null)"), 96);
requireShape(!closeBlock.includes("currentList.find("), 97);
requireShape(!closeBlock.includes("currentList.filter("), 98);

function oldLayouts(currentList, changes) {
  if (!changes) return {scheduled:false};
  const updatedWindows = [...currentList];
  let hasChanges = false;
  for (const change of changes) {
    const windowId = change[0];
    const layoutData = change[1];
    const windowIndex = updatedWindows.findIndex(w => w.id === windowId);
    if (windowIndex < 0) continue;
    const updatedWindow = {};
    for (const prop in updatedWindows[windowIndex])
      updatedWindow[prop] = updatedWindows[windowIndex][prop];
    updatedWindow.layout = layoutData;
    updatedWindows[windowIndex] = updatedWindow;
    hasChanges = true;
  }
  if (!hasChanges) return {scheduled:false};
  return {scheduled:true, windows:updatedWindows};
}

function newLayouts(currentList, changes) {
  if (!changes) return {scheduled:false};
  const updatedWindows = [...currentList];
  const firstIndexById = new Map();
  for (let i=0; i<updatedWindows.length; ++i) {
    const windowId = updatedWindows[i].id;
    if (!firstIndexById.has(windowId))
      firstIndexById.set(windowId, i);
  }
  let hasChanges = false;
  for (const change of changes) {
    const windowId = change[0];
    const layoutData = change[1];
    const windowIndex = firstIndexById.get(windowId);
    if (windowIndex === undefined) continue;
    const updatedWindow = {};
    for (const prop in updatedWindows[windowIndex])
      updatedWindow[prop] = updatedWindows[windowIndex][prop];
    updatedWindow.layout = layoutData;
    updatedWindows[windowIndex] = updatedWindow;
    hasChanges = true;
  }
  if (!hasChanges) return {scheduled:false};
  return {scheduled:true, windows:updatedWindows};
}

function oldClose(currentList, id) {
  const closedWin = currentList.find(w => w.id === id);
  const closedWsId = closedWin?.workspace_id;
  const updatedWindows = currentList.filter(w => w.id !== id);
  return {windows:updatedWindows, closedWsId};
}

function newClose(currentList, id) {
  const updatedWindows = [];
  let closedWin = null;
  for (let i=0; i<currentList.length; ++i) {
    const window = currentList[i];
    if (window.id === id) {
      if (closedWin === null) closedWin = window;
      continue;
    }
    updatedWindows.push(window);
  }
  const closedWsId = closedWin?.workspace_id;
  return {windows:updatedWindows, closedWsId};
}

function normalizeLayouts(result) {
  if (!result.scheduled) return {scheduled:false};
  return {
    scheduled:true,
    windows:result.windows.map(w => ({
      id:w.id,
      workspace_id:w.workspace_id,
      app_id:w.app_id,
      is_floating:w.is_floating,
      marker:w.marker,
      layout:w.layout
    }))
  };
}

function assertRetainedIdentity(before, a, b, removedId) {
  if (a.windows.length !== b.windows.length) process.exit(20);
  for (let i=0; i<a.windows.length; ++i) {
    if (a.windows[i] !== b.windows[i]) process.exit(21);
    const original = before.find(w => w === a.windows[i]);
    if (!original || original.id === removedId) process.exit(22);
  }
}

let seed = 0x41c10eed >>> 0;
function rnd() {
  seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
  return seed;
}
const ids = [null, false, true, -3, -1, 0, 1, 2, 7, "1", "x", "DP"];
for (let c=0; c<50000; ++c) {
  const n = rnd() % 45;
  const windows = [];
  for (let i=0; i<n; ++i) {
    windows.push({
      id: ids[rnd() % ids.length],
      workspace_id: (rnd() % 7) - 1,
      app_id: "app-" + (rnd() % 9),
      is_floating: !!(rnd() & 1),
      marker: i,
      layout: {seed:rnd() % 1000}
    });
  }

  const changeCount = rnd() % 35;
  const changes = [];
  for (let i=0; i<changeCount; ++i) {
    changes.push([
      ids[rnd() % ids.length],
      {x:rnd() % 2000, y:rnd() % 2000, seq:i}
    ]);
  }

  const oldL = oldLayouts(windows, changes);
  const newL = newLayouts(windows, changes);
  if (JSON.stringify(normalizeLayouts(oldL)) !== JSON.stringify(normalizeLayouts(newL)))
    process.exit(10);

  if (oldL.scheduled !== newL.scheduled) process.exit(11);
  if (oldL.scheduled) {
    if (oldL.windows === windows || newL.windows === windows) process.exit(12);
    for (let i=0; i<windows.length; ++i) {
      const oldChanged = oldL.windows[i] !== windows[i];
      const newChanged = newL.windows[i] !== windows[i];
      if (oldChanged !== newChanged) process.exit(13);
    }
  }

  const closeId = ids[rnd() % ids.length];
  const oldC = oldClose(windows, closeId);
  const newC = newClose(windows, closeId);
  if (oldC.closedWsId !== newC.closedWsId) process.exit(14);
  if (oldC.windows.length !== newC.windows.length) process.exit(15);
  if (oldC.windows === windows || newC.windows === windows) process.exit(16);
  for (let i=0; i<oldC.windows.length; ++i) {
    if (oldC.windows[i] !== newC.windows[i]) process.exit(17);
  }
  assertRetainedIdentity(windows, oldC, newC, closeId);
}

console.log("niri-window-event-scan-parity: PASS (50000 randomized cases)");
