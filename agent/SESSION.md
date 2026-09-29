# Autonomous session checkpoint

Hadalis automation is now configured for continuous strict-lossless optimization research rather than a one-shot autonomous objective.

## Why the old behavior stopped

The previous bootstrap prompt allowed ChatGPT to emit `HADALIS_LOOP:DONE` when the current objective/round was complete. The bridge correctly treats DONE as terminal, so the service ran once and then exited successfully.

## New continuous research behavior

- `automation/chat_bridge/INITIAL_PROMPT.md` now defines the strict-lossless research objective dynamically from current `dev` and the newest `docs/CROSS_REPO_OPTIMIZATION_HANDOFF.md` state.
- It is research-only unless the maintainer explicitly authorizes implementation.
- Research findings go to `docs/CROSS_REPO_OPTIMIZATION_HANDOFF.md`.
- Completing a research round must lead to CONTINUE, not DONE.
- ROTATE is used before context rollover after persisting a durable research checkpoint.
- local jobs remain deterministic and may only execute explicit argv arrays.
- continuation and rotation prompts remain in the same strict-lossless research mode.
- the bridge service receives `HADALIS_CONTINUOUS_RESEARCH=1`.
- in that mode, even an accidental DONE is converted into another continuation instead of terminating the research service.
- if a previous persisted state is DONE and the service restarts in continuous mode, it opens a fresh research chat and resumes.

## Validation

`JOB-CONTINUOUS-RESEARCH-VALIDATE-001` exposed one stale test expectation in the new continuation prompt.

That prompt was corrected to retain the exact connector-blocked directive.

`JOB-CONTINUOUS-RESEARCH-VALIDATE-002` then passed every action:
- runtime/protocol/installer Python compile;
- `scripts/test-hadalis-chat-bridge.py`;
- desktop driver syntax;
- desktop CLI syntax.

The latest optimization-research commit observed during setup was Round 49. This is only a checkpoint observation; every autonomous research turn must fetch current `dev`, determine the newest handoff round itself, and audit intervening commits.

## Maintainer activation

From the persistent checkout:
1. fast-forward `dev`;
2. reinstall with `python3 scripts/install-hadalis-automation.py --reset-session-state --enable-now`;
3. after startup, do not type `continue` into ChatGPT;
4. stop the continuous research loop explicitly with `systemctl --user stop hadalis-chat-bridge.service` when desired.

The expected steady behavior is repeated research/commit/CONTINUE or ROTATE cycles. The bridge should no longer become inactive merely because a research round finishes.
