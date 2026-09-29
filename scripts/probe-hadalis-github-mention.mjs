#!/usr/bin/env node

import { chromium } from "file:///usr/lib/chatgpt/resources/cua_node/lib/node_modules/playwright-core/index.mjs";

const CDP = process.env.HADALIS_CHATGPT_CDP_URL ?? "http://127.0.0.1:9222";
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));

async function visible(locator) {
  const out = [];
  const count = await locator.count();
  for (let index = 0; index < count; index += 1) {
    const item = locator.nth(index);
    try {
      if (await item.isVisible())
        out.push(item);
    } catch {}
  }
  return out;
}

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

  const newChat = page.getByRole("button", {
    name: "New chat in Hadalis Cloud"
  });

  if ((await newChat.count()) !== 1)
    throw new Error("Expected exactly one Hadalis Cloud new-chat button");

  await newChat.evaluate(element => element.click());

  const deadline = Date.now() + 15000;
  let composer = null;

  while (Date.now() < deadline) {
    for (const context of browser.contexts()) {
      for (const candidate of context.pages()) {
        try {
          const maybe = candidate.getByRole("textbox", {
            name: /^(Ask ChatGPT|New chat in Hadalis Cloud)$/
          });
          if ((await maybe.count()) === 1 && await maybe.isVisible()) {
            page = candidate;
            composer = maybe;
            break;
          }
        } catch {}
      }
      if (composer) break;
    }
    if (composer) break;
    await sleep(200);
  }

  if (!composer)
    throw new Error("Hadalis composer not found after new chat");

  const project = page.getByRole("button", {
    name: /^(Project: Hadalis Cloud|Change project: Hadalis Cloud)$/
  });
  if ((await project.count()) !== 1)
    throw new Error("Hadalis project guard failed");

  await composer.fill("");
  await composer.focus();
  await composer.pressSequentially("@GitHub", { delay: 80 });
  await sleep(1200);

  const candidateSelectors = [
    '[role="option"]',
    '[role="menuitem"]',
    '[role="menuitemradio"]',
    '[role="listbox"]',
    '[role="menu"]',
    '[data-radix-popper-content-wrapper]',
    'button'
  ];

  const seen = new Set();
  const candidates = [];

  for (const selector of candidateSelectors) {
    for (const locator of await visible(page.locator(selector))) {
      try {
        const data = await locator.evaluate((element, selectorName) => ({
          selector: selectorName,
          tag: element.tagName,
          role: element.getAttribute("role"),
          ariaLabel: element.getAttribute("aria-label"),
          text: (element.innerText ?? element.textContent ?? "")
            .replace(/\s+/g, " ")
            .trim()
            .slice(0, 240)
        }), selector);

        const haystack = `${data.ariaLabel ?? ""} ${data.text}`.toLowerCase();
        if (!haystack.includes("github"))
          continue;

        const key = JSON.stringify(data);
        if (!seen.has(key)) {
          seen.add(key);
          candidates.push(data);
        }
      } catch {}
    }
  }

  const bodyText = (await page.locator("body").innerText())
    .replace(/\s+/g, " ")
    .trim();

  const result = {
    composerText: (await composer.innerText()).trim(),
    candidateCount: candidates.length,
    candidates: candidates.slice(0, 20),
    bodyHasGitHub: bodyText.toLowerCase().includes("github")
  };

  console.log(JSON.stringify(result, null, 2));

  await composer.fill("");
  await page.keyboard.press("Escape").catch(() => {});

  process.exit(result.candidateCount > 0 ? 0 : 2);
}

main().catch(error => {
  console.error(error?.stack ?? String(error));
  process.exit(1);
});
