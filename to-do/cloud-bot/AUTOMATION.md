# Automation stability and isolation

Maintainer-authorized implementation, 2026-09-30. Target contract and audit:
[`docs/AUTOMATION_ARCHITECTURE.md`](../../docs/AUTOMATION_ARCHITECTURE.md).

- [x] Durable config/state migration and receipt storage.
- [x] Conversation/message identity, independent monitoring and concurrent profiles.
- [x] Bounded worker pool, execution receipts, publish retry and orphan cleanup.
- [x] Evidence-driven workflows, private diagnostics and privilege/deployment recovery.
- [ ] Frontend compatibility, regression checks and real Desktop acceptance.

Keep uncertain existing submissions and consumed job results. Do not reset
profiles or resend prompts to make acceptance appear green.
