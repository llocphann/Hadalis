#!/usr/bin/env node
"use strict";

function sameValue(a, b) {
  return Object.is(a, b);
}

function sameArray(a, b) {
  if (a.length !== b.length)
    return false;
  for (let i = 0; i < a.length; i++) {
    if (!sameValue(a[i], b[i]))
      return false;
  }
  return true;
}

function sameTrace(a, b) {
  if (a.length !== b.length)
    return false;
  for (let i = 0; i < a.length; i++) {
    if (a[i].op !== b[i].op || !sameValue(a[i].value, b[i].value))
      return false;
  }
  return true;
}

function oldNormalize(value, trace) {
  if (!Array.isArray(value))
    return [];
  return value
    .filter(item => {
      trace.push({op: "filter", value: item});
      return typeof item === "number" && isFinite(item);
    })
    .map(item => {
      trace.push({op: "round", value: item});
      return Math.round(item);
    });
}

function candidateNormalize(value, trace) {
  if (!Array.isArray(value))
    return [];
  const limits = value.filter(item => {
    trace.push({op: "filter", value: item});
    return typeof item === "number" && isFinite(item);
  });
  for (let i = 0; i < limits.length; i++) {
    const item = limits[i];
    trace.push({op: "round", value: item});
    limits[i] = Math.round(item);
  }
  return limits;
}

function assertParity(value, label) {
  const before = Array.isArray(value) ? value.slice() : null;
  const oldTrace = [];
  const candidateTrace = [];
  const oldResult = oldNormalize(value, oldTrace);
  const candidateResult = candidateNormalize(value, candidateTrace);

  if (!sameArray(oldResult, candidateResult)) {
    console.error("value mismatch:", label, oldResult, candidateResult);
    process.exit(10);
  }
  if (!sameTrace(oldTrace, candidateTrace)) {
    console.error("trace mismatch:", label, oldTrace, candidateTrace);
    process.exit(11);
  }
  if (Array.isArray(value)) {
    if (!sameArray(value, before)) {
      console.error("source mutated:", label);
      process.exit(12);
    }
    if (oldResult === value || candidateResult === value) {
      console.error("fresh-array contract broken:", label);
      process.exit(13);
    }
  }
  const oldAgain = oldNormalize(value, []);
  const candidateAgain = candidateNormalize(value, []);
  if (oldAgain === oldResult || candidateAgain === candidateResult) {
    console.error("fresh publication repeated identity:", label);
    process.exit(14);
  }
}

const directCases = [
  undefined,
  JSON.parse("null"),
  JSON.parse("{}"),
  JSON.parse("[]"),
  JSON.parse("[0,-0,1,-1,1.49,1.5,-1.49,-1.5]"),
  JSON.parse("[null,true,false,\"1\",\"\",{},[],[1],1e400,-1e400,1e-400,-1e-400]"),
  JSON.parse("[2.5,2.5,-2.5,-2.5,99.9,100.1,0,0]"),
  JSON.parse("{\"allowedLimits\":[15,20.5,null,80]}").allowedLimits,
  JSON.parse("{}").allowedLimits
];

for (let i = 0; i < directCases.length; i++)
  assertParity(directCases[i], "direct-" + i);

const atoms = [
  "null", "true", "false", "0", "-0", "1", "-1",
  "1.49", "1.5", "-1.49", "-1.5", "2.5", "-2.5",
  "1e400", "-1e400", "1e-400", "-1e-400",
  "\"1\"", "\"\"", "\"text\"", "{}", "[]", "[1]", "{\"x\":1}"
];

let seed = 0x62f5a11d >>> 0;
function rnd() {
  seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
  return seed;
}

for (let c = 0; c < 50000; c++) {
  const length = rnd() % 40;
  const tokens = [];
  for (let i = 0; i < length; i++)
    tokens.push(atoms[rnd() % atoms.length]);
  const value = JSON.parse("[" + tokens.join(",") + "]");
  assertParity(value, "random-" + c);
}

console.log("tlp-allowed-limits-parity: PASS (phase trace + edge cases + 50000 JSON arrays)");
