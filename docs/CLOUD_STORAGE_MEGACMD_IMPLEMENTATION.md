# Cloud Storage / MEGAcmd — implementation design delta

Status: implementation authorized on `dev`. This document records the delta from the round-7 desk-research freeze for the active implementation.

## 1. Binding architecture

Hadalis uses only official MEGAcmd scriptable clients and the existing `mega-cmd-server`. No MEGA SDK is added. The frontend boundary remains:

`CloudStorageConfig.qml` → deferred `CloudStorageService.qml` → one-shot Rust `inir-mega request` → MEGAcmd.

The Rust protocol is typed JSON over stdin/stdout. Secrets are accepted only in the request body on stdin and must never be copied to argv, config, journal, diagnostics, checkpoints, notifications, or normalized responses. There is no Python mutation fallback.

## 2. Authentication delta

The active task explicitly requires email/password and 2FA inside Quickshell, superseding the earlier Tier-C decision to withhold native login.

This does not permit insecure `mega-login EMAIL PASSWORD` argv. Authentication is a dedicated PTY dialogue owned by `inir-mega`:

1. QML collects email/password in masked controls.
2. `CloudStorageService` sends one typed request to `inir-mega` over stdin.
3. Rust starts the interactive `mega-cmd` shell with no account secret in argv, disables PTY echo and sends only a strictly validated `login <email>` command inside the private PTY.
4. Rust recognizes only fixture-qualified password/MFA/success/failure prompts.
5. Password and MFA are written only to the PTY after the corresponding known prompt.
6. Unknown prompts, timeout, EOF, output-cap, backend epoch change, or parser ambiguity fail closed.
7. The Rust response reports only normalized state such as `mfa_required`, `vendor_reported_authenticated`, or a safe error. It never echoes email/password/MFA.
8. Credentials are not persisted by Hadalis. Vendor session persistence remains MEGAcmd-owned.

Before live vendor execution is enabled, the production-shaped fake vendor harness must prove password and MFA never appear in argv/stdout/stderr/result data, that unexpected prompts cannot cause secret submission, and that timeout/output growth is bounded.

### 2.1 One-shot MFA handshake

`inir-mega` does not keep a credential-bearing vendor process alive between JSON requests. `auth_begin` accepts email/password and an optional `mfa_code`. A first submit may return `mfa_required`; the future QML service may retain the password only in its transient masked draft state long enough for the user to enter the MFA code, then resubmit the same typed operation. Rust starts a fresh private PTY for that second attempt.

This avoids a hidden long-lived auth daemon, cross-request secret files, and replay tokens. It also means a separate `auth_mfa` request is not a valid protocol shape because there is no persistent PTY session to continue. The scriptable `mega-login` client remains forbidden for in-page authentication because its account login syntax would place password/auth-code material in argv.

Live `mega-cmd` authentication remains compile-time fail-closed until the exact installed MEGAcmd prompt/capability behavior is qualified on an explicitly permitted disposable account and an authoritative post-login session readback is defined. Fake PTY qualification alone does not flip that gate.

## 3. Phase ordering

Phase 0 establishes the workspace member, typed request envelope, fail-closed auth state machine, fake-vendor fixtures, and secret-leak contract tests. Real vendor dispatch remains disabled.

Phase 1 adds bounded process/PTY transport, environment sanitization, capability detection, static pre-connect detection, cross-process mutation lock, and private journal primitives. Fake vendor acceptance is mandatory.

Phase 2 adds deferred QML service and the Settings page for ii/Abyss/Waffle, including the email/password/MFA UI. Account/data mutations remain capability-gated.

Phase 3 implements the read-mostly portions of all ten functional groups, then ID-based Tier-A controls. Tier-B account/data operations are enabled only after exact installed-version disposable fixtures and authoritative reconciliation tests.

## 4. Ten-group coverage target

The page retains Overview, Drive, Transfers, Sync, Backups, Sharing, Contacts, Mounts/Local Access, Account/Security, and Preferences/Diagnostics. A group may initially be read-only or visibly capability-gated; unsupported controls show a reason rather than falling back to raw commands.

## 5. Acceptance

A source milestone is not a runtime PASS. Local worker jobs are SHA-pinned and synthetic until an explicitly permitted disposable MEGA environment exists. GitHub Actions are supplemental only.
