# Hadalis chatbot tasks

Read `AGENTS.md`, refetch `dev`, then follow this order:

1. [Issues/bugs — fix first](cloud-bot/ISSUES.md).
2. [Rework/optimization](cloud-bot/REWORK_OPTIMIZATION.md).
3. [New features](cloud-bot/NEW_FEATURES.md).

[Task rules and archive policy](cloud-bot/README.md) govern incoming requests,
deduplication, completion and automatic classification. This is the single entry
point for chatbot work. The application's Todo/Obsidian feature is separate.

Keep technical research in [docs/optimization](../docs/optimization/README.md)
and historical records in [the archive](../docs/archive/README.md). Validate with
repository regressions and `bash scripts/validate-maintainer-local.sh`; source,
exact-SHA local checks and owner desktop acceptance are separate evidence.
