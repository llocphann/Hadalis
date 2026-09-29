#!/usr/bin/env node

import fs from "node:fs";

import {
  connectDesktop,
  extractLoopResponse,
  observeDesktop,
  openHadalisNewChat,
  submitPrompt,
  waitForCompletion
} from "./desktop_driver.mjs";

function writeJson(payload) {
  fs.writeSync(1, JSON.stringify(payload) + "\n");
}

function writeError(error) {
  fs.writeSync(2, (error?.stack ?? String(error)) + "\n");
}

async function readStdin() {
  const chunks = [];
  for await (const chunk of process.stdin)
    chunks.push(chunk);
  return Buffer.concat(chunks).toString("utf8");
}

async function main() {
  const command = process.argv[2] ?? "observe";
  let { page } = await connectDesktop();

  if (command === "observe") {
    writeJson(await observeDesktop(page));
    return;
  }

  if (command === "new-chat") {
    page = await openHadalisNewChat(page);
    writeJson(await observeDesktop(page));
    return;
  }

  if (command === "await-current") {
    try {
      const response = await extractLoopResponse(page, { allowMarkerOnly: true });
      writeJson({
        generation: { attachedToCompleted: true },
        response
      });
      return;
    } catch {}

    const generation = await waitForCompletion(page);
    const response = await extractLoopResponse(page, { allowMarkerOnly: true });
    writeJson({ generation, response });
    return;
  }

  if (command === "send" || command === "rotate-send") {
    if (command === "rotate-send")
      page = await openHadalisNewChat(page);

    const prompt = await readStdin();
    if (!prompt.trim())
      throw new Error("stdin prompt is empty");

    const completionBaseline = await submitPrompt(page, prompt);
    const generation = await waitForCompletion(
      page,
      600000,
      completionBaseline
    );
    const response = await extractLoopResponse(page, {
      allowMarkerOnly: true,
      baselineMarkerCount: completionBaseline.markerCount
    });

    writeJson({ generation, response });
    return;
  }

  throw new Error(`unknown command: ${command}`);
}

main().then(
  () => process.exit(0),
  error => {
    writeError(error);
    process.exit(1);
  }
);
