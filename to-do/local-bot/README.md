# Local Bot — deterministic execution only

Hadalis has **one reasoning agent: ChatGPT/Cloud Bot**. Local Bot is the existing worker, not another LLM planner. It may only execute explicitly supplied SHA-pinned `argv` jobs in an isolated checkout and publish bounded stdout/stderr/exit status. It must not choose tasks, decide commands, patch files, change priorities, mutate the maintainer worktree or judge visual acceptance.

See [VALIDATION.md](VALIDATION.md) for dispatchable jobs and a separate **maintainer-only** acceptance inventory. The binding worker contract is [`../../automation/worker/README.md`](../../automation/worker/README.md) and [`../../agent/CONTEXT.md`](../../agent/CONTEXT.md).

