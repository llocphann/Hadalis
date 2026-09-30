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

## Implemented acceptance, 2026-10-01

| Contract | Verification |
| --- | --- |
| Independent managed chats and simultaneous profiles | Two actual Desktop conversations had overlapping server streams while an unrelated chat remained selected. Both finished after scheduler restart, with distinct stable message IDs and one prompt each. The opt-in native test requires overlap, not just eventual completion. |
| Quickshell independence and frontend compatibility | The actual Settings component loaded from repository and installed copies; confirmed removal archived its pending receipt while retaining the other profile. Killing the private Quickshell fixture left scheduler, worker and broker PIDs unchanged. Reloading the installed user shell also left all three backend PIDs unchanged. |
| Durable recovery without replay | Storage fault injection, lost submission acknowledgements, persisted completion before scheduler crash, server-confirmed failed generation, interrupted worker actions and publication failures are covered by behavior tests. Superseding a managed turn with another user message preserves its receipt and isolates that profile instead of reattaching the wrong stream. |
| Bounded workers and cleanup | Actual subprocess tests cover parallel jobs, shared-resource contention, cancellation, timeout, output limits, inherited pipes, orphan process groups and workspace cleanup. Publication retry consumes the saved result and never executes its actions again. Git observation contention returns without occupying waiting transport slots. |
| Generic evidence-driven workflows | WAIT_RESULT can consume private receipts during publication outages. Continuations receive safe evidence summaries; diagnoses must cite observed evidence IDs. Diagnostics operate without a Quickshell process. Raw journals, screenshots, configuration and command output stay private. |
| Safe legacy migration | Version-1 profiles/state and unknown receipts are retained. Automatic polling-error pauses recover only when a later explicit Start/Resume is evidenced; explicit Pause/Stop wins. Malformed profiles are quarantined without preventing valid profiles from progressing. |

Focused regressions passed. The canonical validator at
`e3f91d57bd2f574603adbc4dbbcf6110789f331a` reported **241 PASS / 32 FAIL /
2 SKIP**. Its 32 failures match the prior `bea23fc62` validation; none are
Automation regressions. Full-repository acceptance remains **NOT_COMPLETE**,
and staged shell deployment correctly refuses a failed canonical validation.

Native probes are opt-in:

```bash
HADALIS_TEST_NATIVE_LIVE=1 HADALIS_TEST_GITHUB=1 python3 scripts/test-hadalis-native-live.py
HADALIS_TEST_SHELL_LIVE=1 python3 scripts/test-hadalis-automation-shell-live.py
# Exercise an installed shell's component instead of repository QML:
HADALIS_TEST_SHELL_LIVE=1 HADALIS_TEST_QML_ROOT="$HOME/.config/quickshell/inir" python3 scripts/test-hadalis-automation-shell-live.py
```

Private evidence is under `$XDG_STATE_HOME/hadalis-automation/acceptance` (or
the standard state directory), outside Git. Real OS reboot, Desktop host restart,
administrator authentication/elevated commands and full risky shell deployment
were not exercised. Those require separate native qualification; unit/dependency
and fault-injection evidence must not be described as a live reboot or privilege
test. The default privilege allowlist is empty.

A 60-second observation of one legacy pending chat measured the scheduler's
main Python process at about **13 MiB PSS / 0.22% of one CPU core**. The whole
scheduler service, including short-lived Node/CDP clients, used **99.5 MiB /
15.33% of one core** in that sample. This identifies transport overhead; it is
not a Python-versus-Bash benchmark or an idle/whole-system performance claim.

## Settings and credentials follow-up, 2026-10-01

Activity uses one bounded viewer, switching between profile events and system
diagnostics. Each prompt has its own scrollable editor; Save, Undo and Default
stay together. Icon/text groups are centered in single-row action controls.
Name and next-chat project share a row. The description editor is removed;
existing description fields and profile/state migration remain compatible.

GitHub tokens are optional, per-profile Secret Service keyring entries. Settings
uses password echo mode, clears unsaved input on profile changes and sends a
save only through the control process's stdin. No token is stored in JSON,
logs, argv, Git URLs or prompts. Status exposes only saved flags. Git's helper
pipe releases the credential only for the exact GitHub repository and resets
inherited credential-store helpers; token-bearing operations disable Git
tracing. Duplicate profiles do not copy credentials. No plaintext fallback is
provided when the keyring is unavailable. This authenticates local Git only;
ChatGPT's connector has separate authorization.

Focused tests cover repository-scoped Git credential exchange and a real
keyring save/lookup/clear with a disposable canary. Native Settings acceptance
covers complete prompt scrolling, centered icon rows, one Activity view,
masked input/private stdin, profile switching/removal and backend survival
after the private shell is killed. Screenshot artifacts contain fixture data
and remain in the private acceptance directory. Automatic five-hour wakeup
was explicitly excluded by the maintainer; no Codex/Work quota timer is added.
