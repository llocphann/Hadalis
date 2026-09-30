# Future Automation Rust migration

Status: **deferred research / future migration plan only**. This note does not authorize a runtime cutover by itself.

Research baseline: initial audit at `bea23fc621f0c13d951140c293d546566f141349`; boundary/compatibility research continued through `4a7938afc5fc3d035b7c2d579b2e43249ca1857c` on 2026-10-01. Re-fetch the current `dev` HEAD and re-audit every referenced file before implementation because Automation is still changing.

Related contract: [`docs/AUTOMATION_ARCHITECTURE.md`](../../docs/AUTOMATION_ARCHITECTURE.md).

## Decision summary

Do **not** rewrite all Automation in Rust. Migrate the Linux/process-sensitive execution substrate first, keep orchestration in Python until measurements justify further movement, and keep the Desktop/CDP adapter in JavaScript while that remains the closest stable boundary to ChatGPT Desktop.

Priority order:

1. **P0a — Rust child/exec wrapper only**
   - replace the Python `automation/worker/child.py` wrapper with a small `inir-automation-exec` binary that arms parent-death protection, durably records the executing process identity, then `exec`s the requested target in the same PID;
   - keep Python `bounded_run` as the supervisor, pipe drainer, timeout/cancellation owner and process-group killer;
   - keep `runner.py` as the Python action orchestrator/security envelope.
2. **P1 — Rust privilege broker**
   - broker/server and elevated fixed-command process supervision in `automation/worker/privilege.py`.
3. **P0b/P2 — benchmark-gated native supervisor or worker-daemon migration**
   - only consider moving Python `bounded_run`/worker scheduling after P0a/P1 measurements prove that the extra migration complexity has real value.
4. **P3 — manager migration only if later profiling proves a meaningful bottleneck**
   - `automation/manager/daemon.py` is not a current Rust priority.

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
├── inir-automation-exec/             # P0a: pre-exec child wrapper that becomes the target PID
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

### Phase 1 — dormant Rust child/exec wrapper

Add one dormant `inir-automation-exec` binary while Python remains the default. P0a should **not** add a second long-lived supervisor process.

The current `bounded_run(..., execution_receipt=path)` already has the ideal cut point: it launches `child.py` in a new session, and that wrapper becomes the target process through `execvpe`. Replace only that wrapper:

1. Python validates the job/cwd, builds `session_env`, verifies Rust capability and selects the backend **before** writing `dispatching`.
2. Python writes the current action `dispatching` intent plus private backend/protocol metadata.
3. `bounded_run` starts either the existing Python child wrapper or `inir-automation-exec` with the expected parent PID, action receipt path and target argv. Existing stdout/stderr pipes, environment and `start_new_session=True` remain unchanged. The parent immediately fsyncs the spawned wrapper PID into the action receipt **without advancing the phase beyond `dispatching`**; this preserves crash-gap identity while distinguishing “wrapper exists” from “target may have executed”.
4. Rust records the original parent PID, arms `PR_SET_PDEATHSIG(SIGKILL)`, verifies that the parent did not change and returns exit 125 without executing the target if that guard fails.
5. Rust reads the existing action intent, verifies the expected `dispatching` phase/index/kind plus the parent/runner and already-recorded wrapper identity, then updates the receipt to `executing`. It writes mode 0600 through a same-directory exclusive temporary file + file fsync + atomic rename + directory fsync, and **must not exec the target if identity capture or this durable write fails**.
6. Rust then performs Python-compatible PATH search and `execve` semantics so the wrapper PID/process group becomes the target PID/process group. Python `bounded_run` continues to drain/hash/bound stdout/stderr, enforce timeout/cancellation, kill the group and observe the real target exit status exactly as it does today.
7. Python `runner.py` keeps the current UTF-8 replacement, secret redaction, `command_sha256`, evidence/source/timestamp fields and final `finished` receipt.

This P0a path creates no durable raw-output artifact, introduces no result IPC protocol, does not duplicate privacy logic and does not add an extra resident supervisor while the command runs.

The first benchmark should therefore isolate the cost of the current Python `child.py` interpreter/import path versus the Rust wrapper using short commands such as a no-op/true process. Do not assume the end-to-end gain before measuring it.

### Optional later P0b — native process supervisor

Only after P0a is qualified should Hadalis reconsider moving nonblocking pipe draining, stream hashing, timeout/cancellation and process-group supervision out of Python.

A standalone Rust supervisor launched by the still-Python runner adds an extra process layer and a new result protocol, so it can be slower for short commands even if its inner loop is faster. Prefer leaving `bounded_run` in Python unless measurements show meaningful CPU/RSS/high-output or cancellation benefits. If P0b is ever pursued, the second-pass ephemeral-output/privacy constraints below remain mandatory.

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

### P0a transport and receipt ownership

P0a needs **no new result transport at all**. The Rust wrapper inherits the exact target stdout/stderr pipes already owned by Python `bounded_run`, then replaces itself with the target through exec.

Phase ownership stays simple:

- Python writes `dispatching`, including backend/protocol selection and the legacy `command_sha256`.
- Rust writes `executing` before exec, preserving the existing intent fields and durably recording its own identity, which becomes the target identity after exec.
- Python writes `finished` after the existing capture/UTF-8 replacement/redaction/provenance path completes.

This is stricter and simpler than the earlier P0 supervisor proposal: no base64 result envelope, no raw native result file and no duplicate output decoder are needed for P0a.

If P0b later moves the supervisor itself into Rust, captured output must still cross only an ephemeral bounded channel until Python redaction or an independently parity-proven Rust redactor has run.

### Keep environment discovery in Python

`session_env` has Hadalis-specific fallback discovery for Wayland, Niri and the user D-Bus socket. It is not a generic process primitive. Keep it in Python and pass the final allowlisted environment map to Rust. This prevents a second implementation from choosing a different compositor/session socket.

### Keep legacy digests Python-owned where practical

The current `command_sha256` is computed from Python `json.dumps(argv)`; changing serializers can change hashes for spacing/escaping/non-ASCII data. During P0, compute this digest in Python before dispatch and preserve it through the Rust helper rather than inventing a second canonicalization.

Likewise, the job `input_sha256` remains owned by the Python daemon because it hashes the exact Git job text.

### Rust binary layout

For P0a, prefer one `inir-automation-exec` wrapper binary. It does not need a persistent daemon mode or async runtime. The repository already uses direct `libc::prctl` parent-death handling in `inir-mpdd`, so the wrapper can follow an established native pattern.

Extract a shared process crate only when P1 or an evidence-backed P0b proves that multiple native components actually need the same primitives.

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
- wrapper is spawned and parent PID is durably recorded while action phase is still `dispatching`, then the runner is killed before the wrapper arms `PDEATHSIG`;
- wrapper arms `PDEATHSIG` but is killed before it writes `executing`;
- wrapper writes `executing` but `execve` fails;
- target completes but Python crashes before it writes `finished`;
- target argv contains NUL or an unpaired-surrogate value that cannot be represented consistently at the OS/Rust boundary;
- target executable is an executable text file without a valid binary/shebang header (must preserve Python `execvpe` failure semantics, not silently invoke a shell);
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

- Should the Rust atomic receipt writer stay local to `inir-automation-exec` in P0a, then be extracted only when the privilege broker needs it?
- Does P0a's measured startup/CPU/RSS improvement justify any P0b native supervisor work?
- Does live benchmarking justify worker-daemon migration at all?
- If P0b is justified, should its bounded result channel use base64 JSON or a dedicated inherited binary FD?

Resolve the remaining questions with fixtures and measurements, not language preference.

## Third-pass finding: the smallest useful Rust cutover is the child wrapper

The current Python topology is:

```text
worker daemon
  -> Python runner
     -> Python child.py (new session / process-group leader)
        -> exec target in the same PID
```

This is important because `child.py` is not an ordinary helper that remains beside the target. It is a pre-exec wrapper. Replacing it with Rust gives a very narrow migration:

```text
worker daemon
  -> Python runner
     -> Rust inir-automation-exec (new session / process-group leader)
        -> exec target in the same PID
```

Therefore all existing Python supervision semantics remain in place:

- the target still has the PID recorded by the pre-exec wrapper;
- the target still owns the new process group created by `start_new_session=True`;
- timeout/cancellation still call the existing `kill_group`;
- stdout/stderr remain the exact pipes already monitored by Python;
- complete-stream hashes/counts and per-stream truncation remain Python-owned;
- secret redaction and public-result allowlisting remain unchanged;
- the Python runner's rlimits and `NoNewPrivileges` continue to be inherited;
- no new daemon/socket/result-file failure mode is introduced.

The Rust wrapper should preserve the current child failure ordering: arm parent-death protection and verify the parent first; make the `executing` receipt durable second; execute arbitrary external code only third. A failed receipt fsync/rename must fail closed before target exec.

This also changes the performance hypothesis. P0a may improve short-action latency because it removes a Python interpreter + import path from every `exec` action. A full Rust supervisor launched from the still-Python runner would add another process layer, so that broader migration is no longer assumed to be faster.

### P0a parity details that are easy to miss

- `start_ticks` is currently serialized as a **string**, not an integer; retain that shape until an explicitly versioned schema change.
- The wrapper must inherit the exact environment supplied by Python; do not rediscover Wayland/Niri/D-Bus sockets in Rust.
- The wrapper must inherit stdin/stdout/stderr exactly; stdin stays `DEVNULL` and target output must not go to journald through the wrapper.
- The wrapper should preserve exit 125 for parent-death guard failure, matching the current child path.
- An exec failure after the durable `executing` write is a completed failed action, not grounds to try the Python backend.
- A malformed/missing action receipt must prevent target exec.
- Capability probing and binary-path discovery happen before `dispatching`; a missing Rust binary after a Rust dispatch receipt exists is recovery-required, not a fallback trigger.

### Separate selector contract

Do **not** add Automation execution to the existing `scripts/native-dispatch` fallback contract. That selector intentionally runs Python after some Rust runtime failures. For an Automation action, a Rust failure can occur after the external command has already started, so the same fallback behavior could duplicate side effects.

P0a can select the child wrapper directly in Python before dispatch. P1 should likewise use an Automation-specific, explicit backend selection. If a convenience backend-switch command is added later, it should operate only at safe idle/reconciled boundaries.

## Fourth-pass last-mile findings

### Preserve the two crash-gap identity checkpoints

Current `exec` actions already write process identity twice:

1. the Python parent `on_spawn()` records the just-created wrapper PID immediately after `Popen`;
2. `child.py` arms `PR_SET_PDEATHSIG`, verifies the expected parent, then fsyncs the same PID again immediately before target `exec`.

That duplication is useful. The first write gives recovery a PID during the tiny pre-`prctl` spawn gap; the second proves that the child reached the guarded pre-exec boundary.

Before P0a, refine the phase semantics rather than removing a checkpoint:

- initial receipt: `phase=dispatching`, no child PID;
- parent spawn receipt: still `phase=dispatching`, now with the wrapper `process` identity;
- child/Rust pre-exec receipt: `phase=executing`, same process identity;
- Python finalizer: `phase=finished`.

The existing runner already treats any pre-existing non-`finished` action as ambiguous and refuses to replay it, so keeping the parent checkpoint in `dispatching` does not weaken no-replay behavior. Startup cleanup also reads the saved `process` identity independently of the action phase.

This distinction improves capability/error handling: a Rust wrapper that starts but rejects an incompatible protocol can exit before `executing`, allowing Python to finalize a deterministic failed action if the runner remains alive. A runner crash in the same gap remains conservatively indeterminate.

### Do not use Rust `CommandExt::exec()` blindly

The current Python wrapper calls `os.execvpe`. CPython searches `PATH` itself and attempts `execve` on candidates. Rust `std::os::unix::process::CommandExt::exec()` uses `execvp`.

That difference matters: POSIX/`execvp` can invoke a shell when an executable file returns `ENOEXEC`, while the current CPython `execvpe` path does not add that shell fallback. Using `CommandExt::exec()` directly could therefore execute a plain text file that the Python worker currently reports as a failure.

P0a should implement the existing semantics explicitly with `execve`:

- if `argv[0]` contains a slash, attempt it directly;
- otherwise search the inherited `PATH`;
- when `PATH` is absent, preserve Python's Unix default `/bin:/usr/bin`;
- preserve empty PATH components as the current directory;
- continue search on `ENOENT`/`ENOTDIR`;
- remember the first other error while continuing the search, matching CPython's selection behavior;
- never add an implicit `/bin/sh` fallback;
- after the durable `executing` receipt, an exec failure is a normal failed action: emit a bounded private diagnostic and exit nonzero, never switch backend.

The wrapper should parse target arguments as OS strings/bytes rather than forcing UTF-8 through Clap `String` fields. The environment is already finalized by Python and should be inherited byte-for-byte.

### Tighten malformed argv before migration

The current job validator bounds argument count/length but does not explicitly reject embedded NUL or surrogate-only Unicode values. Those values can fail later at the process boundary after an action receipt has already been created.

Before backend A/B qualification, make malformed OS argv a pre-dispatch validation failure in Python. This is not a Rust optimization; it removes a backend-dependent ambiguity before the migration.

### Receipt update contract for Rust

The Rust wrapper should not deserialize the action receipt into a closed struct and reserialize only known fields. Python may add private metadata over time. Use an extensible JSON object, validate the required fields, update only the owned keys and preserve unknown keys.

Minimum validation before the Rust `executing` transition:

- receipt is an object and currently `phase=dispatching`;
- `kind=exec` and action `index` matches the wrapper invocation;
- stored runner identity matches the expected live parent;
- parent-spawn `process.pid` matches the wrapper's own PID if already present;
- wrapper can read a non-null identity for itself.

Process identity parsing must retain current semantics exactly:

- split `/proc/<pid>/stat` at the **last** closing parenthesis so unusual process names do not shift fields;
- start-time field remains serialized as string `start_ticks`;
- `boot_id` is trimmed text;
- failure to capture the wrapper's own identity must fail closed before target exec.

Atomic write parity:

- create the temporary file in the receipt's directory with exclusive creation and mode 0600;
- write the complete JSON plus newline;
- fsync the file;
- atomically rename over the receipt;
- fsync the containing directory;
- best-effort remove an unused temporary file on failure.

Formatting/key order does not need byte parity because action receipts are read semantically and are not content-hashed; durability and preserved fields do.

### Linux exec/PDEATHSIG caveats are not fixed by Rust

For ordinary targets, the pre-exec wrapper's parent-death setting survives `execve`. Linux clears it when executing set-user-ID, set-group-ID or file-capability binaries, and caught signal handlers are reset to defaults across exec. This is already a limitation of the Python child path, not a Rust regression.

Therefore:

- do not claim that P0a provides hostile-descendant or arbitrary privileged-binary containment;
- keep process-group cancellation as the stated contract;
- keep the worker service cgroup and `NoNewPrivileges=yes` as independent safety layers;
- if stronger per-action containment is desired later, design it separately (for example a dedicated scope/cgroup or retained native supervisor) and benchmark it as P0b rather than smuggling it into P0a.

### Binary discovery must stay source/runtime local

Automation code is copied as part of the runtime payload, and source/package installs place native binaries under the same runtime root. Use one Automation-specific resolver shared by P0/P1:

1. optional explicit test/staging override such as `HADALIS_AUTOMATION_NATIVE_BIN_DIR`;
2. `ROOT/native/bin` for installed/runtime copies;
3. `ROOT/native/target/release` for a source checkout build.

Do not fall back to `PATH` and do not borrow `INIR_NATIVE_BIN_DIR`; either can bind Automation to a stale helper from a different runtime/source identity.

The Rust backend remains opt-in during staging. If `rust` is explicitly selected and the local binary is missing/incompatible, fail before dispatch instead of silently selecting an unrelated helper.

A non-mutating `--capabilities` response should include component name, protocol version and package version. Pass the expected protocol again on the actual wrapper invocation so a binary replaced between probe and spawn can still fail before target execution. Exact Git SHA can be diagnostic metadata but should not be the compatibility gate.

### Packaging matrix is wider than `install-runtime.sh`

Adding the Rust Automation binaries requires updating every explicit native-binary enumeration, not only Cargo:

- `native/scripts/install-runtime.sh`;
- `nix/package.nix`;
- `distro/arch/inir-shell/PKGBUILD`;
- `distro/arch/inir-shell-git/PKGBUILD`;
- Makefile install/prefix assertions;
- `scripts/test-make-install-lifecycle.sh`;
- `scripts/test-native-production-contract.sh`;
- native/runtime documentation that states the binary set.

`setup` and source install already call `install-runtime.sh`, so they inherit its binary list. Package recipes do not: they copy named binaries manually and need explicit changes.

Keep Automation binaries out of the generic `scripts/native-dispatch` fallback contract even though they share the same `native/bin` directory.

### CI and acceptance gates

The current native workflow triggers primarily on `native/**` and selected native scripts. P0/P1 also change Python boundary files such as `runner.py`, `process.py`, `privilege.py` and the Automation installer. Future Rust parity CI must trigger when either side of that boundary changes.

Recommended qualification split:

- native workflow: Rust fmt/clippy/unit tests plus Python-vs-Rust exec/broker parity fixtures;
- Automation Python tests: selector, receipt, rollback and protocol behavior;
- packaging tests: prove every supported install mode contains the expected helper;
- canonical maintainer validator: still required on the exact cutover SHA;
- live/native privilege/reboot checks: reported separately when actually exercised.

The canonical validator automatically runs tracked `test-*.py` regressions, but it does not currently build the Rust workspace as part of its normal host preflight. Do not label a validator PASS alone as Rust execution qualification.

### Current measurements make manager Rust even lower priority

The accepted Automation architecture note now records a 60-second sample where the scheduler's main Python process was about 13 MiB PSS and 0.22% of one CPU core, while the whole scheduler service including short-lived Node/CDP clients was about 99.5 MiB and 15.33% of one core.

That sample is not a general benchmark, but it is evidence against prioritizing a manager-language rewrite: the observed transport/client work dominated the Python scheduler itself. P3 should stay deferred unless new profiling identifies the manager process as a real bottleneck.

For P1, benchmark idle broker RSS/CPU and mocked same-user request overhead separately from real `sudo`/polkit/`systemctl` latency. The latter is expected to be dominated by external authentication/service work; the main justification for Rust broker migration remains typed boundary/reliability, not a promised user-visible speedup.


## P1 privilege-broker migration refinement

P1 can remain incremental: keep the Python `request()` client in `runner.py` and replace only the long-lived broker server after a compatibility-preparation step.

### P1a — make the Python protocol dual-readable first

The current receipt digest is:

```text
sha256(json.dumps(spec, sort_keys=True).encode())
```

Rust should not try to imitate Python JSON whitespace/Unicode escaping implicitly. A safer compatibility protocol is to add a v2 request form containing the canonical Python string itself:

```json
{
  "protocol": 2,
  "key": "JOB-...:0",
  "spec_json": "<json.dumps(spec, sort_keys=True)>"
}
```

The server hashes the UTF-8 bytes of `spec_json`, parses that same string into the typed request and then performs the normal allowlist validation. Existing Python receipts are automatically compatible because their `input_sha256` was computed from those exact canonical bytes.

Migration order:

1. teach the Python broker to accept both legacy `{"key","spec"}` and v2 `{"protocol":2,"key","spec_json"}`, while the client still sends v1;
2. validate/restart that Python broker;
3. switch the Python client to v2 and prove legacy receipt replay;
4. only then introduce the Rust broker speaking v2 (optionally retaining v1 parsing during the transition).

This avoids a receipt format fork and keeps explicit rollback possible.

### P1b — Rust server contract

The Rust broker should preserve the existing blocking/sequential design rather than adding async or request concurrency:

- same `$XDG_RUNTIME_DIR/hadalis-automation-privilege.sock` endpoint;
- same single-instance broker lock and stale-socket cleanup;
- socket mode 0600 plus same-UID peer verification with `SO_PEERCRED`;
- same 8192-byte request and 65536-byte response bounds;
- same three-second connection read timeout and client-side 40-second request timeout;
- one request handled at a time;
- same per-request durable lock/tombstone semantics;
- same empty-by-default policy and maximum 16 allowlisted service units;
- same `sudo-cache|polkit` authentication enum;
- same fixed operations only: service status and service restart;
- same fixed `/usr/bin/systemctl` command construction;
- same elevated `/usr/bin/timeout --signal=TERM --kill-after=2s 20s` wrapper plus outer bounded observation;
- same environment allowlist;
- same rule that a receipt without a terminal result returns `indeterminate` and is never re-elevated automatically.

The broker remains a **same-user process**, not a root daemon. Elevation stays limited to the fixed child command.

### Validation parity that Rust must implement server-side

Do not rely on the Python client as the only validator. Rust must independently preserve:

- exact allowed operation enum;
- ASCII service-unit grammar and 100-character limit;
- reason length semantics (Python counts Unicode characters, not UTF-8 bytes);
- the credential-key rejection policy used by `SECRET_KEY`;
- unknown-field rejection;
- policy unknown-field rejection;
- result/error-code behavior for denied units and authentication-required failures.

### Redaction compatibility

Unlike P0a, the privilege server itself owns the durable command result, so it cannot leave redaction only to the Python client. Port the narrow `privacy.redact` behavior needed for broker stdout/stderr and qualify it with a cross-language fixture corpus before Rust cutover.

Do not port `public_result` or unrelated privacy policy into the broker. Only the redaction needed before its local durable receipt belongs in P1.

### Service/backend switching

Do not route the privilege broker through the existing generic `scripts/native-dispatch` failure fallback. A service-level selector must choose Python or Rust before accepting requests and keep that backend across automatic restarts.

An explicit backend switch should stop the broker, inspect/reconcile any `dispatching` or `executing` privilege receipts, change the selected implementation, then restart. It must never use a Rust crash as a signal to replay the same request through Python.

The existing install contract already tests that `hadalis-worker.service` has `NoNewPrivileges=yes` while `hadalis-privilege.service` does not. Extend that contract during P1 rather than changing the privilege topology.

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
