# Hadalis deterministic worker

The worker is the **hands**, never the brain. ChatGPT remains the only component that chooses commands, patches, goals, or next development steps.

## Job contract

ChatGPT publishes an explicit job at:

```text
automation/queue/pending/JOB-000001.json
```

Example:

```json
{
  "id": "JOB-000001",
  "base_sha": "<40-character dev HEAD before the job file is created>",
  "actions": [
    {
      "exec": {
        "argv": ["bash", "scripts/validate-maintainer-local.sh"],
        "cwd": ".",
        "timeout_seconds": 1800
      }
    }
  ]
}
```

`base_sha` must equal the first parent of the commit that introduces the job file. This makes a stale or raced GitHub write fail closed instead of silently running against an unexpected repository state.

The worker:

1. fetches `origin/dev`;
2. discovers pending job JSON files;
3. skips jobs that already have a result;
4. resolves the exact commit that introduced the job;
5. verifies its first parent against `base_sha`;
6. clones an isolated automation-owned workspace at that exact commit;
7. executes only the explicit `argv` arrays, never `shell=True`;
8. captures exit code/stdout/stderr with bounded output;
9. removes only its own temporary workspace;
10. publishes a result to `automation/results/JOB-000001.json` through a normal non-force push.

No job is retried once its result exists on `dev`.

## Safety boundaries

- No hard reset, clean, force push, or shared-history rebase.
- The maintainer worktree is never checked out, reset, or cleaned by the worker.
- Command working directories must remain inside the isolated execution clone.
- Execution environment variables are allowlisted.
- Per-command timeouts and capture limits are enforced.
- One local daemon instance is enforced with a file lock under `XDG_STATE_HOME`.
- Publish races are handled by recloning current `dev` and retrying a normal push.

Run one discovery/execution cycle with:

```bash
python automation/worker/daemon.py --once
```

Run continuously with:

```bash
python automation/worker/daemon.py
```
