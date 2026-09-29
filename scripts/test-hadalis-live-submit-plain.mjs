#!/usr/bin/env node

import { chromium } from "file:///usr/lib/chatgpt/resources/cua_node/lib/node_modules/playwright-core/index.mjs";

const CDP = process.env.HADALIS_CHATGPT_CDP_URL ?? "http://127.0.0.1:9222";
const PROMPT = "Automation probe only. Reply exactly: HADALIS_AUTOMATION_PROBE_OK";
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));

async function main() {
  const browser = await chromium.connectOverCDP(CDP);

  let page = null;
  for (const context of browser.contexts()) {
    for (const candidate of context.pages()) {
      if (candidate.url() === "app://-/index.html") {
        page = candidate;
        break;
      }
    }
    if (page) break;
  }

  if (!page)
    throw new Error("Main ChatGPT renderer not found");

  const projectNewChat = page.getByRole("button", {
    name: "New chat in Hadalis Cloud"
  });

  if ((await projectNewChat.count()) !== 1)
    throw new Error(`Expected one Hadalis Cloud new-chat button; found ${await projectNewChat.count()}`);

  await projectNewChat.waitFor({
    state: "visible",
    timeout: 10000
  });

  await projectNewChat.evaluate(element => element.click());

  async function findActiveChatPage() {
    for (const context of browser.contexts()) {
      for (const candidate of context.pages()) {
        try {
          const composer = candidate.getByRole("textbox", {
            name: /^(Ask ChatGPT|New chat in Hadalis Cloud)$/
          });

          if (
            (await composer.count()) === 1 &&
            await composer.isVisible()
          ) {
            return candidate;
          }
        } catch {}
      }
    }
    return null;
  }

  let resolved = null;
  const deadline = Date.now() + 15000;

  while (Date.now() < deadline) {
    resolved = await findActiveChatPage();
    if (resolved) break;
    await sleep(250);
  }

  if (!resolved)
    throw new Error("No visible Hadalis composer after new chat");

  page = resolved;

  const composer = page.getByRole("textbox", {
    name: /^(Ask ChatGPT|New chat in Hadalis Cloud)$/
  });

  const projectGuard = page.getByRole("button", {
    name: /^(Project: Hadalis Cloud|Change project: Hadalis Cloud)$/
  });

  if ((await projectGuard.count()) !== 1)
    throw new Error("Hadalis Cloud project guard failed");

  const send = page.getByRole("button", {
    name: "Send"
  });

  await composer.fill(PROMPT);
  await page.waitForTimeout(300);

  const before = {
    title: await page.title(),
    url: page.url(),
    composerText: await composer.innerText(),
    sendCount: await send.count(),
    sendDisabled:
      (await send.count()) === 1
        ? await send.isDisabled()
        : null
  };

  if (
    before.composerText.trim() !== PROMPT ||
    before.sendDisabled !== false
  ) {
    throw new Error(`Invalid pre-submit state: ${JSON.stringify(before)}`);
  }

  await send.evaluate(element => element.click());

  const samples = [];
  const observeDeadline = Date.now() + 8000;
  let submitted = false;

  while (Date.now() < observeDeadline) {
    const composerText = (await composer.innerText()).trim();
    const stopCount = await page.getByRole("button", {
      name: /stop/i
    }).count();

    const sample = {
      ms: 8000 - (observeDeadline - Date.now()),
      composerEmpty: composerText === "",
      stopCount
    };
    samples.push(sample);

    if (sample.composerEmpty || stopCount > 0) {
      submitted = true;
      break;
    }

    await sleep(200);
  }

  const result = {
    submitted,
    before,
    firstSamples: samples.slice(0, 5),
    lastSamples: samples.slice(-5)
  };

  console.log(JSON.stringify(result, null, 2));

  if (!submitted)
    throw new Error("Exact known-good plain submit sequence did not submit");
}

main().catch(error => {
  console.error(error?.stack ?? String(error));
  process.exitCode = 1;
});
