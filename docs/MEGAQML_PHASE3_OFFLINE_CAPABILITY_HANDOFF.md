# MegaQML Phase 3a — offline-denied feature gate handoff

**Status:** new `dev` source staged; exact-source Linux qualification pending.
This is a typed **policy preview**, not installed-version capability detection,
a MEGA session, or ten implemented features.

## Qualified baseline versus new implementation

* F1 synthetic/offscreen reference: `f7bf4d6eebbcd43344503f7cbaf717a4e64e9c66`;
  `docs/evidence/megaqml/phase2p-f7bf4d6eebbc-20261001T182658Z.md`
  recorded 40/40 PASS and eight independent race repeats. This evidence
  does **not** qualify any later UI or Phase 3a source.
* The maintainer explicitly reported the compact Cloud Storage UI
  **verified** after the `dev` visual revision. This is feedback on the
  observed presentation, **not** independent evidence that every Waffle
  or embedded mode passed the full separate pointer/scale checklist.
* Phase 3a adds the narrow `feature_gates_preview` typed Rust request
  and an independent strict JavaScript response parser. Neither is
  connected to an automatic poller or to real account data. Do not
  infer that a read-only feature is unlocked by this staging milestone.

## Offline schema (version 1)

The caller sends exactly:
`{"protocol":1,"request_id":"unique-id","operation":"feature_gates_preview","params":{}}`
with **no** `secret` field. All other params or any `secret`, including
empty, are rejected with fixed `FEATURE_GATE_INPUT_FORBIDDEN` and
`not_dispatched`; user input and secret canaries never enter the
normalized response.

The successful envelope echoes only the exact request ID and an
`offline_policy_preview` result. Flags are always:
`installed_version_qualified=false`, `connection_attempted=false`,
`connected=false`, `auth_qualified=false`,
`account_reads_enabled=false` and `writes_enabled=false`.
`vendor_execution=blocked_pending_disposable_qualification`.

Ten explicit domain keys: `overview`, `drive`, `transfers`, `sync`,
`backups`, `sharing`, `contacts`, `mounts`, `security`,
`preferences`. Each contains exactly `read=false`, `write=false`
and `reason=installed_version_unqualified`. A successful *policy*
envelope still provides **zero** capability evidence for installed
MEGAcmd. The JS parser fails closed on extra data, missing domains,
stale/wrong ID, malformed JSON, changing any flag to true, or claiming
vendor execution. It constructs its own empty/denied snapshot and
never copies raw payload fields into QML.

## Test and privilege boundary

The existing 40-row F1 Linux runner's composite Rust build/unit,
fake-PATH Rust boundary and JS protocol checks now include the new
strict preview. The fake PATH contains executable-looking vendor names
that create a marker **if run**; the test proves the preview does not
launch them. It injects fabricated password/account fields and
forged read/write state and requires fail-closed behavior and no
canary leakage. The newer source has not yet passed owner Linux.
Do not change the historic F1 40/40 source SHA in evidence.

No automatically generated reports should contain vendor output,
paths, email, credentials, tokens, screenshots or raw QML diagnostics.
`CloudStorageService` remains dormant and unchanged for this phase.
Do **not** enable `LIVE_AUTH_VENDOR_ENABLED`, add account reads,
auto-connect on navigation, start MEGAcmd server, or permit mutation.

## Owner-approval gates remaining

1. Re-run the full exact-source Linux matrix (40/40 and 8/8).
   A clean **temporary checkout** is required when the maintainer's
   normal `dev` worktree contains parallel Wull changes.
2. Verify standalone Material and Waffle and any actively used
   overlay/focus in the owner's actual desktop. Source consistency,
   compact UI feedback and fake-Quickshell PASS are separate evidence.
3. **Separately ask the owner for explicit consent** before invoking
   even ostensibly informational `mega-version`/`mega-*` on the
   installed vendor, since the scriptable clients may start
   `mega-cmd-server`. Use owner-approved disposable environment
   and sanitized version/help/response fixtures only. Do not use
   actual logged-in account data.
4. Only after the installed-version data, parser/argument roundtrip,
   no-background-start and cross-client ownership tests are qualified
   may future **read-only** domains be individually gated as
   available. Auth, writes, sync changes, sharing and data mutation
   require additional distinct owner approval and no-silent-overwrite
   reconciliation. A found binary is not a capability verdict.

**Packaging audit:** `native/scripts/install-runtime.sh`, Nix and
`inir-shell-git` enumerate `inir-mega`. The Arch non-VCS
`distro/arch/inir-shell/PKGBUILD` currently enumerates only the
older four Rust binaries. This is a **release parity gap to review
at the release gate**; do not silently modify the stable package
recipe or Git `stable` while live adapter qualification is pending.
