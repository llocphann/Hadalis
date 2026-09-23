# Hadalis agent workflow

Hadalis uses a single-agent development workflow on `dev`.

## Working rules

1. Fetch/refetch the current `dev` HEAD before every audit and immediately before every write or ref update. Never assume a previously seen HEAD is current.
2. Work directly on `dev`. Do not create a branch or PR unless the maintainer explicitly asks for one. Never mutate `stable`.
3. Re-read every file you intend to edit from the current HEAD and avoid overwriting valid concurrent work. Fix forward; do not rewrite shared history.
4. Keep commits atomic and technical-purpose focused.
5. Use repository regression tests and the canonical local validator as the primary acceptance path. Do not infer product quality from GitHub Actions state.
6. Nix support stays in-tree but dedicated Nix validation is deferred/non-blocking for the maintainer workflow.
7. Waffle is a separate supported shell family. Never classify Waffle as legacy or remove it as ii/Connected Perimeter cleanup.
8. Prefer behavior/contract tests over implementation-spelling grep assertions. Do not change runtime behavior merely to make a stale test green.
9. Do not create task-board, bot-number, ownership, collision-boundary, or handoff bureaucracy. Continue the highest-value unresolved work in one agent context.

## Current product priorities

Until the maintainer changes them, prioritize:

1. Caelestia-like UI/UX using the existing iNiR surfaces: existing popups should visually connect to their bar/screen edge instead of introducing a second popup system.
2. Connected-surface presentation is the default for existing bar popups and must not require a user-facing toggle. Keep the broader `iiPerimeter` composition cutover guarded until it can replace the legacy composition without dropping functionality.
3. Keep Dock presentation simple: Panel is the canonical ii dock style; historical style values must degrade safely to Panel.
4. English-only localization. `translations/en_US.json` is the only shipped locale catalog; multilingual translation generation/auditing is not an active product requirement.
5. Runtime correctness, local regression coverage, install/update lifecycle, and source/package identity.

Documentation/wiki polish and release prose are lower priority and must not block the product/UI loop unless a change directly invalidates a required runtime or packaging contract.

## Validation

Canonical maintainer validation entry point:

```bash
bash scripts/validate-maintainer-local.sh
```

A PASS applies only to the exact SHA printed by that run. Environment-only desktop acceptance (live Niri/Quickshell interaction, multi-output/hotplug/suspend/fractional scaling) remains separate from static/local contract validation.
