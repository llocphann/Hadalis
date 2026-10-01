# Cloud Storage — MEGAcmd ↔ Rust ↔ QML implementation

> **Phase 2a source scaffold (2026-10-01; QML runtime pending):** A dormant static-only CloudStorageService, a ten-route Settings shell visible for ii/Abyss/Waffle, search, translations and focused static source tests were added. Backend remains detect-only for UI: Connect, auth credentials, account reads and all writes are withheld. No live MEGA, installed-version acceptance or rendered UI PASS is claimed.

> **Implementation authorization (2026-10-01):** maintainer authorized design and source implementation on `dev`. Historical “research only” statements below describe the evidence state when written and no longer prohibit QML/Rust/source work for this task. Live account/data actions remain gated to an explicitly permitted disposable environment.

> **Milestone I3 — strict runtime/package route qualified locally (2026-10-01):** current-source install/Nix/rolling-Arch paths ship `inir-mega`, and `scripts/native-dispatch mega` is a Rust-only route with no Python fallback. The pinned non-VCS Arch package intentionally remains on its older reviewed source snapshot until that snapshot advances to a commit containing `inir-mega`; packaging tests guard against falsely advertising the binary there. Private worker receipt `JOB-MEGACMD-F1-PACKAGE-012` (base source `ff63b492ec5dbd23e7058165fb7b968dfa7ba80d`, job/test source `fbeb3ad930e7788da2c9240048553dab15aea448`) passed selector, production-route, packaging, make-install lifecycle, and `cargo test -p inir-mega` actions; evidence `JOB-MEGACMD-F1-PACKAGE-012:0` through `:4` all exited 0 without timeout/cancellation/truncation. This qualifies the source/package route only; real installed-version auth/account/data acceptance remains gated.
>
> **Milestone I2 — production-shaped auth transport qualified locally (2026-10-01):** private worker receipt `JOB-MEGACMD-F1-AUTH-011` passed `cargo test -p inir-mega` and `cargo check -p inir-mega` on source SHA `6dadecde913e067c7910404563e82080010f4931` (evidence `JOB-MEGACMD-F1-AUTH-011:0` and `:1`, both exit 0, no timeout/truncation). Git publication of that result was not yet visible through the connector when this checkpoint was written; the managed local receipt is the evidence source. Real installed-version auth remains unqualified and disabled.


> **Milestone I1 — Fake PTY harness qualified (2026-10-01):** `JOB-MEGACMD-F1-PTY-010` passed `cargo test -p inir-mega` and `cargo check -p inir-mega` for base source `6d7be8f9129cfb6a78fb971dcca08b12646051ae` (job commit `aae52d00ec8218a35cee7da5b91da2b46c2b9f2f`). Synthetic PTY tests cover password→MFA→success, unknown-prompt fail-closed, secret non-echo, and bounded silent-vendor timeout. This qualifies only the fake transport harness; real MEGAcmd authentication, installed-version prompts/capabilities, and account/data actions remain disabled/unqualified.

> **Milestone I0 — Phase 0 substrate started:** gap audit at `e5cbf7f5dcf763d89194f8913def51f501e7c8b8` found no existing `inir-mega`, `CloudStorageService.qml`, or `CloudStorageConfig.qml`. The implementation delta is in [CLOUD_STORAGE_MEGACMD_IMPLEMENTATION.md](../../docs/CLOUD_STORAGE_MEGACMD_IMPLEMENTATION.md). Phase 0 adds the Rust workspace member, typed stdin/stdout protocol, fail-closed auth/MFA prompt classifier, and secret non-echo tests. Real vendor dispatch remains disabled until the fake PTY harness is qualified.


> **Research round 7 — FINAL FREEZE:** [Final implementation readiness](../../docs/CLOUD_STORAGE_MEGACMD_FINAL_IMPLEMENTATION_READINESS.md) is now the implementation entry point. It freezes Tier A/B/C scope, dedicated Rust `inir-mega`, parser/capability rules, current MEGAcmd 2.6.0 corrections, packaging map and the fake/disposable qualification sequence. Further desk research is closed unless upstream changes.

> **Research round 6:** [Last-mile edge-case audit](../../docs/CLOUD_STORAGE_MEGACMD_LAST_MILE_EDGE_CASE_AUDIT.md) covers cross-process locking, MEGAcmd environment/backend identity, interactive-prompt traps, strict Unicode/64-bit IDs, suspend/recovery, clipboard/notification privacy and package-upgrade races.

> **Research round 5:** [Frontend/backend stability contract](../../docs/CLOUD_STORAGE_MEGACMD_FRONTEND_BACKEND_CONTRACT.md) defines the concrete QML deferred-service ↔ typed Rust ↔ MEGAcmd boundary, request/generation guards, no-replay writes and post-action reconciliation.

> **UX research round 4:** [Shared component/layout rules](../../docs/CLOUD_STORAGE_MEGACMD_UX_COMPONENTS.md) and [per-section control/wizard choices](../../docs/CLOUD_STORAGE_MEGACMD_UX_CONTROL_MATRIX.md) define practical button, combo, context menu, status-chip and dialog details. No code or live MEGA commands.

> **Research round 3:** [Protocol, SDK feasibility, Desktop IPC and data-loss decisions](../../docs/CLOUD_STORAGE_MEGACMD_PROTOCOL_DECISIONS.md) refines both the [full design](../../docs/CLOUD_STORAGE_MEGACMD_FULL_DESIGN.md) and [source audit](../../docs/CLOUD_STORAGE_MEGACMD_SOURCE_AUDIT.md). Remote and local sync overlap **both matter**; ordinary CLI-based Drive mutations are not automatically safe.

> **Research round 2:** [Source-level audit and blocking acceptance gates](../../docs/CLOUD_STORAGE_MEGACMD_SOURCE_AUDIT.md) supersedes earlier optimistic assumptions about generic CLI argv, column parsing and pre-connect read-only probes. The Rust bridge is still the preferred direction, but capability-gated Drive mutations are mandatory.

**Historical research status:** source implementation is now authorized by the active maintainer task; live account/data actions remain separately gated.

**Canonical full command/UX/security/architecture research:** [`../../docs/CLOUD_STORAGE_MEGACMD_FULL_DESIGN.md`](../../docs/CLOUD_STORAGE_MEGACMD_FULL_DESIGN.md).  
**Prior feasibility snapshot:** [`../../docs/CLOUD_STORAGE_MEGACMD_RESEARCH.md`](../../docs/CLOUD_STORAGE_MEGACMD_RESEARCH.md) (historical provisional Python suggestion is superseded by Rust in the new design).

### Completed desk research
- [x] Re-audit shared Hadalis Settings registry, page host, standalone/overlay/focus presentations, ABI/build boundaries and the already-existing native Rust workspace.
- [x] Count and classify all **76 officially documented MEGAcmd command help files** into primary QML, advanced/gated, CLI-only and external/withheld controls.
- [x] Specify ten-section Cloud Storage UI, typed Rust+JSON operation boundary, lifecycle and performance measurement plan, security and destructive-operation guardrails.
- [x] Document MEGAcmd versus MEGA Desktop separate ownership; actual Desktop GUI control remains unproven.
- [x] Identify beta FUSE and backup caveats, separate transfer/sync states, sharing exposure, and unsupported-until-proven trash/versions restore.

### Evidence and blockers remaining (do not mark complete from desk research)
- [ ] Capture sanitized `mega-version -l`, relevant `--help` output and real output/error fixtures on the **owner's target Linux host**.
- [ ] Verify existing MEGA Desktop coexistence, direct API support if needed, and prevent path/mount double ownership with disposable fixtures.
- [ ] Verify safe vendor PTY/stdin account+MFA and protected-link/proxy-password entry; otherwise retain external interactive sign-in and block insecure CLI secrets.
- [ ] Confirm trash/version restore behavior and unusual filenames/Unicode/large tree parser correctness using throwaway data.
- [ ] Benchmark Rust helper vs Python and vendor client IPC end-to-end against a measurable no-background-cost acceptance target.
- [ ] Review desired ten-section UX and feature gating with the maintainer and obtain explicit authorization before any runtime implementation.

The autonomous Local Bot must not contact a real MEGA account, initiate a sync or infer human GUI acceptance. Only dispatch isolated, deterministic, SHA-pinned synthetic validation jobs if the maintainer authorizes a later implementation.

### Newly confirmed source-audit findings
- [x] Verify vendor client reconstructs argv into command text and server re-tokenizes it; forbid untested unusual-filename mutations.
- [x] Verify `ColumnDisplayer --col-separator` does **not** quote/escape arbitrary cell data in the inspected source; require ambiguous-row rejection.
- [x] Verify normal vendor CLI commands can auto-start `mega-cmd-server`; perform only static binary detection before explicit Connect.
- [x] Inspect vendor interactive password/no-history behavior and vendor log redaction **environment override**; do not promise safe in-page login.
- [x] Find official SDK version enumeration/restore APIs; treat SDK-backed Drive as independent opt-in research, not an approved implementation.
- [x] Identify exact production Rust/Arch/Nix binary-install enumeration and QML appended-page applicability traps in Hadalis.
- [x] Record scope/version of open upstream reports on sync IDs beginning with a dash and hung vendor servers.

### Additional non-negotiable gates
- [ ] Reproduce safe vendor argv roundtrip and table parser fixtures for Unicode, embedded delimiters/newlines, quotes, `--` and leading-dash sync IDs on the actual installed version; fail closed where not representable.
- [ ] Verify zero unconsented server startup and bounded hung-server handling without terminating an externally owned vendor process.
- [ ] Assess whether an official SDK adapter is necessary for unrestricted Drive and version restore, including separate session, packaging and resource/security impacts; **do not assume integration**.
- [ ] Confirm never-secret user diagnostics, no vendor log collection by default and whether current external vendor process has redaction override enabled.

### Round-3 desk research completed
- [x] Audit the official SDK's lack of remote cross-client locking and local double-exposure/nested/symlink data-loss warnings.
- [x] Inspect MEGA Desktop's Linux extension sockets; distinguish partial **internal** local-root observations from a supported full Desktop management API.
- [x] Prove noninteractive `mega-login email` refuses missing password; reject fake stdin-based secure login and keep official interactive sign-in.
- [x] Confirm `mega-mv` may remove an existing file destination and leave partial result if rename subsequently fails.
- [x] Identify `//bin` generic move-out as a disposable-test hypothesis only, not verified original-location restore.
- [x] Check SDK `restoreVersion`/node methods, app-key, missing bundled Rust binding and isolated-instance feasibility/packaging constraints.
- [x] Map Quickshell tracked-process lifetime and JSON output cap requirements to Hadalis visibility-demand architecture.

### New gates before implementation
- [ ] Establish both **local** and **remote** sync overlap proof, and user-facing unknown-external-client warning; internal Desktop socket data must never be considered authoritative.
- [ ] Specify and test a no-silent-overwrite policy for `mega-mv`, including external race and partially successful vendor actions, before enabling Drive writes.
- [ ] Verify actual `//bin` move-out on throwaway data; separately investigate original-path restoration and SDK version restoration.
- [ ] Resolve SDK separate account/app-key/session/FFI/cache costs and whether unrestricted Drive is a requirement before adding any second client.
- [ ] Collect real installed-version and latency/output fixtures with explicit consent on an isolated test account; until then claim **design only**.

### Round-4 micro-interaction/design research
- [x] Audit current Settings/Abyss/Waffle button, dropdown, card, menu, tooltip, loading, dialog and responsive ContentPage behavior.
- [x] Preserve ten canonical Cloud Storage sections while avoiding a ten-pill navigation bar: five groups plus 1–3 child sections with compact combo fallback.
- [x] Specify button hierarchy/states, value-dropdown versus action-menu rules, keyboard/focus, scaling, loading, empty/stale/error and confirmation behavior.
- [x] Map Overview, Drive, Transfers, Sync, Backups, Sharing, Contacts, Mounts/Local Access, Account/Security and Preferences/Diagnostics to concrete controls/options/wizards.
- [x] Add no-silent-overwrite move workflow, structured ignore-filter builder, backup UTC/first-run controls, sharing permission controls and FUSE/WebDAV safe defaults.
- [ ] Validate responsive breakpoints and every menu/dialog at 100/125/150/200% font scale in standalone, Abyss overlay, SettingsFocus and Waffle after implementation approval.
- [ ] Confirm a safe host local-file/folder picker before exposing Browse; no such Cloud-specific picker is assumed from the current audit.
- [ ] Verify every dynamic remote chooser, button enabled rule and dropdown option against installed-version sanitized fixtures before any write action is enabled.

### Round-5 frontend/backend contract research
- [x] Audit Hadalis native JSON patterns (`inir-mpdd` request IDs/no-replay tests), QML stale-request handling (Lyrics), lifecycle generations/consumer leases (Equalizer/ResourceUsage) and Rust-default dispatch behavior.
- [x] Select dormant deferred `CloudStorageService.qml` as frontend state/mutation owner; page view must not directly own risky mutation Process lifetime.
- [x] Specify one-shot Rust `inir-mega request` with JSON stdin and exactly one bounded JSON stdout envelope; no raw-command API and no automatic Python fallback for mutations.
- [x] Specify request ID + connection generation + account fingerprint stale-response rejection and coalesced per-domain reads.
- [x] Specify serialized mutation phases, backend fresh preconditions, high-risk prepare/review digest/execute and authoritative post-action readback.
- [x] Specify no-replay crash/restart journal design and read-only recovery path; unknown writes disable further mutation until reconciled.
- [x] Map every visible control domain to typed backend operations and stable normalized models/errors.
- [x] Define fake-vendor, QML service, crash recovery, packaging and route contract tests before any real account test.
- [ ] Decide private crash-journal target identifiers/retention after privacy review; never persist secrets or raw vendor output.
- [ ] Measure and set operation deadlines/output caps/poll rates using fake and disposable installed-version fixtures.
- [ ] Validate each operation's authoritative reconciliation query against the owner's installed MEGAcmd version before enabling writes.

### Round-6 last-mile edge-case research
- [x] Prove standalone Settings is a separate QML process; require Rust/OS mutation lock in addition to per-process CloudStorageService serialization.
- [x] Audit MEGAcmd HOME/config/socket and server PATH startup identity; reject hidden no-HOME fallback and mixed backend epochs.
- [x] Audit dangerous inherited MEGAcmd environment overrides and define owned-child sanitization without blindly discarding proxy/UTF-8 user environment.
- [x] Verify `mega-version` is a post-Connect server/network operation, not static package detection.
- [x] Verify scriptable `mega-*` can request confirmation/string input from stdin; require null child stdin, non-interactive command paths and bounded unexpected-prompt failure.
- [x] Identify first-public-export copyright confirmation and specify explicit Hadalis terms review rather than hidden vendor prompt.
- [x] Add account/public-folder/signed-out session-kind model and privacy-safe account epoch requirements.
- [x] Require all opaque/64-bit handles, IDs and tags as JSON strings; strict UTF-8 identity with no lossy/normalized mutation keys.
- [x] Extend overlap safety across sync, backup, FUSE, download destinations and inbound-share recovery semantics.
- [x] Specify concurrent stdout/stderr draining, child reaping, suspend-aware deadlines and shell-crash helper/journal behavior.
- [x] Audit Hadalis clipboard history and persistent notifications; keep MEGA links/paths/account metadata out of automatic clipboard/toast/log flows.
- [x] Specify private journal permissions/atomic durability, stable-ID frontend selection and backend-epoch invalidation across upgrades.
- [ ] Validate the full round-6 fake-harness matrix before any live account/write implementation.
- [ ] Decide exact Linux lock/state paths and privacy-preserving cross-restart account identifier after implementation-time filesystem/permission tests.
- [ ] Capture installed MEGAcmd public-folder/account, unexpected-prompt, locale and package-upgrade fixtures on a disposable owner-approved environment.


### Round-7 final research freeze
- [x] Re-check current upstream MEGAcmd/SDK/Desktop source heads; no newer upstream source commit supersedes the pinned research snapshots.
- [x] Re-check current MEGAcmd release behavior: transfers always HTTPS; \`https\` is deprecated; remove any planned HTTPS toggle.
- [x] Account for MEGAcmd 2.6.0 lower-case \`http_proxy\`/\`https_proxy\` support without exposing proxy credentials in diagnostics.
- [x] Add capability-gated WebDAV streaming-cache controls for \`file_service_reclaim_*\`; document that threshold is not a hard cap.
- [x] Prove \`--col-separator\` emits raw unescaped values; freeze command-specific minimal-column parsers and fail-closed arbitrary path handling.
- [x] Freeze bounded-snapshot semantics; vendor \`--limit\` without offset is not pagination.
- [x] Freeze dedicated one-shot Rust \`inir-mega\`; no Python mutation fallback and no permanent Hadalis daemon for v1.
- [x] Re-audit current Hadalis Settings/native packaging paths and define exact implementation files/tests.
- [x] Freeze Tier A (read/ID-based), Tier B (installed/disposable-fixture gated), Tier C (withheld) scope.
- [x] Freeze fake vendor harness as first implementation milestone.
- [x] IMPLEMENTATION AUTHORIZED: Phase 0 substrate started; exact-SHA local qualification pending.
- [ ] LOCAL QUALIFICATION: capture the owner's installed MEGAcmd capability fixtures using sanitized/disposable data before enabling writes.
- [ ] Reopen research only when an upstream MEGAcmd/SDK/Desktop change materially affects a frozen capability.
