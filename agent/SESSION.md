# Autonomous session checkpoint

Desktop feasibility is complete: submit, generation start, generation completion, and response detection all passed.

Focused automation validation `JOB-AUTOMATION-VALIDATE-002` passed every action. Canonical validation `JOB-MAINTAINER-VALIDATE-001` completed but the repository remains non-green because of 33 unrelated product/regression failures; the three Hadalis automation regression tests passed inside that run.

A production-safety change now starts new autonomous sessions with `rotate-send`, which creates a fresh chat inside Hadalis Cloud before sending the initial prompt. Continuations remain in the current chat; explicit rotation also uses `rotate-send`.

Pending mechanical evidence: `JOB-DESKTOP-LIVE-ACCEPT-001`.

Resume procedure:
1. Fetch current `dev` HEAD.
2. Read `automation/results/JOB-DESKTOP-LIVE-ACCEPT-001.json` if present.
3. If absent, wait for the deterministic local worker; do not invent the result.
4. If it failed, inspect exact stdout/stderr and fix forward on current `dev`.
5. If it passed, install the user services from the maintainer's persistent local checkout, not from an ephemeral worker clone.
6. Start the worker, ChatGPT CDP host supervisor, and chat bridge.
7. Confirm the first autonomous bootstrap creates a fresh Hadalis Cloud chat, uses the GitHub connector, fetches current `dev` HEAD, and advances by loop markers without the user typing "continue".
