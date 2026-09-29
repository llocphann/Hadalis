# Active autonomous work

## Objective

Bring the Hadalis autonomous development loop from feasibility to a validated first end-to-end local run while preserving the rule that ChatGPT is the only reasoning agent.

## Current implementation

- deterministic loop-marker protocol and state transitions;
- mandatory GitHub connector mention in automatic prompts;
- ChatGPT Desktop CDP driver and CLI;
- crash-safe bridge runtime with persisted local state and singleton locking;
- deterministic local execution worker;
- user-service installer;
- localhost-only ChatGPT CDP host supervisor;
- regression tests for protocol/state, worker safety, and CDP host safety;
- first-use bootstrap now opens a fresh Hadalis Cloud chat instead of reusing an existing conversation;
- autonomous prompts whose first line is the GitHub connector marker are composed through the ChatGPT rich-mention picker, then the remaining prompt body is inserted without replacing the token;
- completion detection snapshots marker/action counts before submit and accepts a stable post-submit advance after the composer clears, so very fast responses do not require observing Stop and do not depend on a particular Regenerate/Retry label;
- the installer supports a lock-safe fresh bridge-session reset before first service startup.

## Validation status

Focused automation validation `JOB-AUTOMATION-VALIDATE-002` passed all six actions.

Canonical maintainer validation `JOB-MAINTAINER-VALIDATE-001` ran successfully as a validator but returned FAIL because the repository currently has 33 product/regression failures outside the autonomous automation path. The automation-specific tests inside that canonical run all passed:
- `scripts/test-hadalis-chat-bridge.py`
- `scripts/test-hadalis-desktop-host.py`
- `scripts/test-hadalis-worker.py`

Do not describe the current repository SHA as canonically green.

## Current gate

Pending local live transport acceptance:

`JOB-DESKTOP-LIVE-ACCEPT-007`

It performs a syntax check, then opens a fresh Hadalis Cloud chat through the production CDP driver, sends a fixed prompt containing the GitHub connector mention, verifies read access to `llocphann/Hadalis` and current `dev` HEAD through ChatGPT, waits for generation completion, and requires exactly:

`HADALIS_LOOP:DONE`

After this passes, proceed to the one-time user-service installation and first real autonomous bootstrap session.
