# Shell Surface Contracts

This document records the stabilization contracts that should be checked during a local acceptance pass on `dev`.

## Connected bar popups

- Existing bar popups continue through `modules/bar/StyledPopup.qml`; no parallel popup framework is introduced.
- The popup composes `ConnectedSurfaceGeometry`, `ConnectedSurfaceFrame`, and `ConnectedSurfaceMask` from `modules/common/perimeter/`.
- Attachment must work from top, bottom, left, and right bars.
- The popup body/connector overlap is device-pixel-aware so the seam does not expose a transparent gap at fractional scale.
- Reveal/growth originates from the attached edge.
- Transparent regions outside the popup shape remain click-through.
- Connected popup presentation does not require enabling the broad `iiPerimeter` cutover.

## Dock

- Panel is the only supported user-facing Dock style.
- Legacy persisted values such as Pill, macOS, Island, or M3 normalize to `panel` during startup.
- The settings UI must not expose the legacy style matrix again.
- Waffle remains a separate panel family and is not a value of `dock.style`.

## UI language

- Shell UI localization is English-only.
- `services/Translation.qml` exposes canonical `en_US` and loads `translations/en_US.json`.
- Legacy `language.ui` values normalize to `en_US` during startup.
- `translations/` contains no other locale JSON catalogs.
- Translator/application language features are separate from shell UI localization and are not implied by this contract.

## Regression guard

Run the focused static contract locally with:

```sh
python scripts/test-shell-surface-contracts.py
```

This guard is intentionally narrow. It checks architectural invariants and source/catalog state; it does not replace live visual testing.

## Local visual acceptance

For the final local pass, verify at minimum:

1. open each existing bar popup from a top bar and confirm the connector/body read as one surface;
2. repeat with bottom, left, and right bar placement;
3. verify reveal starts at the bar/screen edge rather than appearing as an independently scaled card;
4. verify clicks outside the visible popup shape are not captured by its full-output host window;
5. restart with a legacy `dock.style` value and verify the persisted value is normalized to `panel` and only Panel UI is shown;
6. verify Waffle behavior is unchanged and is not presented as a Dock style;
7. restart with a legacy `language.ui` value and verify the shell remains English and normalizes it to `en_US`.

If a full `iiPerimeter` composition is tested separately, keep fallback coverage in scope: do not treat loss of legacy-only functionality as an acceptable connected-surface result.
