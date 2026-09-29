#!/usr/bin/env node

import assert from "node:assert/strict";
import {
  markerAfterBaseline,
  requireIdleComposer,
  scanLoopMarkerTokens
} from "../automation/chat_bridge/desktop_driver.mjs";

assert.deepEqual(
  scanLoopMarkerTokens("HADALIS_LOOP:DONE"),
  ["HADALIS_LOOP:DONE"]
);

assert.deepEqual(
  scanLoopMarkerTokens("HADALIS_LOOP:DONE Copy Share"),
  ["HADALIS_LOOP:DONE"]
);

assert.deepEqual(
  scanLoopMarkerTokens(
    "Prompt says HADALIS_LOOP:DONE\nAssistant says HADALIS_LOOP:DONE"
  ),
  ["HADALIS_LOOP:DONE", "HADALIS_LOOP:DONE"]
);

assert.deepEqual(
  scanLoopMarkerTokens("HADALIS_LOOP:WAIT_RESULT JOB-ABC_123"),
  ["HADALIS_LOOP:WAIT_RESULT JOB-ABC_123"]
);

assert.deepEqual(
  scanLoopMarkerTokens("HADALIS_LOOP:CONNECTOR_BLOCKED GITHUB"),
  ["HADALIS_LOOP:CONNECTOR_BLOCKED GITHUB"]
);

assert.deepEqual(
  scanLoopMarkerTokens("HADALIS_LOOP:WAIT_RESULT"),
  []
);

assert.deepEqual(
  scanLoopMarkerTokens("nothing relevant here"),
  []
);


const bootstrapMarkers = [
  "HADALIS_LOOP:CONTINUE",
  "HADALIS_LOOP:ROTATE",
  "HADALIS_LOOP:DONE",
  "HADALIS_LOOP:CONNECTOR_BLOCKED GITHUB",
  "HADALIS_LOOP:WAIT_RESULT JOB-SERVICE-E2E-001"
];

assert.equal(
  markerAfterBaseline(bootstrapMarkers, 4),
  "HADALIS_LOOP:WAIT_RESULT JOB-SERVICE-E2E-001"
);

assert.equal(
  markerAfterBaseline(bootstrapMarkers.slice(0, 4), 4),
  null
);

assert.throws(
  () => markerAfterBaseline([
    ...bootstrapMarkers,
    "HADALIS_LOOP:DONE"
  ], 4),
  /expected exactly one post-submit/
);

function guardedPage({ stop = false, text = "", projectLabel = null } = {}) {
  const locator = (count, value = "") => ({
    count: async () => count,
    nth: () => ({ isVisible: async () => true }),
    innerText: async () => value
  });
  return {
    getByRole: (role, options) => {
      if (role === "textbox") return locator(1, text);
      if (role === "button" && String(options.name) === "/stop/i") return locator(stop ? 1 : 0);
      if (role === "button" && String(options.name).includes("Project:")) {
        const label = projectLabel ?? `Project: ${process.env.HADALIS_CHATGPT_PROJECT ?? "Hadalis Cloud"}`;
        return locator(options.name.test(label) ? 1 : 0);
      }
      return locator(1);
    }
  };
}

await assert.rejects(requireIdleComposer(guardedPage({ stop: true })), /generation is active/);
await assert.rejects(requireIdleComposer(guardedPage({ text: "draft" })), /non-empty/);
await assert.rejects(requireIdleComposer(guardedPage({ projectLabel: "Project: Wrong project" })), /project guard/);
await assert.rejects(requireIdleComposer(guardedPage({ projectLabel: "Project: HadalisXLocal" })), /project guard/);
await requireIdleComposer(guardedPage());
await requireIdleComposer(guardedPage(), false);

console.log("PASS: desktop loop-marker token scanner");
