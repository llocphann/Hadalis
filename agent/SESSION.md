# Autonomous session checkpoint

Desktop feasibility is complete: submit, generation start, generation completion, and response detection all passed.

Focused automation validation `JOB-AUTOMATION-VALIDATE-002` passed every action. Canonical validation `JOB-MAINTAINER-VALIDATE-001` completed but the repository remains non-green because of 33 unrelated product/regression failures; the three Hadalis automation regression tests passed inside that run.

A production-safety change now starts new autonomous sessions with `rotate-send`, which creates a fresh chat inside Hadalis Cloud before sending the initial prompt. Continuations remain in the current chat; explicit rotation also uses `rotate-send`.

Interactive testing confirmed the GitHub rich-mention picker path can select GitHub, append the prompt body, and submit. The production desktop driver now converts the tracked first-line connector marker into that rich mention instead of filling the markdown literal into the composer. Rotation also follows the renderer that owns the newly created chat.

The 005 through 008 live runs visibly completed in ChatGPT with the correct current dev HEAD and HADALIS_LOOP:DONE, while the local worker action remained alive. The uploaded original successful submit probe explicitly called `process.exit(0)` after writing its result; the production CLI/live test had instead relied on Node exiting naturally while a Playwright CDP websocket remained attached. The CLI and live acceptance now write JSON synchronously with `fs.writeSync` and explicitly exit after success/error, without calling `browser.close()` and therefore without closing ChatGPT Desktop. Marker-delta completion remains the protocol signal. A lock-safe `--reset-state` runtime path plus installer `--reset-session-state` option is ready for the first service rollout.

Live transport acceptance `JOB-DESKTOP-LIVE-ACCEPT-013` passed every action and published its result to `dev`. Transport acceptance is closed.

Resume procedure:
1. Fetch current `dev` HEAD in the maintainer's persistent checkout.
2. Install the user services with a fresh deterministic bridge session:
   `python3 scripts/install-hadalis-automation.py --reset-session-state --enable-now`
3. Confirm `hadalis-chatgpt.service`, `hadalis-worker.service`, and `hadalis-chat-bridge.service` are active.
4. Confirm the first autonomous bootstrap creates a fresh Hadalis Cloud chat, uses the GitHub connector, fetches current `dev` HEAD, and advances by loop markers without the user typing "continue".

Live acceptance 009 did publish a result, but it failed before any ChatGPT interaction: `node --check automation/chat_bridge/desktop_cli.mjs` caught an extra `)` introduced while switching to synchronous `fs.writeSync` output. The syntax defect is fixed; 010 reruns the same four checks and live acceptance.

Live acceptance 012 exited and published normally, confirming the CDP-process hang is fixed. Its only failure was `No completed assistant HADALIS_LOOP response found` after completion had already been detected. Root cause: the renderer can flatten marker text together with response toolbar/neighbor text, while extraction required a full-line marker match. The driver now scans protocol marker tokens independent of UI line boundaries, chooses the last marker near the newest response action with a body-level fallback, and a static regression test covers merged UI suffix text plus duplicate prompt/assistant markers. Acceptance 013 validates this path before the next service rollout step.

The one-shot worker now prints a concise terminal outcome such as `Hadalis worker: JOB-... -> passed; result published to origin/dev`, fixing the confusing silent-return behavior observed after acceptance 013.

The first `--enable-now` rollout failed before service startup because the generated user units used `WorkingDirectory="..."`. `systemd-analyze verify` treats those quotes as part of the path for this directive, making it non-absolute and causing `Unit hadalis-chatgpt.service has a bad unit file setting`. The installer now writes the absolute working directory without literal quotes, quotes complete `Environment=NAME=VALUE` tokens, and verifies all three units with `systemd-analyze --user verify` before any enable/start attempt. Retry the installer from the persistent checkout after fast-forwarding `dev`.

The corrected systemd rollout has now been observed locally in its intended terminal state: `hadalis-chatgpt.service` and `hadalis-worker.service` are active; `hadalis-chat-bridge.service` is inactive/dead with `Result=success`, `ExecMainCode=1` (normal process exit), `ExecMainStatus=0`, and persisted bridge state `done`. This confirms that an inactive bridge after DONE is expected lifecycle behavior, not a failed service.

One final service-mode end-to-end gate remains before declaring the autonomous loop fully validated: reset bridge state, restart only the bridge service, and require the next fresh ChatGPT bootstrap to create one fresh harmless local job with a new `JOB-SERVICE-E2E-*` id and current dev HEAD, emit `HADALIS_LOOP:WAIT_RESULT JOB-...`, let the already-running worker service publish the result, receive the bridge's automatic continuation with no user message, inspect that result, and terminate with `HADALIS_LOOP:DONE`. This specifically validates the WAIT_RESULT -> worker -> result -> automatic continuation path under installed services.
