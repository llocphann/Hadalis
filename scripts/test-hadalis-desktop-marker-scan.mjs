#!/usr/bin/env node

import assert from "node:assert/strict";
import {
  managedPoll,
  markerAfterBaseline,
  openHadalisNewChat,
  requireIdleComposer,
  scanLoopMarkerTokens
} from "../automation/chat_bridge/desktop_driver.mjs";

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


const bootstrapMarkers = [
  "HADALIS_LOOP:CONTINUE",
  "HADALIS_LOOP:ROTATE",
  "HADALIS_LOOP:DONE",
  "HADALIS_LOOP:CONNECTOR_BLOCKED GITHUB",
  "HADALIS_LOOP:WAIT_RESULT JOB-SERVICE-E2E-001"
];

assert.equal(
  markerAfterBaseline(bootstrapMarkers, 4),
  "HADALIS_LOOP:WAIT_RESULT JOB-SERVICE-E2E-001"
);

assert.equal(
  markerAfterBaseline(bootstrapMarkers.slice(0, 4), 4),
  null
);

assert.throws(
  () => markerAfterBaseline([
    ...bootstrapMarkers,
    "HADALIS_LOOP:DONE"
  ], 4),
  /expected exactly one post-submit/
);

function guardedPage({ stop = false, text = "", domText = text, projectLabel = null } = {}) {
  const locator = (count, value = "", content = value) => ({
    count: async () => count,
    nth: () => ({ isVisible: async () => true }),
    innerText: async () => value,
    evaluate: async callback => callback({ textContent: content })
  });
  return {
    getByRole: (role, options) => {
      if (role === "textbox") return locator(1, text, domText);
      if (role === "button" && String(options.name) === "/stop/i") return locator(stop ? 1 : 0);
      if (role === "button" && String(options.name).includes("Project:")) {
        const label = projectLabel ?? `Project: ${process.env.HADALIS_CHATGPT_PROJECT ?? "Hadalis Cloud"}`;
        return locator(options.name.test(label) ? 1 : 0);
      }
      return locator(1);
    }
  };
}

await assert.rejects(
  requireIdleComposer(guardedPage({ stop: true })),
  error => error.code === "HADALIS_DESKTOP_BUSY" && /generation is active/.test(error.message)
);
await assert.rejects(requireIdleComposer(guardedPage({ text: "draft" })), /non-empty/);
await assert.rejects(requireIdleComposer(guardedPage({ text: "  " })), /non-empty/);
await assert.rejects(
  requireIdleComposer(guardedPage({ projectLabel: "Project: Wrong project" })),
  error => error.code === "HADALIS_DESKTOP_VIEW_CHANGED" && /project guard/.test(error.message)
);
await assert.rejects(
  requireIdleComposer(guardedPage({ projectLabel: "Project: HadalisXLocal" })),
  error => error.code === "HADALIS_DESKTOP_VIEW_CHANGED"
);
await requireIdleComposer(guardedPage());
await requireIdleComposer(guardedPage({ text: "\n", domText: "" }));
await requireIdleComposer(guardedPage(), false);
await assert.rejects(
  managedPoll(guardedPage({ projectLabel: "Project: Wrong project" }), { responseActionCount: 1 }),
  /project guard/
);
assert.equal((await managedPoll(guardedPage(), { responseActionCount: 1 })).completed, false);

function delayedNewChat({ busyPrevious = false, missingPreviousComposer = false,
                          blankPrevious = false, sameProjectPrevious = false } = {}) {
  const project = process.env.HADALIS_CHATGPT_PROJECT ?? "Hadalis Cloud";
  let fresh = false;
  let clicked = false;
  const locator = (count, { body = "", label = null, click = null } = {}) => {
    const item = {
      count: async () => typeof count === "function" ? count() : count,
      nth: () => item,
      isVisible: async () => true,
      isDisabled: async () => false,
      getAttribute: async name => name === "aria-label" ? label : null,
      innerText: async () => typeof body === "function" ? body() : body,
      evaluate: async callback => click ? click() : callback({ textContent: "" })
    };
    return item;
  };
  const browser = { contexts: () => [{ pages: () => [page] }] };
  const page = {
    url: () => "app://-/index.html",
    context: () => ({ browser: () => browser }),
    locator: selector => {
      if (selector === "body")
        return locator(1, { body: () => fresh || blankPrevious ? "" : "HADALIS_LOOP:CONTINUE" });
      if (selector.includes('aria-current="page"'))
        return locator(() => fresh || blankPrevious ? 0 : 1, { label: "Previous chat" });
      if (selector === `button[aria-label="New chat in ${project}"]`)
        return locator(1, { click: () => {
          clicked = true;
          setTimeout(() => { fresh = true; }, 80);
        } });
      return locator(0);
    },
    getByRole: (role, options) => {
      if (role === "textbox") return locator(() => fresh || !missingPreviousComposer ? 1 : 0);
      const name = String(options.name);
      if (name === "/stop/i") return locator(() => !fresh && busyPrevious ? 1 : 0);
      if (name.includes("Project:"))
        return locator(() => fresh || sameProjectPrevious || !busyPrevious ? 1 : 0);
      if (name.includes("regenerate")) return locator(() => fresh || blankPrevious ? 0 : 1);
      if (name === `New chat in ${project}`) return locator(1);
      return locator(0);
    }
  };
  return { page, result: () => ({ clicked, fresh }) };
}

const navigation = delayedNewChat();
const started = Date.now();
assert.equal(await openHadalisNewChat(navigation.page), navigation.page);
assert.deepEqual(navigation.result(), { clicked: true, fresh: true });
assert.ok(Date.now() - started >= 80, "new-chat must wait for a visible transition");

const busyNavigation = delayedNewChat({ busyPrevious: true });
await assert.rejects(
  openHadalisNewChat(busyNavigation.page),
  error => error.code === "HADALIS_DESKTOP_BUSY"
);
assert.equal(busyNavigation.result().clicked, false, "owned chat must not rotate while generating");
assert.equal(
  await openHadalisNewChat(busyNavigation.page, { unownedPreviousChat: true }),
  busyNavigation.page
);
assert.deepEqual(busyNavigation.result(), { clicked: true, fresh: true });

const unsupportedPreviousComposer = delayedNewChat({
  busyPrevious: true, missingPreviousComposer: true
});
assert.equal(
  await openHadalisNewChat(unsupportedPreviousComposer.page, { unownedPreviousChat: true }),
  unsupportedPreviousComposer.page
);
assert.deepEqual(unsupportedPreviousComposer.result(), { clicked: true, fresh: true });

const alreadyBlank = delayedNewChat({ blankPrevious: true });
assert.equal(
  await openHadalisNewChat(alreadyBlank.page, { unownedPreviousChat: true }),
  alreadyBlank.page
);
assert.deepEqual(alreadyBlank.result(), { clicked: false, fresh: false });

const busyTargetProject = delayedNewChat({
  busyPrevious: true, sameProjectPrevious: true
});
await assert.rejects(
  openHadalisNewChat(busyTargetProject.page, { unownedPreviousChat: true }),
  error => error.code === "HADALIS_DESKTOP_BUSY"
);
assert.equal(busyTargetProject.result().clicked, false);

console.log("PASS: desktop marker, composer, project, and new-chat guards");
