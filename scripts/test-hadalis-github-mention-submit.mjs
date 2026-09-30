#!/usr/bin/env node

import { chromium } from "file:///usr/lib/chatgpt/resources/cua_node/lib/node_modules/playwright-core/index.mjs";

const CDP = process.env.HADALIS_CHATGPT_CDP_URL ?? "http://127.0.0.1:9222";
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));

const REST = `

Hadalis autonomous connector acceptance probe.

Use the GitHub connector explicitly.
Verify read access to llocphann/Hadalis and fetch the current dev HEAD.
Do not modify the repository.
Finish with exactly:

HADALIS_LOOP:DONE
`;

async function visible(locator) {
  const items = [];
  const count = await locator.count();
  for (let i = 0; i < count; i += 1) {
    const item = locator.nth(i);
    try {
      if (await item.isVisible()) items.push(item);
    } catch {}
  }
  return items;
}

async function findMainPage(browser) {
  for (const context of browser.contexts()) {
    for (const page of context.pages()) {
      if (page.url() !== "app://-/index.html") continue;
      const composer = page.getByRole("textbox", {
        name: /^(Ask ChatGPT|New chat in Hadalis Cloud)$/
      });
      if ((await composer.count()) === 1 && await composer.isVisible())
        return page;
    }
  }
  throw new Error("Main ChatGPT renderer not found");
}

async function openHadalisNewChat(page) {
  const button = page.getByRole("button", {
    name: "New chat in Hadalis Cloud"
  });

  if ((await button.count()) !== 1)
    throw new Error("Expected one Hadalis Cloud new-chat button");

  await button.evaluate(element => element.click());

  const deadline = Date.now() + 15000;
  while (Date.now() < deadline) {
    try {
      const composer = page.getByRole("textbox", {
        name: /^(Ask ChatGPT|New chat in Hadalis Cloud)$/
      });
      const project = page.getByRole("button", {
        name: /^(Project: Hadalis Cloud|Change project: Hadalis Cloud)$/
      });

      if (
        (await composer.count()) === 1 &&
        await composer.isVisible() &&
        (await project.count()) === 1
      ) {
        return;
      }
    } catch {}
    await sleep(200);
  }

  throw new Error("Hadalis new chat did not become ready");
}

async function selectGitHubMention(page, composer) {
  await composer.fill("");
  await composer.focus();

  // Trigger the app picker with the minimal token first.
  await page.keyboard.insertText("@");
  await sleep(700);

  const roleLocators = [
    page.getByRole("option", { name: /GitHub/i }),
    page.getByRole("menuitem", { name: /GitHub/i }),
    page.getByRole("menuitemradio", { name: /GitHub/i }),
    page.getByRole("button", { name: /GitHub/i })
  ];

  for (const locator of roleLocators) {
    const candidates = await visible(locator);
    if (!candidates.length) continue;

    const candidate = candidates[0];
    await candidate.evaluate(element => element.click());
    await sleep(500);
    return { method: "role-click" };
  }

  // Some ChatGPT builds expose mention suggestions as plain text rows.
  const exactText = page.getByText(/^GitHub$/i);
  for (const item of await visible(exactText)) {
    const clickable = item.locator(
      'xpath=ancestor-or-self::*[@role="option" or @role="menuitem" or @role="menuitemradio" or self::button][1]'
    );

    if ((await clickable.count()) === 1) {
      await clickable.evaluate(element => element.click());
      await sleep(500);
      return { method: "text-ancestor-click" };
    }
  }

  // Last semantic fallback: type enough to filter to GitHub, then select
  // the first picker row with keyboard navigation.
  await page.keyboard.insertText("GitHub");
  await sleep(500);
  await page.keyboard.press("ArrowDown");
  await page.keyboard.press("Enter");
  await sleep(500);

  return { method: "keyboard-picker" };
}

async function main() {
  const browser = await chromium.connectOverCDP(CDP);
  let page = await findMainPage(browser);

  await openHadalisNewChat(page);
  page = await findMainPage(browser);

  const composer = page.getByRole("textbox", {
    name: /^(Ask ChatGPT|New chat in Hadalis Cloud)$/
  });
  const project = page.getByRole("button", {
    name: /^(Project: Hadalis Cloud|Change project: Hadalis Cloud)$/
  });

  if ((await project.count()) !== 1)
    throw new Error("Hadalis project guard failed");

  const mention = await selectGitHubMention(page, composer);

  // Continue typing after the selected rich mention rather than replacing
  // composer contents, so the app token remains intact.
  await composer.focus();
  await page.keyboard.insertText(REST);
  await page.waitForTimeout(300);

  const send = page.getByRole("button", { name: "Send" });
  if ((await send.count()) !== 1)
    throw new Error("Expected exactly one Send button");
  if (await send.isDisabled())
    throw new Error("Send is disabled after GitHub mention + prompt");

  const composerText = (await composer.innerText()).trim();
  if (!composerText.includes("Hadalis autonomous connector acceptance probe"))
    throw new Error(`Prompt body missing after mention selection: ${JSON.stringify(composerText)}`);

  // Use the exact submit primitive already proven by the successful probe.
  await send.evaluate(element => element.click());

  const submitDeadline = Date.now() + 8000;
  let sawClear = false;
  let sawStop = false;

  while (Date.now() < submitDeadline) {
    try {
      sawClear ||= (await composer.innerText()).trim() === "";
    } catch {}

    sawStop ||= (await page.getByRole("button", {
      name: /stop/i
    }).count()) > 0;

    if (sawClear || sawStop) break;
    await sleep(200);
  }

  if (!(sawClear || sawStop))
    throw new Error("GitHub mention prompt did not submit");

  console.log(JSON.stringify({
    passed: true,
    mention,
    sawClear,
    sawStop
  }));
}

main().catch(error => {
  console.error(error?.stack ?? String(error));
  process.exitCode = 1;
});
