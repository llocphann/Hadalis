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

Execution uses a private fsynced job/action ledger under
`$XDG_STATE_HOME/hadalis-automation/worker`. The supervisor admits at most two
jobs by default (`HADALIS_WORKER_CONCURRENCY`, bounded 1..4), with a separate
single publisher. Publication failure retries the saved result, never the
commands. Stable job IDs are execution tombstones; do not reuse an ID for a
different job. Recovery reports an interrupted external action as
`indeterminate`, with `recovery_required`, instead of guessing its outcome.

Jobs may name `profile_id` and up to eight `resources` (for example
`shell:inir`). Only equal resource names serialize. Each command has bounded
pipe capture, process-group cancellation, CPU/address-space limits and a
parent-death guard. Startup terminates identified orphan groups, reconstructs
completed receipts and cleans private clones. Completed evidence expires after
14 days; execution tombstones stay. A 256 MiB evidence admission limit prevents
unbounded collection. Cancellation is a durable file in `worker/cancellations`
named by job ID, written by the control frontend.

An action can collect evidence without Quickshell:

```json
{"diagnostics":{"checks":["services","processes","journal","git","resources","runtime"],"lines":100}}
```

Supported checks also include hardware, crashes, config and one private
screenshot. Config reads are restricted to compositor/shell/Automation paths;
credential paths are denied. Capture, journal history, commands and observation
time are bounded. Evidence IDs, source SHA and timestamps identify every action.
Raw stdout, journals, configuration and screenshots remain private (0700/0600).
Git results use a strict metadata allowlist, not heuristic log redaction.
The managed chat can receive structured error codes and status metrics with
provenance; it must cite the evidence supporting each debugging conclusion.

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
