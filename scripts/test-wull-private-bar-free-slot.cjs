#!/usr/bin/env node
// FAKE ONLY: source-pinned pure private Bar free-segment calculator contract.
// No Qt, Wayland, desktop reads, screenshots, HTTP, Git or file modifications.
// Uses only built-in fs/crypto/vm in this local inert test process.
"use strict";
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const vm = require("node:vm");
const assert = require("node:assert/strict");
const root = path.resolve(__dirname, "..");
const source = path.join(root, "scripts/wull-private-bar-free-slot.js");
const raw = fs.readFileSync(source);
const blob = crypto.createHash("sha1")
  .update(Buffer.concat([Buffer.from("blob " + raw.length + "\0"),raw]))
  .digest("hex");
assert.equal(blob, "342960e0c6d19068732eea805a6c4cc35e055a3e");
const sandbox = vm.createContext(Object.create(null),{
  codeGeneration:{strings:false,wasm:false}
});
vm.runInContext(raw.toString("utf8"),sandbox,{timeout:1500});
assert.equal(typeof sandbox.slot,"function");
function query(params) {
  const input = {edge:"bottom",extent:1000,footprint:168,desired:720,
    clearance:18,sideGuard:16,cornerStart:0,cornerEnd:0,
    records:[],reservations:[],...params};
  return JSON.parse(JSON.stringify(sandbox.slot(input)));
}
let count = 0;
function check(flag, label) {
  assert.ok(flag,label);
  count++;
}
function safeResult(r) { return r.qualified === false && typeof r.reason === "string"; }

let free = query({});
check(free.qualified && free.center === 720, "free source layout");
check(free.footprint === 168 && free.occupiedOnEdge === 0,"source footprint");

let obstacle = {edge:"bottom",along:680,span:230,active:true};
let kept = JSON.stringify(obstacle);
let moved = query({records:[obstacle]});
check(moved.qualified && moved.center === 578, "right Bar record pushes Wull left");
check(moved.center + 84 + 18 <= obstacle.along, "no contact with module after clearance");
check(JSON.stringify(obstacle) === kept, "do not mutate live layout data");
let repeated = query({records:[obstacle,obstacle]});
check(repeated.qualified && repeated.center === moved.center,"overlap record order");
let reversed = query({records:[obstacle,{edge:"bottom",along:80,span:100}]});
let forward = query({records:[{edge:"bottom",along:80,span:100},obstacle]});
check(reversed.qualified && forward.qualified &&
      reversed.center === forward.center, "record order invariant");

let anotherEdge = query({records:[{edge:"left",along:500,span:300}]});
check(anotherEdge.qualified && anotherEdge.center === 720 &&
      anotherEdge.occupiedOnEdge === 0,"other edge record not treated as BOTTOM");

let exact = query({extent:1000,footprint:100,desired:500,clearance:10,
  records:[{edge:"bottom",along:480,span:40}]});
check(exact.qualified && exact.center === 420,"deterministic tie to lower side");
check(exact.center + 50 + 10 === 480,"exact clearance tangent safe");

let activePopup = query({reservations:[
  {edge:"bottom",along:680,span:230,active:true}
]});
check(activePopup.qualified && activePopup.center === moved.center,
      "active popup reservation treated as obstacle");
let closedPopup = query({reservations:[
  {edge:"bottom",along:680,span:230,active:false}
]});
check(closedPopup.qualified && closedPopup.center === 720,
      "inactive popup does not take free segment");

let full = query({records:[{edge:"bottom",along:0,span:1000}]});
check(safeResult(full) && full.reason === "NO_FREE_SEGMENT",
      "never overlap fully occupied Bar");
let slim = query({extent:150,footprint:140,desired:80});
check(safeResult(slim) && slim.reason === "INSUFFICIENT_EDGE",
      "small output without actual free area fails closed");

let restricted = query({records:[obstacle],maxShift:100});
check(safeResult(restricted) && restricted.reason === "NO_NEARBY_CLEARANCE",
      "far-away slot not silently selected");
let corners = query({cornerStart:150,cornerEnd:150,desired:90});
check(corners.qualified && corners.center >= 250 &&
      corners.center <= 750,"adjacent corner reservation respected");

let sentinel = query({records:[{edge:"bottom",along:NaN,span:20}]});
check(safeResult(sentinel) && sentinel.reason === "UNVERIFIED_RECORD",
      "malformed compositor geometry fails closed");
let badEdge = query({records:[{edge:"underside",along:150,span:25}]});
check(safeResult(badEdge) && badEdge.reason === "UNVERIFIED_RECORD",
      "invalid source edge fails closed");
let invalidExtent = query({extent:NaN});
check(safeResult(invalidExtent) && invalidExtent.reason === "INVALID_INPUT",
      "malformed output cannot be accepted");
let invalidFootprint = query({footprint:0});
check(safeResult(invalidFootprint) && invalidFootprint.reason === "INVALID_INPUT",
      "invisible Wull cannot qualify");
let capped = query({records:Array(513).fill(
  {edge:"bottom",along:0,span:1}
)});
check(safeResult(capped) && capped.reason === "INVALID_INPUT",
      "strict bound on source records");
let overflow = query({records:[{edge:"bottom",along:1e308,span:1e308}]});
check(safeResult(overflow) && overflow.reason === "UNVERIFIED_RECORD",
      "numeric source overflow fails closed");

for (const e of ["top","right","bottom","left"]) {
  let result = query({edge:e,records:[{edge:e,along:550,span:210}]});
  check(result.qualified && (result.center + 84 + 18 <= 550
        || result.center - 84 - 18 >= 760),
        "same geometry rule usable at edge " + e);
}
assert.ok(count >= 25);
console.log("WULL_PRIVATE_FREE_BAR_SLOT_INERT_PASS");
