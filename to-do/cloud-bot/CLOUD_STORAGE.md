# Cloud Storage — MEGAcmd ↔ Rust ↔ QML research

> **Research round 3:** [Protocol, SDK feasibility, Desktop IPC and data-loss decisions](../../docs/CLOUD_STORAGE_MEGACMD_PROTOCOL_DECISIONS.md) refines both the [full design](../../docs/CLOUD_STORAGE_MEGACMD_FULL_DESIGN.md) and [source audit](../../docs/CLOUD_STORAGE_MEGACMD_SOURCE_AUDIT.md). Remote and local sync overlap **both matter**; ordinary CLI-based Drive mutations are not automatically safe.

> **Research round 2:** [Source-level audit and blocking acceptance gates](../../docs/CLOUD_STORAGE_MEGACMD_SOURCE_AUDIT.md) supersedes earlier optimistic assumptions about generic CLI argv, column parsing and pre-connect read-only probes. The Rust bridge is still the preferred direction, but capability-gated Drive mutations are mandatory.

**Status: DESIGN RESEARCH ONLY; no QML, Rust, script, packaging or account actions authorized.**

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
