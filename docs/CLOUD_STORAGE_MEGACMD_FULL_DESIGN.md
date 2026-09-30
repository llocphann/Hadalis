# Hadalis Cloud Storage — detailed MEGAcmd → Rust → QML design

**Status: research/design specification only; no source implementation, no runtime or account tests.**  
Research date: 2026-09-30 (Asia/Ho_Chi_Minh). Hadalis reference: `llocphann/Hadalis@dev` inspected at `c8d86c6dd4b400533ac6794a7420a63f9dcce8f4`.  
Official MEGAcmd source examined: `meganz/MEGAcmd` `master` (observed head `6505327a5a7a0e94f26f611f83b024aeeb63582c`, 2026-08-28); published `UserGuide.md` labels its generated commands **MEGAcmd 2.6.0**. This is a *documentation baseline*, **not** a claim about installed binaries or future feature support. Command options and output MUST be negotiated against the installed `mega-version -l` / per-command `--help` before activation.

**Requested architecture revision:** where a backend is needed, prefer **Rust > Python** when the measured end-to-end workload benefits; use JSON as the QML boundary format, not as an alternative programming language. Hadalis already has `native/Cargo.toml` (Rust 2024, rust-version 1.95, `serde`/`serde_json`, thin LTO), so reuse its existing workspace and build/install practices. The earlier [feasibility snapshot](CLOUD_STORAGE_MEGACMD_RESEARCH.md) describes a *provisional Python bridge*; this document **supersedes that implementation choice**.

## 1. Product contract and explicit non-goals

The feature is **Settings → Features & Services → Cloud Storage**, initially with **MEGA (MEGAcmd)** as the only provider. Hadalis supplies a full integrated GUI for safely representable MEGAcmd capabilities—not a reimplementation of MEGA's sync engine, scheduler, file encryption, authentication, or a second desktop client. No background work starts simply because Hadalis launches.

MEGAcmd manages its own background `mega-cmd-server`, persistent account session, transfers, sync/backup schedules, FUSE and optional WebDAV/FTP servers. The official MEGA Desktop/MEGAsync GUI is a **different process and configuration owner**: public documentation reviewed does not guarantee an official control IPC between the two. Display "MEGAcmd account" and "MEGAcmd syncs", never silently imply that existing MEGA Desktop jobs are being controlled. User-requested direct MEGA Desktop management remains an independent research track needing a supported vendor API. Full MEGAcmd CLI command **coverage** does not mean every command should become an ordinary one-click button: account cancellation, master-key disclosure and unsafe secret arguments remain terminal/out-of-app or withheld until a secure supported interface is proven.

### Source confidence model

- **Verified in official source/docs:** 76 command documentation files in `contrib/docs/commands/` match `UserGuide.md` command summary; exact names/options/constraints noted below; FUSE and backups are documented beta features.
- **Verified in Hadalis source:** shared Settings registry, standalone/overlay/focus page presentations, existing lazy page host, present Rust workspace, present optional deferred service and JSON helper patterns. Existing app products/features must not be interrupted.
- **Inferred design, not verified live:** Rust subprocess timings, delimiters/parser stability, vendor interprocess reliability, installed-version availability, canonical local paths under actual Linux mount namespaces, desktop/CLI coexistence, actual QML responsiveness and account actions.

## 2. Information architecture: one QML page, ten task sections

Place **Cloud Storage** in **Features & Services** for every supported panel family (Abyss and Waffle included). The Settings page follows `ContentPage` + `SettingsTaskNavigator` + `SettingsCardSection` / `SettingsGroup`, Settings search/deep-link integration, responsive column layout, existing Material/Abyss design tokens and `ConfirmationService`. **No extra popup framework or separate Settings window.** Persist only the active *section* and innocuous display preferences.

| Section | Primary view | Explicit workflows / controls | Failure, empty and permission states |
| --- | --- | --- | --- |
| **Overview** | Backend found/version, CLI-owned account, storage quota, sync/transfer/backup summary and freshness | Opt-in connect; manual refresh; navigate to attention-required items | Missing optional package, server not started, logged out, offline, stale, parser unsupported, vendor blocked |
| **Drive** | Breadcrumb, folder list, root selector (`mega-mount`), details pane, search and free-space context | Upload, download, new folder, copy, move/rename, size, text/image preview; deliberate delete/restore checks; import link | Empty roots, no read permission, Unicode, duplicate name, enormous folder, stale path, unsupported version |
| **Transfers** | Active / queued / completed tabs, kind filters, progress/speed/tags and visibility of sync/backup provenance | Pause/resume/cancel selected tags, optional all with higher confirmation, global upload/download rate and connection limits | Tags can disappear, transfer may complete between click and action, quota/connection issues |
| **Sync folders** | Local↔remote mappings, distinct `RUN_STATE`, `STATUS`, errors and issue count | Create wizard, pause/enable, remove definition, root filters, default filters, issue detail | Must not imply `Disabled` equals paused cached state; conflict resolution may require manual desktop file action |
| **Backups** | Schedules, UTC next-run, retention, last-run state, history | Create schedule, edit period/count, inspect previous snapshots, abort current and remove definition | Running/complete/incomplete/aborted/miscarried/skipped are independent; server must be active |
| **Sharing** | Outbound public links vs contact ACL vs inbound shares | Create/revoke export, optional expiry/writable folder where supported, import link, share with contact and permission levels | Public-link/key exposure, account-tier limitations, key-verified contacts, existing export must be re-created to change |
| **Contacts** | Contacts, sent/pending/inbound invitations and verified/unverified badges | Invite/revoke, accept/deny/ignore request, inspect trust verification instructions | Verification is a security-sensitive ceremony, not equivalent to a cosmetic toggle |
| **Mounts & Local Access** | Separate FUSE / WebDAV / FTP cards (feature-gated beta/advanced) | List, safe local-only enable/disable, read-only mounts, limited config, view cache footprint guidance | FUSE absent on macOS/beta, cache disk-full, delayed writes, no FUSE streaming; public endpoint defaults forbidden |
| **Account & Security** | Current account/session identity (only nonsecret display), safe interactive-login handoff, session-list metadata | Explicit logout with full explanation, guarded session revocation, read-only profile attributes | Do not expose recovery key/session string/MFA or account cancellation through ordinary UI |
| **Preferences & Diagnostics** | Version/capabilities, network, bandwidth, cache, issue detail, last redacted operation | Safe read-only configuration, opt-in advanced modifications, structured copy/export sanitized logs | Never infer success from zero exit code alone; unknown parsing is visible unsupported state |

Section prioritization for initial implementation is *phasing only*: a complete design inventories all ten; implementation is authorized separately.

### Selected high-risk interaction details

**Drive**: never rely on CLI global working directory (`mega-cd`) shared by concurrent clients. Every read/write uses explicit remote paths or verified stable handles (`mega-ls --show-handles` / `mega-find`) and named local destination. Folder pagination is a Rust-side **bounded view over a potentially unbounded CLI result**, not an undocumented vendor remote pagination API. First test whether the installed CLI permits stable machine parsing of names with tabs/newlines; if not, forbid destructive batch operations on ambiguous listings. Text preview (`mega-cat`) must enforce a byte cap and file-type restriction; arbitrary remote file content is not trusted HTML/QML.

**Deletion and versions**: the official help exposes `mega-rm` and irreversible `mega-deleteversions`. It also exposes `mega-mount` roots including Rubbish, and `mega-ls --versions`, but does **not** substantiate a single general-purpose restore-from-trash/version-rollback CLI action in the reviewed docs. Design trash browsing and delete-confirmation now; **do not promise restore/empty-trash/version rollback** until the installed-version behavior and handle/path operation are established on disposable data. Always show which outcome a test proved.

**Public links and keys**: `mega-export` can disclose a full link/key; opening a share must show who will be able to access it. Expiry/password depend on account plan; password flags are unsafe to pass as subprocess argv. Treat writable folder links as high-risk receive points, not automatically equivalent to write-only file requests. Existing exports may have to be revoked/re-created to modify options.

**Backup**: on creation the vendor can make the first backup immediately, *even with a future schedule*. The vendor's cron-like period is six-field and documentation examples use **UTC**; provide timezone conversion and an explicit "first backup runs now" preview. Retention can delete older snapshots, except vendor safety handling of incomplete backups; show destructive storage implications.

**Mounts**: vendor FUSE is beta and says entire files download before opening, may defer uploads and uses a separate on-disk cache. WebDAV *can* stream and caches content; expose localhost-only as safe initial mode and never advertise public/remote binding without separate threat model and active firewall/TLS checks. FTP is separate and advanced-off by default. Do not show a single "streaming" claim for all access types.

## 3. Complete official command inventory and interface disposition

Derived from the official `UserGuide.md` summary / 76 command docs, **not** from an installed binary. Primary UI = first-class normal Settings workflow. Advanced/gated = only when documented feature probe, tests and owner choice permit it. External/withheld = never put secrets or extreme-risk operations in generic GUI. CLI-only means an equivalent GUI action may already exist without invoking the interactive-shell state command. Each row links to official documentation.

| MEGAcmd command | Official group | Proposed UI location | Exposure | Risk/guard |
| --- | --- | --- | --- | --- |
| [`signup`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/signup.md) | Account / Contacts | Security (external only) | External / withheld | Action-specific guard |
| [`confirm`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/confirm.md) | Account / Contacts | Security (external only) | External / withheld | Action-specific guard |
| [`invite`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/invite.md) | Account / Contacts | Contacts · Requests | Primary UI | Low/conditional |
| [`showpcr`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/showpcr.md) | Account / Contacts | Contacts · Pending | Primary UI | Low/conditional |
| [`ipc`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/ipc.md) | Account / Contacts | Contacts · Accept/deny | Primary UI | Low/conditional |
| [`users`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/users.md) | Account / Contacts | Contacts · Verify/view | Primary UI | Low/conditional |
| [`userattr`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/userattr.md) | Account / Contacts | Account · Profile (allowlist) | Advanced / gated | Low/conditional |
| [`passwd`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/passwd.md) | Account / Contacts | Security (external only) | External / withheld | Action-specific guard |
| [`masterkey`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/masterkey.md) | Account / Contacts | Recovery (external only) | External / withheld | Action-specific guard |
| [`login`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/login.md) | Login / Logout | Security · External interactive login | Security-gated | Low/conditional |
| [`logout`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/logout.md) | Login / Logout | Security · Explicit logout | Security-gated | Action-specific guard |
| [`whoami`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/whoami.md) | Login / Logout | Overview · Account | Primary UI | Low/conditional |
| [`session`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/session.md) | Login / Logout | Secret (never log/show) | External / withheld | Action-specific guard |
| [`killsession`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/killsession.md) | Login / Logout | Security · Revoke session | Advanced / gated | Action-specific guard |
| [`cd`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/cd.md) | Browse | Terminal-only navigation | Advanced / gated | Low/conditional |
| [`lcd`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/lcd.md) | Browse | Terminal-only navigation | Advanced / gated | Low/conditional |
| [`ls`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/ls.md) | Browse | Drive · Folder listing | Primary UI | Low/conditional |
| [`pwd`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/pwd.md) | Browse | Terminal-only navigation | Advanced / gated | Low/conditional |
| [`lpwd`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/lpwd.md) | Browse | Terminal-only navigation | Advanced / gated | Low/conditional |
| [`attr`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/attr.md) | Browse | Drive · Metadata (allowlist) | Advanced / gated | Low/conditional |
| [`du`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/du.md) | Browse | Drive · Space usage | Primary UI | Low/conditional |
| [`find`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/find.md) | Browse | Drive · Search | Primary UI | Low/conditional |
| [`mount`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/mount.md) | Browse | Drive · Root selector | Primary UI | Low/conditional |
| [`mkdir`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/mkdir.md) | Moving / Copying files | Drive · Create folder | Primary UI | Low/conditional |
| [`cp`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/cp.md) | Moving / Copying files | Drive · Copy | Primary UI | Low/conditional |
| [`put`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/put.md) | Moving / Copying files | Drive · Upload | Primary UI | Action-specific guard |
| [`get`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/get.md) | Moving / Copying files | Drive · Download | Primary UI | Action-specific guard |
| [`preview`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/preview.md) | Moving / Copying files | Drive · Image preview | Advanced / gated | Low/conditional |
| [`thumbnail`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/thumbnail.md) | Moving / Copying files | Drive · Thumbnail | Advanced / gated | Low/conditional |
| [`mv`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/mv.md) | Moving / Copying files | Drive · Move/rename | Primary UI | Low/conditional |
| [`rm`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/rm.md) | Moving / Copying files | Drive · Delete (gated) | Primary UI | Action-specific guard |
| [`transfers`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/transfers.md) | Moving / Copying files | Transfers · Queue | Primary UI | Low/conditional |
| [`speedlimit`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/speedlimit.md) | Moving / Copying files | Transfers · Limits | Primary UI | Low/conditional |
| [`sync`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/sync.md) | Moving / Copying files | Sync · Definitions | Primary UI | Action-specific guard |
| [`sync-issues`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/sync-issues.md) | Moving / Copying files | Sync · Conflicts | Primary UI | Low/conditional |
| [`sync-ignore`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/sync-ignore.md) | Moving / Copying files | Sync · Filters | Primary UI | Low/conditional |
| [`sync-config`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/sync-config.md) | Moving / Copying files | Sync · Delayed upload readout | Advanced / gated | Low/conditional |
| [`exclude`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/exclude.md) | Moving / Copying files | Sync · Legacy defaults | Advanced / gated | Low/conditional |
| [`backup`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/backup.md) | Moving / Copying files | Backups · Schedule/history | Primary UI | Action-specific guard |
| [`export`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/export.md) | Sharing (your own files, of course, without infringing any copyright) | Sharing · Public links | Primary UI | Action-specific guard |
| [`import`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/import.md) | Sharing (your own files, of course, without infringing any copyright) | Drive · Import link | Primary UI | Low/conditional |
| [`share`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/share.md) | Sharing (your own files, of course, without infringing any copyright) | Sharing · Contact ACL | Primary UI | Action-specific guard |
| [`webdav`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/webdav.md) | Sharing (your own files, of course, without infringing any copyright) | Local Access · WebDAV (beta) | Advanced / gated | Action-specific guard |
| [`fuse-add`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/fuse-add.md) | FUSE (mount your cloud folder to the local system) | Mounts · Add (beta) | Advanced / gated | Action-specific guard |
| [`fuse-remove`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/fuse-remove.md) | FUSE (mount your cloud folder to the local system) | Mounts · Remove (beta) | Advanced / gated | Low/conditional |
| [`fuse-enable`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/fuse-enable.md) | FUSE (mount your cloud folder to the local system) | Mounts · Enable (beta) | Advanced / gated | Low/conditional |
| [`fuse-disable`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/fuse-disable.md) | FUSE (mount your cloud folder to the local system) | Mounts · Disable (beta) | Advanced / gated | Low/conditional |
| [`fuse-show`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/fuse-show.md) | FUSE (mount your cloud folder to the local system) | Mounts · Status (beta) | Advanced / gated | Low/conditional |
| [`fuse-config`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/fuse-config.md) | FUSE (mount your cloud folder to the local system) | Mounts · Options (beta) | Advanced / gated | Low/conditional |
| [`autocomplete`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/autocomplete.md) | Misc. | Terminal-only shell | Advanced / gated | Low/conditional |
| [`cancel`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/cancel.md) | Misc. | Account closure (external only) | External / withheld | Action-specific guard |
| [`cat`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/cat.md) | Misc. | Drive · Small text preview | Advanced / gated | Low/conditional |
| [`clear`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/clear.md) | Misc. | Terminal-only shell | Advanced / gated | Low/conditional |
| [`codepage`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/codepage.md) | Misc. | Terminal-only shell | Advanced / gated | Low/conditional |
| [`configure`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/configure.md) | Misc. | Advanced · CLI settings | Advanced / gated | Low/conditional |
| [`confirmcancel`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/confirmcancel.md) | Misc. | Account closure (external only) | External / withheld | Action-specific guard |
| [`debug`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/debug.md) | Misc. | Diagnostics (external only) | External / withheld | Low/conditional |
| [`deleteversions`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/deleteversions.md) | Misc. | Drive · Versions (irreversible) | Advanced / gated | Action-specific guard |
| [`df`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/df.md) | Misc. | Overview · Storage | Primary UI | Low/conditional |
| [`errorcode`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/errorcode.md) | Misc. | Diagnostics · Vendor error | Advanced / gated | Low/conditional |
| [`exit`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/exit.md) | Misc. | Terminal/server lifecycle | Advanced / gated | Low/conditional |
| [`ftp`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/ftp.md) | Misc. | Local Access · FTP/FTPS (beta) | Advanced / gated | Action-specific guard |
| [`graphics`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/graphics.md) | Misc. | Advanced · Media metadata | Advanced / gated | Low/conditional |
| [`help`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/help.md) | Misc. | Diagnostics · CLI help | Advanced / gated | Low/conditional |
| [`https`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/https.md) | Misc. | Advanced · Transport display | Advanced / gated | Low/conditional |
| [`log`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/log.md) | Misc. | Diagnostics · Vendor log level | Advanced / gated | Low/conditional |
| [`mediainfo`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/mediainfo.md) | Misc. | Drive · Media metadata | Advanced / gated | Low/conditional |
| [`permissions`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/permissions.md) | Misc. | Advanced · New-file permissions | Advanced / gated | Low/conditional |
| [`proxy`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/proxy.md) | Misc. | Advanced · Proxy | Advanced / gated | Action-specific guard |
| [`psa`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/psa.md) | Misc. | Diagnostics · Public notice | Read-only | Low/conditional |
| [`quit`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/quit.md) | Misc. | Terminal/server lifecycle | Advanced / gated | Low/conditional |
| [`reload`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/reload.md) | Misc. | Diagnostics · Explicit refresh | Advanced / gated | Low/conditional |
| [`tree`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/tree.md) | Misc. | Drive · Tree view | Advanced / gated | Low/conditional |
| [`unicode`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/unicode.md) | Misc. | Terminal-only shell | Advanced / gated | Low/conditional |
| [`update`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/update.md) | Misc. | Advanced · Update (not Linux) | Advanced / gated | Low/conditional |
| [`version`](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/version.md) | Misc. | Overview · CLI detection | Read-only | Low/conditional |

**Coverage caveat:** This is a comprehensive mapping of the **documented 76-command baseline**, not evidence of complete functionality on a specific MEGAcmd installation. Additional command additions/deletions require version-probe updates and a fresh inventory. Some commands (`cd`, `lcd`, `clear`) are interactive-shell conveniences; implementing them as independent QML features would be misleading.

## 4. Detailed component architecture (planning only)

### 4.1 Process and ownership diagram

`Hadalis Settings QML` → `optional CloudStorage controller (load-on-demand)` → `native/inir-mega Rust CLI` ⇄ `documented mega-* scriptable clients` ⇄ `mega-cmd-server` ⇄ `MEGA service`.

- **Single accountable engine:** only official MEGAcmd controls actual sync, transfer/backup scheduling, FUSE and server lifetime. Hadalis is a client of the *existing* session and acts only when the user requests a permitted change.
- **One Rust binary:** proposed `native/inir-mega/` as an additional member of the **existing** `native/Cargo.toml` workspace, using existing workspace `serde`/`serde_json`/`clap`/`anyhow`. Prefer synchronous bounded `std::process::Command` at first; only introduce an async runtime/persistent daemon if representative benchmarks demonstrate need. Any daemon would be optional/demand-gated, never duplicate MEGA's sync engine.
- **One JSON boundary:** QML's `Quickshell.Io.Process` calls Rust with a **fixed operation enum + validated nonsecret arguments**. Rust launches vendor clients with argv arrays, no `sh -c`/`bash -c` or string interpolation. Use Rust side for output parsing, serialization, redaction, path checks and concurrency control.
- **Settings QML:** `modules/settings/CloudStorageConfig.qml`; optionally `services/deferred/MegaCmdService.qml` only if multiple consumers warrant it. Use existing widget/QML service patterns, do not add an unrelated global polling singleton or couple the feature to `automation/manager`.
- **Build/package:** new Cargo workspace member; confirm exact native build/install/test paths in `Makefile`, packaging, Nix lane, and `sdata/runtime-payload-dirs.txt` before implementation. A Rust source directory under `native/` alone does **not** guarantee installed executable distribution. Optional vendor MEGAcmd package remains external, never a mandatory dependency for starting the shell.

### 4.2 Rust operation model and JSON contract

Treat JSON as a versioned typed protocol, not human-table passthrough. Proposed request **operation names** (not executable shell commands):

| Domain | Read operations | Guarded write operations |
| --- | --- | --- |
| Capability/session | `probe`, `account.status`, `storage.summary` | `server.connect` (explicit), `account.logout` (separate confirmation) |
| Drive | `drive.roots`, `drive.list`, `drive.search`, `drive.size`, `drive.versions`, `drive.preview` | `drive.upload`, `drive.download`, `drive.mkdir`, `drive.copy`, `drive.move`, `drive.remove` (validated only), `drive.import` |
| Transfers | `transfers.summary`, `transfers.list`, `limits.get` | `transfers.pause/resume/cancel` by observed TAG; `limits.set` |
| Sync | `sync.list`, `sync.issues`, `sync.filters`, `sync.config` | `sync.create/pause/enable/remove`; `sync.filter.add/remove` with validated schema |
| Backups | `backup.list`, `backup.history` | `backup.create/update/abort/remove` |
| Sharing/contacts | `exports.list`, `shares.list`, `contacts.list`, `contacts.requests` | `exports.create/revoke`; `shares.grant/revoke`; `contacts.invite/respond` after guards |
| Advanced | `fuse.list`, `webdav.list`, `ftp.list`, `settings.read`, `diagnostics.last` | Allowlisted beta advanced options only after target-platform and security checks |

**Minimal request shape** (illustrative; exact fields must be fixture-validated):
`{"protocol":1,"request_id":"opaque-nonsecret-id","op":"sync.list","params":{}}`

**Minimal response shape**:
`{"protocol":1,"request_id":"opaque-nonsecret-id","ok":true,"observed_at":"ISO8601","source":"megacmd-cli","backend_version":"discovered","stale":false,"capabilities":{"sync":true},"data":{"syncs":[]},"error":null}`

Errors carry `code` (e.g., `DEPENDENCY_MISSING`, `SERVER_NOT_RUNNING`, `SESSION_MISSING`, `AUTH_REQUIRED`, `CLI_UNSUPPORTED`, `OUTPUT_UNRECOGNIZED`, `COMMAND_FAILED`, `COMMAND_TIMEOUT`, `SYNC_PATH_OVERLAP`, `ALREADY_RUNNING`, `CANCELLED`), a sanitized human message, stage, retriable flag, timestamp and a stable diagnostic reference; **never raw stderr containing secrets**. Store last nonsecret result in-memory while page remains alive; do not persist the cloud file tree, tokens, keys or arbitrary raw vendor output into Hadalis config.

Read completion is not the same as data validity. A *write* returns `accepted/pending/failed` plus vendor exit metadata; UI shows true success **only after a subsequent authoritative read confirms the requested MEGAcmd state**. Race example: transfer tag disappears between list and pause → "already completed or no longer found", not "paused."

### 4.3 Version/capability probing and parser plan

**No official JSON CLI contract was established in reviewed docs.** Available commands differ: `sync`, `sync-issues`, `transfers` and `fuse-show` have `--output-cols` and `--col-separator`; `ls -l` does not document the same schema. Avoid assuming all clients have CSV/JSON. Per-command capability negotiation uses installed `mega-version -l` / vendor `--help` in a bounded, redacted **explicitly connected** session, with one owned versioned parser fixture bundle. For remote nodes use handle-based verification where supported; even handles may be scoped/invalid after account/session switch.

- For tabular outputs, select explicit columns and an unusual delimiter; verify uniqueness/escaping/Unicode and fail closed if data itself contains the delimiter. Do not claim arbitrary filenames are safe until adversarial fixtures validate the parser.
- For variable prose and tree text, either use a **verified stable output form**, a separately assessed official MEGA SDK integration, or show a documented read-only limitation. Never issue delete/move/share actions based on an ambiguously parsed node.
- Debounce/cancel stale GUI reads; run at most one mutating vendor command at a time per MEGAcmd session. Read/write overlap should be prevented by Rust operation coordination or the page's single-flight action state. If multiple Hadalis processes may control one account, add an OS-backed per-user action lock and document behavior; it cannot protect against external CLI clients, so always reconcile.
- Bound stdout/stderr bytes, transferred-item count, command duration and retry rates; not every bounded subprocess call has a cancel-safe vendor-side effect (queued transfers may continue).

## 5. Authentication, filesystem, sharing and network safety

1. **No secrets in process arguments.** Vendor `login`, `import --password`, `export --password`, `passwd`, `proxy --password` and session-link operations have argument-sensitive interfaces. Environment variables and keyring storage do *not* make argv secret-safe. Phase 1 launches/opens an official interactive MEGAcmd session for login/MFA, then QML adopts the existing login. A native Qt/Rust in-page login must prove a supported vendor PTY/stdin mechanism with no echo, secure zeroization as practical, no core dumps, no persistent secret strings in QML/IPC or logs, and tested MFA failures *before shipping*. Current Hadalis `KeyringStorage.qml` uses `secret-tool` for another feature; do not silently reuse it to retain MEGA credentials.
2. **Never run `mega-session`, `mega-masterkey` or `mega-cancel` from ordinary page refresh/actions.** `mega-whoami -l` may contain session metadata—parse/redact before logging. Revoke (`killsession`) requires full scope and target confirmation. A non-`--keep-session` logout can remove cached session-related configuration; the UI must explain sync/backup implications in a two-step explicit confirmation. Never add "switch accounts" that automatically logs out without listing consequences.
3. **Path safety:** canonicalize local paths, inspect symlinks and mount boundaries, reject filesystem root and empty paths, require explicit selection for all destinations, detect same/nested local paths among MEGAcmd syncs and owned mounts. Detect concurrent **MEGA Desktop** processes and warn or deny new CLI sync creation when ownership/overlap cannot be reliably established; never attempt private Desktop config scraping to "prove" safety.
4. **Delete and shares:** enumerate affected nodes when verifiable; require explicit confirmation for recursive delete, wildcard, mass transfer cancel, version removal, global session kill, ACL owner-level share and public writable exports. Do not pass regex/wildcards in destructive jobs unless target identity and expansion are independently validated; prefer handles/paths exactly. Read-only view of an unparseable folder is safer than guessing affected nodes.
5. **Local access:** initial WebDAV localhost-only (no `--public`), no FTP public exposure or implicit TLS key handling. FUSE mount selection validates existing mountpoints, filesystem permissions, cache space, overlap with sync roots and delayed writes. Do not infer that a FUSE mount is "fully uploaded" because an app closed a file.
6. **Diagnostics:** separate `user-facing message`, `vendor error code`, `adapter stage` and `raw redacted debug record`. Copy/export only a reviewed allowlist of safe fields, with local-account email/path anonymization option; excluded: session IDs, recovery keys, full public links, password/MFA, credentials, arbitrary vendor stdout and home-directory private filenames by default. No automatic telemetry of MEGA content.

## 6. Performance and lifecycle budget

**Rust may reduce startup/serialization/parse cost versus Python, but vendor process launch, SDK IPC, network and cloud sync dominate many user-visible operations. No performance percentages are established.** Benchmark the whole pipeline before claiming Rust is materially faster; the workspace already uses thin release LTO.

- **Zero idle overhead target:** when no Cloud Storage UI or optional status widget is visible, Hadalis does not spawn vendor commands, start MEGAcmd, install timers or wake the background server merely to draw Settings navigation.
- **Explicit start:** detect presence/version without a command known to auto-start the vendor server; where detection itself would start the server, use filesystem/process discovery or defer until the user presses Connect. Never terminate a pre-existing vendor process.
- **On-demand batch strategy:** overview status pulls the cheapest subset of probes, lists fetch on tab entry, heavy versions/issues/history only on expansion. Use at most one in-flight read and one mutation slot with mutation taking precedence; last-read cache is explicitly timestamped and invalidated on account changes.
- **Tentative visible-page cadence only:** active transfers every 5–10 s, idle page every 30–60 s, manual and post-action immediate. No per-row subprocesses; fetch N items in a single bounded read where possible. Suspend polls while Settings hidden, laptop suspended, low-power mode or backend offline, then refresh on resume/return.
- **Races:** retain operation IDs and vendor transfer tags/IDs, discard stale responses by revision and session identity, apply backoff on errors, and distinguish "sync engine busy", "command timed out", "snapshot stale" and "true sync failure".
- **Measure:** cold/hot Rust CLI cost, spawned mega-client latency, 10/100/1000 nodes, 0/10/100 concurrent transfers, huge paths, no-session/offline failures, idle shell CPU/RSS/wakeups and actual power overhead. Specify acceptance budgets from measured baseline; do not insert invented milliseconds or gains in product claims.

## 7. Design-level acceptance matrix

| Scenario | Expected behavior |
| --- | --- |
| MEGAcmd absent | Beautiful installed/unsupported state; no shell block; optional setup instructions only |
| CLI present, server stopped | Dependency inspection does not accidentally launch server; explicit connect asks permission |
| Server pre-existing | Adopt, do not kill/replace; close Settings leaves sync/backup running |
| Signed out, MFA required | Existing-session check safe; interactive login guidance; never send secrets in argv |
| Account changes externally | Invalidate all cached handles, selected nodes, transfer tags and snapshots; display source transition |
| Overlap with MEGA Desktop or FUSE | Prevent or explicitly block unsafe sync creation; no two engines on same local subtree |
| Sync `Running/Synced` versus `Suspended`/`Disabled` | Separate chips: engine run state, data status, issue/error state |
| Sync conflicts | Show vendor issue ID/reason then verified detail; provide manual-resolution guidance; no blind overwrite |
| Backup server down/schedule skipped | Preserve vendor `SKIPPED`/`MISCARRIED` states; next-run shown UTC/local correctly |
| Transfer completed between refresh and click | Reconcile; no false "pause successful" |
| Large Unicode folder and unusual filename delimiters | Correct identity or fail-closed read-only fallback, never wrong-file move/delete |
| File/share delete, mass operation | Scope preview, cancellation/acknowledgment and authoritative post-action read |
| File link password, MFA or proxy password | Ordinary JSON/argv bridge refuses secret-bearing options until secure protocol validated |
| FUSE beta on unsupported platform | Capability-gated unavailable with vendor explanation; no launch attempt |
| WebDAV/FTP remote bind | Disabled by default and gated behind separate review; no accidental network-public service |
| Widget hidden, Settings closed, suspend/resume | No extra polls; external sync/backup persists; stale snapshots clearly marked |
| QML variants | Standalone, rail overlay and Focus; Abyss and Waffle; custom saved arrangements, search and deep links |
| Packaging | Rust binary available in installed Arch/source/Nix flows where supported; vendor MEGAcmd remains optional |

Tests to write **only after implementation authorization**: Rust synthetic parser fixtures per installed supported version (success/failure/truncation/locale/malicious strings), CLI argument-contract tests with a fake MEGAcmd binary (never hit actual cloud), JSON protocol backwards compatibility, cross-process action lock, version-feature matrices, QML registry/applicability/route/loader search assertions, package test, exact-SHA `bash scripts/validate-maintainer-local.sh`, then human visual/QML and segregated disposable-account E2E. Never test deletes, recursive sync, public exports, permanent version deletion or quota actions on the maintainer's actual data.

## 8. Phased delivery proposal (does NOT authorize code)

| Phase | Functional slice | Entry/exit gate |
| --- | --- | --- |
| **R0: research (this document)** | Full 76-command feature map; QML IA; Rust/JSON contract; risk model | Published report only; no runtime effects |
| **R1: read-only design validation** | Installed CLI capture and redacted parser fixtures; read-only capability tests; UX prototype/spec approval | Owner-machine versions known; no accidental start |
| **I1: safe foundation** | Optional Rust workspace CLI; QML page routing; Overview, read-only Drive/Sync/Transfers/Backups; redacted diagnostics | Contract tests plus exact-SHA local validator, zero idle overhead |
| **I2: owned core actions** | Transfer actions, sync controls, upload/download, folder operations, backup schedule, safe speed limits | Disposable-account tests, destructive guards and post-action observation |
| **I3: extended workflows** | Share/export/import, contact requests, verified issues and ignore filters, read-only file versions | Privacy/security review; plan-based feature gating |
| **I4: beta/advanced** | FUSE, local WebDAV, optional FTP, safe advanced config | Platform capabilities, disk/cache tests and local-network attack-surface review |
| **Separate track** | In-page secret entry, direct MEGA Desktop control, irreversible account operations | Only after an officially supported credential/control path and explicit new approval |

## 9. Remaining decisions and blockers — be explicit, not a false "fully ready"

- [x] Official **76 documented commands** mapped into QML feature domains and deliberate exclusions.
- [x] A full proposed interaction information architecture for **ten sections**, secure action taxonomy, JSON protocol and Rust integration with existing Hadalis native workspace.
- [x] Identified critical official caveats: no universal JSON CLI guarantee, sync run/status distinction, backup initial/immediate behavior, FUSE streaming limitation/beta support, password-bearing CLI argv exposure, existing export recreation, Linux's absent `mega-update`.
- [ ] Verify exact **installed** MEGAcmd version, command output/schema and supported features on the target Linux desktop; produce redacted fixtures for an offline/signed-out/active/test account.
- [ ] Resolve native secure login: confirm vendor-endorsed non-argv secret entry *before* adding QML password/MFA controls. Current safe design uses external interactive sign-in.
- [ ] Determine reliable overlap/detection with an independently running MEGA Desktop client on the target system; direct control remains unproven.
- [ ] Prove trash/versions *restore* using throwaway files or clearly leave those buttons unavailable. Do not assume unsupported commands.
- [ ] Measure end-to-end Rust-versus-Python and CLI subprocess costs before asserting a performance win; native Rust is the preferred **design direction** due existing workspace and potential runtime/memory benefits.
- [ ] Review 10-section UX and permission prompts on the actual three Settings presentations and both panel families.
- [ ] Obtain **explicit** authorization before any QML/Rust/packaging/runtime edits.

### Official primary references

- Command taxonomy: https://github.com/meganz/MEGAcmd/blob/master/UserGuide.md
- Auto-generated command help generator: https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/generate_command_docs.py
- Sync states: https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/sync.md
- Sync issues/ignore: https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/sync-issues.md and https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/sync-ignore.md
- Backup semantics: https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/backup.md
- FUSE beta/caching: https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/FUSE.md
- WebDAV/FTP: https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/webdav.md and https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/ftp.md
- Secure-login limitation: https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/login.md
- Hadalis settings/natives: `modules/settings/SettingsPageRegistryData.qml`, `modules/settings/SettingsPageRegistry.qml`, `modules/settings/SettingsPageHost.qml`, `native/Cargo.toml` and `AGENTS.md` in this repository.
