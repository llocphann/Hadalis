# Autonomous session checkpoint

Desktop feasibility is complete: submit, generation start, generation completion, and response detection all passed.

Focused automation validation `JOB-AUTOMATION-VALIDATE-002` passed every action. Canonical validation `JOB-MAINTAINER-VALIDATE-001` completed but the repository remains non-green because of 33 unrelated product/regression failures; the three Hadalis automation regression tests passed inside that run.

A production-safety change now starts new autonomous sessions with `rotate-send`, which creates a fresh chat inside Hadalis Cloud before sending the initial prompt. Continuations remain in the current chat; explicit rotation also uses `rotate-send`.

Interactive testing confirmed the GitHub rich-mention picker path can select GitHub, append the prompt body, and submit. The production desktop driver now converts the tracked first-line connector marker into that rich mention instead of filling the markdown literal into the composer. Rotation also follows the renderer that owns the newly created chat.

The 005, 006, and 007 live runs visibly completed in ChatGPT with the correct current dev HEAD and HADALIS_LOOP:DONE, but the worker still did not publish a result. The 007 evidence showed the response itself was correct while the completion detector remained too coupled to composer/toolbar state. The driver now uses the autonomous protocol directly: snapshot loop-marker count before submit, then complete when that count increases and no Stop control is active, with a short stability confirmation. The live test wait is bounded to 90 seconds. A lock-safe `--reset-state` runtime path plus installer `--reset-session-state` option is ready for the first service rollout.

Pending mechanical evidence: `JOB-DESKTOP-LIVE-ACCEPT-008`.

Resume procedure:
1. Fetch current `dev` HEAD.
2. Read `automation/results/JOB-DESKTOP-LIVE-ACCEPT-008.json` if present.
3. If absent, wait for the deterministic local worker; do not invent the result.
4. If it failed, inspect exact stdout/stderr and fix forward on current `dev`.
5. If it passed, install the user services from the maintainer's persistent local checkout, not from an ephemeral worker clone.
6. Start the worker, ChatGPT CDP host supervisor, and chat bridge.
7. Confirm the first autonomous bootstrap creates a fresh Hadalis Cloud chat, uses the GitHub connector, fetches current `dev` HEAD, and advances by loop markers without the user typing "continue".
