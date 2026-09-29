# Autonomous development invariants

- ChatGPT is the only reasoning agent.
- No Local LLM may plan, choose commands, generate patches, interpret failures, or select the next development step.
- The local worker only executes explicit deterministic jobs and returns mechanical evidence.
- Repository state on `llocphann/Hadalis` branch `dev` is the durable source of truth.
- Every automatic ChatGPT prompt starts with `[@GitHub](plugin://github@openai-curated-remote)` and verifies connector access by fetching the current `dev` HEAD.
- If GitHub is unavailable, expired, disconnected, or lacks access, stop with `HADALIS_LOOP:CONNECTOR_BLOCKED GITHUB`; never substitute web search or stale repository state.
- Local execution jobs live at `automation/queue/pending/JOB-*.json`; results live at `automation/results/JOB-*.json`.
- Job `base_sha` must equal the first parent of the commit that introduces the job file.
- The worker uses isolated workspaces, argv arrays, bounded capture, allowlisted environment, normal non-force pushes, and never mutates the maintainer worktree.
- Chat/session identifiers, CDP targets, PIDs, retry counters, cookies, credentials, and temporary output stay local under `XDG_STATE_HOME` and are never committed.
- Work directly on `dev`, respect concurrent updates, refetch before every write, and never force-push or rewrite shared history.
