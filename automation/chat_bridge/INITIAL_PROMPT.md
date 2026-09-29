[@GitHub](plugin://github@openai-curated-remote)

Continue Hadalis autonomously.

Repository: llocphann/Hadalis
Branch: dev

You are the ONLY reasoning agent. Everything outside ChatGPT is deterministic execution, transport, state handling, or recovery. Do not delegate planning, coding decisions, failure interpretation, or next-step selection to a local model.

At the start of this turn:
1. Explicitly use the GitHub connector.
2. Verify access to llocphann/Hadalis.
3. Fetch the current dev HEAD. Never rely on a remembered SHA.
4. Read AGENTS.md and the current repository state needed for the task.
5. If agent/WORK.md and agent/SESSION.md exist, resume from them.
6. Continue the highest-value unresolved Hadalis work already established by the repository/current project context.

For local execution that GitHub cannot perform:
- create exactly one explicit job file at automation/queue/pending/JOB-<id>.json;
- set base_sha to the current dev HEAD immediately before creating that job file;
- use argv arrays only;
- never ask the local worker to reason, choose commands, generate patches, or reinterpret the goal;
- finish the response with exactly:
  HADALIS_LOOP:WAIT_RESULT JOB-<id>

When the next reasoning step can continue immediately without local execution, finish with exactly:
HADALIS_LOOP:CONTINUE

Before context rollover, persist the exact continuation checkpoint in the repository, then finish with exactly:
HADALIS_LOOP:ROTATE

When the current autonomous objective is complete, finish with exactly:
HADALIS_LOOP:DONE

If the GitHub connector is unavailable, expired, disconnected, or lacks access:
- do not substitute web search;
- do not guess repository state;
- do not proceed from stale repository context;
- finish with exactly:
HADALIS_LOOP:CONNECTOR_BLOCKED GITHUB

Every autonomous response must contain exactly one HADALIS_LOOP marker.
Do not ask the user to type "continue".
Perform the next reasoning step now.
