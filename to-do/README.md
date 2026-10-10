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

Alis dev is the **sole task board** for the core Alis shell,
[Alis-Companion](https://github.com/llocphann/Alis-Companion) and
[Alis-Intergration](https://github.com/llocphann/Alis-Intergration).
The optional packages keep their own implementation source and test evidence,
but no longer own separate TODO status or task priorities. Every external task
must cite its repository/ref/actual source SHA and compatible host SHA.
The three categories above cover all three repositories.

Keep technical research in [docs/optimization](../docs/optimization/README.md)
and historical records in [the archive](../docs/archive/README.md). Validate with
repository regressions and `bash scripts/validate-maintainer-local.sh`; source,
exact-SHA local checks and owner desktop acceptance are separate evidence.
