# Future Automation Rust migration

Status: **deferred research / future migration plan only**. This note does not authorize a runtime cutover by itself.

Research baseline: initial audit at `bea23fc621f0c13d951140c293d546566f141349`; second-pass boundary audit through `00086e6097f23a35fdd13fcbca5df2beed2dc74f` on 2026-09-30. Re-fetch the current `dev` HEAD and re-audit every referenced file before implementation because Automation is still changing.

Related contract: [`docs/AUTOMATION_ARCHITECTURE.md`](../../docs/AUTOMATION_ARCHITECTURE.md).

## Decision summary

Do **not** rewrite all Automation in Rust. Migrate the Linux/process-sensitive execution substrate first, keep orchestration in Python until measurements justify further movement, and keep the Desktop/CDP adapter in JavaScript while that remains the closest stable boundary to ChatGPT Desktop.

Priority order:

1. **P0 — native Rust helper for the `exec` action only**
   - add a small `inir-automation-exec` helper behind the existing `automation/worker/runner.py` `exec` branch;
   - keep `runner.py` as the Python action orchestrator/security envelope;
   - keep `automation/worker/process.py` for Git, diagnostics, deployment and other Python orchestration;
   - retire `automation/worker/child.py` from the exec path only after native parity is proven.
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
- `automation/worker/process.py` as the Python subprocess utility for non-exec orchestration
- `automation/worker/runner.py` as the job/action orchestrator during P0
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

**Second-pass scope refinement:** `bounded_run` is also used by worker Git operations, private diagnostics, shell deployment and the privilege path. Therefore P0 must **not** replace `bounded_run` globally or delete `process.py`. The first Rust boundary should replace only the arbitrary job `exec` child lifecycle. Python remains responsible for the surrounding job state machine and the other external-tool orchestration.

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

Candidate future layout should start smaller than the first audit proposed:

```text
native/
├── inir-automation-exec/             # P0: bounded exec-action supervisor + hidden child-exec mode
└── inir-automation-privileged/       # P1: Unix-socket privilege broker
```

Do not create a shared Automation protocol/process crate before it has two real consumers. When P1 starts, extract the stable process/receipt primitives into `native/crates/inir-automation-process/` only if the exec and privilege implementations actually share them. A later `inir-automation-worker` daemon should be added only if profiling justifies P2.

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

Add one dormant `inir-automation-exec` binary while Python remains the default. Do not move the whole runner or generic `bounded_run` in this phase.

Recommended P0 handoff:

1. Python resolves/validates `cwd`, builds the allowlisted environment with the existing `session_env`, computes the existing Python `command_sha256`, verifies native protocol capability, selects the backend, then writes the durable action `dispatching` intent including private `executor_backend` and protocol metadata.
2. Python invokes `inir-automation-exec` with only bounded control arguments such as spec/receipt path and action index. Do not expose the target job argv as the helper's own process argv.
3. The Rust supervisor validates that the request belongs to the expected private worker/action directory and that the existing receipt is the matching `dispatching` intent.
4. A hidden child-exec mode arms `PR_SET_PDEATHSIG`, verifies its expected parent, updates the same action receipt to `executing` with the target process identity, fsyncs it, then execs the target in place. Preserve the current identity shape: integer `pid`, string `start_ticks`, string `boot_id`.
5. The Rust supervisor owns target pipe draining, full-stream hashes/counts, per-stream capture limits, timeout and process-group TERM/KILL behavior. It must react to cancellation/termination without letting the target group silently escape.
6. Target stdout/stderr must **not** be written durably by Rust before sanitization. Return bounded captured bytes through an ephemeral parent channel (for example base64 fields in the helper's captured JSON stdout); Python decodes with its existing UTF-8 `errors="replace"`, applies `privacy.redact`, adds evidence/source/timestamp provenance and writes the final `finished` action receipt.
7. If the helper or Python runner disappears after dispatch but before the Python `finished` receipt is durable, preserve the existing conservative result: `indeterminate` / recovery required, never an automatic replay.

The helper's own exit code is a **transport/protocol status**, not the target command exit code. A successfully observed target that exits nonzero should still allow the helper itself to return transport success with the target `exit_code` inside the result envelope.

This split keeps privacy policy and job orchestration in Python while moving the Linux child lifecycle into Rust.

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

## Second-pass design decisions

The current source resolves several questions from the first audit.

### P0 transport and receipt ownership

Use the existing durable filesystem ledger for request identity and phase state; do not add a persistent socket for the exec helper. The helper result itself should cross an **ephemeral pipe**, not a durable raw-output file.

Phase ownership should be explicit:

- Python writes `dispatching`, including backend/protocol selection and the legacy `command_sha256`.
- Rust child-exec writes `executing` immediately before target exec, preserving the existing intent fields and durably recording process identity.
- Python writes `finished` only after it has decoded and redacted captured output and added provenance.

This deliberately leaves a crash after target completion but before Python finalization as `indeterminate`, matching the current conservative semantics instead of persisting unredacted command output.

A JSON result envelope with base64-encoded captured bytes is a reasonable P0 transport because the capture is already bounded. It keeps invalid UTF-8 byte-exact until Python applies the current decoder/redactor. Derive the outer helper capture bound from the configured per-stream capture limit; never make it unbounded.

### Keep environment discovery in Python

`session_env` has Hadalis-specific fallback discovery for Wayland, Niri and the user D-Bus socket. It is not a generic process primitive. Keep it in Python and pass the final allowlisted environment map to Rust. This prevents a second implementation from choosing a different compositor/session socket.

### Keep legacy digests Python-owned where practical

The current `command_sha256` is computed from Python `json.dumps(argv)`; changing serializers can change hashes for spacing/escaping/non-ASCII data. During P0, compute this digest in Python before dispatch and preserve it through the Rust helper rather than inventing a second canonicalization.

Likewise, the job `input_sha256` remains owned by the Python daemon because it hashes the exact Git job text.

### Rust binary layout

For P0, prefer one `inir-automation-exec` binary with a private/hidden child-exec mode over two separately packaged binaries. The repository already uses direct `libc::prctl` parent-death handling in `inir-mpdd`, so this approach matches existing native style without introducing an async runtime.

Extract a shared process crate only when P1 proves that the privilege broker needs the same primitives.

### Capability/version check

Add a non-mutating capability command that returns at least binary name, protocol version, package version and optional build source identity. Protocol compatibility is the hard gate; exact source SHA should be diagnostic only because Hadalis already supports services running from a source checkout that differs from the deployed Quickshell tree.

Probe capability **before** writing an action's `dispatching` intent. If the selected Rust backend is unavailable or incompatible at that point, Python may remain selected for that new action. After `dispatching`, backend switching is forbidden.

### Privilege service boundary

Keep the privilege broker a separate same-user service. Today `hadalis-worker.service` has `NoNewPrivileges=yes`, while `hadalis-privilege.service` deliberately does not because it must invoke the fixed `sudo`/polkit elevation path. A Rust migration must preserve that separation; do not make the worker privileged and do not run the broker itself as root.

Backend selection for the privilege service should be fixed when the service starts. If a Rust broker crashes after a request may have been delivered, systemd may restart the same backend, but a dispatcher must not silently switch to Python and replay the request.

The broker's existing receipt digest is based on Python `json.dumps(spec, sort_keys=True)`. Before P1 cutover, update the Python broker/reader to understand an explicit digest scheme or otherwise provide backward-compatible comparison of legacy receipts. Do not introduce Rust receipts that the Python rollback path would reject.

### Packaging/discovery

`native/scripts/install-runtime.sh` currently enumerates four production binaries explicitly, and `setup` builds that qualified runtime into the active runtime tree. A future Automation binary therefore requires explicit install-list and CI updates.

The standalone `scripts/install-hadalis-automation.py` currently does not build Rust. Before production cutover it needs a deterministic source-checkout-local binary discovery/build policy. Do not resolve Automation helpers from an unrelated deployed QML tree.

Use an Automation-specific selector such as `HADALIS_AUTOMATION_EXECUTOR=python|rust`; do not reuse the global `INIR_NATIVE_BACKEND` selector because Automation has stricter no-replay fallback semantics.

### P2 daemon economics

The worker daemon performs external Git operations and also fsyncs its heartbeat/state through the existing durable writer. Those costs can dominate Python interpreter overhead. Before considering a Rust daemon, separately measure Git latency, heartbeat fsync cost and Python CPU/RSS. Do not attribute I/O latency to the language.

The manager is also still receiving correctness/concurrency changes on current `dev` (including nonblocking shared Git observation at `00086e6097f23a35fdd13fcbca5df2beed2dc74f`), which is another reason not to port that state machine while its contract is actively moving.

## Additional failure cases discovered in the second pass

Add these to the P0/P1 qualification matrix:

- Python runner receives SIGTERM while the Rust helper is supervising a live target;
- Rust supervisor receives SIGTERM and must terminate the target process group before exiting;
- Rust supervisor is SIGKILLed after the child wrote `executing`;
- target completes but the result pipe breaks before Python writes `finished`;
- target emits invalid UTF-8 and embedded NUL bytes;
- helper JSON/base64 result reaches its maximum derived transport size;
- Rust capability mismatch is detected before `dispatching`;
- a stale/mismatched helper is discovered only after an existing Rust `dispatching` receipt (must not fall back);
- legacy Python `command_sha256` remains identical for non-ASCII argv;
- privilege broker replays a legacy Python receipt after Rust cutover;
- privilege broker Rust receipt remains readable after an explicit rollback to Python;
- service stop/restart while an elevated request has been dispatched but its response is lost;
- a target forks a same-process-group child;
- separately document behavior for a target that deliberately creates a new session/process group. Process-group containment is the current contract; stronger hostile-descendant containment would be a separate design, not an implicit promise of this migration.

For fault testing, prefer dependency-injected Rust unit tests plus external kill-at-observed-phase integration tests. Do not add production fault-injection environment variables unless a crash boundary cannot otherwise be exercised deterministically.

## Remaining open questions before implementation

- Does the ephemeral result channel use base64 JSON on stdout or a dedicated inherited binary FD? Base64 JSON is simpler and byte-exact but adds bounded encoding overhead.
- What exact helper transport-size formula and hard ceiling should be enforced for the configured maximum capture?
- Should the Rust atomic receipt writer be local to the exec binary in P0, then extracted only when the privilege broker needs it?
- Does live benchmarking justify P2 worker-daemon migration at all?

Resolve the remaining questions with fixtures and measurements, not language preference.

## Security/systemd constraints to preserve

The installed worker already has `KillMode=control-group`, `TasksMax=256`, `MemoryMax=2G`, `CPUQuota=200%` and `NoNewPrivileges=yes`. The Python runner additionally sets core/no-file/address-space/CPU rlimits so manual/standalone execution keeps a safety envelope. Keeping the Python runner in P0 preserves those limits automatically for the Rust helper and its target descendants.

Do not weaken these layers merely because Rust is memory safe. Rust protects the helper implementation; it does not replace process/cgroup/resource policy.

The privilege service has its own smaller task/memory bounds and intentionally separate elevation semantics. Preserve the exact fixed-command model, including the elevated timeout and `systemctl ... --no-block` behavior for restarts.

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
