# Automation stability and isolation

Maintainer-authorized implementation, 2026-09-30. Target contract and audit:
[`docs/AUTOMATION_ARCHITECTURE.md`](../../docs/AUTOMATION_ARCHITECTURE.md).

- [x] Durable config/state migration and receipt storage.
- [x] Conversation/message identity, independent monitoring and concurrent profiles.
- [x] Bounded worker pool, execution receipts, publish retry and orphan cleanup.
- [x] Evidence-driven workflows, private diagnostics and privilege/deployment recovery.
- [ ] Frontend compatibility, regression checks and real Desktop acceptance.
- [ ] Future/deferred: migrate the Linux/process-sensitive Automation execution substrate to Rust only after parity and benchmark gates in [`AUTOMATION_RUST_MIGRATION.md`](AUTOMATION_RUST_MIGRATION.md).

Keep uncertain existing submissions and consumed job results. Do not reset
profiles or resend prompts to make acceptance appear green.
