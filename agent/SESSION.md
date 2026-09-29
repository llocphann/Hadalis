# Autonomous session checkpoint

Desktop feasibility is complete: submit, generation start, generation completion, and response detection all passed.

Focused automation validation `JOB-AUTOMATION-VALIDATE-002` passed every action. Canonical validation `JOB-MAINTAINER-VALIDATE-001` completed but the repository remains non-green because of 33 unrelated product/regression failures; the three Hadalis automation regression tests passed inside that run.

A production-safety change now starts new autonomous sessions with `rotate-send`, which creates a fresh chat inside Hadalis Cloud before sending the initial prompt. Continuations remain in the current chat; explicit rotation also uses `rotate-send`.

Interactive testing confirmed the GitHub rich-mention picker path can select GitHub, append the prompt body, and submit. The production desktop driver now converts the tracked first-line connector marker into that rich mention instead of filling the markdown literal into the composer. Rotation also follows the renderer that owns the newly created chat.

The 005 through 008 live runs visibly completed in ChatGPT with the correct current dev HEAD and HADALIS_LOOP:DONE, while the local worker action remained alive. The uploaded original successful submit probe explicitly called `process.exit(0)` after writing its result; the production CLI/live test had instead relied on Node exiting naturally while a Playwright CDP websocket remained attached. The CLI and live acceptance now write JSON synchronously with `fs.writeSync` and explicitly exit after success/error, without calling `browser.close()` and therefore without closing ChatGPT Desktop. Marker-delta completion remains the protocol signal. A lock-safe `--reset-state` runtime path plus installer `--reset-session-state` option is ready for the first service rollout.

Pending mechanical evidence: `JOB-DESKTOP-LIVE-ACCEPT-013`.

Resume procedure:
1. Fetch current `dev` HEAD.
2. Read `automation/results/JOB-DESKTOP-LIVE-ACCEPT-013.json` if present.
3. If absent, wait for the deterministic local worker; do not invent the result.
4. If it failed, inspect exact stdout/stderr and fix forward on current `dev`.
5. If it passed, install the user services from the maintainer's persistent local checkout, not from an ephemeral worker clone.
6. Start the worker, ChatGPT CDP host supervisor, and chat bridge.
7. Confirm the first autonomous bootstrap creates a fresh Hadalis Cloud chat, uses the GitHub connector, fetches current `dev` HEAD, and advances by loop markers without the user typing "continue".

Live acceptance 009 did publish a result, but it failed before any ChatGPT interaction: `node --check automation/chat_bridge/desktop_cli.mjs` caught an extra `)` introduced while switching to synchronous `fs.writeSync` output. The syntax defect is fixed; 010 reruns the same four checks and live acceptance.

Live acceptance 012 exited and published normally, confirming the CDP-process hang is fixed. Its only failure was `No completed assistant HADALIS_LOOP response found` after completion had already been detected. Root cause: the renderer can flatten marker text together with response toolbar/neighbor text, while extraction required a full-line marker match. The driver now scans protocol marker tokens independent of UI line boundaries, chooses the last marker near the newest response action with a body-level fallback, and a static regression test covers merged UI suffix text plus duplicate prompt/assistant markers. Acceptance 013 validates this path before the next service rollout step.
