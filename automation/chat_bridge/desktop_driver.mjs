const PLAYWRIGHT = process.env.HADALIS_PLAYWRIGHT_MODULE ?? "file:///usr/lib/chatgpt/resources/cua_node/lib/node_modules/playwright-core/index.mjs";
const { chromium } = await import(PLAYWRIGHT);

const CDP = process.env.HADALIS_CHATGPT_CDP_URL ?? "http://127.0.0.1:9222";
const MAIN_URL = "app://-/index.html";
const COMPOSER = /^(Ask ChatGPT|New chat in Hadalis Cloud)$/;
const PROJECT = /^(Project: Hadalis Cloud|Change project: Hadalis Cloud)$/;

const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));

async function visibleCount(locator) {
  const count = await locator.count();
  let visible = 0;
  for (let i = 0; i < count; i += 1) {
    try {
      if (await locator.nth(i).isVisible()) visible += 1;
    } catch {}
  }
  return visible;
}

async function requireOne(locator, label) {
  const count = await locator.count();
  const visible = await visibleCount(locator);
  if (count !== 1 || visible !== 1)
    throw new Error(`${label}: expected one visible element, got count=${count}, visible=${visible}`);
  return locator;
}

async function semanticClick(locator, label) {
  await requireOne(locator, label);
  if (await locator.isDisabled()) throw new Error(`${label} is disabled`);
  await locator.evaluate(el => el.click());
}

async function findMainPage(browser) {
  for (const context of browser.contexts()) {
    for (const page of context.pages()) {
      if (page.url() !== MAIN_URL) continue;
      const composer = page.getByRole("textbox", { name: COMPOSER });
      const newChat = page.getByRole("button", { name: "New chat in Hadalis Cloud" });
      if ((await visibleCount(composer)) === 1 || (await visibleCount(newChat)) === 1)
        return page;
    }
  }
  throw new Error("main ChatGPT renderer not found");
}

async function verifyProject(page) {
  await requireOne(page.getByRole("button", { name: PROJECT }), "Hadalis Cloud project guard");
}

async function resolveComposer(page) {
  return requireOne(page.getByRole("textbox", { name: COMPOSER }), "composer");
}

export async function openHadalisNewChat(page) {
  const button = page.getByRole("button", { name: "New chat in Hadalis Cloud" });
  await semanticClick(button, "Hadalis Cloud new chat");
  const deadline = Date.now() + 15000;
  while (Date.now() < deadline) {
    try {
      await resolveComposer(page);
      await verifyProject(page);
      return;
    } catch {}
    await sleep(250);
  }
  throw new Error("new chat did not become ready");
}

export async function submitPrompt(page, prompt) {
  await verifyProject(page);
  const composer = await resolveComposer(page);
  await composer.fill(prompt);
  if ((await composer.innerText()).trim() !== prompt.trim())
    throw new Error("composer text mismatch");
  const send = page.getByRole("button", { name: "Send" });
  await semanticClick(send, "Send");
}

export async function waitForCompletion(page, timeoutMs = 600000) {
  const deadline = Date.now() + timeoutMs;
  let sawStop = false;
  let sawClear = false;

  while (Date.now() < deadline) {
    const stop = await visibleCount(page.getByRole("button", { name: /stop/i }));
    const regen = await visibleCount(page.getByRole("button", { name: /regenerate response/i }));
    const composer = await resolveComposer(page);
    const empty = (await composer.innerText()).trim() === "";

    sawStop ||= stop > 0;
    sawClear ||= empty;

    if (sawClear && stop === 0 && regen > 0) {
      await sleep(900);
      const stop2 = await visibleCount(page.getByRole("button", { name: /stop/i }));
      const regen2 = await visibleCount(page.getByRole("button", { name: /regenerate response/i }));
      if (stop2 === 0 && regen2 > 0)
        return { sawStop, sawClear, completed: true };
    }
    await sleep(250);
  }
  throw new Error("generation completion timeout");
}

const LOOP_MARKER =
  /^HADALIS_LOOP:(?:WAIT_RESULT|CONTINUE|ROTATE|DONE|CONNECTOR_BLOCKED)(?:[ \\t]+[A-Za-z0-9._/-]+)?[ \\t]*$/m;

export async function extractLoopResponse(page) {
  const regenerate = page.getByRole("button", { name: /regenerate response/i });
  const count = await regenerate.count();
  if (count < 1) throw new Error("Regenerate response control is unavailable");

  const source = LOOP_MARKER.source;
  const result = await regenerate.last().evaluate((button, markerSource) => {
    const marker = new RegExp(markerSource, "m");
    let node = button;
    for (let depth = 0; depth < 10 && node; depth += 1) {
      const text = (node.innerText ?? "").trim();
      if (text && marker.test(text))
        return { depth, text };
      node = node.parentElement;
    }
    return null;
  }, source);

  if (!result)
    throw new Error("No HADALIS_LOOP marker found near completed assistant response");
  return result;
}

export async function observeDesktop(page) {
  const composer = page.getByRole("textbox", { name: COMPOSER });
  const send = page.getByRole("button", { name: "Send" });
  return {
    title: await page.title(),
    url: page.url(),
    composerVisible: await visibleCount(composer),
    projectGuardVisible: await visibleCount(page.getByRole("button", { name: PROJECT })),
    sendVisible: await visibleCount(send),
    sendDisabled: (await send.count()) === 1 ? await send.isDisabled() : null
  };
}

export async function connectDesktop() {
  const browser = await chromium.connectOverCDP(CDP);
  const page = await findMainPage(browser);
  return { browser, page };
}
