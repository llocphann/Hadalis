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
- [x] Final responses and job receipts share the transition contract: preserve evidence/checkpoint first, then honor rotation, run limits and interval timing after WAIT_RESULT.
- [x] Consumed malformed Wull job retained byte-for-byte as archived evidence, with its original terminal result and digest; no action replay or job-ID reuse. Job authoring requires JSON serialization/validation before publication.
- [x] Worker discovery recovery clears its own stale health warning while retaining independent job metadata failures and private exception boundaries.
- [x] A failed stream with only its user prompt can recover from explicit server FAILURE. Matching history reads bracket the server status and preserve a later user turn; client errors, ambiguous branches, rate limits and COMPLETE without a final message cannot authorize replay.
- [x] Client stream interruptions and COMPLETE without a final response remain visible as distinct observation states instead of false Thinking. Fixed per-turn evidence survives restart/rate-limit retries; independent profiles continue and an eventual original response is consumed once.
- [x] Per-profile Chat slider offers Instant / Medium / High, initially High, with a saved default for new profiles. Instant selects its enabled Chat lane; Medium/High use standard/extended thinking. Capability-checked model/effort are pinned in durable intent, compatible lane changes work in an existing chat, and legacy pending submissions remain unchanged.
- [ ] Future/deferred: migrate the Linux/process-sensitive Automation execution substrate to Rust only after parity and benchmark gates in [`AUTOMATION_RUST_MIGRATION.md`](AUTOMATION_RUST_MIGRATION.md).

Keep uncertain existing submissions and consumed job results. Do not reset
profiles or resend prompts to make acceptance appear green.

The maintainer explicitly removed automatic continuation after a five-hour
Codex/Work limit from this task. No five-hour quota timer is added. A separately
requested ten-minute Codex heartbeat monitors Wull Companion and MegaQML, reads
bounded logs and repairs/reconciles errors while respecting later user Stop/Pause.
Existing profile descriptions remain compatible in config; only their editor
is removed. Tokens authenticate local Git, not the ChatGPT GitHub connector.

Focused Automation regressions pass. Previous whole-repository validation
remains **FAIL**: 250 pass, 32 fail, 2 skip at `c589ddf41`; its failures match
the inherited baseline. Revalidate the exact current commit before claiming
canonical acceptance. See the architecture note for native acceptance and
untested environment boundaries.
