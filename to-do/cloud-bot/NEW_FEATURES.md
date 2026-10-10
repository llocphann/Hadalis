# New features

Work after [Issues/bugs](ISSUES.md) and [Rework/optimization](REWORK_OPTIMIZATION.md).
Source-implemented features below still need their stated delivery/owner gates;
do not reimplement them solely because a checkbox is open.

- [ ] **Edit Abyss Layout Screen Edge module multi-selection — owner request 2026-10-10:**
  Add an explicit multiple-selection mode for Screen Edge modules while
  **Edit Abyss Layout** is active. Show which modules are selected, support
  add/remove/clear selection and coherent subsequent edits when several targets
  are selected. Keep normal non-edit behavior intact; define guarded batch
  actions instead of silently changing unrelated modules. Test horizontal and
  vertical edges, cross-edge/per-output selection, drag/snapping and Cancel/
  Undo/Done/save semantics; coordinate with compact toolbar redesign in
  [Rework](REWORK_OPTIMIZATION.md). State: NEW, design/implementation and owner
  input acceptance pending.

- [ ] **Quick Notes image delivery:** Hadalis `add29d6f8` implements shared
  paste/import, original-byte storage, Markdown persistence and preview with
  stable asynchronous note ownership. Hadalird `b0c975a7f40bdf531012be326bc728f5c014b696`
  (0.2.1) exports referenced images to the selected Obsidian vault's configured
  attachment location. Core/optional synthetic filesystem and real QML tests
  pass, including delayed tab switching, selection, restart and collisions.
  Confirm installed versions and explicit owner paste/export with source/drafts
  retained. No fixture writes to a personal vault or reads personal clipboard.

- [ ] **Utilities feature delivery:** source already provides Monitor
  Arrangement, Display Mode, Sound Output and Night Light/Anti Flashbang pages
  with bottom-centered dots/swipe and existing display/audio backends. Verify
  actual Extend/Primary/Second-only/Mirror, hotplug/failure rollback, `wl-mirror`
  lifetime, PipeWire default sink and Night Light/Anti Flashbang sensitivity.
  Do not claim real Mirror from a synthetic fixture or introduce a second backend.

- [ ] **Non-Arch optional system gateway:** add trusted distro-owned
  provisioning beyond Arch for Hadalird helpers. Keep root gateway/policy separate
  from user-owned optional payloads and require explicit native authorization.
  Prove package ownership, removal and failure behavior per supported distro;
  never use a user-checkout installer as root or claim untested distro support.

- [ ] **Power-profile render quality delivery:** qualify Abyss automatic quality
  following and manual mode through live profile changes without reload or lost
  preferences. Hadanion owns Companion's two levels: Performance and Quality
  (former Balanced), safe old-tier migration and shared AI behavior. Hadalis
  retains the Launcher effective-quality indicator and optional host API.
  Do not silently lower manual quality as part of strict-lossless optimization.

## External feature ownership

Hadalird extraction is source/package-qualified. Its optional TLP, Thinkfan and
Obsidian implementation belongs to [Hadalird](https://github.com/llocphann/Hadalird).
Host installer/state/Polkit failures stay in Hadalis Issues/bugs. Generic Notes,
AI and shell features must work with optional packages absent.

Companion requests — Aqua/Octo edge orientation, symmetrical cloud actions,
themed Obsidian icon, portals, rolling, quicksand clipping, render quality and
AI/mood/energy/schedule behavior — belong to the current Hadanion plans:

- [Design and animation](https://github.com/llocphann/Hadanion/blob/main/to-do/cloud-bot/ABYSS_WATER_DROPLET_COMPANION.md).
- [Local AI](https://github.com/llocphann/Hadanion/blob/main/to-do/cloud-bot/WULL_LOCAL_AI.md).

Keep Hadalis' optional host/shared AI APIs; preserve concurrent Hadanion work
and the owner's Companion enablement preference. Historical Hadalis Companion
checklists and captures do not override the owning repo's current state.
