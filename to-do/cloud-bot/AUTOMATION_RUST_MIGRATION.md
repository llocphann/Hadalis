# Future Automation Rust migration

Status: **deferred research / future migration plan only**. This note does not authorize a runtime cutover by itself.

Research baseline: `dev` at `bea23fc621f0c13d951140c293d546566f141349` on 2026-09-30. Re-fetch the current `dev` HEAD and re-audit every referenced file before implementation because Automation is still changing.

Related contract: [`docs/AUTOMATION_ARCHITECTURE.md`](../../docs/AUTOMATION_ARCHITECTURE.md).

## Decision summary

Do **not** rewrite all Automation in Rust. Migrate the Linux/process-sensitive execution substrate first, keep orchestration in Python until measurements justify further movement, and keep the Desktop/CDP adapter in JavaScript while that remains the closest stable boundary to ChatGPT Desktop.

Priority order:

1. **P0 — Rust process execution substrate**
   - `automation/worker/process.py`
   - the low-level execution parts of `automation/worker/runner.py`
   - `automation/worker/child.py`
2. **P1 — Rust privilege broker**
   - broker/server and elevated process supervision in `automation/worker/privilege.py`
3. **P2 — benchmark-gated worker daemon migration**
   - consider `automation/worker/daemon.py` only after P0/P1 are proven and profiled
4. **P3 — manager migration only if later profiling proves a meaningful bottleneck**
   - `automation/manager/daemon.py` is not a current Rust priority

Initially keep these in Python:

- `automation/manager/model.py`
- `automation/manager/store.py`
- `automation/manager/control.py`
- `automation/worker/diagnostics.py`
- `automation/worker/deployment.py`
- install/test/validation scripts

Keep the ChatGPT Desktop/CDP adapter in JavaScript unless that transport boundary is redesigned separately.

## Why P0 is the strongest Rust candidate

The current execution path already operates at Linux primitive level rather than ordinary Python business logic.

`automation/worker/process.py` currently owns:

- process/session creation through `subprocess.Popen(..., start_new_session=True)`;
- `/proc/<pid>/stat` identity plus boot ID checks;
- nonblocking stdout/stderr with `selectors`, `os.set_blocking` and `os.read`;
- bounded capture while hashing the complete streams;
- timeout and cancellation;
- process-group `SIGTERM` followed by `SIGKILL`;
- cleanup when descendants inherit output file descriptors;
- process identity checks used by orphan recovery.

`automation/worker/runner.py` and `child.py` add:

- `ctypes` calls into `prctl`;
- `PR_SET_NO_NEW_PRIVS`;
- parent-death signalling;
- resource limits;
- the child/exec gap where durable execution identity must exist before arbitrary external code runs;
- signal-driven cancellation.

Those responsibilities are a better fit for a small typed native component than for expanding Python + `ctypes`/Linux-specific glue. The expected gain is primarily stronger lifecycle/resource correctness and lower process-management overhead; any speed or memory claim must still be benchmarked.

## Why the privilege broker is P1

`automation/worker/privilege.py` is a security boundary. It currently implements:

- a mode-0600 Unix socket;
- `SO_PEERCRED` same-UID validation;
- a typed logical allowlist implemented through runtime dictionary/string validation;
- durable request identity and input digest receipts;
- `sudo -n` or `pkexec` selection;
- bounded elevated `systemctl` execution;
- secret redaction;
- indeterminate handling when delivery may already have happened.

Rust can make the request/operation/unit protocol statically typed while keeping the same least-privilege design. This migration must not broaden the allowlist or introduce any password/token field.

## Existing Rust infrastructure to reuse

Hadalis already ships a production Rust workspace in `native/` using Rust 1.95 / edition 2024. The workspace already carries useful dependencies such as `anyhow`, `clap`, `libc`, `serde`, `serde_json` and `sha2`.

The native backend also already has a Python rollback strategy. Reuse its build/install/CI lessons, but **do not copy its automatic runtime fallback semantics blindly** for Automation.

Candidate future layout:

```text
native/
├── crates/
│   ├── inir-protocol/
│   ├── inir-automation-protocol/     # versioned serde request/result types
│   └── inir-automation-process/      # Linux process/pipe/identity primitives
├── inir-automation-exec/             # bounded action execution
└── inir-automation-privileged/       # Unix-socket privilege broker
```

A later `inir-automation-worker` daemon should be added only if profiling justifies P2.

Do not introduce an async runtime merely because the code is moving to Rust. Start with the smallest blocking/polling implementation that preserves the current semantics, then benchmark.

## Non-negotiable exactly-once / uncertainty rule

Automation cannot safely use the generic pattern:

```text
try Rust
if Rust fails:
    rerun the same action with Python
```

A Rust process may have launched or partially completed an external mutating command before its caller loses the result. Running Python afterward could execute the action twice.

Therefore:

1. choose the executor backend **before dispatch**;
2. persist the selected backend and dispatch intent before the external action;
3. once the action reaches a durable `dispatching`/`executing` boundary, never switch backend and retry that action automatically;
4. if the outcome cannot be proven, return `indeterminate` with `recovery_required=true`;
5. Python rollback may be selected for a **new, not-yet-dispatched** action/job only;
6. an unresolved receipt must remain bound to the backend that created it until reconciled.

This rule is more important than obtaining a successful test result.

## Compatibility boundary

The first migration should preserve the existing Python worker/manager contracts instead of combining a Rust rewrite with a state/schema redesign.

Preserve semantically:

- current job JSON schema and SHA pinning;
- private durable job/action receipts;
- `dispatching -> executing -> finished` intent ordering;
- `exit_code`;
- `timed_out`;
- `cancelled`;
- captured `stdout` / `stderr`;
- complete-stream byte counts;
- SHA-256 values;
- truncation flags;
- evidence IDs and source SHA provenance;
- current public-result sanitization/redaction;
- process identity and orphan-recovery semantics;
- resource leases;
- current cancellation-file behavior;
- existing consumed-result / no-rerun guarantees.

If extra native metadata is useful, keep it private and versioned, for example `executor_backend`, protocol version and native build identity. Do not silently change the Git result schema.

## Staged migration

### Phase 0 — freeze behavioral contracts and collect baseline

Before adding native execution:

- re-fetch current `dev`;
- enumerate every caller of `bounded_run`, `process_identity`, `is_same_process` and `kill_group`;
- record current focused Automation test coverage;
- add missing crash-point fixtures before changing ownership of receipts;
- collect Python baseline CPU, RSS, spawn/cancel latency and output-drain measurements.

Do not infer a required percentage improvement in advance.

### Phase 1 — dormant Rust exec helper

Add Rust process/protocol crates and a dormant `inir-automation-exec` binary while Python remains the default.

Prefer migrating the `exec` action substrate first rather than rewriting all action kinds. Python may continue orchestrating diagnostics, deployment and privilege actions while the Rust helper owns the child process lifecycle.

The native helper must be able to durably expose the spawned process identity before arbitrary external code is considered safely executing. Design the IPC/file protocol around this requirement rather than around convenience.

### Phase 2 — explicit A/B parity selector

Add an explicit staging selector such as:

```text
HADALIS_AUTOMATION_EXECUTOR=python|rust
```

Do not add an `auto` mode that retries a started action on another backend.

Run the same deterministic fixtures against Python and Rust and compare semantic results. Keep Python available as rollback for future unstarted work during qualification.

### Phase 3 — Rust privilege broker

Move the broker server to a separate Rust binary while keeping the same socket path/protocol or a deliberately versioned compatible protocol.

Required parity:

- socket is not usable by other UIDs;
- request size stays bounded;
- unit names and operations remain allowlisted;
- reused request identity with changed input remains rejected;
- disconnect after possible delivery stays `indeterminate`;
- credentials never enter request JSON, argv, receipts or Git results;
- durable receipt precedes the only elevation point.

Do not merge the privilege broker into the ordinary worker process.

### Phase 4 — benchmark worker daemon

Only after P0/P1 qualification, profile `automation/worker/daemon.py`.

A Rust daemon migration is justified only if evidence shows useful improvement in one or more of:

- idle CPU/wakeups;
- resident memory;
- high-output drain overhead;
- job scheduling latency;
- concurrent job scaling;
- recovery latency/robustness.

Git fetch/clone/show/push and filesystem operations are external/I/O dominated, so a full daemon rewrite may provide little benefit. Keep Python if that is what measurements show.

### Phase 5 — production cutover

Cut over the execution substrate only after parity, crash recovery and local acceptance all pass on the same SHA.

Update the source/package install path so the required Automation Rust binaries are built and installed alongside the existing native runtime. Add protocol/version diagnostics so a stale binary cannot silently consume a newer Python schema.

Keep an explicit Python rollback path for **new** work. Do not switch an unresolved action to another backend.

### Phase 6 — optional manager re-evaluation

Profile the manager after worker migration. Do not port it only for language uniformity.

The current manager spends substantial time waiting on Desktop/Node, Git, filesystem state and polling intervals. `manager/store.py` also intentionally pays `fsync`/atomic-rename cost for durability; Rust does not remove that disk latency.

A manager rewrite needs separate evidence and a separate design note if ever justified.

## Mandatory parity and failure matrix

P0 cannot cut over without tests for at least:

- zero exit;
- nonzero exit;
- timeout;
- explicit cancellation;
- SIGTERM-ignoring child requiring SIGKILL;
- descendant holding inherited stdout/stderr FDs;
- large stdout;
- large stderr;
- simultaneous stdout/stderr pressure;
- invalid UTF-8;
- capture truncation with complete byte/hash accounting;
- child exits before identity capture;
- parent/runner death before child spawn;
- parent/runner death after spawn but before final receipt;
- PID reuse/process-identity mismatch;
- boot-ID mismatch;
- cancellation during output drain;
- cwd boundary/escape rejection;
- environment/session socket parity;
- no-new-privileges and resource-limit parity;
- existing finished action is consumed without rerun;
- ambiguous action receipt is not rerun;
- daemon restart orphan recovery;
- worker restart with unpublished finished result;
- Git publication retry does not repeat execution.

Privilege tests additionally need:

- foreign-UID connection rejection;
- malformed/oversized request;
- non-allowlisted unit;
- identical request replay;
- request-ID reuse with different digest;
- broker/client disconnect at each durable phase;
- `sudo-cache` unavailable;
- polkit cancellation/failure;
- redaction of sensitive-looking output.

Crash tests should target the durable boundaries explicitly, not only happy-path subprocess fixtures.

## Benchmark set

Record Python and Rust results on the same machine/build where practical:

- cold helper/action startup latency: median and tail;
- repeated short-action latency;
- CPU time while draining sustained stdout/stderr;
- peak RSS;
- cancellation-to-process-death latency;
- timeout enforcement latency;
- 1/2/4 concurrent action behavior;
- idle RSS/CPU/wakeups if the daemon itself is compared;
- recovery after forced runner/daemon death.

Performance is secondary to semantic parity. A faster executor that weakens receipt ordering, cancellation or orphan recovery is a regression.

## Packaging and CI work required at implementation time

Expected future touch points include:

- `native/Cargo.toml`;
- new Automation protocol/process crates and binaries;
- `native/scripts/install-runtime.sh`;
- `.github/workflows/native-rust.yml`;
- `scripts/install-hadalis-automation.py`;
- focused Python/Rust parity scripts under `scripts/`;
- Automation worker tests;
- systemd units if the privilege broker becomes a native service;
- package/source install manifests that enumerate native binaries.

Keep `cargo fmt`, clippy with warnings denied, locked tests and parity fixtures in the native CI path.

## Rollback requirements

Rollback must be boring and evidence-preserving.

- Keep the Python executor available through the initial production cutover.
- Display/diagnose which backend produced a private receipt.
- Never delete or rewrite Rust-created unresolved receipts just to return to Python.
- Stop/resume only at safe boundaries.
- Roll back the default backend for future work, then reconcile any existing Rust in-flight/indeterminate action separately.
- Preserve old result/receipt readers across the transition until retained history no longer requires them.

## Parts that should remain Python unless new evidence appears

### Manager / scheduler

Keep Python initially. Its current bounded thread pool and two-second scheduler cadence are not obvious CPU hot paths, and Desktop/Git waits dominate many turns.

### Durable store

Keep `manager/store.py` initially. Atomic temporary files, `fsync`, rename and directory `fsync` are correctness costs dominated by storage latency. Porting JSON serialization alone is unlikely to matter.

### Diagnostics and deployment

Keep their orchestration in Python while the commands they launch remain external tools. They benefit from rapid iteration and readable validation logic.

### Test and install tooling

Keep Python/shell unless a specific measured reason requires otherwise.

### Desktop/CDP bridge

Keep JavaScript while the Desktop adapter is tied to Electron/CDP semantics. A separate persistent transport redesign may be valuable, but it is not part of this Rust migration.

## Open design questions before implementation

Resolve these from current-head evidence before coding:

- Should the exec helper communicate through a versioned request/result file, stdin/stdout, or a Unix socket?
- Which component owns the durable `executing` receipt in the final P0 design?
- Should process primitives be a shared Rust library used by both exec and privilege binaries?
- What private native build identity is sufficient to diagnose stale binary/source mismatches?
- Can session-environment discovery remain Python-owned, or should its exact current behavior move into the native helper?
- Which crash points need a purpose-built fault-injection hook for deterministic tests?
- Does worker-daemon profiling justify P2 at all?

Do not answer these by preference alone; use parity fixtures and measurements.

## Completion definition

This future migration is complete only when:

- Rust is the qualified production executor for the targeted low-level components;
- Python fallback remains safe and cannot duplicate an uncertain action;
- all durable receipt/recovery guarantees are preserved;
- privilege boundaries are no broader than today;
- packaging installs matching native binaries reliably;
- focused parity + crash tests and the canonical maintainer validator pass on the exact cutover SHA;
- any claimed performance/resource improvement is supported by measured evidence.

Until then, this file is a migration plan, not a statement that the current Python implementation is defective.
