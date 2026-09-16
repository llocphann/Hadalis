# Hadalis multi-bot agent routing

This repository is developed concurrently by BOT 1 through BOT 5.

When the user sends the generic continuation prompt (for example: `tiếp tục thực hiện nhiệm vụ`), every bot must:

1. Identify its existing BOT number from the conversation/project context.
2. Fetch the latest `dev` HEAD before doing anything else. Never assume a previously seen HEAD is current.
3. Read `docs/BOT_TASKS.md` and take the current task assigned to that BOT number.
4. Re-verify that the task is still unresolved on the latest `dev`. Another bot may already have fixed it.
5. If the assigned task is already resolved, run its targeted verification and then pivot to the next highest-value unresolved item inside that bot's normal role. Do not idle.
6. Mutate `dev` only. Never mutate `stable`.
7. Keep commits atomic. Immediately before every write/ref update, re-fetch `dev` and avoid overwriting concurrent work.
8. Do not revert or rewrite another bot's valid concurrent changes merely to make a stale test pass. Prefer updating stale contracts when runtime behavior is intentionally newer.
9. Validate with repository scripts and report the exact commit SHA plus PASS/FAIL evidence.
10. Do not require or request Work mode for repository work.

Important project rule: Waffle is a separate supported panel family. Never classify Waffle as legacy code to remove.

The detailed stabilization assignments and ownership boundaries live in `docs/BOT_TASKS.md`.
