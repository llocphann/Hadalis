#!/usr/bin/env node
"use strict";

const fs = require("fs");

const power = fs.readFileSync("services/WidgetPowerManager.qml", "utf8");
const widget = fs.readFileSync(
  "modules/background/widgets/AbstractBackgroundWidget.qml", "utf8");

function requireShape(condition, code) {
  if (!condition)
    process.exit(code);
}

// §40.18 is deliberately not part of this candidate: keep both public
// reactive bindings independent so their dependency/signal topology is
// unchanged.
requireShape(power.includes(
  'readonly property bool widgetsActive: !root.shouldPauseForOutput("")'), 90);
requireShape(power.includes(
  'readonly property bool reducedMode: root.shouldPauseForOutput("")'), 91);
requireShape(widget.includes(
  "readonly property bool powerActive: WidgetPowerManager.widgetsActiveForOutput(root.outputName)"), 92);
requireShape(widget.includes(
  "readonly property bool powerReduced: WidgetPowerManager.reducedModeForOutput(root.outputName)"), 93);

// §40.19: preserve the public trigger helper but let shouldPauseForOutput()
// pass the eligibility it already resolved into a private builder.
requireShape(power.includes(
  "function _triggersForOutputWithEligibility(outputName: string, outputAllowed: bool): var"), 94);
requireShape(power.includes(
  "const outputAllowed = scopedOutput.length === 0\n            || DesktopWidgetLayout.outputAllowed(scopedOutput);"), 95);
requireShape(power.includes(
  "outputAllowed = DesktopWidgetLayout.outputAllowed(scopedOutput);"), 96);
requireShape(power.includes(
  "const triggers = root._triggersForOutputWithEligibility(outputName, outputAllowed);"), 97);

function oldDecision(c, trace) {
  const scoped = String(c.outputName ?? "");
  trace.push("normalize:outer");
  if (scoped.length > 0) {
    trace.push("allowed:first");
    if (!c.allowed)
      return true;
  }

  trace.push("enabled");
  if (!c.enabled)
    return false;

  trace.push("edit:early");
  if (c.edit)
    return false;

  trace.push("normalize:trigger");
  let outputDisabled = false;
  if (scoped.length > 0) {
    trace.push("allowed:trigger");
    outputDisabled = !c.allowed;
  }

  trace.push("pauseGame");
  const game = c.pauseGame ? (trace.push("game"), c.game) : false;
  trace.push("pauseFullscreen");
  const fullscreen = c.pauseFullscreen
    ? (trace.push("fullscreen"), c.fullscreen) : false;
  trace.push("pauseWindows");
  const windows = c.pauseWindows ? (trace.push("windows"), c.windows) : false;
  trace.push("edit:trigger");

  return outputDisabled || game || fullscreen || windows;
}

function newDecision(c, trace) {
  const scoped = String(c.outputName ?? "");
  trace.push("normalize:outer");
  let allowed = true;
  if (scoped.length > 0) {
    trace.push("allowed:first");
    allowed = c.allowed;
    if (!allowed)
      return true;
  }

  trace.push("enabled");
  if (!c.enabled)
    return false;

  trace.push("edit:early");
  if (c.edit)
    return false;

  trace.push("normalize:trigger");
  const outputDisabled = scoped.length > 0 && !allowed;

  trace.push("pauseGame");
  const game = c.pauseGame ? (trace.push("game"), c.game) : false;
  trace.push("pauseFullscreen");
  const fullscreen = c.pauseFullscreen
    ? (trace.push("fullscreen"), c.fullscreen) : false;
  trace.push("pauseWindows");
  const windows = c.pauseWindows ? (trace.push("windows"), c.windows) : false;
  trace.push("edit:trigger");

  return outputDisabled || game || fullscreen || windows;
}

function withoutDuplicateEligibility(trace) {
  return trace.filter(step => step !== "allowed:trigger");
}

let cases = 0;
for (const outputName of ["", "DP-1"]) {
  for (const allowed of [false, true])
  for (const enabled of [false, true])
  for (const edit of [false, true])
  for (const pauseGame of [false, true])
  for (const game of [false, true])
  for (const pauseFullscreen of [false, true])
  for (const fullscreen of [false, true])
  for (const pauseWindows of [false, true])
  for (const windows of [false, true]) {
    const c = {
      outputName, allowed, enabled, edit,
      pauseGame, game, pauseFullscreen, fullscreen, pauseWindows, windows
    };
    const before = [];
    const after = [];
    const oldValue = oldDecision(c, before);
    const newValue = newDecision(c, after);

    if (oldValue !== newValue)
      process.exit(10);
    if (JSON.stringify(withoutDuplicateEligibility(before))
        !== JSON.stringify(after))
      process.exit(11);

    const removed = before.filter(step => step === "allowed:trigger").length;
    const expectedRemoved =
      outputName !== "" && allowed && enabled && !edit ? 1 : 0;
    if (removed !== expectedRemoved)
      process.exit(12);
    cases++;
  }
}

if (cases !== 1024)
  process.exit(13);

console.log("widget-power-output-eligibility-parity: PASS (" + cases + " cases)");
