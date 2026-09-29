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
- completion detection snapshots loop-marker count before submit and treats a stable post-submit marker-count increase with no active Stop control as the protocol completion signal; it does not depend on composer clearing or response-toolbar labels;
- desktop CLI/live acceptance explicitly terminate their Node process after synchronously writing the result, so the open CDP websocket cannot keep the worker action alive after ChatGPT has already completed.
- the installer supports a lock-safe fresh bridge-session reset before first service startup.

## Validation status

- first service rollout exposed a systemd unit syntax bug: `WorkingDirectory=` was emitted with literal quotes, so systemd treated the value as non-absolute and rejected `hadalis-chatgpt.service` as a bad unit. The installer now emits raw absolute `WorkingDirectory=` paths, quotes complete `Environment=NAME=VALUE` assignments, and runs `systemd-analyze --user verify` before enabling services.
- live acceptance 012 proved completion and worker publication are fixed; its remaining failure was response extraction because the UI can flatten the marker together with toolbar/neighbor text, so exact line matching returned no assistant marker. The driver now token-scans protocol markers independent of UI line boundaries, and a static regression covers merged UI text plus prompt/assistant duplicate occurrences.
- live acceptance 009 failed before opening ChatGPT because `desktop_cli.mjs` had a syntax error in the new synchronous JSON writer path; that syntax defect is fixed and 010 is the retry.
Focused automation validation `JOB-AUTOMATION-VALIDATE-002` passed all six actions.

Canonical maintainer validation `JOB-MAINTAINER-VALIDATE-001` ran successfully as a validator but returned FAIL because the repository currently has 33 product/regression failures outside the autonomous automation path. The automation-specific tests inside that canonical run all passed:
- `scripts/test-hadalis-chat-bridge.py`
- `scripts/test-hadalis-desktop-host.py`
- `scripts/test-hadalis-worker.py`

Do not describe the current repository SHA as canonically green.

## Current gate

Live transport acceptance `JOB-DESKTOP-LIVE-ACCEPT-013` passed all five actions, including:
- static loop-marker scanner regression;
- production rich GitHub mention composition;
- automatic submit;
- current `dev` HEAD verification through the GitHub connector;
- generation completion and exact `HADALIS_LOOP:DONE` extraction;
- explicit Node/CDP process termination and worker result publication.

The current gate is retrying the one-time user-service installation with the corrected systemd unit syntax, then validating all three services and the first real autonomous bootstrap session. The one-shot worker also prints a concise terminal outcome after publishing its result.
