#!/usr/bin/env node

import fs from "node:fs";

import {
  connectDesktop,
  extractLoopResponse,
  openHadalisNewChat,
  submitPrompt,
  waitForCompletion
} from "../automation/chat_bridge/desktop_driver.mjs";

const prompt = `[@GitHub](plugin://github@openai-curated-remote)

Hadalis autonomous transport acceptance probe.

Use the GitHub connector explicitly.
Verify read access to llocphann/Hadalis and fetch the current dev HEAD.
Do not modify the repository.
After that check, finish your response with exactly one loop marker:

HADALIS_LOOP:DONE
`;

function writeJson(payload) {
  fs.writeSync(1, JSON.stringify(payload) + "\n");
}

function writeError(error) {
  fs.writeSync(2, (error?.stack ?? String(error)) + "\n");
}

async function main() {
  let { page } = await connectDesktop();

  page = await openHadalisNewChat(page);
  const completionBaseline = await submitPrompt(page, prompt);
  const generation = await waitForCompletion(
    page,
    90000,
    completionBaseline
  );
  const response = await extractLoopResponse(page, { allowMarkerOnly: true });

  const markers = response.text
    .split(/\r?\n/)
    .map(line => line.trim())
    .filter(line => line.startsWith("HADALIS_LOOP:"));

  if (markers.length !== 1 || markers[0] !== "HADALIS_LOOP:DONE") {
    throw new Error(
      `expected exactly HADALIS_LOOP:DONE, got ${JSON.stringify(markers)}`
    );
  }

  writeJson({
    passed: true,
    generation,
    marker: markers[0]
  });
}

main().then(
  () => process.exit(0),
  error => {
    writeError(error);
    process.exit(1);
  }
);
