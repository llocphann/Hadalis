# Hadalis chatbot tasks

**Local and Cloud development AI share this entry point and the same backlog.**
Read [AGENTS.md](../AGENTS.md), refetch `dev`, then follow this order:

1. [Issues/bugs — fix first](cloud-bot/ISSUES.md).
2. [Rework/optimization](cloud-bot/REWORK_OPTIMIZATION.md).
3. [New features](cloud-bot/NEW_FEATURES.md).

[Shared intake, task selection and archive policy](cloud-bot/README.md) is
mandatory for both environments: classify actionable requests on receipt, merge
duplicates/corrections, then select the highest-priority actionable work without
waiting for the maintainer to choose it. Re-evaluate on new input, "continue"
and completed milestones. Waiting desktop/hardware gates stay open while other
authorized work proceeds. The `cloud-bot` folder holds both environments' lists;
the application's Todo/Obsidian feature is separate.

Keep technical research in [docs/optimization](../docs/optimization/README.md)
and historical records in [the archive](../docs/archive/README.md). Validate with
repository regressions and `bash scripts/validate-maintainer-local.sh`; source,
exact-SHA local checks and owner desktop acceptance are separate evidence.
