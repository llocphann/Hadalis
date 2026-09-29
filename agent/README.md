# Hadalis autonomous checkpoint

This directory is a minimal durable checkpoint for the autonomous development loop. It is not a task board, ownership system, or substitute for the product documentation.

Load order for an autonomous continuation:
1. `AGENTS.md`
2. `agent/CONTEXT.md`
3. `agent/WORK.md`
4. `agent/SESSION.md`

GitHub `dev` remains authoritative. Always fetch the current `dev` HEAD before acting; never treat a SHA written here as current without verification.

Update `WORK.md` when the active objective changes. Update `SESSION.md` before emitting `HADALIS_LOOP:ROTATE` so a fresh chat can resume without relying on chat history.
