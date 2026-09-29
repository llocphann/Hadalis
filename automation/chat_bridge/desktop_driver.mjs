import { spawnSync } from "node:child_process";

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

async function submissionStarted(page, composer) {
  try {
    if ((await composer.innerText()).trim() === "")
      return true;
  } catch {}

  return (await visibleCount(
    page.getByRole("button", { name: /stop/i })
  )) > 0;
}

async function waitForSubmissionStart(page, composer, timeoutMs = 1500) {
  const deadline = Date.now() + timeoutMs;

  while (Date.now() < deadline) {
    if (await submissionStarted(page, composer))
      return true;
    await sleep(100);
  }

  return submissionStarted(page, composer);
}

async function dispatchCdpEnter(page) {
  const session = await page.context().newCDPSession(page);

  try {
    const event = {
      key: "Enter",
      code: "Enter",
      windowsVirtualKeyCode: 13,
      nativeVirtualKeyCode: 13
    };

    await session.send("Input.dispatchKeyEvent", {
      type: "rawKeyDown",
      ...event
    });
    await session.send("Input.dispatchKeyEvent", {
      type: "keyUp",
      ...event
    });
  } finally {
    await session.detach();
  }
}

async function dispatchSemanticClick(send) {
  await send.evaluate(element => {
    element.dispatchEvent(new PointerEvent("pointerdown", {
      bubbles: true,
      cancelable: true,
      composed: true,
      button: 0,
      buttons: 1,
      pointerId: 1,
      pointerType: "mouse",
      isPrimary: true
    }));
    element.dispatchEvent(new MouseEvent("mousedown", {
      bubbles: true,
      cancelable: true,
      composed: true,
      button: 0,
      buttons: 1
    }));
    element.dispatchEvent(new MouseEvent("mouseup", {
      bubbles: true,
      cancelable: true,
      composed: true,
      button: 0,
      buttons: 0
    }));
    element.dispatchEvent(new MouseEvent("click", {
      bubbles: true,
      cancelable: true,
      composed: true,
      button: 0
    }));
  });
}

function runNative(argv, timeout = 3000) {
  const result = spawnSync(argv[0], argv.slice(1), {
    encoding: "utf8",
    timeout,
    env: process.env
  });

  return {
    argv,
    status: result.status,
    signal: result.signal,
    stdout: (result.stdout ?? "").trim().slice(0, 2000),
    stderr: (result.stderr ?? "").trim().slice(0, 2000),
    error: result.error ? String(result.error) : null
  };
}

async function dispatchNativeWaylandEnter() {
  const windowsResult = runNative(["niri", "msg", "--json", "windows"]);
  if (windowsResult.status !== 0) {
    return {
      ok: false,
      stage: "niri-windows",
      windowsResult
    };
  }

  let windows;
  try {
    windows = JSON.parse(windowsResult.stdout);
  } catch (error) {
    return {
      ok: false,
      stage: "parse-windows",
      error: String(error),
      windowsResult
    };
  }

  if (!Array.isArray(windows)) {
    return {
      ok: false,
      stage: "windows-shape",
      windowsResult
    };
  }

  const candidates = windows.filter(window => {
    const haystack = [
      window?.app_id,
      window?.title
    ]
      .filter(value => typeof value === "string")
      .join(" ")
      .toLowerCase();

    return haystack.includes("chatgpt");
  });

  const target =
    candidates.find(window =>
      typeof window?.title === "string" &&
      window.title.toLowerCase().includes("hadalis cloud")
    ) ??
    candidates.find(window => window?.is_focused === true) ??
    (candidates.length === 1 ? candidates[0] : null);

  if (!target || target.id == null) {
    return {
      ok: false,
      stage: "select-window",
      candidates: candidates.map(window => ({
        id: window?.id ?? null,
        app_id: window?.app_id ?? null,
        title: window?.title ?? null,
        is_focused: window?.is_focused ?? null
      }))
    };
  }

  const focusResult = runNative([
    "niri",
    "msg",
    "action",
    "focus-window",
    "--id",
    String(target.id)
  ]);

  if (focusResult.status !== 0) {
    return {
      ok: false,
      stage: "focus-window",
      target,
      focusResult
    };
  }

  await sleep(250);

  let keyResult = runNative([
    "wtype",
    "-P",
    "Return",
    "-p",
    "Return"
  ]);

  if (keyResult.status !== 0) {
    keyResult = runNative([
      "wtype",
      "-k",
      "Return"
    ]);
  }

  await sleep(250);

  return {
    ok: keyResult.status === 0,
    stage: "wtype",
    target: {
      id: target.id,
      app_id: target.app_id ?? null,
      title: target.title ?? null,
      is_focused: target.is_focused ?? null
    },
    focusResult,
    keyResult
  };
}

export async function submitPrompt(page, prompt) {
  await verifyProject(page);
  const composer = await resolveComposer(page);
  await composer.fill(prompt);

  if ((await composer.innerText()).trim() !== prompt.trim())
    throw new Error("composer text mismatch");

  const send = page.getByRole("button", { name: "Send" });
  await requireOne(send, "Send");

  // Match the known-good feasibility probe exactly: after fill(), allow
  // ChatGPT's React/composer state to settle, then activate the semantic
  // Send control through HTMLElement.click() before trying any key path.
  await page.waitForTimeout(300);

  if (await send.isDisabled())
    throw new Error("Send is disabled after composer settle");

  await send.evaluate(element => element.click());

  if (await waitForSubmissionStart(page, composer, 2500))
    return;

  // Keep the action deterministic and coordinate-free. Start with the
  // normal editor gesture while explicitly restoring focus after fill().
  await composer.focus();
  await page.keyboard.press("Enter");

  if (await waitForSubmissionStart(page, composer))
    return;

  // Playwright key synthesis can be ignored by Electron/Chromium in some
  // embedded-editor states. Dispatch the Enter key through the underlying
  // Chromium DevTools protocol next; this does not depend on OS focus.
  await composer.focus();
  await dispatchCdpEnter(page);

  if (await waitForSubmissionStart(page, composer))
    return;

  // Then exercise the semantic Send control through a full event sequence.
  // This still avoids screen coordinates and pointer hit-testing.
  await dispatchSemanticClick(send);

  if (await waitForSubmissionStart(page, composer))
    return;

  // Final DOM fallback for builds where the button's native click path is
  // wired differently from delegated pointer handlers.
  await send.evaluate(element => element.click());

  if (await waitForSubmissionStart(page, composer))
    return;

  // Last-resort platform input: focus the real ChatGPT window through niri
  // by stable window id, then inject a real Wayland Return key with wtype.
  // This is still coordinate-free and is only reached after all CDP/DOM
  // submission paths have been verified ineffective.
  const nativeWayland = await dispatchNativeWaylandEnter();

  if (nativeWayland.ok && await waitForSubmissionStart(page, composer, 2500))
    return;

  const diagnostic = await page.evaluate(() => ({
    activeTag: document.activeElement?.tagName ?? null,
    activeRole: document.activeElement?.getAttribute?.("role") ?? null,
    activeAriaLabel: document.activeElement?.getAttribute?.("aria-label") ?? null
  }));

  throw new Error(
    `prompt did not submit after keyboard, CDP Enter, semantic Send, or native Wayland Return: ${JSON.stringify({ diagnostic, nativeWayland })}`
  );
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

    if (sawStop && sawClear && stop === 0 && regen > 0) {
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
