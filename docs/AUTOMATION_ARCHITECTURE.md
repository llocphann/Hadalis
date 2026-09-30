# Automation isolation and recovery

The 2026-09-30 audit found three architectural faults in dev: a DOM toolbar
baseline was tied to the selected Desktop chat, one transport owner stopped
other profiles, and the worker executed again after an unpublished result.
Polling exhaustion also disabled observation permanently; timeout capture
was clipped only after accumulating all output, and children/workspaces could
outlive failed jobs. Quickshell was already a separate process, but the bridge
service required Desktop and could therefore disappear with its dependency.

## Target contract

- Each profile owns a project/conversation and a durable user message ID.
  Read completion by that identity through Desktop's authenticated service,
  independent of navigation, composer, selected project, or shell frontend.
  A capability-checked Desktop adapter fails closed on unsupported builds.
  It never extracts or persists authentication tokens.
- Persist submission intent and mark dispatch **before** contacting Desktop.
  Reconcile ambiguous delivery against the exact message ID. Never resend an
  ambiguous prompt. Keep completion receipt/checkpoint before continuation.
- Schedule profiles independently with bounded transport concurrency. Waiting
  on a response/job does not hold a global lease. Serialize only operations on
  the same conversation, deployment target, or Git publication.
- Retain JSON config/status compatibility. A private, fsynced transaction
  journal commits config/state together. Migrate legacy pending baselines by
  evidence; an unidentified old chat cannot be guessed or silently discarded.
- A bounded worker pool uses private durable job/action receipts. Persist
  results before publishing; publish retries never repeat execution. A crash
  between recording intent and spawning an arbitrary external command is
  inherently ambiguous: report `indeterminate`, terminate identified orphans,
  and require reconciliation rather than claim impossible exactly-once effects.
- Use isolated SHA-pinned workspaces, bounded pipe draining, process-group
  cancellation, resource ceilings, explicit shared-resource leases and cleanup.
  Existing jobs/results remain readable and consumed results are never rerun.
- Generic objectives use continuation, WAIT_RESULT and durable checkpoints.
  Cloud ChatGPT reasons; workers gather bounded evidence and execute explicit
  actions. Debug conclusions must cite evidence IDs, SHA, time and command.
  Raw machine observations stay private; Git receives only allowlisted summary
  metadata/digests, never raw journals, screenshots, config or credentials.
- Privilege is a typed allowlist broker using sudo's existing credential cache
  or an interactive system authentication agent. No password setting/file/argv.
  Record purpose and outcome locally; elevate only the specific command.
- Backend and worker remain independent of Quickshell and Desktop lifecycle.
  Risky shell deployment requires staging, validation and a known-good rollback
  receipt/watchdog; a failed shell does not remove diagnostics or recovery.

## Acceptance and evidence

Phases: durable storage; independent transport/concurrent scheduler; worker
receipts/pool and diagnostics; privilege/deployment recovery; frontend migration
and live acceptance. Run focused behavior tests each phase and the canonical
maintainer validator on published milestones. Label Desktop/native evidence
separately. Full validator failures must be retained with exact SHA; no global
PASS is inferred from focused tests or previous runs.
