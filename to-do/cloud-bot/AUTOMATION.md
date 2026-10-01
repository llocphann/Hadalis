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
- [x] Preserve typed HTTP status/resource across Desktop IPC; distinguish throttled history/status reads from generation quotas with fixed private observations. Timeout/legacy CLI compatibility and bounded read-only model catalog are covered without exposing error bodies, headers or account data.
- [x] Per-profile Chat slider offers Instant / Medium / High, initially High, with a saved default for new profiles. Instant selects its enabled Chat lane; Medium/High use standard/extended thinking. Capability-checked model/effort are pinned in durable intent, compatible lane changes work in an existing chat, and legacy pending submissions remain unchanged.
- [x] Each future turn selects the highest enabled Chat model from live account metadata, with numeric version ordering and no legacy-model pinning. Instant/Thinking lanes stay distinct; unsupported highest-model effort fails before dispatch, and pending turns are retained unchanged.
- [x] Custom workflows follow their own objective repository/branch. GitHub research citations are distinct from verified local machine diagnostics; rejected completed responses keep precise reasons and correction context. Guarded monitor Resume cannot override a later owner Stop/Pause or replay a pending turn/job.
- [x] Repeated account API 429s use durable bounded exponential retry rounds; a successful read between limits cannot reset the sequence. Due profile reads reserve staggered API slots without serializing generations, local jobs or cached receipts.
- [x] WAIT_RESULT referring to a removed/different profile's immutable job result rejects ownership as a precise protocol conflict, retaining the original final receipt and correction context instead of retrying it as a network outage. Owner Pause/Stop and guarded recovery remain authoritative; no foreign result adoption or action replay.
- [x] Verified active turns use lightweight server status between bounded full history audits. Receipt loss, uncertain submissions and completion/failure force exact-turn reads; status-only observations cannot authorize recovery, final consumption or stream reattachment. Healthy streams no longer reattach unnecessarily.
- [x] Fresh-session monitor recovery uses the same atomic final-response/command guard as Resume. A later owner Pause/Stop or a pending turn rejects recovery; consumed receipts remain intact and the new step has distinct chat/message identities.
- [ ] Future/deferred: migrate the Linux/process-sensitive Automation execution substrate to Rust only after parity and benchmark gates in [`AUTOMATION_RUST_MIGRATION.md`](AUTOMATION_RUST_MIGRATION.md).

Keep uncertain existing submissions and consumed job results. Do not reset
profiles or resend prompts to make acceptance appear green.

The maintainer explicitly removed automatic continuation after a five-hour
Codex/Work limit from this task. No five-hour quota timer is added. The maintainer
subsequently chose backend-only operation instead of restoring the deleted
ten-minute Codex heartbeat. Direct monitoring reads bounded logs and respects
later user Stop/Pause and profile removal.
Existing profile descriptions remain compatible in config; only their editor
is removed. Tokens authenticate local Git, not the ChatGPT GitHub connector.

Focused Automation regressions pass. Previous whole-repository validation
remains **FAIL**: 250 pass, 32 fail, 2 skip at `c589ddf41`; its failures match
the inherited baseline. Revalidate the exact current commit before claiming
canonical acceptance. See the architecture note for native acceptance and
untested environment boundaries.
