#!/usr/bin/env node

import {
  connectDesktop,
  extractLoopResponse,
  observeDesktop,
  openHadalisNewChat,
  submitPrompt,
  waitForCompletion
} from "./desktop_driver.mjs";

async function readStdin() {
  const chunks = [];
  for await (const chunk of process.stdin)
    chunks.push(chunk);
  return Buffer.concat(chunks).toString("utf8");
}

async function main() {
  const command = process.argv[2] ?? "observe";
  const { page } = await connectDesktop();

  if (command === "observe") {
    console.log(JSON.stringify(await observeDesktop(page)));
    return;
  }

  if (command === "new-chat") {
    await openHadalisNewChat(page);
    console.log(JSON.stringify(await observeDesktop(page)));
    return;
  }

  if (command === "await-current") {
    const generation = await waitForCompletion(page);
    const response = await extractLoopResponse(page);
    console.log(JSON.stringify({ generation, response }));
    return;
  }

  if (command === "send" || command === "rotate-send") {
    if (command === "rotate-send")
      await openHadalisNewChat(page);

    const prompt = await readStdin();
    if (!prompt.trim())
      throw new Error("stdin prompt is empty");

    await submitPrompt(page, prompt);
    const generation = await waitForCompletion(page);
    const response = await extractLoopResponse(page);

    console.log(JSON.stringify({ generation, response }));
    return;
  }

  throw new Error(`unknown command: ${command}`);
}

main().catch(error => {
  console.error(error?.stack ?? String(error));
  process.exitCode = 1;
});
