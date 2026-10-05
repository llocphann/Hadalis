#!/usr/bin/env node
"use strict";

const fs = require("fs");
const src = fs.readFileSync("modules/settings/SidebarsConfig.qml", "utf8");

function requireShape(ok, code) {
  if (!ok) process.exit(code);
}

requireShape(src.includes("const index = current.indexOf(widgetId)"), 90);
requireShape(src.includes("const included = index !== -1"), 91);
requireShape(src.includes("(widgetId !== widgetId && current.includes(widgetId))"), 92);
requireShape(src.includes("current.splice(index, 1)"), 93);

function oldSetWidget(source, widgetId, active) {
  const current = [...source];
  let published = false;
  let branch = "noop";

  if (active && !current.includes(widgetId)) {
    current.push(widgetId);
    published = true;
    branch = "add";
  } else if (!active && current.includes(widgetId)) {
    current.splice(current.indexOf(widgetId), 1);
    published = true;
    branch = "remove";
  }

  return {current, published, branch};
}

function newSetWidget(source, widgetId, active) {
  const current = [...source];
  const index = current.indexOf(widgetId);
  const included = index !== -1
    || (widgetId !== widgetId && current.includes(widgetId));
  let published = false;
  let branch = "noop";

  if (active && !included) {
    current.push(widgetId);
    published = true;
    branch = "add";
  } else if (!active && included) {
    current.splice(index, 1);
    published = true;
    branch = "remove";
  }

  return {current, published, branch};
}

function sameValue(a, b) {
  return Object.is(a, b) || (a === b);
}
function sameArray(a, b) {
  if (a.length !== b.length) return false;
  for (let i=0; i<a.length; ++i)
    if (!sameValue(a[i], b[i])) return false;
  return true;
}
function assertSame(a, b) {
  if (a.published !== b.published || a.branch !== b.branch)
    process.exit(10);
  if (!sameArray(a.current, b.current))
    process.exit(11);
}

const sharedA = {id:"shared-a"};
const sharedB = {id:"shared-b"};
const values = [
  "calculator", "sysmon", "weather", "", null, undefined,
  false, true, 0, -0, 1, -1, NaN, Infinity, -Infinity,
  sharedA, sharedB
];

for (const active of [false, true]) {
  for (const widgetId of values) {
    const cases = [
      [],
      [widgetId],
      [widgetId, widgetId],
      ["calculator", "sysmon"],
      ["calculator", widgetId, "sysmon", widgetId],
      [NaN, "tail"],
      ["head", NaN],
      [0, -0, false, null, undefined],
      [sharedA, sharedB, sharedA]
    ];
    for (const source of cases)
      assertSame(oldSetWidget(source, widgetId, active),
                 newSetWidget(source, widgetId, active));
  }
}

let seed = 0x6245a11d >>> 0;
function rnd() {
  seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
  return seed;
}
for (let c=0; c<50000; ++c) {
  const len = rnd() % 40;
  const source = [];
  for (let i=0; i<len; ++i)
    source.push(values[rnd() % values.length]);
  const widgetId = values[rnd() % values.length];
  const active = !!(rnd() & 1);
  assertSame(oldSetWidget(source, widgetId, active),
             newSetWidget(source, widgetId, active));
}

console.log("sidebar-widget-index-parity: PASS (edge cases + 50000 randomized cases)");
