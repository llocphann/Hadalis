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
3. Rust starts the vendor login client with nonsecret argv only and a private PTY.
4. Rust recognizes only fixture-qualified password/MFA/success/failure prompts.
5. Password and MFA are written only to the PTY after the corresponding known prompt.
6. Unknown prompts, timeout, EOF, output-cap, backend epoch change, or parser ambiguity fail closed.
7. The Rust response reports only normalized state such as `mfa_required`, `authenticated`, or a safe error. It never echoes email/password/MFA.
8. Credentials are not persisted by Hadalis. Vendor session persistence remains MEGAcmd-owned.

Before vendor execution is enabled, the fake vendor harness must prove password and MFA never appear in argv/stdout/stderr/result data and that unexpected prompts cannot cause secret submission.

## 3. Phase ordering

Phase 0 establishes the workspace member, typed request envelope, fail-closed auth state machine, fake-vendor fixtures, and secret-leak contract tests. Real vendor dispatch remains disabled.

Phase 1 adds bounded process/PTY transport, environment sanitization, capability detection, static pre-connect detection, cross-process mutation lock, and private journal primitives. Fake vendor acceptance is mandatory.

Phase 2 adds deferred QML service and the Settings page for ii/Abyss/Waffle, including the email/password/MFA UI. Account/data mutations remain capability-gated.

Phase 3 implements the read-mostly portions of all ten functional groups, then ID-based Tier-A controls. Tier-B account/data operations are enabled only after exact installed-version disposable fixtures and authoritative reconciliation tests.

## 4. Ten-group coverage target

The page retains Overview, Drive, Transfers, Sync, Backups, Sharing, Contacts, Mounts/Local Access, Account/Security, and Preferences/Diagnostics. A group may initially be read-only or visibly capability-gated; unsupported controls show a reason rather than falling back to raw commands.

## 5. Acceptance

A source milestone is not a runtime PASS. Local worker jobs are SHA-pinned and synthetic until an explicitly permitted disposable MEGA environment exists. GitHub Actions are supplemental only.
