# Autonomous session checkpoint

Desktop feasibility is complete: submit, generation start, generation completion, and response detection all passed.

Focused automation validation `JOB-AUTOMATION-VALIDATE-002` passed every action. Canonical validation `JOB-MAINTAINER-VALIDATE-001` completed but the repository remains non-green because of 33 unrelated product/regression failures; the three Hadalis automation regression tests passed inside that run.

A production-safety change now starts new autonomous sessions with `rotate-send`, which creates a fresh chat inside Hadalis Cloud before sending the initial prompt. Continuations remain in the current chat; explicit rotation also uses `rotate-send`.

Interactive testing confirmed the GitHub rich-mention picker path can select GitHub, append the prompt body, and submit. The production desktop driver now converts the tracked first-line connector marker into that rich mention instead of filling the markdown literal into the composer. Rotation also follows the renderer that owns the newly created chat.

The 005 through 008 live runs visibly completed in ChatGPT with the correct current dev HEAD and HADALIS_LOOP:DONE, while the local worker action remained alive. The uploaded original successful submit probe explicitly called `process.exit(0)` after writing its result; the production CLI/live test had instead relied on Node exiting naturally while a Playwright CDP websocket remained attached. The CLI and live acceptance now write JSON synchronously with `fs.writeSync` and explicitly exit after success/error, without calling `browser.close()` and therefore without closing ChatGPT Desktop. Marker-delta completion remains the protocol signal. A lock-safe `--reset-state` runtime path plus installer `--reset-session-state` option is ready for the first service rollout.

Pending mechanical evidence: `JOB-DESKTOP-LIVE-ACCEPT-009`.

Resume procedure:
1. Fetch current `dev` HEAD.
2. Read `automation/results/JOB-DESKTOP-LIVE-ACCEPT-009.json` if present.
3. If absent, wait for the deterministic local worker; do not invent the result.
4. If it failed, inspect exact stdout/stderr and fix forward on current `dev`.
5. If it passed, install the user services from the maintainer's persistent local checkout, not from an ephemeral worker clone.
6. Start the worker, ChatGPT CDP host supervisor, and chat bridge.
7. Confirm the first autonomous bootstrap creates a fresh Hadalis Cloud chat, uses the GitHub connector, fetches current `dev` HEAD, and advances by loop markers without the user typing "continue".
