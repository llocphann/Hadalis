# Pyramid Popup v2 — motion architecture

Status: source implementation checkpoint. Owner-runtime visual acceptance is still required.

## Why the earlier animation failed

The previous experiments mixed three independent concerns:

1. semantic popup ownership,
2. resting-layout allocation, and
3. visual close/reflow animation.

A semantic close immediately removes a request from `AbyssBodyPlacement.arrange()`. When the exit animation then tried to read the post-close allocator, the closing body had already lost its old tier and surviving peers had already moved. Retained-placement and close-only geometry fields compensated for that ordering problem, but they also created blank, teleport and wrong-Screen-Edge-origin regressions.

Pyramid v2 does not restore those fields.

## Ownership model

`AbyssBodyPlacement.js` remains deterministic resting layout only. A popup opts in with `stackPolicy: "pyramid"`. At the same physical Edge and anchor center (within 2 px), the largest requested popup owns the Edge tier and smaller popups stack inward. Different anchors and non-popup bodies keep the normal allocator order.

`AbyssPyramidCoordinator.qml` owns visual transactions only. When a popup begins a semantic close it snapshots the closing placement, freezes only surviving peers at that same anchor, and builds a collapsed origin from the nearest lower popup. Input/focus ownership is revoked immediately. The closing body remains visually resident only because its existing reveal scalar is still above zero.

After the closing tail reaches zero, the coordinator releases that group's freeze. Surviving bodies then animate from their frozen visual positions to the allocator's already-computed resting positions through the existing placement Behaviors.

## Motion contract

Pyramid motion has one scalar: the popup's existing reveal progress. There is no second spring or close clock.

For a popup with full record `F` and collapsed origin `O`:

- open/reopen: `O -> F`,
- close: `F -> O`,
- reopen during close: the same scalar reverses from the current frame.

`AbyssPyramidMotion.interpolateRecord()` never interpolates a popup from another popup's tangent position. `along` and `span` always come from the popup's own final record. Only the Edge-normal surface/content extent changes. This is the key invariant that prevents the old “popup slides from somewhere else on the Screen Edge” artifact.

If a lower same-anchor popup exists, `O` is its workspace-facing boundary. Otherwise `O` is the physical Screen Edge owner strip. Thus the intended chain is top -> middle, middle -> bottom, bottom -> Edge without borrowing another popup's tangent anchor.

Join Edge is applied after the interpolated record is produced, so corner joining remains presentation policy and is not encoded into allocator state.

## Content rendering

During Pyramid motion, the content stays at its full resting dimensions in `contentCanvas`. `contentFrame` is the moving clip. Opacity remains 1. This matches the mature `StyledPopup` slide-under rule: no scale, no label/icon squeeze, no staged fade.

## StyledPopup hover hand-off

A mature popup normally allows a 90 ms compositor leave/enter grace while the pointer crosses from the Bar surface to the popup surface. Pyramid semantic ownership therefore uses `liquidSemanticVisible`, which includes that grace but excludes the later retract tail. This prevents a one-frame input revocation from breaking hover transfer while still ensuring input disappears as soon as a real close begins.

## Required acceptance matrix

Before Pyramid v2 can be called runtime-complete, test:

- two and three same-anchor popups;
- close top, middle and bottom in every order;
- reopen during retract;
- simultaneous/overlapping closes;
- generic + mature StyledPopup mixtures;
- different anchors on one Edge (must never pyramid);
- Join Edge at all four corners;
- top, bottom, left and right Edges;
- reduced/disabled motion;
- shrink/eviction pressure;
- hover transfer between source and popup;
- immediate input/focus revocation while the visual tail remains.

No acceptance item above is implied by source contracts alone.


## Entry arming

A newly opened pyramid tier must resolve its collapse origin before the first reveal frame. The host therefore computes the entry origin from the allocator's final `placement` / full record synchronously when that placement becomes available. It does **not** wait for the animated `visualPlacement` reflow and does not queue another `Qt.callLater` hop.

This removes a subtle ordering race: both generic and mature StyledPopup owners already delay reveal by one event-loop turn, but the previous Pyramid host delayed origin resolution by an additional turn. Under load, reveal could therefore begin from the physical Screen Edge for a frame before switching to the lower-popup boundary. The current contract arms the correct same-anchor origin during the allocator update itself; close snapshots still use the current visual state so mid-reflow close/reopen remains reversible.


## Overlapping transactions

Two additional motion invariants are enforced:

- **Entry origin is latched once reveal begins.** While progress is still at zero, allocator updates may re-arm the origin so the popup starts from the correct lower tier. Once progress is above the reveal threshold, peer reflow may change the final resting target but cannot rewrite the already-visible origin. This avoids a mid-flight discontinuity.
- **A lower popup that is already closing contributes its current visual boundary.** When another popup starts an overlapping open/close transaction, the coordinator samples the lower host's currently published geometry instead of using its old full resting record. The new transaction therefore meets the surface that is actually visible on that frame. The original full snapshot remains only as a fallback after the host stops publishing.

These rules are presentation-only and do not change allocator ordering or resting geometry.
