# Cloud Storage — MEGA / MEGAcmd research

Status: **RESEARCH ONLY — NO CODE CHANGES AUTHORIZED**.

Detailed findings, proposed Settings UX and technical architecture: [`../../docs/CLOUD_STORAGE_MEGACMD_RESEARCH.md`](../../docs/CLOUD_STORAGE_MEGACMD_RESEARCH.md).

- [x] Audit Hadalis' shared Settings registry, lazy page host, existing JSON helper pattern and source-payload layout.
- [x] Confirm official MEGAcmd CLI coverage for account status, storage, sync definitions, transfers, issues, exclusions and scheduled backups.
- [x] Identify the MEGA Desktop/MEGAsync versus MEGAcmd process/config ownership distinction; do **not** claim supported control of the running GUI application without further evidence.
- [ ] Confirm maintainer's intended ownership: an integrated **MEGAcmd-managed** cloud page versus direct management of an **existing MEGA Desktop** sync engine.
- [ ] Collect safe, redacted version/help/output fixtures from an installed MEGAcmd on the target host and validate exact parsing, startup and failure semantics.
- [ ] Establish coexistence/double-sync guard and a separate credential/MFA design that never passes secrets through process argv.
- [ ] Complete read-only design review and synthetic test plan before proposing any implementation.

Implementation (new QML/service/helper files, routing, config, packaging, installation and runtime tests) is **not authorized by this research request**. Keep any prospective source change separate until the maintainer asks for it.
