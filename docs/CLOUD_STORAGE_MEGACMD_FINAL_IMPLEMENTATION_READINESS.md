# Cloud Storage / MEGAcmd — final research freeze and implementation readiness (research round 7)

**Status: FINAL DESK-RESEARCH FREEZE / DESIGN ONLY. No QML, Rust, package, runtime, MEGAcmd command or MEGA-account mutation was executed.**  
Research date: 2026-09-30. Hadalis \`dev\` audited at \`cc44b43222d099b7e680c4da05da942e66c4d340\`. Upstream source baselines rechecked on the same date: MEGAcmd \`6505327a5a7a0e94f26f611f83b024aeeb63582c\`, MEGA SDK \`74326bb0aa09b13f0a1ec8eab9611e4c0de98cc6\`, MEGA Desktop \`22e72f5ac548d5024b13eef773fb31dceab99332\`. These source snapshots do **not** identify the maintainer machine's installed MEGAcmd build.

This document closes the desk-research phase. It does not add another feature wishlist. It freezes the architecture, corrects a few remaining assumptions, separates implementation-ready surfaces from evidence-gated ones, and defines the exact proof still required on the installed MEGAcmd version before any write operation is shipped.

Read this after:

- [full feature design](CLOUD_STORAGE_MEGACMD_FULL_DESIGN.md)
- [source-level safety audit](CLOUD_STORAGE_MEGACMD_SOURCE_AUDIT.md)
- [protocol / SDK decisions](CLOUD_STORAGE_MEGACMD_PROTOCOL_DECISIONS.md)
- [QML component design](CLOUD_STORAGE_MEGACMD_UX_COMPONENTS.md)
- [control matrix](CLOUD_STORAGE_MEGACMD_UX_CONTROL_MATRIX.md)
- [frontend/backend contract](CLOUD_STORAGE_MEGACMD_FRONTEND_BACKEND_CONTRACT.md)
- [last-mile edge-case audit](CLOUD_STORAGE_MEGACMD_LAST_MILE_EDGE_CASE_AUDIT.md)

If these documents conflict, the more conservative rule wins; this round is the latest research decision.

## 1. Final architecture decision

Production direction remains:

\`CloudStorageConfig.qml\`  
→ deferred \`CloudStorageService.qml\`  
→ **dedicated one-shot Rust binary \`inir-mega\`**  
→ official scriptable \`mega-*\` clients  
→ existing vendor \`mega-cmd-server\`  
→ MEGA.

### Why a dedicated \`inir-mega\`, not Python

Hadalis already treats Rust as the production native backend. Cloud Storage has security- and correctness-sensitive parsing, deadlines, output caps, concurrent pipe draining, OS locking, durable journal writes and strict typed JSON. Rust is the preferred implementation when it provides better latency/memory/correctness characteristics than a Python helper.

There is **no Python mutation fallback**. A Rust failure after vendor dispatch cannot safely be retried by another implementation.

### Why a dedicated binary instead of adding a broad \`inir-native mega\` subcommand

A separate binary is preferred because it:

- gives Cloud Storage a distinct security/recovery boundary;
- can be mandatory even when the generic native selector is forced to Python for unrelated features;
- avoids accidentally inheriting the generic Rust→Python fallback behavior;
- allows narrowly scoped tests, deadlines, environment policy and journal code;
- makes future seccomp/systemd-scope hardening possible without affecting other native helpers;
- keeps an eventual MEGA SDK/FFI experiment isolated from the general desktop helper.

The existing \`scripts/native-dispatch\` may still be used only as a **binary locator/exec router** if a \`mega\` branch is added that always requires \`inir-mega\` and never falls back. Direct packaged binary invocation is also acceptable if source/package path resolution is solved equivalently.

Do **not** introduce a permanent Hadalis Cloud Storage daemon in v1. MEGAcmd already owns the persistent server/cache/session. The Rust layer remains one-shot until profiling proves that adapter startup, rather than vendor latency, is a material bottleneck.

## 2. Current upstream baseline corrections

### 2.1 MEGAcmd 2.6.0 transport behavior

Current upstream changelog/source identifies MEGAcmd 2.6.0 as the current source release baseline examined. In this branch:

- file transfers always use HTTPS;
- \`https on\` is accepted but changes nothing;
- \`https off\` is rejected;
- the \`https\` command is deprecated.

**Product decision:** Cloud Storage must not expose an HTTPS on/off toggle. At most, diagnostics may show “Transfers use HTTPS” when installed capability confirms the same behavior.

### 2.2 Proxy environment now matters

The 2.6.0 changelog states Linux/macOS use \`http_proxy\` and \`https_proxy\` environment variables when no vendor proxy is configured.

Round-6 environment sanitization is therefore refined:

- preserve legitimate lower-case proxy variables when spawning a vendor client/server;
- never copy their values into diagnostics because URLs can contain credentials;
- do not include raw proxy URL in backend identity/journal;
- vendor \`proxy --password\` remains excluded from the normal JSON/argv bridge.

### 2.3 WebDAV streaming now has an on-disk cache policy

Current upstream WebDAV documentation says streamed content is cached on disk and cleaned through:

- \`file_service_reclaim_age_threshold\`
- \`file_service_reclaim_batch_size\`
- \`file_service_reclaim_delay\`
- \`file_service_reclaim_period\`
- \`file_service_reclaim_threshold\`
- \`file_service_reclaim_target\`

The threshold is **not a hard maximum**; cleanup is timer/age driven and a busy stream can exceed it.

**Product decision:** if installed help proves these keys exist, local-only WebDAV may expose an advanced “Streaming cache” card with exact vendor semantics. Do not label threshold “Max cache size.” Do not expose these controls on older builds just because Hadalis was compiled against newer research.

## 3. Final parser conclusion: text columns are not a structured protocol

The source implementation of \`ColumnDisplayer\` does:

\`value1 + separator + value2 + ... + newline\`

It does **not** quote or escape cell contents.

Therefore:

- \`--col-separator\` is useful for known enum/ID fields;
- it is not CSV/TSV;
- any path/name/error/free-text field can contain the delimiter;
- a path/name can also contain a newline on POSIX;
- output row count can become ambiguous.

### 3.1 Parser policy

For every command parser:

1. request the smallest possible explicit \`--output-cols\`;
2. prefer opaque IDs, booleans and documented enums;
3. when practical, request **one column at a time** to eliminate delimiter ambiguity;
4. compare exact header names when headers are expected;
5. reject unknown enum values rather than mapping them to a success-like state;
6. treat embedded row ambiguity/truncation as \`AMBIGUOUS_VENDOR_OUTPUT\`;
7. never reconstruct a mutation target from a lossy display row;
8. never treat a partial prefix obtained before timeout/output cap as complete.

A separator-based parser is never promoted to lossless identity merely because a delimiter was chosen that is “unlikely.”

### 3.2 \`find --print-only-handles\` helps but does not solve Drive listing

Upstream \`find --print-only-handles\` is explicitly intended to print only node handles, which is useful for automation and exact remote identity. But it does not provide a lossless handle→arbitrary-name serialization.

So it can help discover/verify handles, but it does **not** make an unrestricted GUI Drive browser safe by itself.

### 3.3 Scriptable argv remains an independent limitation

The scriptable client reconstructs process argv into one command string. In the inspected code it adds quotes primarily for arguments containing spaces or empty strings, then the server tokenizes the command again.

This keeps the round-2 conclusion intact:

- Rust \`Command::args\` avoids shell injection;
- it does **not** guarantee byte-exact MEGAcmd argument round-trip for every legal filename;
- quotes, backslashes, tabs/newlines/control characters and other parser-sensitive strings need fixtures;
- local absolute paths should be used whenever a local path is unavoidable;
- remote **handles** should be preferred over remote paths whenever the command accepts them.

## 4. No fake pagination

Several vendor commands have \`--limit=N\`, but no offset/cursor API:

- transfers
- sync issues
- FUSE listing

Other discovery commands such as \`find\` can emit large output without a true paging protocol.

UI rules:

- call these results **bounded snapshots**, not pages;
- “Load more” may increase the same limit and replace/merge by stable ID, but is not server pagination;
- never display “page 2 of …”;
- output-cap truncation is distinct from vendor limit truncation;
- a global destructive bulk action cannot be based on a known-incomplete snapshot;
- \`limit=0\` / unlimited is not used in ordinary UI.

## 5. Final implementation-readiness tiers

These tiers describe **desk-research readiness**, not live acceptance. Every mutation still requires fake-harness proof and installed-version capability/fixture validation.

### Tier A — implement first

These are the best candidates for the first production slice because they can be made ID/enum oriented and do not require an unrestricted filename data plane.

#### Connection / health

- static dependency detection by filesystem/PATH inspection without executing \`mega-*\`;
- explicit Connect that may start/adopt the vendor server;
- backend/session kind: account / public folder / signed out / unknown;
- vendor capability fingerprint after Connect;
- last-success/fresh/stale/degraded state.

#### Overview

- short account identity from a narrowly tested \`whoami\` parser;
- quota/storage summary from a version-pinned \`df\` parser;
- server/client capability/version diagnostics after Connect;
- no \`mega-session\` and no master key.

#### Sync read/control

- list \`ID\`, \`RUN_STATE\`, \`STATUS\`, selected enum/count fields using minimal columns;
- optional remote handle when proven;
- pause/enable/remove by **sync ID**, not local path;
- sync issue count/ID and bounded details;
- do not use issue paths as mutation identity.

#### Transfers

- bounded active/completed snapshot;
- transfer tag treated as opaque string;
- pause/resume/cancel by tag;
- separate sync/backup transfer type display;
- no assumption that a tag is a permanent cross-session database key.

#### Nonsecret preferences

- upload/download speed limits and connection limits;
- sync delayed-upload configuration;
- nonsecret capability/query preferences whose installed syntax has been probed.

Tier-A implementation should be read-mostly first; mutation buttons stay feature-gated until disposable live tests pass.

### Tier B — implement only behind installed-version + disposable-account fixtures

#### Create sync

Conditions:

- local source passes strict safe-path/argv fixtures;
- local overlap graph is clear enough to proceed;
- remote folder is referenced by validated handle where possible;
- Full access verified;
- own-drive vs inbound-share recovery semantics shown;
- post-create sync ID is reobserved authoritatively.

Arbitrary exotic local source paths remain unsupported if exact vendor roundtrip is unproven.

#### Upload/download

- prefer one explicit source/destination per operation in v1;
- local path must pass exact safe-path policy;
- remote target/source uses handle when possible;
- destination collision semantics shown exactly;
- queued transfer tag is reconciled from vendor state;
- password-protected public links remain excluded.

#### Backups

Vendor backup remains beta. Creation/edit/remove/abort need disposable fixtures covering:

- first backup starts immediately;
- UTC schedule rendering;
- SKIPPED/MISCARRIED/INCOMPLETE behavior;
- retention changes;
- removal does not remove generated backup folders;
- human output parser stability.

#### FUSE

FUSE remains beta. Allow only after feature probe and Linux fixture:

- read-only + disabled default;
- safe local mountpoint;
- safe user-visible mount name;
- remote handle where supported;
- bounded \`fuse-show\` parser;
- disable-before-remove;
- no automatic forced/lazy repair unmount.

#### Local-only WebDAV

Allow only localhost mode initially after:

- command existence/help probe;
- exact served-root parser fixture;
- cache policy capability probe;
- local port conflict behavior test;
- stop/restart/logout persistence test.

Public bind stays withheld.

#### Public export without passwords

Only when:

- node identity is exact;
- first-use copyright notice is handled by Hadalis review;
- no password/auth-key secret option;
- generated link is shown/copied only by explicit user action;
- link is excluded from logs/notifications.

#### Contact share/revoke

Only after:

- contact list/verification state parser fixture;
- exact target node handle;
- exact email selected from current vendor state;
- access level review;
- owner-level share remains withheld initially.

### Tier C — intentionally withheld from first implementation

These are not “forgotten.” They are blocked because the current CLI boundary cannot prove the required correctness/security yet.

- unrestricted arbitrary-filename Drive file manager mutations;
- blanket claim that Drive listing is lossless for all POSIX names;
- move/rename/copy/delete that depends on ambiguous human path output;
- QML-native username/password/MFA login;
- password-protected import/export links through argv;
- writable public-folder auth-key handling;
- proxy password UI;
- session-string display/copy;
- master-key display/copy;
- account cancellation;
- delete-all/version-history convenience actions;
- Owner-level contact share in normal UI;
- public WebDAV/FTP bind;
- automatic MEGA Desktop private-IPC control;
- direct use of MEGAcmd internal Unix socket framing;
- automatic mutation retry after timeout;
- Python mutation fallback.

If unrestricted Drive is later a hard requirement, reopen the isolated official MEGA SDK data-plane research instead of weakening CLI guards.

## 6. Capability detection is behavioral, not version-number-only

A semantic version is useful diagnostic context but is not sufficient. Distribution packaging, compile-time features and long-running old server processes can differ.

### Before Connect

Allowed:

- find candidate \`mega-*\` executables;
- canonicalize paths;
- inspect executable metadata;
- inspect whether matching \`mega-cmd-server\` is present.

Not allowed:

- \`mega-version\`;
- \`mega-help\`;
- \`mega-whoami\`;
- any normal vendor client that can auto-start the server.

### After explicit Connect

Build a capability snapshot from safe, bounded probes such as:

- command existence;
- \`command --help\` option tokens;
- supported column names/options;
- FUSE/WebDAV presence;
- \`configure\` keys;
- deprecated/always-on HTTPS behavior where relevant;
- observed server version when available.

A parser is selected by **capability fingerprint + fixture**, not just \`major.minor.patch\`.

A high-risk review digest includes this capability epoch. If it changes before Execute, require Prepare again.

## 7. Error handling freeze

Exit code is evidence, never complete success authority.

The public client converts negative vendor codes to positive process exit values. The server can also surface MEGA API errors, synchronization errors and textual diagnostics.

Normalized Rust error fields remain:

- \`stage\`: detect/connect/validate/dispatch/reconcile/parse/journal;
- \`kind\`: stable Hadalis code;
- \`vendor_exit\`: optional integer/string;
- \`vendor_code\`: optional normalized code;
- \`retryable_read\`: bool;
- \`outcome\`: not_dispatched / confirmed_failed / unknown;
- \`user_message\`: safe;
- \`debug_redacted\`: allowlisted.

Mutation success always requires authoritative postcondition readback.

## 8. Transfer identity and refresh

Transfer TAG is treated as **current vendor operation identity**, not a permanent history primary key.

Consequences:

- frontend selection stores \`tag + direction/type + backend/account epoch\`;
- on server/account epoch change, transfer selections clear;
- completed-history row identity may include an observation nonce if tag reuse/restore behavior is not fixture-proven;
- a stale tag never authorizes cancel/pause after reconnect without a fresh row match.

## 9. Performance freeze

Performance priorities are:

1. avoid unnecessary \`mega-*\` process invocation;
2. coalesce duplicate reads;
3. keep polling tied to visible consumers;
4. query minimal columns;
5. cap output;
6. avoid parsing large human tables;
7. keep Rust one-shot startup small;
8. profile before introducing a permanent Hadalis daemon.

JSON is retained as the QML↔Rust protocol. For expected status/control payload sizes, JSON parsing is not the dominant cost compared with process/vendor/server/network work.

### Suggested visibility cadence remains guidance, not an invariant

- visible active transfer/sync view: fast bounded refresh;
- visible overview/idle page: slower;
- hidden cached Settings page: release/slow consumer;
- no Settings consumer: no UI polling.

Exact milliseconds are implementation-tuned by profiling and power behavior, not frozen in research.

## 10. Exact current Hadalis integration map

Current Hadalis source was re-audited at this round.

### New files expected

- \`modules/settings/CloudStorageConfig.qml\`
- \`services/deferred/CloudStorageService.qml\`
- \`native/inir-mega/Cargo.toml\`
- \`native/inir-mega/src/main.rs\` plus focused Rust modules
- Cloud Storage fixture/contract tests under the repository's existing test conventions

### Existing files expected to change

- \`native/Cargo.toml\` — add workspace member
- \`native/scripts/install-runtime.sh\` — add \`inir-mega\` binary
- \`Makefile\` — package/install assertion list
- \`nix/package.nix\` — build/install binary list
- \`scripts/native-dispatch\` — optional strict \`mega\` exec route and backend-info; **no Python fallback**
- \`services/deferred/qmldir\` — export CloudStorageService
- \`modules/settings/SettingsPageRegistryData.qml\` — append stable Cloud Storage page
- \`modules/settings/SettingsPageRegistry.qml\` — explicitly permit the appended page for ii/Abyss/Waffle
- \`translations/en_US.json\` — all new shell UI strings
- relevant Settings/native/runtime contract tests

### Settings index observation

At this audit, the live registry ends with Automation at index 35. If no concurrent page is added before implementation, Cloud Storage appends at index 36.

**Never hardcode 36 without re-reading live HEAD at implementation time.** The stable route key is \`cloud-storage\`; index is an implementation-time allocation.

Current \`isPageApplicable()\` still restricts Waffle and ordinary non-Abyss pages to \`index < 32\`, so merely appending the page would hide it. It must be explicitly allowed across supported families.

Current “Features & Services” category includes Automation only for Abyss and not for other families; Cloud Storage must be deliberately added to the correct default category for each supported family, not rely on accidental arrangement fallback.

## 11. Native packaging consequence

The current native installer/package lists are explicit:

\`inir-inputd inir-mpdd inir-native inir-theme\`.

Adding a new Rust binary is not complete until **every** authoritative binary list is updated and tested. A source build succeeding while packaged Hadalis omits \`inir-mega\` is a release blocker.

The existing native production contract test also enumerates the binaries and must be updated to include \`inir-mega\`.

## 12. Suggested Rust module boundaries

Keep command construction and parsing isolated from QML protocol types.

Possible internal structure:

- \`protocol.rs\` — stdin request / stdout response schema and protocol version;
- \`capabilities.rs\` — binary discovery, backend epoch, help probes;
- \`process.rs\` — environment, null stdin, concurrent stdout/stderr, caps/deadlines/reaping;
- \`lock.rs\` — per-user OS mutation lock;
- \`journal.rs\` — atomic private mutation journal;
- \`vendor/\` — operation-specific command builders;
- \`parse/\` — command/version-specific parsers;
- \`model/\` — normalized account/sync/transfer/backup/mount models;
- \`reconcile.rs\` — postcondition verification;
- \`redact.rs\` — diagnostic allowlist/redaction.

Do not make one generic “run arbitrary MEGAcmd command” endpoint reachable from QML.

## 13. QML service freeze

\`CloudStorageService.qml\` owns presentation-facing state, not vendor syntax.

Minimum state:

- connection/backend state;
- account/session epoch;
- capability epoch;
- request generation;
- per-domain freshness/loading/error;
- normalized models;
- consumer visibility;
- one local mutation state;
- cross-process busy result;
- pending recovery notice.

The service never:

- constructs \`mega-*\` flags;
- parses vendor tables;
- retains passwords/MFA/session strings;
- marks success from process exit;
- retries writes;
- uses row index as identity.

## 14. Final UX corrections

### Remove/deprecate

- no HTTPS toggle;
- no generic “Force” option;
- no “Retry write” after timeout;
- no fake server pagination;
- no one-way Sync selector;
- no generic claim that every delete is recoverable;
- no copyable session/master key;
- no public-network WebDAV/FTP switch in v1.

### Add/retain

- explicit Connect;
- exact freshness/stale state;
- backend/version capability diagnostics;
- read-only Recheck for unknown outcomes;
- bounded-results note;
- clear “unsupported for this installed MEGAcmd build” reasons;
- Streaming cache card only when capability exists;
- distinction between vendor sync, backup, FUSE and transfer state;
- explicit clipboard-history warning before copying sensitive public links.

## 15. Fake harness becomes the first implementation milestone

Before owner account access, implement a fake \`mega-*\` executable suite that can emulate:

- normal output by command/capability fingerprint;
- malformed headers/columns;
- delimiter/newline injection;
- invalid UTF-8;
- huge output;
- stdout/stderr backpressure;
- confirmation/string prompt request;
- nonzero vendor/API exit;
- process signal;
- timeout before dispatch;
- timeout after simulated dispatch;
- server/version epoch change;
- account epoch change;
- public-folder session;
- output cap;
- lock contention;
- helper crash after journal phase changes;
- suspend/time-jump test hooks.

This harness should prove that malformed/ambiguous evidence **removes capability** instead of silently producing a plausible UI state.

## 16. Disposable installed-version qualification sequence

Only after fake harness passes:

1. record exact installed executable/server identity;
2. explicit Connect on a disposable account/environment;
3. capture sanitized \`--help\`/read fixtures;
4. test read-only account/sync/transfer state;
5. create disposable remote/local trees containing adversarial safe-test names;
6. prove allowed local argv roundtrip;
7. prove handle-based remote addressing;
8. prove sync ID operations;
9. prove transfer tag control;
10. prove backup lifecycle;
11. prove FUSE/WebDAV only if those features are enabled;
12. force timeout/network interruption cases;
13. verify no duplicate write after shell/Rust restart;
14. verify logs/clipboard/notifications contain no forbidden secret fields;
15. only then enable corresponding mutation capability in UI.

A capability that fails qualification remains disabled while the rest of Cloud Storage can ship.

## 17. Final v1 implementation sequence

### Phase 0 — substrate

- \`inir-mega\` skeleton;
- JSON protocol;
- capability fingerprint;
- process runner;
- redaction;
- OS lock;
- journal;
- fake vendor tests.

### Phase 1 — read-only page

- Settings registration;
- Connect/disconnect UI semantics;
- Overview;
- backend/session state;
- read-only Sync and Transfers;
- diagnostics.

### Phase 2 — narrow ID-based controls

After disposable fixtures:

- sync pause/enable/remove by ID;
- transfer pause/resume/cancel by tag;
- speed/connection limits;
- sync issue browsing.

### Phase 3 — constrained creation/workflows

After path fixtures:

- create sync;
- upload/download;
- backups.

### Phase 4 — optional beta/local services

After capability/platform fixtures:

- FUSE;
- localhost WebDAV;
- streaming cache controls.

### Phase 5 — sharing

After contact/export fixtures:

- nonpassword public links;
- safe share/revoke levels.

### Not in initial phase

Unrestricted Drive mutation remains withheld until a lossless data plane is proven.

## 18. Final must-pass acceptance gates

### Architecture
- [ ] Dedicated Rust Cloud Storage backend; no Python write fallback.
- [ ] No permanent Hadalis daemon without profiling evidence.
- [ ] QML has no vendor command syntax.

### Packaging
- [ ] \`inir-mega\` present in source install, packaged install and Nix outputs.
- [ ] Native production contract updated for the binary.

### Lifecycle
- [ ] Opening Settings performs no MEGAcmd client call.
- [ ] Explicit Connect is the first vendor-starting boundary.
- [ ] Closing Settings does not stop vendor sync/server.
- [ ] Hidden page releases or slows polling.

### Parsing
- [ ] Separator output never treated as escaped serialization.
- [ ] Opaque IDs stay strings.
- [ ] Strict UTF-8 identity.
- [ ] Bounded output + explicit incomplete state.
- [ ] No fake pagination.
- [ ] Unknown enum/header/version fails closed.

### Mutation safety
- [ ] Cross-process OS lock.
- [ ] Fresh final preflight.
- [ ] Durable dispatch journal before vendor write.
- [ ] No auto retry.
- [ ] Postcondition reconciliation.
- [ ] Backend/account/capability epoch invalidates review.

### Security/privacy
- [ ] Vendor stdin null for normal child execution.
- [ ] Unexpected interactive prompt bounded/fails closed.
- [ ] Secret-bearing argv options withheld.
- [ ] Dangerous MEGAcmd debug/redaction bypass env removed.
- [ ] Legitimate \`http_proxy\`/\`https_proxy\` preserved without logging values.
- [ ] Clipboard/system notifications do not leak private paths/links/account secrets.

### Installed-version evidence
- [ ] Command/help/capability fixtures captured and sanitized.
- [ ] Every enabled parser tied to a proven fixture.
- [ ] Every enabled mutation tested on disposable data.
- [ ] Failed capability disables only that control/domain.

## 19. Research freeze decision

No further source-only research is required before implementation of the **Tier-A substrate/read path**.

The remaining unknowns cannot be responsibly resolved by reading more upstream source alone. They are empirical:

- exact MEGAcmd build installed on the maintainer machine;
- its compiled feature set;
- its real scriptable output under that environment;
- exact argv roundtrip on adversarial local paths;
- live timeout/server restart behavior;
- account/public-folder behavior;
- FUSE/WebDAV availability;
- disposable write/reconciliation behavior.

Those are implementation qualification tasks, not reasons to keep expanding design documents indefinitely.

If upstream MEGAcmd/SDK/Desktop changes after this freeze, reopen research only for affected capability fingerprints rather than restarting the whole architecture study.

**Final result:** implement **Rust \`inir-mega\` + typed JSON + deferred QML + official MEGAcmd engine**, begin with read/ID-based domains, fail closed per capability, and keep unrestricted Drive/secret-bearing operations withheld until a lossless/safe data plane is demonstrated.
