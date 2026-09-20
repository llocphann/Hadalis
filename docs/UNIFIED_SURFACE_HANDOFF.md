# Unified Surface Research — New Chat Handoff

Use this file when the current ChatGPT conversation is too long and work must continue in a fresh chat.

Primary research document:

- `docs/UNIFIED_SURFACE_RESEARCH.md`

Related existing architecture/contracts:

- `docs/PERIMETER.md`
- `docs/SHELL_SURFACE_CONTRACTS.md`
- `ARCHITECTURE.md`
- `AGENTS.md`

## Current repository state

The contact-corner patch series was reverted.

Revert commit:

- `cef10e8923c24ef4cf4106237dfaa418c1abe4a9`
- `revert: restore pre-contact-corner baseline`

The affected production files were verified byte-identical to the pre-corner baseline:

- `ad42c9326e34cdec6e2d7791a2a0664d8bbfb82f`

The branch continues to receive unrelated Code Workflow Editor commits, so **always refetch current `dev` before doing anything**.

Do not reset/rewrite unrelated Workflow Editor work.

## Key decision already reached

Do **not** continue trying to solve the visual requirement with:

- Canvas corner flares;
- extra `RoundCorner` objects;
- contact-inset patches;
- per-consumer seam offsets;
- manual “join” geometry as the fundamental model.

The user wants Bar/Screen Edge + connected popup/panel to behave as **one material/silhouette**, especially when Bar modules are reordered.

The research direction is Caelestia-like unified surface composition:

```text
shared visual host/domain
  + inverted frame
  + moving rounded panel/popout shapes
  -> SDF smooth union / border sink
  -> one silhouette
```

Source module movement should only update the popup rectangle. The union topology should follow automatically.

## Important constraints

1. Do not modify the locked physical Screen Edge/Bar geometry while researching.
2. A real SDF union cannot span independent `QQuickWindow` scenegraphs. Shapes that visually union need representations inside one visual host/window/domain.
3. Interactive content may remain in separate windows; the shared host can own only material/background/shadow.
4. One global host is not automatically correct because Settings Overlay/scrim and other layer relationships differ. Investigate **composition domains**.
5. Hadalis currently has no native Qt Quick rendering plugin. Native QSG work has packaging/ABI consequences.
6. Hadalis already ships a `.qsb` ShaderEffect asset (`FluidRipple`), making a non-production QSB SDF PoC plausible.
7. Do not commit production implementation until the remaining architecture blockers are researched.

---

## Copy/paste prompt for the next chat

```text
Continue the Hadalis unified-surface research from the repository handoff.

Repository: llocphann/Hadalis
Branch: dev

FIRST:
1. Refetch the current dev HEAD because unrelated Code Workflow Editor work is continuing in parallel.
2. Read:
   - docs/UNIFIED_SURFACE_RESEARCH.md
   - docs/UNIFIED_SURFACE_HANDOFF.md
   - docs/PERIMETER.md
   - docs/SHELL_SURFACE_CONTRACTS.md
   - ARCHITECTURE.md / AGENTS.md as applicable.
3. Verify the reverted contact-corner files still match the pre-experiment baseline ad42c9326e34cdec6e2d7791a2a0664d8bbfb82f where expected.
4. Do not rewrite/reset unrelated commits.

Context:
- The Canvas/flare/contact-plane patch approach was rejected and reverted.
- The product requirement is a Caelestia-like common silhouette: Bar/Screen Edge and connected popup/panel should behave as one shape/material.
- When a Bar module is reordered, the popup's contact topology must follow its live anchor automatically; the renderer must not select/draw corners manually.
- Caelestia achieves this with BlobGroup + rounded/inverted SDF shapes in one scenegraph.
- Cross-QQuickWindow SDF union is not possible after separate scenegraphs render; Hadalis likely needs visual composition domains/hosts while retaining separate input/content windows.
- Do NOT commit production code yet.

Continue research deeply on these three blockers first:
A. Niri/Wayland layer-shell stacking and lifetime for a shared input-transparent visual host:
   - ScreenEdges FrameWindow vs Bar vs Overlay popup;
   - same-layer creation/remap ordering;
   - whether Bar popout backgrounds can be rendered by a Top host while content stays Overlay;
   - whether a second Overlay visual domain is needed.

B. Blur/material/shadow ownership:
   - current BackgroundEffect.blurRegion behavior;
   - how a unified host can request blur only inside the SDF union;
   - transparent Material/backgroundTransparency cases;
   - common union shadow;
   - Settings Overlay/scrim ordering.

C. Renderer/package architecture:
   - minimal QSB ShaderEffect SDF PoC vs native QQuickItem/QSG plugin;
   - repo-copy update lifecycle;
   - Arch package and Nix package;
   - QML import path/Qt ABI/hot reload/fallback;
   - leverage the existing optional native Code Workflow parser packaging pattern only where appropriate.

Also extract the minimum Caelestia Blob shader model needed for Hadalis:
- rounded-rect SDF;
- inverted frame;
- smooth union;
- border sink;
- bounding geometry/fill-rate strategy.

Then design, but do NOT yet implement, the exact U1 PoC:
- one output-local visual host;
- locked frame parameters reproduced as data;
- one moving popup rounded rect driven by a real/fake Bar module anchor;
- renderer has zero module-specific or corner-specific branches;
- topology tests for center/edges/top-bottom/vertical/fractional scale;
- performance instrumentation;
- explicit pass/fail gates and rollback.

Use GitHub integration to inspect source/history. Do not commit until the user explicitly approves implementation after reviewing the research.
```

## Reminder for future implementation

The first implementation should be an **isolated PoC**, not a replacement for `StyledPopup`, `ScreenEdges`, Sidebar or Dashboard.

A successful PoC must prove:

- one SDF silhouette;
- source module can move and contact follows automatically;
- no `joinTop/joinRight`-style topology logic;
- no per-popup magic offset;
- correct fractional-scale rendering;
- acceptable performance;
- no input interception;
- no production geometry mutation.
```
