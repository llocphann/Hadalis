#!/usr/bin/env node

import assert from "node:assert/strict";
import { scanLoopMarkerTokens } from "../automation/chat_bridge/desktop_driver.mjs";

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

console.log("PASS: desktop loop-marker token scanner");
