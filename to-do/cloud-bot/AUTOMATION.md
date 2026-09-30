# Automation stability and isolation

Maintainer-authorized implementation, 2026-09-30. Target contract and audit:
[`docs/AUTOMATION_ARCHITECTURE.md`](../../docs/AUTOMATION_ARCHITECTURE.md).

- [x] Durable config/state migration and receipt storage.
- [x] Conversation/message identity, independent monitoring and concurrent profiles.
- [x] Bounded worker pool, execution receipts, publish retry and orphan cleanup.
- [x] Evidence-driven workflows, private diagnostics and privilege/deployment recovery.
- [x] Frontend compatibility, regression checks and real Desktop acceptance.
- [x] Settings follow-up: one Activity viewer, scrollable prompts, compact icon buttons, name/project row and masked per-profile GitHub token stored in system keyring.
- [x] Shell process cleanup: stop only verified members of the stopped service; preserve independent Quickshell validation/workflow sessions and recheck ownership before escalation.
- [x] Two-workflow monitoring: classify ChatGPT rate limits privately, bound conversation polling and persist a shared API cooldown while local receipts/jobs continue. Regression covers concurrent profiles, restart persistence and no prompt replay. Live Wull/MegaQML monitoring and current canonical validation are tracked separately.
- [x] Restart is consumed once at durable dispatch; cancellation preserves WAIT_RESULT, final receipt and provenance before the fresh chat. Legacy recovery needs an acknowledged chat and an earlier explicit restart event.
- [x] Failed exec receipts project bounded fixed compiler/QML/test/lockfile error codes to the managed chat while preserving private raw logs; diagnostics include the actual `inir.service` shell unit.
- [ ] Future/deferred: migrate the Linux/process-sensitive Automation execution substrate to Rust only after parity and benchmark gates in [`AUTOMATION_RUST_MIGRATION.md`](AUTOMATION_RUST_MIGRATION.md).

Keep uncertain existing submissions and consumed job results. Do not reset
profiles or resend prompts to make acceptance appear green.

The maintainer explicitly removed automatic continuation after a five-hour
Codex/Work limit from this task. No five-hour quota timer is added. A separately
requested ten-minute Codex heartbeat monitors Wull Companion and MegaQML, reads
bounded logs and repairs/reconciles errors while respecting later user Stop/Pause.
Existing profile descriptions remain compatible in config; only their editor
is removed. Tokens authenticate local Git, not the ChatGPT GitHub connector.

Implementation and focused Automation acceptance are complete. Whole-repository
validation remains **FAIL**: 241 pass, 32 fail, 2 skip at `e3f91d57b`; the same
32 failures were present at `bea23fc62`, with no Automation failures. See the
architecture note for native acceptance and untested environment boundaries.
