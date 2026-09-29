#!/usr/bin/env node

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

async function main() {
  const { page } = await connectDesktop();

  await openHadalisNewChat(page);
  await submitPrompt(page, prompt);
  const generation = await waitForCompletion(page);
  const response = await extractLoopResponse(page);

  const markers = response.text
    .split(/\r?\n/)
    .map(line => line.trim())
    .filter(line => line.startsWith("HADALIS_LOOP:"));

  if (markers.length !== 1 || markers[0] !== "HADALIS_LOOP:DONE") {
    throw new Error(
      `expected exactly HADALIS_LOOP:DONE, got ${JSON.stringify(markers)}`
    );
  }

  console.log(JSON.stringify({
    passed: true,
    generation,
    marker: markers[0]
  }));
}

main().catch(error => {
  console.error(error?.stack ?? String(error));
  process.exitCode = 1;
});
