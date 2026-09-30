# Cloud Storage — QML ↔ Rust ↔ MEGAcmd frontend/backend contract (research round 5)

> **Implementation entry point round 7:** [CLOUD_STORAGE_MEGACMD_FINAL_IMPLEMENTATION_READINESS.md](CLOUD_STORAGE_MEGACMD_FINAL_IMPLEMENTATION_READINESS.md) freezes which operations may use this contract in v1 and which remain gated/withheld. The transport/state-machine rules below remain binding.

> **Last-mile edge audit round 6 (2026-09-30):** [CLOUD_STORAGE_MEGACMD_LAST_MILE_EDGE_CASE_AUDIT.md](CLOUD_STORAGE_MEGACMD_LAST_MILE_EDGE_CASE_AUDIT.md) adds cross-process OS mutation locking, HOME/socket/client/server backend identity, safe vendor environment rules, null vendor stdin/unexpected-prompt handling, public-folder session states, string-only opaque IDs, strict UTF-8 identity, suspend-aware deadlines, secure journal durability and clipboard/notification privacy. These details are binding refinements of this contract; research only.

**Status: RESEARCH / DESIGN ONLY. No QML, Rust, package or runtime implementation was changed; no \`mega-*\` command or real MEGA account was touched.**  
Research date: 2026-09-30. Hadalis \`dev\` source audited at \`90ca89f54dd710a19266d553e0e93236ae588d1c\`.

This document binds the existing [functional design](CLOUD_STORAGE_MEGACMD_FULL_DESIGN.md), [vendor source audit](CLOUD_STORAGE_MEGACMD_SOURCE_AUDIT.md), [protocol/SDK decisions](CLOUD_STORAGE_MEGACMD_PROTOCOL_DECISIONS.md), [QML component rules](CLOUD_STORAGE_MEGACMD_UX_COMPONENTS.md) and [control matrix](CLOUD_STORAGE_MEGACMD_UX_CONTROL_MATRIX.md) into one implementation contract. The objective is not merely “QML can invoke MEGAcmd”; it is that every visible frontend state and action has one typed backend operation, one lifecycle, one authority source, bounded failure behavior and an explicit reconciliation path.

## 1. Architectural decision: four owners, one mutation boundary

**Proposed first production topology:**

\`CloudStorageConfig.qml (view)\`  
→ \`services/deferred/CloudStorageService.qml (frontend controller/state owner)\`  
→ \`native/inir-mega (one-shot typed Rust adapter)\`  
→ official \`mega-*\` scriptable clients  
→ existing vendor \`mega-cmd-server\`  
→ MEGA service.

**Do not introduce a permanent Hadalis Rust daemon for phase 1.** The current source already demonstrates two useful patterns:

- [\`services/deferred/EqualizerService.qml\`](../services/deferred/EqualizerService.qml) uses consumer counting, lifecycle generations and stale-process rejection. Cloud Storage needs the same *demand ownership* but stricter write semantics.
- [\`native/inir-mpdd/src/main.rs\`](../native/inir-mpdd/src/main.rs) already proves a native JSON RPC model with \`v\`, request \`id\`, operation allowlists, bounded socket timeouts and—critically—tests that a failed mutation is **not replayed** automatically after reconnect.
- [\`services/LyricsService.qml\`](../services/LyricsService.qml) already uses monotonically increasing request IDs and rejects stale responses when the target track changes.
- [\`services/ResourceUsage.qml\`](../services/ResourceUsage.qml) shows explicit keep-alive/release lifecycle rather than allowing a poll timer to perpetually renew its own demand.

Cloud Storage should combine those lessons. The QML page is presentation only; it must never construct vendor argument strings, parse vendor stdout, decide whether a failed mutation is safe to retry or own MEGAcmd lifecycle.

### Ownership table

| Layer | Owns | Must never own |
| --- | --- | --- |
| \`CloudStorageConfig.qml\` | Visible section, drafts, selected rows, dialogs, local UX focus/scroll | Vendor command names/flags, command quoting, retry policy, raw stderr parsing, account truth |
| Deferred \`CloudStorageService.qml\` | Consumer lease, normalized frontend snapshots, request serial/generation, read coalescing, one mutation state, UI-safe errors, stale-response rejection | Secret credentials, arbitrary vendor text parsing, implicit server shutdown |
| Rust \`inir-mega\` | Protocol validation, operation allowlist, capability checks, subprocess deadline/output caps, vendor parsers, path/ID validation, preconditions, mutation dispatch + post-read reconciliation, redaction | UI layout/localized prose, automatic secret login, direct MEGA Desktop private-control dependence |
| MEGAcmd server | Actual account session, transfers, sync/backup engines, FUSE/WebDAV/FTP state | Hadalis UI state or Hadalis retry assumptions |

The future optional MEGA SDK route remains behind the *same frontend protocol*. QML should not care whether \`drive.list\` was fulfilled by validated CLI or a separately approved SDK adapter: backend capability metadata tells the service which operations are available.

## 2. Why a deferred QML service is necessary even with a one-shot Rust binary

Putting \`Process{}\` directly inside \`CloudStorageConfig.qml\` is insufficient for writes:

1. \`SettingsPageHost.qml\` lazily caches pages but may evict/unload them. Closing Settings can destroy page-owned processes.
2. Killing a Rust helper after MEGAcmd accepted a command does **not** prove the vendor action was cancelled.
3. A mutation needs to finish/reconcile even when the user switches from Drive to Backups or closes Settings.
4. The current app already has proven consumer/generation patterns in deferred services.

Therefore the proposed service is a **dormant QML singleton**, not a resident external daemon. It is loaded when Cloud Storage is first used, registers consumers from the active page, and owns two one-shot process channels:

- **Read channel:** at most one read command in flight; repeated refresh requests coalesce into one dirty flag and the latest required domain set.
- **Mutation channel:** exactly one mutation in flight globally for phase 1. Auto-polling is suspended while the mutation is dispatching/reconciling, then affected domains refresh once.
- Optional **diagnostic/export channel** can be added later only if it cannot contend with mutation state.

When consumer count reaches zero:
- stop timers;
- cancel not-yet-dispatched reads;
- retain normalized snapshots as **stale** only in memory;
- **do not terminate a mutation already past dispatch**;
- once the mutation reaches terminal/unknown outcome, the service becomes fully dormant;
- never stop \`mega-cmd-server\` merely because Hadalis no longer has consumers.

This is intentionally more conservative than \`AutomationConfig.qml\`, whose page directly owns status/action processes; cloud file/account mutations have higher ambiguity and data-loss cost.

## 3. Rust transport: one JSON request on stdin, exactly one JSON response on stdout

Do **not** encode remote/local paths and IDs into \`inir-mega\` command-line flags. Quickshell \`Process\` already supports stdin writing (see [\`KeyringStorage.qml\`](../services/deferred/KeyringStorage.qml)); use it for a typed nonsecret JSON envelope. This avoids Hadalis-shell quoting and command-line length problems, while acknowledging that upstream MEGAcmd still reparses arguments internally and therefore arbitrary-filename safety remains capability-gated.

Proposed invocation:

\`\`\`
native/bin/inir-mega request
stdin:  one UTF-8 JSON object + EOF
stdout: one bounded UTF-8 JSON object + newline
stderr: developer-only bounded diagnostics; QML does not display or parse it directly
\`\`\`

No generic \`inir-mega command <raw mega args…>\`. Unknown operation = hard reject.

### Request envelope

\`\`\`json
{
  "v": 1,
  "id": "cs-1842",
  "op": "sync.pause",
  "expected_account": "sha256:…",
  "params": {
    "sync_id": "opaque-observed-id"
  },
  "preconditions": {
    "run_state": "running"
  }
}
\`\`\`

Rules:

- \`v\`: Cloud protocol version, independent of MEGAcmd version.
- \`id\`: monotonically unique within current QML service lifetime; echoed exactly.
- \`op\`: closed Rust enum/string allowlist.
- \`expected_account\`: nonsecret stable fingerprint of the account identity observed by QML; absent for \`probe.static\` and pre-login reads.
- \`params\`: typed by operation, never free-form CLI tokens.
- \`preconditions\`: frontend observation the user reviewed. Backend **re-reads** current state and rejects stale context; it does not trust QML as the authority.

### Response envelope

\`\`\`json
{
  "v": 1,
  "id": "cs-1842",
  "op": "sync.pause",
  "ok": true,
  "backend": {
    "kind": "megacmd_cli",
    "adapter_version": "0.1.0",
    "vendor_version": "observed-or-null"
  },
  "account": {
    "fingerprint": "sha256:…",
    "signed_in": true
  },
  "observed_at_ms": 1790750000000,
  "freshness": "fresh",
  "result": {},
  "mutation": {
    "outcome": "confirmed",
    "reconcile_required": false
  },
  "warnings": [],
  "error": null
}
\`\`\`

Error example:

\`\`\`json
{
  "v": 1,
  "id": "cs-1842",
  "op": "sync.pause",
  "ok": false,
  "freshness": "unknown",
  "result": null,
  "mutation": {
    "outcome": "unknown",
    "reconcile_required": true
  },
  "error": {
    "code": "ACTION_OUTCOME_UNKNOWN",
    "stage": "dispatch",
    "retriable": false,
    "safe_message": "The vendor command stopped responding after dispatch. Recheck current sync state before doing anything else.",
    "diagnostic_id": "local-nonsecret-id"
  }
}
\`\`\`

**Stdout is protocol-only.** No banner, warning, progress line or fallback text may precede/follow JSON. The current [\`scripts/native-dispatch\`](../scripts/native-dispatch) supports Python fallbacks for several older helpers; **Cloud Storage must not automatically fall back from Rust to Python for mutation operations**, because an alternative implementation could have different validation/retry semantics and a failed Rust attempt may already have dispatched. Missing/incompatible Rust adapter makes the optional feature unavailable.

## 4. Protocol versioning and capability negotiation

Do not make QML compare MEGAcmd version strings to decide which button works. Rust returns a normalized capability tree from installed \`--help\`/fixture-validated parsers **only after explicit Connect where vendor invocation can start the server**.

Static pre-connect capability is limited to:
- \`inir-mega\` binary available;
- discovered \`mega-*\` executable paths/executable bits without executing them;
- existence of a local pending-action journal;
- platform/kernel basics needed for conditional UI, without probing private Desktop IPC.

Post-connect capability example:

\`\`\`json
{
  "drive": {
    "list": {"supported": true, "safe_for_arbitrary_names": false},
    "move": {"supported": false, "reason": "filename_roundtrip_not_verified"}
  },
  "sync": {
    "list": true,
    "pause": true,
    "enable": true,
    "remove": true,
    "issues": true
  },
  "backups": {"list": true, "create": true},
  "fuse": {"available": true, "beta": true},
  "webdav": {"available": true, "public_bind_allowed_by_hadalis": false},
  "auth": {"interactive_terminal_only": true}
}
\`\`\`

Frontend rendering rule:
- capability false → disabled control + reason;
- capability unknown → "Not verified" + Recheck capabilities, not hidden success;
- capability true → still requires operation-specific current state/preconditions;
- backend can downgrade an operation at runtime if parser safety fails.

Cloud protocol version mismatch is a hard frontend/backend compatibility error. Unknown **response fields** are ignored for forward compatibility; unknown enum values map to \`unknown\` rather than breaking QML. QML never assumes presence of optional field.

## 5. QML lifecycle state and stale-response protection

### Service-level fields (proposed)

\`consumerCount\`, \`connectedRequested\`, \`connectionGeneration\`, \`requestSerial\`, \`currentAccountFingerprint\`, \`backendState\`, \`capabilities\`, \`domainSnapshots\`, \`domainFreshness\`, \`readBusy\`, \`mutationBusy\`, \`mutationState\`, \`pendingRefreshDomains\`, \`lastSafeError\`, \`recoveryPending\`.

**Generation rule:** increment \`connectionGeneration\` on:
- explicit disconnect/logout;
- signed-in ↔ signed-out transition;
- account fingerprint change;
- backend protocol reset/incompatibility;
- Rust adapter restart after a critical parser/lifecycle failure.

Each QML \`Process\` instance stores both \`generation\` and \`requestId\` when started. On stdout/exit, ignore payload if:
- protocol \`v\` mismatch;
- echoed \`id\` mismatch;
- process generation ≠ current generation;
- response account ≠ expected current account for account-bound operation;
- active operation no longer matches.

This extends the request-ID discipline already present in \`LyricsService.qml\` and lifecycle-generation discipline in \`EqualizerService.qml\`.

**Never cancel a dispatched mutation merely because generation changed.** Mark it detached from the old account context and await backend terminal/unknown response. If actual account changed externally during mutation, Rust must return \`ACCOUNT_CHANGED_DURING_ACTION\` / \`ACTION_OUTCOME_UNKNOWN\`, then QML invalidates all handles/TAGs and requires a fresh account snapshot.

## 6. Read scheduling and state merge rules

Reads are idempotent and can be safely coalesced, but do not blindly retry every error.

### Domain set

\`overview\`, \`drive\`, \`transfers\`, \`sync\`, \`backups\`, \`sharing\`, \`contacts\`, \`mounts\`, \`security\`, \`preferences\`.

Each stores:
- \`status = not_requested|loading|fresh|stale|unsupported|error\`;
- \`last_request_id\`;
- \`observed_at_ms\`;
- \`last_success_ms\`;
- \`source = megacmd_cli|sdk_future|desktop_best_effort|hadalis_static\`;
- normalized data;
- safe error code/detail.

### Coalescing algorithm

1. View registers consumer + desired domain(s).
2. If no read is running → issue one Rust read request for the smallest supported batch.
3. If a read is running → OR requested domains into \`pendingRefreshDomains\`; do not spawn a second process.
4. When current read finishes, merge only if generation/request/account match.
5. If pending domains remain and still demanded, schedule **one** follow-up via \`Qt.callLater\`; do not loop synchronously inside \`onExited\`.
6. During mutation dispatch/reconciliation, suspend auto-read and set affected domains dirty.
7. On mutation terminal/unknown response, execute one authoritative refresh of affected domains.

This prevents timer overlap and mirrors existing Hadalis comments that restarting processes inside \`onExited\` can race with \`Process.running\`.

### Retry classes

| Error | Auto retry? | Rule |
| --- | --- | --- |
| Rust helper spawn failed **before process start** | One deferred read retry allowed | No vendor command could have run |
| Read-only vendor timeout/offline | Bounded retry/backoff only while visible/demanded | Stop after budget; show stale/offline |
| Parser ambiguous/unsupported | **No automatic retry loop** | Capability becomes unsupported until explicit recheck/version change |
| Authentication missing | No poll loop | Wait for user sign-in/connect |
| Any write after dispatch started | **Never automatic retry** | Reconcile/read only |

No poll timer may keep a deferred service alive by itself, following the \`ResourceUsage.qml\` lease principle.

## 7. Mutation state machine: frontend and backend must agree on the same phases

\`idle → validating → review_required → queued → dispatching → reconciling → confirmed | rejected | failed_before_dispatch | outcome_unknown\`.

### Frontend transition contract

- **validating:** send a *read/preflight* request; button busy, no vendor mutation.
- **review_required:** Rust returns normalized review data used by dialog: account, target IDs/display paths, exact intended effect, collision/permission/overlap state and warnings.
- **queued:** user confirmed; service serializes mutation behind any current write.
- **dispatching:** backend has passed final fresh preconditions and is invoking vendor. From this point Escape/page-close cannot claim cancellation.
- **reconciling:** vendor command returned or timed out; backend performs bounded authoritative read where possible.
- **confirmed:** requested postcondition observed.
- **rejected:** fresh state changed / confirmation obsolete / capability revoked; nothing dispatched.
- **failed_before_dispatch:** validation/vendor process failed before any command execution was started; safe to let user try again after correcting cause.
- **outcome_unknown:** command may have been accepted but postcondition cannot be proven. Only read/reconcile action is allowed; no automatic second write.

### Backend precondition rule

For every write, Rust re-reads the minimal authority immediately before dispatch. Examples:

- pause sync: account fingerprint and sync ID still exist; run state matches the reviewed state or operation is demonstrably still safe.
- cancel transfer: TAG still belongs to same observed direction/provenance; if missing return \`ALREADY_COMPLETED_OR_MISSING\`, not dispatch a guessed target.
- move file: source unique handle still exists; destination parent unchanged; **target collision absent**; parser can represent both safely.
- create sync: local canonical path/mount and remote node still match review; overlap checks rerun.
- share permission: account/folder/contact and current ACL still match review.
- logout/session revoke: current account still matches the one shown in security dialog.

Frontend-supplied preconditions are used to detect "what user reviewed changed"; they are never accepted as proof.

## 8. Two-phase review hash for destructive/high-risk actions

For high-risk operations, use a backend-produced **review digest**, without maintaining a long-lived token server:

1. QML calls \`<op>.prepare\` or sends \`mode:"prepare"\`.
2. Rust reads current authority and returns normalized \`review\` plus \`review_digest = SHA-256(canonical review + account fingerprint + op)\`.
3. UI displays **only this normalized review**.
4. On Confirm, QML sends original typed params + \`review_digest\`.
5. Rust repeats preflight, recomputes digest. If any relevant fact changed, return \`STALE_PRECONDITION\`; nothing is dispatched.
6. If digest still matches, dispatch once and reconcile.

Use for: \`drive.move/remove\`, \`sync.create/remove\`, \`backup.create/remove/retention decrease\`, public/writable export, contact permission escalation, FUSE writable activation, WebDAV/FTP start, session revoke and logout.

Low-risk reversible changes (e.g. transfer pause, safe speed limit) may run direct with a single backend preflight, still serialized and reconciled.

Digest is **not a security token**. QML is a trusted local client; its purpose is stale-review detection. Backend always recomputes instead of trusting the digest.

## 9. Crash/restart recovery: non-replay journal for mutating operations

Even a deferred QML service dies on shell crash/update. For data safety, the Rust adapter should eventually maintain a tiny per-user private journal, conceptually:

\`$XDG_STATE_HOME/inir/cloud-storage/mutations.json\` (mode 0600, atomic replace + fsync policy to be validated).

Minimum record:
- protocol/journal schema;
- \`action_id\` / request ID;
- operation type;
- start timestamp;
- account fingerprint;
- nonsecret stable target identifiers where safe (sync ID, transfer TAG, backup ID/node handle where reviewed);
- phase \`prepared|dispatch_started|reconciling|terminal\`;
- expected postcondition **hash**, not sensitive display text;
- terminal result code if known.

**Do not persist passwords, link keys, raw vendor stdout, complete local paths or complete diagnostic content in this journal by default.**

Before vendor dispatch, write \`dispatch_started\` durably. After confirmed authoritative read, write terminal then compact/remove according to a short retention policy. If Hadalis restarts and finds nonterminal journal entries, **static probe may report "Previous action needs reconciliation" without executing MEGAcmd**. After the user connects, \`reconcile.pending\` performs reads only. It never replays the write.

This deliberately extends the "reconnect without mutation replay" property already tested in \`inir-mpdd\`.

Open research gate: for operations whose only safe identity is a sensitive/local path, determine whether a private journal may store an encrypted/permission-protected identifier, a stable vendor handle, or only enough metadata to tell the user "unknown operation needs manual review." Do not weaken privacy to make crash recovery look complete.

## 10. Error taxonomy: backend code, frontend prose

Rust emits a stable machine \`error.code\`; QML maps code to English product wording with \`Translation.tr\` according to current Hadalis English-only product policy. Vendor raw strings are never the primary UI state.

Suggested codes:

**Transport/lifecycle:** \`DEPENDENCY_MISSING\`, \`CONSENT_REQUIRED\`, \`ADAPTER_PROTOCOL_MISMATCH\`, \`HELPER_SPAWN_FAILED\`, \`SERVER_NOT_RUNNING\`, \`SERVER_UNRESPONSIVE\`, \`OFFLINE\`, \`COMMAND_TIMED_OUT\`, \`OUTPUT_TOO_LARGE\`.

**Auth/identity:** \`LOGIN_REQUIRED\`, \`ACCOUNT_CHANGED\`, \`ACCOUNT_CHANGED_DURING_ACTION\`, \`SESSION_TARGET_MISSING\`.

**Parsing/capability:** \`VENDOR_VERSION_UNSUPPORTED\`, \`OPERATION_UNSUPPORTED\`, \`AMBIGUOUS_VENDOR_OUTPUT\`, \`UNKNOWN_VENDOR_STATE\`, \`UNSAFE_ARGUMENT_ROUNDTRIP\`.

**Data safety:** \`STALE_PRECONDITION\`, \`TARGET_NOT_FOUND\`, \`TARGET_NOT_UNIQUE\`, \`DESTINATION_EXISTS\`, \`LOCAL_PATH_OVERLAP\`, \`REMOTE_PATH_OVERLAP\`, \`EXTERNAL_OWNER_UNKNOWN\`, \`INSUFFICIENT_PERMISSION\`, \`SYNC_ID_UNREPRESENTABLE\`.

**Mutation outcome:** \`ACTION_REJECTED\`, \`ACTION_FAILED_BEFORE_DISPATCH\`, \`ACTION_OUTCOME_UNKNOWN\`, \`ACTION_PARTIAL\`, \`ALREADY_COMPLETED_OR_MISSING\`.

**Secret policy:** \`SECRET_ARGUMENT_FORBIDDEN\`, \`INTERACTIVE_LOGIN_REQUIRED\`, \`UNSAFE_PUBLIC_BIND_FORBIDDEN\`.

Each response also reports \`stage = static_probe|connect|read|validate|review|dispatch|reconcile|serialize\` and \`retriable\` chosen by Rust policy. QML must not infer retryability from exit code.

## 11. Normalized data models: frontend never parses MEGAcmd strings

### SyncRecord

\`{id, local_path, remote_path, remote_handle?, run_state, data_status, error_code?, issue_count?, size_bytes?, file_count?, dir_count?, observed_at_ms}\`

Enums unknown → \`unknown\`. \`run_state\` and \`data_status\` never merged.

### TransferRecord

\`{tag, direction, provenance, state, name?, source_display?, destination_display?, transferred_bytes?, total_bytes?, speed_bps?, observed_at_ms}\`

UI progress shown only when both numeric fields are authoritative and denominator >0.

### BackupRecord

\`{id/tag, local_path, remote_path, state, period_raw, next_run_utc?, retention_count?, history_summary?, observed_at_ms}\`.

### DriveNode

\`{stable_id?, name, kind, remote_path_display, parent_id?, size_bytes?, modified_at?, versions_count?, share_state?, permissions?, identity_safe_for_write}\`.

A row can be read-only even if list itself is available. \`identity_safe_for_write=false\` disables move/delete/share for that node while preserving browsing.

### Share/Contact/Mount

Use explicit IDs/permission enums and normalized capability flags. No QML interpretation of vendor numeric access levels or beta/platform strings beyond backend enums.

**Invariant:** any object that can trigger a write carries the stable identity that backend will revalidate. A translated display label alone is never a mutation key.

## 12. Frontend control → backend operation mapping

### Global/Overview

| Frontend | Rust operation | Backend | Completion |
| --- | --- | --- | --- |
| Open page | \`probe.static\` | Check binaries/journal **without invoking mega client** | Installed/disconnected/recovery-pending state |
| Connect | \`backend.connect\` | Explicitly allow vendor client/server start, then safe account/capability reads | Ready/signed-out/offline + account fingerprint |
| Refresh | \`overview.read\` | Account short status + quota + cheap summaries | Replace only Overview snapshot |
| Sign in | **No secret backend op** | UI launches documented official interactive terminal route once supported | User manually Refreshes/Connect observes new state |

### Drive

| Frontend | Operation | Stability behavior |
| --- | --- | --- |
| Root chooser | \`drive.roots\` / \`drive.list\` | No vendor working-directory state |
| Breadcrumb / folder open | \`drive.list\` with explicit stable target | Stale request discarded by ID/generation |
| Search | \`drive.search\` | Bounded output; explicit truncated flag |
| Details | \`drive.details\` | Safe read; no arbitrary raw \`ls\` text in QML |
| Upload/download | \`drive.upload.prepare/execute\`, \`drive.download.prepare/execute\` | Destination/source collision, account and path check; transfer TAG returned where safe |
| New folder | \`drive.mkdir.prepare/execute\` | Name roundtrip + duplicate preflight |
| Move/rename | \`drive.move.prepare/execute\` | **Block existing destination**; verify source and destination afterward |
| Remove | \`drive.remove.prepare/execute\` | Disabled until exact recoverability/target semantics verified |

### Transfers

\`transfers.read\`, \`transfers.pause\`, \`transfers.resume\`, \`transfers.cancel.prepare/execute\`, \`limits.read\`, \`limits.set\`.

Frontend never constructs TAG flags. Rust confirms TAG still maps to expected record. "Cancel all" first resolves explicit currently observed TAG set and review scope; never sends an unreviewed global wildcard simply because UI said All.

### Sync

\`sync.read\`, \`sync.issues.read\`, \`sync.filters.read\`, \`sync.create.prepare/execute\`, \`sync.pause\`, \`sync.enable\`, \`sync.remove.prepare/execute\`, \`sync.filter.add.prepare/execute\`, \`sync.filter.remove.prepare/execute\`.

Create revalidates both local **and remote** overlap just before dispatch. Frontend filter builder sends a typed filter object; Rust constructs/validates vendor syntax. QML never emits compact \`-f:*.txt\` text unless an explicit future advanced raw mode is approved.

### Backups

\`backups.read\`, \`backups.history.read\`, \`backup.create.prepare/execute\`, \`backup.update.prepare/execute\`, \`backup.abort.prepare/execute\`, \`backup.remove.prepare/execute\`.

Rust normalizes schedule values, returns UTC/local review data, and highlights first-run-immediate possibility before execute. Frontend does not encode cron itself without backend normalization.

### Sharing/Contacts

\`exports.read\`, \`export.create.prepare/execute\`, \`export.revoke.prepare/execute\`, \`shares.read\`, \`share.grant.prepare/execute\`, \`share.revoke.prepare/execute\`, \`contacts.read\`, \`contacts.requests.read\`, \`contacts.invite.prepare/execute\`, \`contacts.respond.prepare/execute\`.

Password-bearing public link operations return \`SECRET_ARGUMENT_FORBIDDEN\` until a safe vendor secret channel is established. Existing-export "edit" is normalized by backend into a **recreate plan**; the UI must review link rotation, not pretend vendor supports in-place edit.

### Mounts / local services

\`fuse.read\`, \`fuse.add.prepare/execute\`, \`fuse.config.prepare/execute\`, \`fuse.enable/disable\`, \`fuse.remove.prepare/execute\`, \`webdav.read\`, \`webdav.start.prepare/execute\`, \`webdav.stop.prepare/execute\`, corresponding guarded FTP operations if explicitly enabled.

Backend enforces Hadalis policy \`public=false\` for first-phase WebDAV/FTP regardless of QML bugs. **Critical security constraints are backend policy too**, not only disabled buttons.

### Account/Security

\`security.sessions.read\` only on explicit user action; \`security.session.revoke.prepare/execute\`; \`account.logout.prepare/execute\`.

No normal op for \`masterkey\`, \`session\` secret extraction, password change or account cancellation. Unknown/raw op cannot bypass the UI.

### Preferences/Diagnostics

\`capabilities.read\`, \`diagnostics.preview\`, \`diagnostics.export\`, \`reconcile.pending\`.

Diagnostics backend constructs an **allowlisted structured object**; frontend cannot request "raw stdout". Preview and export use the exact same sanitized payload hash so what the user reviewed is what gets copied/exported.

## 13. Frontend button/dropdown enablement derives from three independent gates

A control is enabled only if all required gates are true:

1. **Capability gate:** backend says operation exists and parser/argument route is safe on this installed version.
2. **State gate:** normalized current snapshot says action makes sense (e.g. transfer active, sync pauseable).
3. **Identity/precondition gate:** current object has safe stable ID, correct account generation and no known conflict.

Example:

\`Pause sync.enabled = capability.sync.pause && snapshot.sync.fresh && record.id_safe && record.run_state == running && !mutationBusy\`.

Do **not** bind enablement to display strings like \`statusLabel === "Running"\`. Backend enums are stable machine keys; UI text can change safely.

Dropdown selection changes only a draft. Any choice with external side effects has **Apply/Review**. For example bandwidth unit/value edits remain local until Apply; share access level is draft until Share; backup schedule presets are draft until Review/Create. This prevents accidental vendor calls from QML binding churn/model reset.

## 14. Timeout, output and resource budgets

No invented millisecond contract is ready. Implementation should define measured operation classes:

- \`STATIC\`: no vendor process.
- \`FAST_READ\`: account/version/summary.
- \`LIST_READ\`: bounded rows.
- \`WRITE\`: vendor mutation.
- \`TRANSFER_START\`: upload/download creation (may queue).
- \`DIAGNOSTIC\`: bounded sanitized collection.

Rust owns vendor child wall-clock deadlines and maximum stdout/stderr bytes. On timeout it kills **only the scriptable \`mega-*\` child it spawned**, never \`mega-cmd-server\`. If the operation crossed dispatch, timeout = unknown, not failure-before-dispatch.

QML may have a longer watchdog for a stuck Rust helper. If that watchdog terminates the helper during mutation, service records \`ACTION_OUTCOME_UNKNOWN\` and disables further writes until reconciliation. Read helper kill may simply mark read error/stale.

Output caps exist at both levels:
- raw vendor bytes;
- parsed row count;
- serialized JSON response size;
- frontend list model items.

When list is truncated backend explicitly sets \`truncated:true\` and an observed row count. QML never calls a locally capped first page "all files".

## 15. Security invariants enforced below the UI

Backend must reject:
- any secret-bearing password/MFA/proxy/public-link operation through argv/JSON;
- public WebDAV/FTP bind in first approved phase;
- arbitrary unknown CLI op;
- wildcard/regex destructive targeting not resolved to exact reviewed identities;
- Drive write where node identity is ambiguous;
- move/rename onto existing destination unless a future explicit replace operation is separately designed;
- account mismatch;
- stale high-risk review digest;
- operation while another mutation is dispatching/reconciling.

Frontend still disables these paths for UX, but Rust is the safety boundary if a QML bug fires the wrong signal.

Rust logs must be structured/redacted. Never log entire request JSON because params can contain local/private paths. Prefer \`request_id, op, stage, result_code, elapsed_ms, vendor_exit_code(optional)\` and hashed identifiers. QML gets a nonsecret \`diagnostic_id\`.

## 16. Testing contract: prove frontend/backend behavior without real MEGA first

### Rust fake-vendor tests

A fake executable named like \`mega-sync\`, \`mega-transfers\`, etc. records argv and serves controlled stdout/stderr/delay/exit. Tests cover:

- request version/op validation;
- stdin JSON and exactly-one-JSON stdout;
- output limits;
- Unicode, quotes, newlines, delimiters and leading-dash IDs;
- fake server hang / child timeout;
- read retry classification;
- **write not replayed after connection/process failure**;
- prepare digest invalidated when target changes;
- move destination appears between prepare and execute → no dispatch;
- account fingerprint changes before execute → no dispatch;
- write timeout after fake "accepted" marker → \`ACTION_OUTCOME_UNKNOWN\`, no retry;
- second concurrent mutation rejected/queued by QML service contract;
- secret-bearing op hard rejected.

### QML service contract tests

Using a fake \`inir-mega\`:
- request IDs monotonically increase;
- stale ID/generation/account responses ignored;
- active section consumer starts read demand;
- hidden/evicted page releases demand;
- timer cannot keep service alive;
- duplicate Refresh coalesces;
- mutation suspends polls, then one affected refresh occurs;
- switching section does not kill dispatched mutation;
- closing Settings does not claim mutation cancellation;
- dropdown draft never sends external op before Apply;
- outcome-unknown disables writes and exposes Recheck;
- reconnect/account switch invalidates handles/TAGs and open chooser.
- malformed/oversized/non-JSON stdout becomes protocol error without parsing fallback.

### Crash/recovery tests

Using only fake vendor:
- crash helper after journal \`dispatch_started\`;
- restart static probe shows recovery pending without executing fake \`mega-*\`;
- \`reconcile.pending\` performs only reads;
- exact previous mutation never replays;
- terminal journal is compacted safely;
- journal permission and no-secret schema checks.

### Packaging/route tests

Authorized implementation must add the Rust binary to the existing Cargo workspace and **all** native install lists (runtime installer, Makefile, Arch stable/git, Nix) in one patch. Settings registry tests verify \`cloud-storage\` exists for Abyss, Waffle and ordinary families despite current index<32 applicability guards. Local canonical validation applies to the exact implementation SHA; live MEGA validation remains an explicit disposable-account owner session.

## 17. Recommended implementation sequence after explicit authorization

**F0 — Protocol/fake harness only:** define Rust request/response structs, error enums, fake vendor fixtures and QML service mock. No MEGAcmd invocation.  
**F1 — Static + explicit connect/read-only:** static dependency detection, Connect consent, account/quota/capability/sync/transfer/backup reads; no write buttons enabled.  
**F2 — Low-risk mutations:** transfer pause/resume, bounded speed limits, sync pause/enable with fresh post-read.  
**F3 — Reviewed definitions:** create/remove sync and backup via prepare/digest/execute; crash journal enabled.  
**F4 — Drive writes only after filename/identity gates:** upload/download/mkdir; move/delete remain capability-dependent.  
**F5 — Shares/security/mounts:** only after per-domain security tests; public network/secret routes remain disabled unless separately approved.  
**F6 — Optional SDK Drive data plane:** frontend protocol unchanged; backend advertises \`backend.kind=mega_sdk\` for eligible reads/writes only after separate approval.

This sequence keeps UI/backend linkage stable before adding risky breadth.

## 18. Open blockers — research is not live verification

- [ ] Owner-machine installed MEGAcmd version/output fixtures.
- [ ] Safe arbitrary filename/node identity for Drive mutation.
- [ ] Host file/folder picker selection contract.
- [ ] Exact crash journal identifiers/privacy policy.
- [ ] QML behavior when shell is terminated during a vendor-accepted mutation; fake harness first, live disposable account later.
- [ ] Whether MEGAcmd exposes sufficiently reliable cheap reads for postcondition reconciliation on each write.
- [ ] Whether eventual SDK access is worth its second client/session/resource cost.
- [ ] Measured timeout/output/poll budgets.
- [ ] Live visual behavior of error/recovery states in standalone/Abyss/SettingsFocus/Waffle.

**Bottom line:** the stable boundary should be *typed operation + precondition + authoritative readback*, not "button → shell command". Rust owns safety and normalization; a deferred QML service owns lifecycle/races; the view owns presentation only. A write is successful only when a fresh backend observation confirms its postcondition, and an ambiguous write is never replayed automatically.
