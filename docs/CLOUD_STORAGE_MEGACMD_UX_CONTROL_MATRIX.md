# Cloud Storage — Detailed control, option and wizard matrix (research round 4)

**Design proposal only; all controls are unimplemented.** Hadalis `dev` reference `ba1f6cda9b30f787777fb7d333fe90fcbe039ad8`. [Read the component/layout/keyboard policy](CLOUD_STORAGE_MEGACMD_UX_COMPONENTS.md), [full feature design](CLOUD_STORAGE_MEGACMD_FULL_DESIGN.md), [vendor source safety findings](CLOUD_STORAGE_MEGACMD_SOURCE_AUDIT.md) and [cross-client SDK constraints](CLOUD_STORAGE_MEGACMD_PROTOCOL_DECISIONS.md). Every enabled mutation requires installed-version capability probing and unique validated target identity. An unverified button must show disabled + reason, never a speculative CLI fallback.

**Gate abbreviations:** D = binary present/explicit owner Connect; A = vendor reachable/signed in; V = installed-version syntax/output verified; I = unique item/path/permissions and local/remote sync ownership checked; C = source/destination and consequences reviewed/confirmed. A task's gate is **minimum**; security restrictions from previous source audit still apply.

## Global header and compact navigation

| UI | Exact behavior | Do not do |
| --- | --- | --- |
| `Connect to MEGAcmd` primary | Deliberate consent: "May start the MEGAcmd background service. Closing Settings won't stop syncing"; single dispatch, spinner, then observed server/session read | No vendor client call before opt-in; binary-path detection is static |
| `Refresh` secondary | Read active section and necessary summary; last successful per-section timestamp and spinner | Never interpret failed read as zero work/all synced |
| Account/status summary | Nonsecret email, dependency/version only when safely observed; chips Installed/Disconnected/Signed out/Ready/Offline/Stale | No full `whoami -l` or `mega-session` in normal dashboard |
| Area/Section | Five group buttons on wide host; compact area combo; 1–3 child segmented choices or child combo | Do not show a 10-pill toolbar or create 10 separate Settings pages |
| `⋮` header | Non-destructive: help, capabilities, diagnostics navigation | No global "Stop all", "Logout" or secret exposure as one-click menu item |

## 1. Overview

| Widget | Kind / choices | Enabled or disabled/feedback |
| --- | --- | --- |
| Quota card | Usage bar + "X used / Y total" + per-root details | A + V (`mega-df`); unknown denominator = N/A, never divide by zero |
| MEGAcmd health | Server, authentication, issue summary, last contact | Independent source/time per metric; no one misleading green master badge |
| `Connect` / `Sign in via official terminal` | Primary connect, external interactive-login help after terminal workflow validated | Terminal route must not put password/MFA in argv, QML JSON or logs |
| `View issues` | Link to `sync` issues card | Only if observed issues count is trusted |
| `Dependency help` | Expandable explanatory card | No silent optional package installation |

## 2. Drive

| Widget | Type and exact values | Safety contract |
| --- | --- | --- |
| Root selector | Dropdown Cloud Drive / Rubbish / incoming shares / observed roots | Based on tested `mega-mount`; don't assume permissions or current working directory |
| Breadcrumb | Clickable ancestors with middle overflow | Explicit full remote paths/verified handles; no shared interactive `mega-cd` state |
| Search field | Query + Search button; filters All / Files / Folders; optional advanced modified-time/size controls | `mega-find` supports filters; cap actual vendor output, do not advertise backend pagination |
| Sort | Dropdown Name ↑/↓, Size, Date, Type; View segmented List/Grid | Sort only a *complete bounded observed dataset*; "showing N only" if truncated |
| `Upload files / folder` | Primary; local chooser (only if supported) + explicit remote destination review | A+V+I+C; source picker existence unverified in current Hadalis; `mega-put -q --print-tag-at-start` available in docs but must test version/parser |
| `Download` | Selected row/menu; explicit local target and conflict policy | `mega-get` may add " (NUM)" on differing existing file; folder merge `-m` is separate reviewed option |
| `New folder` | Name field, path breadcrumb and Create button | Block unsupported Unicode/quote roundtrip, collision or ambiguous output |
| Single row | Click: Open folder/Details; trailing icon `⋮`: Download, Copy safe identifier, then capability-gated Move/Rename/Delete | No immediate delete via row click/Delete key or unsafe unvalidated user filenames |
| Multi-select | Checkboxes, count chip, chosen rows list and action bar | "Select all" = *loaded visible results*, never all unknown remote entries |
| Empty/error | Distinct Empty folder/No search results/Not loaded/Unsupported parser/Permission denied | No fake green "empty account" after error |

**Move/Rename wizard:** (1) identify one source unambiguously, (2) choose destination **folder** with account/breadcrumb, (3) optional rename, (4) recheck destination collision, (5) review exact paths and explicit Apply, (6) post-action authoritative source+destination check. **Existing destination file = BLOCK by default**: upstream `mega-mv` can remove a pre-existing target file in its multi-step implementation. If movement succeeds but rename fails, show `Partial or outcome unknown`, never automatically retry/delete cleanup. [Vendor implementation](https://github.com/meganz/MEGAcmd/blob/6505327a5a7a0e94f26f611f83b024aeeb63582c/src/megacmdexecuter.cpp#L4796-L4910).

**Rubbish:** list is a separate root. A future "Move from Rubbish to chosen folder" is *only a disposable-test hypothesis*; there is no verified one-click original-path restore through CLI. "Restore version" requires a separately approved SDK route. Permanent delete/version-history removal remains off until verified and specially confirmed.

## 3. Transfers

| Control | Values / action | Guard and subtlety |
| --- | --- | --- |
| State tabs | Active / Completed | `--show-completed` and `--only-completed` have precise vendor meaning; verify actual installed fixture |
| Kind filters | All / Uploads / Downloads / Sync / Backup | Only upload/download/vendor `--show-syncs` flags are documented; adapter may classify "Backup" from rows, not invent a flag |
| Display limit | 10 / 25 / 50 / 100 selector and "Results limited" note | Vendor defaults to first 10; `--limit=N` available, not infinite server pagination |
| Per-row `Pause`/`Resume` | One **contextual** button plus `⋮` | Observed transfer TAG must still exist; distinguish upload/download/sync/backup provenance |
| `Cancel` | Opens confirmation with explicit transfer name/tag and type | Timed-out Rust helper does not prove vendor transfer was cancelled |
| Bulk action | Scoped "Pause selected/all uploads" / "Cancel N" behind explicit menu + review | Never label row action "All" or share same tiny hit area |
| Speed limits | Separate Upload and Download: Unlimited or numeric + B/s/KiB/s/MiB/s/GiB/s, optional slider, **Apply** | `mega-speedlimit` 0 means unlimited; no per-drag command writes |
| Max connections | Advanced spinboxes upload/download | Validate permissible range on installed CLI |
| Row metrics | Progress/ETA only if actual vendor observation provides it | No fabricated smoothed percentage/long-term history |

## 4. Sync Folders

**Row:** Local → remote, **three separate** `RUN_STATE`, `STATUS`, `ERROR/issue count` chips; trailing `⋮`: View issues; Pause/Enable; Edit filters; Remove definition. `Running` ≠ `Synced`. Pausing with vendor `-p` and enabling `-e` operate the sync definition; `Disabled` in upstream help may restart like a freshly configured sync. [Official state definitions](https://github.com/meganz/MEGAcmd/blob/6505327a5a7a0e94f26f611f83b024aeeb63582c/contrib/docs/commands/sync.md).

**Create sync 5-step form:** Local folder (validate canonical path/nested aliases/mount/symlinks) → Cloud folder (verified handle, permissions, remote overlap) → Optional exclusion preview → Safety review (bidirectional deletion/conflict risks, MEGA Desktop partial/unknown ownership) → Create, then independently observe exact mapping/ID/state. Actions Back/Next/Cancel preserve draft; revalidate before final dispatch. Unknown external ownership is visible, not "Clear".

**Ignore filter builder**, not a raw-string-only textbox:

| Field | Control | Options |
| --- | --- | --- |
| Rule | Segmented | Exclude / Include |
| Match target | Combo | All / Files / Directories / Symlinks |
| Scope | Combo | All descendant names (default) / Root only / Relative path |
| Syntax | Combo | Glob / POSIX extended regex |
| Case sensitivity | Switch | Case-sensitive / insensitive if installed vendor syntax verified |
| Pattern | Labeled input | Inline generated compact vendor-filter preview; locally validate syntax |
| Action | Add/Remove reviewed filter | Vendor `sync-ignore` controls root-level filters only; DEFAULT applies to **future new syncs**, not existing ones |

Removal confirmation **must say**: "Remove synchronization definition; existing local/cloud files are not deleted by this command" (vendor-documented) and that state will be reobserved. Do not use generic "Delete folder". Issue details use vendor IDs, unknown output remains "Issues unavailable", not zero.

## 5. Backups

**Row:** source/destination, next run UTC+local, retention, last state and menu View history/Edit/Abort ongoing/Remove schedule. Preserve `ONGOING/INCOMPLETE/ABORTED/MISCARRIED/SKIPPED` rather than merging all into failed.

**Create/edit form:** Source chooser → Cloud target → Schedule mode `Interval / Advanced (six-field cron)`, with safe generated Daily/Weekly/Monthly presets only after installed validator → Retention `ConfigSpinBox` with explanatory warning → Summary & `Create backup`. Show both UTC-origin vendor schedule and user-local preview; no promise arbitrary DST behavior. **The first backup can start immediately** regardless of future schedule, show this before final Create. Reducing retention can remove older snapshots—require current/new comparison. Removing schedule via documented `backup -d` does **not** delete generated backup folders; show that precisely. [Vendor backup reference](https://github.com/meganz/MEGAcmd/blob/6505327a5a7a0e94f26f611f83b024aeeb63582c/contrib/docs/commands/backup.md).

## 6. Sharing

**Two child content tabs:** Public links and Shared with contacts. Public link rows display active/expiry only, **not** secret key fragment; `Copy link` requires explicit click. `Create link` review:
- Default ordinary read link.
- Expiry and password rows visibly disabled if account tier/version not supported; password entry is **withheld** while only unsafe argv exists.
- Writable folder link under Advanced with clear **read AND write** exposure warning; not equivalent to a write-only file request.
- Existing export edit is NOT a simple dropdown change: vendor requires revoke and re-export; show old link invalidation before an explicitly approved rotate/recreate flow.

Contact share card: target folder chooser + verified contact selection + access dropdown **Read (0), Read & write (1), Full (2)**; **Owner (3)** only behind gated advanced review. `Share` confirmation names folder, contact and level; revoke names them too. Contact verification is a distinct security process and cannot be represented by a decorative toggle. [Official sharing](https://github.com/meganz/MEGAcmd/blob/6505327a5a7a0e94f26f611f83b024aeeb63582c/contrib/docs/commands/share.md), [link behavior](https://github.com/meganz/MEGAcmd/blob/6505327a5a7a0e94f26f611f83b024aeeb63582c/contrib/docs/commands/export.md).

## 7. Contacts

Three result cards: Contacts, Incoming requests, Outgoing requests. Bounded client search, rows show email/verified or unverified text, and only actions valid for current observed request. Incoming `Accept` and `Decline` are labeled, spatially separated; `Ignore` only if official vendor semantics verified. "Verified" is a guided identity-check workflow, never a switch. A dynamic contact selector should be a searchable dialog displaying full email and verification, not a dropdown filled with potentially thousands of entries.

## 8. Mounts & Local Access

FUSE `Add mount` wizard default override **read-only and initially disabled** (`--read-only --disabled` supported by vendor documentation; installed test required), even though CLI defaults writable and immediately enabled. Fields: display name, local mountpoint chooser, remote root, persistence (Persistent/Transient), read-only behavior, cache-space and pending-upload warning. The Edit screen puts writable permission behind explicit consequences. FUSE beta and **no direct streaming**: full file must download into cache first; a closed local file may still be uploading.

WebDAV form: remote root, port (vendor default when verified), explicit `Start local WebDAV`; `Public access` remains **locked off** in first phase. Multiple served roots share **first server parameters**: port/TLS edits warn they require stopping all roots, never pretend changes affect just one row. WebDAV can stream and caches to disk; FUSE cannot stream. FTP/FTPS remain advanced gated with passive-port/TLS implications and no public bind until separate security review. [FUSE](https://github.com/meganz/MEGAcmd/blob/6505327a5a7a0e94f26f611f83b024aeeb63582c/contrib/docs/commands/fuse-add.md), [WebDAV](https://github.com/meganz/MEGAcmd/blob/6505327a5a7a0e94f26f611f83b024aeeb63582c/contrib/docs/commands/webdav.md), [FTP](https://github.com/meganz/MEGAcmd/blob/6505327a5a7a0e94f26f611f83b024aeeb63582c/contrib/docs/commands/ftp.md).

## 9. Account & Security

Account identity/status is **safe nonsecret summary**. Sign-in opens official MEGAcmd interactive terminal with no QML password field pending independent PTY security work; noninteractive vendor login requires secret-bearing arguments. Session list is an explicit advanced read with sanitized fields only; no `mega-session` in normal dashboard. Per-session revoke uses explicit scoped confirmation; revoke-other-sessions enumerates count where safely known. Logout dialog explains potential local cache/sync/backup configuration removal; never a quick toolbar toggle. Master-key display/account cancellation are **withheld** from ordinary page UI, not hidden behind a seductive one-click "Advanced" menu.

## 10. Preferences & Diagnostics

Optional `Auto-refresh while visible` (if future measured/approved), `Normal / Reduced activity` preference if benchmark justifies; hidden page always **stops Hadalis polling** regardless. Redirect bandwidth editor to Transfers instead of duplicate conflicting settings. Cap parser/version support detail table to on-demand expandable card. `Recheck capabilities` is a bounded read only **after Connect**. Diagnostics toolbar: `Preview sanitized data` → optional anonymize personal paths/email → `Copy` or `Export` only after the user reviews included fields. Full vendor stdout/stderr, password/MFA/session IDs, public-link fragments and recovery keys never entered in generic export. No automatic report upload.

## Status chips, dropdown stability and acceptance

| Area | Exact labels | Rule |
| --- | --- | --- |
| Server | Not installed / Disconnected / Connecting / Signed out / Ready / Offline / Unresponsive / Stale | Reconnect/recheck is read-only unless user explicitly Connects |
| Sync run | Pending / Loading / Running / Suspended / Disabled | Orthogonal to status |
| Sync data | Unknown / Synced / Pending / Syncing / Processing | "No issues" only after successful separate issue read |
| Backup | Ongoing / Complete / Incomplete / Aborted / Miscarried / Skipped | Source/vendor status + timestamp |
| Transfer | Active / Paused / Completed / Failed / TAG unavailable | Manual vs Sync vs Backup provenance separately |
| Mounts | Disabled / Enabled / Read-only / Writable / Beta / Unsupported | "Writable" is permission, not "Enabled" |

Each status chip includes word+icon, theme color redundant, last-observed time and source (MEGAcmd vs best-effort Desktop presence). When external account changes, close dynamic menus, invalidate remote handles and transfer TAGs, preserve only harmless draft fields and display "Account changed: reselect destination". Vendor refresh must **not** silently reset combobox to first value.

**Proposed acceptance cases (future implementation only):** 300-character/Vietnamese/emoji path; zero/unknown quota; 200% typography; insufficient popup space; keyboard Tab/Enter/Escape; selected row removed while menu visible; 1000+ items bounded without fake server paging; popup open during new vendor snapshot; mobile-like narrow Settings overlay; suspended vs disabled sync; backup first-run warning; existing destination file collision; share permission escalation; unknown server status; externally switched account. These are *test specifications*, not passed tests.
