# Cloud Storage — last-mile edge-case audit (research round 6)

> **Final freeze:** The decisions and acceptance tiers derived from this edge-case audit are consolidated in [CLOUD_STORAGE_MEGACMD_FINAL_IMPLEMENTATION_READINESS.md](CLOUD_STORAGE_MEGACMD_FINAL_IMPLEMENTATION_READINESS.md). Further source-only expansion is not required before Tier-A implementation.

**Status: RESEARCH / DESIGN ONLY. No QML, Rust, package, runtime or MEGA-account operation was performed.**  
Research date: 2026-09-30. Hadalis \`dev\` reference audited at \`b341635ee87465115b223b83ec81a3328a6b0a33\`. Official vendor source references are pinned to MEGAcmd \`6505327a5a7a0e94f26f611f83b024aeeb63582c\` and MEGA SDK \`74326bb0aa09b13f0a1ec8eab9611e4c0de98cc6\`; they are **not** evidence of the owner machine's installed version.

This audit is deliberately about details that are easy to miss after the larger architecture already looks complete: process environment, multiple Settings processes, file-descriptor lifetime, interactive vendor prompts, 64-bit identity in QML/JSON, invalid UTF-8, sleep/time changes, clipboard history, persistent notifications, journal durability, package upgrades, symlink/mount races, public-folder sessions and cross-feature ownership. It extends [the frontend/backend contract](CLOUD_STORAGE_MEGACMD_FRONTEND_BACKEND_CONTRACT.md), [source audit](CLOUD_STORAGE_MEGACMD_SOURCE_AUDIT.md), [protocol/SDK decisions](CLOUD_STORAGE_MEGACMD_PROTOCOL_DECISIONS.md) and [UX control matrix](CLOUD_STORAGE_MEGACMD_UX_CONTROL_MATRIX.md).

## 1. Cross-process reality: a QML singleton is not a global mutation lock

Hadalis has more than one Settings execution topology. Overlay/Focus Settings run in the main shell process, while \`settings.qml\` is launched as a separate \`qs\` process. [\`ServicesConfig.qml\`](../modules/settings/ServicesConfig.qml) explicitly documents that QML singletons are isolated in separate window mode. [\`scripts/inir\`](../scripts/inir) serializes launching a detached Settings entry with \`flock\`, and closes the lock FD before \`exec\` so descendants cannot accidentally keep the launch lock alive.

Therefore the round-5 "one mutation at a time" rule needs **two levels**:

- QML \`CloudStorageService.qml\`: one mutation within one QML process.
- Rust/OS: one Cloud Storage mutation across **all Hadalis processes** for the user.

### Proposed OS lock contract

- Acquire a per-user mutation lock immediately before the final authoritative preflight, not at initial dialog creation.
- Prefer a private directory under \`$XDG_RUNTIME_DIR/inir/cloud-storage/\`, after checking it is owned by the effective UID and not writable by other users. If runtime dir is unavailable or unsafe, use the Hadalis private state directory after equivalent ownership/permission checks. Do **not** silently use a predictable world-writable \`/tmp/foo.lock\`.
- The lock file itself is not a stale-state indicator; use kernel advisory locking (\`flock\`/equivalent), so process death releases ownership automatically.
- Lock FD is close-on-exec. The spawned \`mega-*\` client, and a server it may start, must not inherit the Hadalis mutation lock.
- Hold the lock through: final preflight → journal \`dispatch_started\` durability → vendor dispatch → reconciliation → terminal/unknown journal update. Do not release between dispatch and reconciliation.
- If another Hadalis process owns it, return \`MUTATION_BUSY_OTHER_HADALIS_INSTANCE\` immediately. Do **not** queue behind a potentially stale review; the second UI refreshes/re-prepares.
- Reads do not need this global mutation lock, but their UI must not claim that a state change was caused by the local page.
- External \`mega-*\` clients, MEGA Desktop and other hosts are outside this lock. Fresh preconditions and post-read reconciliation remain mandatory.

A single global per-user Cloud Storage mutation lock is deliberately conservative for first release. Supporting multiple intentionally isolated MEGAcmd sockets/accounts can be researched later; do not key locks to untrusted display strings.

## 2. Backend identity is more than "MEGAcmd installed"

Official [MEGAcmd platform-directory source](https://github.com/meganz/MEGAcmd/blob/6505327a5a7a0e94f26f611f83b024aeeb63582c/src/megacmdcommonutils.cpp) shows Linux configuration/runtime state derives from \`HOME\`, normally \`$HOME/.megaCmd\`; if no usable home exists it falls back under \`/tmp/megacmd-UID\`. The Unix socket filename can be overridden by \`MEGACMD_SOCKET_NAME\`. The same source creates its socket directory mode 0700. The [public README](https://github.com/meganz/MEGAcmd/blob/6505327a5a7a0e94f26f611f83b024aeeb63582c/README.md) confirms session, sync definitions, cache and extra configuration are retained in the local home.

A Hadalis backend epoch therefore needs to cover at least:

- effective UID;
- canonical/effective HOME identity;
- intentional \`MEGACMD_SOCKET_NAME\` identity, if present;
- selected absolute MEGAcmd client installation;
- observed server/capability epoch after Connect;
- session kind/account epoch.

**First-phase policy:** refuse a hidden no-HOME fallback for normal Hadalis use. If HOME is absent/unusable or unexpectedly differs between frontend processes, return \`ENVIRONMENT_MISMATCH\` / \`HOME_UNAVAILABLE\` and explain it. Do not accidentally attach to a different \`/tmp\` session.

Never launch Cloud Storage as root or via privilege escalation. Local file access and MEGAcmd cache ownership must remain the logged-in desktop user's.

### Mixed client/server installation trap

When a scriptable client cannot connect, upstream [POSIX communications source](https://github.com/meganz/MEGAcmd/blob/6505327a5a7a0e94f26f611f83b024aeeb63582c/src/megacmdshell/megacmdshellcommunications.cpp) forks and attempts \`execvp("mega-cmd-server", ...)\` before an alternative server beside the current executable. That means an absolute \`/opt/foo/mega-sync\` can still start a different \`mega-cmd-server\` found first in inherited PATH.

Before explicit Connect, Rust should resolve one vendor installation and construct a controlled PATH where the matching server directory is first **without discarding legitimate system/network environment**. If a server already exists, adopt it rather than replace it; after Connect, its reported capability/version becomes part of the backend epoch. A client/server path mismatch is diagnostic evidence, not permission to kill the existing server.

Do not manufacture a random \`MEGACMD_SOCKET_NAME\` to "isolate Hadalis": that would create another independent vendor server/session and violate the single-engine design.

## 3. Environment sanitization: remove dangerous vendor overrides, preserve legitimate connectivity

MEGAcmd recognizes environment controls that can materially alter safety/debug behavior. Source shows examples including:

- \`MEGACMD_DO_NOT_REDACT_LINES\`: disables vendor command-line redaction.
- \`MEGACMD_DISABLE_UTF8_VALIDATIONS\`: bypasses UTF-8 validation.
- \`MEGACMD_LOGLEVEL\` / \`MEGACMD_JSON_LOGS\`: affect server logging when a new server is started.
- \`MEGACMD_SOCKET_NAME\`: deliberately selects a socket identity.

Hadalis-owned vendor subprocesses should use an explicit environment policy:

1. preserve required user context such as HOME, UTF-8 locale and legitimate proxy/network environment;
2. preserve an intentional existing socket name as **identity**, not as arbitrary user data;
3. unset safety-bypassing/test/debug vendor variables such as \`MEGACMD_DO_NOT_REDACT_LINES\` and \`MEGACMD_DISABLE_UTF8_VALIDATIONS\`;
4. do not force verbose logging on a server Hadalis may start;
5. document that an **already-running externally started server** keeps its own environment—Hadalis cannot retroactively sanitize it.

Do not blindly use \`LANG=C\` just because another Hadalis integration does. [\`Network.qml\`](../services/Network.qml) intentionally forces C locale because it parses localized \`nmcli\` keywords; MEGAcmd's Unix server derives language from the process locale and calls the SDK language setter. Starting the persistent server under an artificial locale can change its behavior. Prefer the user's valid UTF-8 locale and parse stable columns/enums. Only adopt \`C.UTF-8\` for a specific command after fixtures prove it safe and it cannot unexpectedly define the long-lived server locale.

## 4. Static detection must not call \`mega-version\`

A subtle but important correction: \`mega-version\` is not a static local binary metadata probe. The [server-side version implementation](https://github.com/meganz/MEGAcmd/blob/6505327a5a7a0e94f26f611f83b024aeeb63582c/src/megacmdexecuter.cpp) prints the MEGAcmd build and also calls \`getLastAvailableVersion\`, waiting up to about two seconds; like other normal scriptable commands it may start the vendor server first.

Therefore:

- Pre-Connect static probe = filesystem/executable inspection only; no \`mega-version\`, \`mega-help\`, \`mega-whoami\`.
- After explicit Connect, call version/capability probes and cache them per backend epoch.
- Name the observed value \`server_version\` / \`vendor_capability_version\`, not "installed package version" unless package metadata independently proves that.
- A package upgrade while an old server remains running is possible. The backend must invalidate old parser/capability assumptions when executable metadata, server version or command-help contract changes.
- A high-risk review digest includes backend/protocol/capability epoch. If the package/server changed between Prepare and Execute, return \`BACKEND_CHANGED_REPREPARE\`.

## 5. Scriptable vendor prompts are a hidden hang/input channel

This is one of the most important last-mile findings.

Upstream [\`megacmdclient.cpp\`](https://github.com/meganz/MEGAcmd/blob/6505327a5a7a0e94f26f611f83b024aeeb63582c/src/client/megacmdclient.cpp) defines a generic \`readresponse(question)\` that prints the prompt and reads a line from **stdin**. The [POSIX communications loop](https://github.com/meganz/MEGAcmd/blob/6505327a5a7a0e94f26f611f83b024aeeb63582c/src/megacmdshell/megacmdshellcommunications.cpp) handles \`MCMD_REQCONFIRM\` and \`MCMD_REQSTRING\`; confirmation repeats until it receives an accepted yes/no/all/none response.

A QML→Rust JSON stdin boundary therefore does **not** imply the child \`mega-*\` stdin is harmless.

### Required child-process policy

- Rust consumes its own request JSON completely.
- Every vendor child gets stdin from \`/dev/null\` (or equivalent null handle), never inherited from Rust/QML.
- More importantly, every operation must select a vendor invocation known to be **non-interactive** for that exact installed capability.
- An unexpected prompt is a protocol violation for Hadalis. Bound output and time, terminate/reap the exact client child, return \`VENDOR_INTERACTIVE_PROMPT_BLOCKED\`, and conservatively reconcile if dispatch may have begun.
- Do not build a generic stdin-answering prompt engine. Especially do not answer password/MFA/string prompts.
- A command-specific force flag is allowed only when Hadalis itself already displayed the exact equivalent review and source semantics are known. There is no generic "force everything" UI or backend escape hatch.

Examples: \`rm -f\` suppresses folder-delete confirmation, and \`deleteversions -f\` suppresses irreversible history confirmation. Those flags are **not** proof the operation is otherwise safe; target identity/recoverability still needs separate evidence.

### First public export has its own terms prompt

Upstream \`exportNode()\` asks the user to accept copyright terms if they were not previously accepted and no existing public links imply acceptance. \`export -f\` means implicit acceptance and vendor persists that acceptance.

So \`export.create\` needs a Hadalis-owned first-use terms review before a non-interactive vendor call. Never let a background process unexpectedly stall on the vendor question. Do not scrape private \`.megaCmd\` configuration to discover this state. A future acceptance record must be scoped to account/vendor-terms identity and clearly state that accepting through the vendor persists there. If no reliable state exists, conservatively show the notice before creation.

## 6. Public-folder session is not the same as "signed out"

Official [login documentation](https://github.com/meganz/MEGAcmd/blob/6505327a5a7a0e94f26f611f83b024aeeb63582c/contrib/docs/commands/login.md) supports logging into a user account, a public/exported folder, or a previous session—only one entity at a time.

Source details create an easy UI bug:

- \`whoami\` uses \`getMyUser()\`; if absent it reports "Not logged in."
- \`mount\` gates on filesystem availability.
- \`listtrees()\` can display a root even when \`api->isLoggedIn()\` is false.

Therefore the normalized session model should be:

\`session_kind = account | public_folder | signed_out | unknown\`.

Candidate detection after explicit Connect (must be fixture-validated):
- safe short \`whoami\` succeeds → account;
- \`whoami\` says no user but a filesystem/root is available → possible public-folder session;
- no filesystem/session → signed out.

A public-folder session must not show account quota, account security/session controls, normal sync/backups or other account-only controls merely because "backend is connected." Writable folder-link authority is separately sensitive and currently secret-channel constrained.

The round-5 account fingerprint also needs refinement: **never persist a raw unsalted SHA-256 of an email address**. Email hashes are guessable. Prefer a nonsecret vendor account identifier if safely available; otherwise use an in-memory opaque account epoch, or a locally keyed/HMAC-derived identifier for private journal correlation. If a safe cross-restart identifier cannot be obtained, recovery should ask for manual review rather than weaken privacy.

## 7. JSON/QML numeric identity: every opaque identifier is a string

QML/JavaScript uses IEEE-754 Number; integers above \(2^53-1\) cannot be represented exactly. MEGA handles and other IDs may be 64-bit/opaque.

Protocol invariant:

- remote node handles: JSON **string**;
- sync IDs: string;
- backup tags/IDs: string;
- transfer tags: string even when vendor currently prints digits;
- session metadata IDs: string;
- request/action IDs: string;
- byte counts that can exceed JS safe integer: decimal string plus a backend-computed display value/fraction where needed.

Never round-trip an identity through JSON number. Never parse an ID with \`Number(...)\`.

\`observed_at_ms\` can remain an integer while safely below JS's exact-integer limit; do not send nanosecond Unix timestamps as Number. Never emit NaN/Infinity in JSON.

Request IDs need only be unique within one frontend generation for response matching, but persistent \`action_id\` values used in journals must also be unique across multiple Settings processes. Use a random/process nonce + counter or UUID-like 128-bit string, not a bare \`cs-1842\` counter across processes.

## 8. Unicode, invalid UTF-8, normalization and visually deceptive names

Official MEGA SDK documentation warns that POSIX filenames are assumed to be UTF-8 and invalid byte sequences can produce undefined behavior. MEGAcmd itself contains UTF-8 validation paths and an environment switch that disables them.

For identity-bearing data:

- Parse vendor bytes as strict UTF-8.
- **Never use lossy UTF-8 replacement** for a path/name that may later identify a mutation target. Two different byte names can collapse into the same replacement-character string.
- Invalid UTF-8 ⇒ read-only unsupported identity / \`INVALID_UTF8_IDENTITY\`, not a guessed filename.
- Do not normalize NFC/NFD or case-fold before identity comparison.
- Unicode normalization/case folding is allowed only for display search/sort keys that never become mutation keys.
- NUL is rejected even if JSON can encode \`\\u0000\`; Unix argv/path APIs cannot represent it.
- Legal newlines/tabs/control characters, bidi marks and zero-width characters require escaped/isolated visual rendering. A destructive review cannot show only an elided basename that hides the distinguishing suffix.
- Duplicate or visually identical names require parent context + stable handle; no basename-only operation.
- A sanitized/lossy version may be used in **non-authoritative diagnostics**, clearly marked, never fed back into vendor operations.

This extends the existing quote/backslash/delimiter adversarial fixture suite.

## 9. Sync-specific tiny traps from the official SDK

The official [MEGA SDK README sync caveats](https://github.com/meganz/sdk/blob/74326bb0aa09b13f0a1ec8eab9611e4c0de98cc6/README.md#folder-syncing) add constraints that should appear in both backend guards and UX:

- Remote folders have no cross-client locking; same-name server duplicates can occur.
- Cross-platform filename semantics such as \`ABC.TXT\` vs \`abc.txt\` can cause loss on another filesystem.
- A local item must not be exposed to the sync subsystem more than once; nesting or filesystem links can lead to unexpected results/data loss.
- Deleted remote content uses \`//bin/SyncDebris\` for own-cloud syncs, but **inbound-share syncs have no SyncDebris facility**.
- Changed files are whole-file overwrites, not delta writes; live database files are poor sync candidates.
- Sync is bidirectional; there is no upload-only/download-only sync mode.
- Syncing to an inbound share requires full access.

Product consequences:

- No "one-way sync" dropdown. Use Backup for backup workflows.
- Inbound-share sync creation requires verified Full access and explicit recovery-difference warning.
- Do not promise Rubbish/SyncDebris recovery uniformly across own drive and inbound shares.
- Local root overlap detection includes symlink/link/mount aliases; a simple string/realpath comparison is insufficient.
- A "database/live VM image" warning may be useful for known extensions/sizes, but do not claim reliable content-type detection.
- Multi-device sync is a supported use case conceptually, but Hadalis cannot coordinate remote locks that MEGA itself does not provide.

## 10. Cross-feature ownership graph, not just "sync vs sync"

Before creating a job or choosing a download destination, the backend should reason about a graph of **known** local and remote ownership:

Local relationships:
- Sync A vs Sync B, including ancestor/descendant.
- Symlink/bind mount aliases and same inode where detectable.
- Sync root vs MEGA FUSE mount.
- Backup source inside/around a sync or FUSE mount.
- Download destination inside a sync/FUSE root (may immediately upload again).
- FUSE cache/mountpoint relationships.

Remote relationships:
- Sync target vs another sync target.
- Sync target vs backup destination.
- Sync/backup target vs FUSE remote root.
- Own Cloud Drive vs inbound share and its permissions/recovery rules.
- Best-effort known MEGA Desktop roots.
- Unknown other hosts remain **unknown**.

Implementation research should inspect canonical path + stat identity and Linux mount information; even then it must not claim perfect detection of every hardlink, namespace or remote device. A detected potential recursion/cloud→mount→sync loop is a hard block until reviewed.

For FUSE recovery, vendor docs mention manual \`fusermount -u\` for a broken "Transport endpoint is not connected." Cloud Storage should show diagnostics/instructions; it must **not automatically run** lazy/forced unmount repair while applications may have open files.

## 11. Local filesystem TOCTOU cannot be designed away with a preflight alone

Even with canonicalization, a local path can change between Prepare and vendor execution: symlink target replaced, mount changed, directory renamed, permission changed.

For each path-bearing mutation, record the strongest practical identity at Prepare (canonical path, file type, device/inode where meaningful, mount identity) and re-check immediately under the OS mutation lock. If it changes, reject \`LOCAL_TARGET_CHANGED\`.

Residual risk remains because MEGAcmd ultimately receives a path string; Hadalis cannot keep an \`openat\` directory FD as the vendor's authoritative target. Do not describe this as atomic path protection. This is another reason to avoid broad unattended destructive operations.

## 12. Rust child I/O: prevent pipe deadlocks and partial-snapshot lies

Vendor stdout and stderr must be drained **concurrently** with independent byte caps. Reading one pipe fully before the other can deadlock if the unconsumed pipe fills.

Process result model distinguishes:
- spawn failed;
- exited normally with code;
- terminated by signal;
- deadline exceeded;
- stdout cap exceeded;
- stderr cap exceeded;
- invalid UTF-8;
- parser incomplete/ambiguous.

Rules:

- Vendor child stdin = null.
- Never parse a prefix obtained before timeout/output overflow as a complete list.
- On deadline/cap, kill only the exact scriptable client PID spawned by Rust; never indiscriminately kill a process group that can contain or refer to the independently running vendor server.
- Always wait/reap the child after termination.
- The vendor server can survive because its startup path uses \`setsid()\`; do not depend on that as a correctness mechanism.
- Raw stderr remains backend diagnostic input only and is not copied into QML.

## 13. Shell crash and orphan-helper lifetime

Hadalis's user service deliberately uses \`KillMode=process\`. [\`inir cleanup-orphans\`](../scripts/inir) cleans specific known shell helpers but, correctly today, has no generic rule to kill a future \`inir-mega\`.

So a Cloud Storage Rust helper may outlive the QML process after a shell crash. This is not automatically wrong: a dispatched mutation may need to finish its reconciliation/journal update. But it must be bounded:

- every helper has a self-enforced deadline independent of QML;
- a read-only helper expires and exits;
- a helper past dispatch may finish one bounded reconciliation/journal terminal write and then exits;
- never leave a resident orphan indefinitely;
- shell restart reads the journal; it does not reissue the mutation.

Do not add \`inir-mega\` to generic orphan killing without phase/journal awareness. A blind cleanup could destroy the only process capable of recording the result of an already accepted vendor action.

## 14. Suspend/resume, wall-clock jumps and deadlines

A normal monotonic clock is good for timeouts because NTP/manual clock changes cannot move it backwards—but on Linux the usual monotonic clock does not necessarily count time spent suspended. A laptop sleeping for hours must not turn a nominal 30-second helper into a multi-hour live operation.

Implementation direction:
- use a monotonic deadline for ordinary active execution;
- additionally use a Linux suspend-aware elapsed clock such as \`CLOCK_BOOTTIME\` (workspace already has \`libc\`) or an equivalent robust resume guard;
- after wake, if the operation exceeded its total budget, enter timeout/reconcile semantics immediately;
- wall time is for user-facing timestamps, not sole timeout authority.

Frontend freshness must also handle:
- negative/large wall-clock jumps → mark stale rather than showing negative age;
- resume after long sleep → refresh active domain before enabling mutation;
- an open high-risk review across suspend/time change → require Prepare again;
- transfer speed/ETA sample spanning sleep → reset, not average sleep time into speed.

Backup schedules remain stored/reviewed in vendor UTC/raw representation. Local timezone/DST preview is recomputed for display and never becomes the mutation identity.

## 15. Network state is advisory, not an authorization gate

Hadalis already has NetworkManager-derived connectivity state, but MEGAcmd may use a proxy/VPN, cached local state or recover independently.

Therefore:
- show "Network appears limited/offline" as a hint only;
- do not disable all read/reconcile operations purely from \`Network.qml\`;
- vendor operation result remains authority;
- reset read backoff after actual successful backend observation, not merely when Network says "full";
- a network drop after dispatch can produce \`ACTION_OUTCOME_UNKNOWN\`; reconnect triggers read-only reconciliation, never automatic replay.

## 16. Clipboard history and persistent notifications are privacy boundaries

Hadalis installs clipboard history watchers (\`wl-paste --type text --watch ... cliphist store\`). Its Notifications service also persists notification content in the state directory.

Consequences for MEGA secrets/private metadata:

- Never automatically copy a public link/key.
- A deliberate "Copy link" action should explain at least once that system clipboard history may retain it.
- Do **not** auto-clear the clipboard after a timeout. That breaks the user's clipboard and does not reliably erase an already persisted cliphist entry.
- Password, MFA, MEGA session string and recovery master key remain non-copyable/non-exposed in first-phase UI.
- Prefer in-page transient success/state over system notifications.
- If a notification is needed after a page closes, use generic wording: no full local/remote path, email, public-link fragment, session ID or diagnostic payload.
- "Copy sanitized diagnostic" shows the exact allowlisted preview first; the same clipboard-history caveat applies.
- Tooltips and accessibility descriptions must not accidentally contain the hidden full secret just because the visible text is masked.

## 17. Journal/diagnostic storage: permissions and durability are part of correctness

Use Hadalis state conventions rather than vendor \`.megaCmd\`. [\`Directories.qml\`](../modules/common/Directories.qml) derives a standard state directory and \`stateUserPath\`; Cloud Storage recovery data belongs under a private Hadalis-owned subdirectory there, so a vendor logout cannot erase recovery evidence.

Journal requirements:
- parent directories owner-only (0700);
- journal file 0600;
- no symlink following on creation/open;
- same-directory temporary file;
- write complete new schema;
- \`fsync\` file;
- atomic rename over old file;
- \`fsync\` parent directory where supported;
- schema version + backend/protocol epoch;
- corruption is fail-closed/manual-recovery, never "empty means no pending action."

Do not store raw full paths unless a privacy review proves they are necessary. Prefer opaque stable IDs and hashes of canonical expected postconditions. If only a sensitive path can identify a pending action, it may be safer to say "previous action outcome requires manual review" than to persist private content.

Diagnostic export similarly uses an exclusive/non-clobbering, non-symlink target and 0600 permissions. Avoid predictable \`/tmp/cloud-log.txt\` files.

## 18. Account fingerprint, review digest and journal IDs must have distinct semantics

Do not conflate three identifiers:

- **request_id**: response correlation; unique within service generation.
- **action_id**: globally unique across concurrent Settings processes/restarts; journal key.
- **account_epoch/fingerprint**: proves the UI/backend still refers to the same session identity.
- **review_digest**: stale-review detector only; **not** authentication.

A review digest should hash a versioned canonical representation (fixed field order/types) of the backend-produced review + operation + account/backend capability epoch. Do not hash arbitrary JSON text whose object key order can change.

An account fingerprint should not be a plain hash of email. Review digest may be ordinary SHA-256 because its inputs are not being used as a privacy-preserving identifier and the digest is explicitly not an auth token.

## 19. Stable frontend selection: never use list index as identity

Refresh/sort can reorder rows while a user has a menu or multi-selection open.

Frontend rules:
- selection is keyed by string stable ID + account epoch;
- row index is presentation only;
- keyed diff preserves selection only if the same IDs remain;
- if an item disappears, remove it from selection and explain before a bulk action;
- bulk Prepare resolves the **current** selected ID set; missing/changed item makes the old review stale;
- account/backend epoch change clears all remote selections, transfer tags and open remote chooser state;
- an open dropdown is not silently reset to index 0 after its selected item disappears;
- display sort/search keys may be casefolded but never replace canonical identity.

## 20. Vendor local cache/logout behavior and recovery data must remain separate

Official UserGuide states the local cache contains session access plus sync/backup/WebDAV configuration; full logout cleans cache and those configurations. \`logout --keep-session\` preserves the session/cache.

Therefore:
- Logout review explicitly lists affected vendor job/config state.
- Never place Hadalis mutation journal under \`$HOME/.megaCmd\`.
- External logout/session kill is an account-generation boundary.
- If logout occurs while a Hadalis write is uncertain, don't try to reconstruct old handles from the new session; show unresolved/manual reconciliation where necessary.

## 21. Upgrade/reload in the middle of a reviewed action

A prepared mutation becomes stale if any of these change before final Execute:

- Cloud Storage protocol version;
- Rust adapter build identity;
- selected vendor client executable identity;
- effective HOME/socket backend identity;
- observed server version/capability parser epoch;
- account/session epoch;
- target/precondition state.

Final preflight under the OS lock compares all of them. Any mismatch => \`BACKEND_CHANGED_REPREPARE\` / \`STALE_PRECONDITION\`, no vendor write.

After Hadalis or MEGAcmd package update:
- invalidate cached capabilities;
- first explicit Connect/refresh re-probes;
- do not assume the existing vendor server was restarted with the package;
- do not use Linux \`mega-update\` as a package manager.

## 22. Recovery semantics differ by destination/root

The UI must not use one generic "recoverable deletion" statement.

Examples requiring separate tested language:
- own-cloud sync deletions may use SyncDebris behavior;
- inbound-share sync explicitly lacks that SyncDebris facility per SDK documentation;
- ordinary \`rm\` calls the SDK removal path, whose exact Rubbish/permanent behavior in each root must be observed before Hadalis promises restore;
- file-version deletion is separately irreversible history removal;
- public export revoke removes the link, not the underlying node;
- removing a sync definition does not delete files;
- removing a backup definition does not delete generated backup folders per vendor docs.

Confirmation copy must be derived from operation/root semantics, not a generic destructive-dialog template.

## 23. Accessibility/focus edge cases tied to backend state

Backend races can create accessibility bugs if focus is tied to an item that disappears:

- close an anchored row menu before a mutation that may remove/reorder that row;
- move keyboard focus to a persistent status/section heading while reconciling;
- after confirmed removal, restore focus to the nearest surviving logical row, not stale object pointer;
- after rejected/stale precondition, focus the changed field/notice explaining why review is invalid;
- an \`outcome_unknown\` alert is keyboard reachable and announces that Recheck is read-only;
- don't repeatedly announce polling failures every timer tick—announce state transition once and preserve a visible error;
- masked sensitive content's Accessible description must also be masked.

## 24. Additional fake-harness cases created by this audit

Before a real MEGA account is involved, add deterministic fixtures for:

- two separate QML/adapter processes attempt writes simultaneously → exactly one obtains OS lock; loser does not wait/dispatch;
- lock owner crashes → kernel releases lock; journal remains recovery authority;
- lock FD marked CLOEXEC → fake vendor proves it did not inherit it;
- HOME missing, HOME changed, socket-name changed, and mismatched client/server PATH;
- inherited \`MEGACMD_DO_NOT_REDACT_LINES=1\` / \`MEGACMD_DISABLE_UTF8_VALIDATIONS=1\` → Rust strips them for owned vendor child;
- fake vendor requests confirmation/string unexpectedly → no QML/user stdin forwarded, output/deadline bound, no replay;
- first export terms Prepare/Execute stale or not accepted → no export dispatch;
- IDs at \`2^53-1\`, \`2^53\`, \`2^64-1\` round-trip as strings unchanged;
- invalid UTF-8 filename bytes → explicit unsupported, no replacement-character mutation;
- NFC/NFD visually equal names and bidi/zero-width/newline names remain distinct identities;
- stdout fills while stderr fills simultaneously → no deadlock;
- partial output then timeout → no partial snapshot publication;
- shell dies after \`dispatch_started\`, helper completes journal, new shell reconciles without replay;
- shell dies before dispatch journal durability → vendor not invoked;
- suspend longer than helper budget → expires/reconciles immediately after resume;
- wall clock moves backward/forward → no negative freshness, no deadline extension;
- package/vendor backend epoch changes while confirmation is open → Prepare invalidated;
- public-folder session fixture → not mislabeled signed out/account;
- clipboard/link copy is always explicit; notification fixtures contain no secret path/email/link fragments;
- selection survives reorder by stable string ID, not row number;
- local symlink/mount identity changes between Prepare and Execute → no write;
- inbound-share sync creation without Full access / SyncDebris warning → blocked or explicitly reviewed.

## 25. Must-not-ship-without checklist

- [ ] Cross-process OS mutation lock, CLOEXEC and crash-release behavior tested.
- [ ] Private journal atomicity/ownership/permission/corruption behavior tested.
- [ ] No secret or safety-bypass MEGAcmd environment leaks into Hadalis-owned child/server startup.
- [ ] Static page opening executes no \`mega-*\`, including \`mega-version\`.
- [ ] Vendor stdin is null and every enabled command path is proven non-interactive; unexpected prompts fail boundedly.
- [ ] All 64-bit/opaque IDs cross QML JSON as strings.
- [ ] Identity parsing is strict UTF-8; no lossy/normalized/casefolded mutation identity.
- [ ] Account vs public-folder vs signed-out state is fixture-tested.
- [ ] HOME/socket/client/server capability epoch cannot silently change between Review and Execute.
- [ ] Read stdout/stderr concurrency, output caps, child reaping and timeout semantics tested.
- [ ] Suspend/resume and wall/timezone changes cannot extend actions or authorize stale reviews.
- [ ] Local+remote cross-feature overlap graph covers sync/backup/FUSE/download hazards at the documented confidence level.
- [ ] Clipboard history and persistent-notification privacy behavior reviewed.
- [ ] First-export vendor terms flow cannot deadlock or silently accept terms.
- [ ] Package upgrade/reload invalidates parser/capability/review state.
- [ ] Every destructive confirmation text is root/operation-specific and does not promise unverified recovery.
- [ ] All of the above is first proven against fake/sanitized fixtures, then owner-approved disposable account; never the maintainer's live data.

**Result of round 6:** the architecture remains Rust + typed JSON + deferred QML service + official MEGAcmd engine, but stability now explicitly depends on **cross-process locking, environment/backend identity, no-prompt child execution, string-safe identities, strict Unicode, durable no-replay recovery and privacy-aware UI surfaces**. These are implementation acceptance requirements, not optional polish.
