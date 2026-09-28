# Pyramid Popup v2 — motion architecture

Status: source implementation through `0f5c56d177304889d9ae159646fa301bf571c9f7`. Owner-runtime visual acceptance is still required.

## Why the earlier animation failed

The previous experiments mixed three independent concerns:

1. semantic popup ownership,
2. resting-layout allocation, and
3. visual close/reflow animation.

A semantic close immediately removes a request from `AbyssBodyPlacement.arrange()`. When the exit animation then tried to read the post-close allocator, the closing body had already lost its old tier and surviving peers had already moved. Retained-placement and close-only geometry fields compensated for that ordering problem, but they also created blank, teleport and wrong-Screen-Edge-origin regressions.

Pyramid v2 does not restore those fields.

## Ownership model

`AbyssBodyPlacement.js` remains deterministic resting layout only. A popup opts in with `stackPolicy: "pyramid"`. Pyramid grouping now follows the common runtime case rather than requiring nearly identical anchors. Two popup requests on the same physical Edge join one neighborhood when their requested tangent content intervals overlap or are within the normal 24 logical-pixel allocator clearance. Connected neighborhoods are transitive (A↔B↔C). Within that neighborhood, the largest requested popup owns the Edge-direct slot and smaller peers stack inward. Far-apart intervals, perpendicular Edges and non-popup bodies remain independent.

`AbyssPyramidCoordinator.qml` owns visual transactions only. When a popup begins a semantic close it snapshots **that closing popup's** placement and builds a collapsed origin from the nearest lower popup. Input/focus ownership is revoked immediately. The closing body remains visually resident only because its existing reveal scalar is still above zero.

Surviving popups are no longer frozen behind the closing tail. As soon as semantic close removes the old request from the allocator, survivors receive their new resting placements and their existing placement Behaviors start reflowing in the same frame. For the common Utilities → Media case, Utilities can retract while Media remains fully visible and simultaneously slides toward its new tier. The closing popup alone keeps its snapshot so its retract path cannot jump.

## Motion contract

Pyramid motion has one scalar: the popup's existing reveal progress. There is no second spring or close clock.

For a popup with full record `F` and collapsed origin `O`:

- open/reopen: `O -> F`,
- close: `F -> O`,
- reopen during close: the same scalar reverses from the current frame.

`AbyssPyramidMotion.interpolateRecord()` never interpolates a popup from another popup's tangent position. `along` and `span` always come from the popup's own final record. Only the Edge-normal surface/content extent changes. This is the key invariant that prevents the old “popup slides from somewhere else on the Screen Edge” artifact.

If a lower same-neighborhood popup exists, `O` is its workspace-facing boundary. Otherwise `O` is the physical Screen Edge owner strip. Thus the intended chain is top -> middle, middle -> bottom, bottom -> Edge without borrowing another popup's tangent anchor.

Join Edge is applied after the interpolated record is produced, so corner joining remains presentation policy and is not encoded into allocator state.

## Content rendering

During Pyramid motion, the content stays at its full resting dimensions in `contentCanvas`. `contentFrame` is the moving clip. Opacity remains 1. This matches the mature `StyledPopup` slide-under rule: no scale, no label/icon squeeze, no staged fade.

## StyledPopup hover hand-off

A mature popup normally allows a 90 ms compositor leave/enter grace while the pointer crosses from the Bar surface to the popup surface. Pyramid semantic ownership therefore uses `liquidSemanticVisible`, which includes that grace but excludes the later retract tail. This prevents a one-frame input revocation from breaking hover transfer while still ensuring input disappears as soon as a real close begins.

## Required acceptance matrix

Before Pyramid v2 can be called runtime-complete, test:

- two and three same-neighborhood popups;
- close top, middle and bottom in every order;
- reopen during retract;
- simultaneous/overlapping closes;
- generic + mature StyledPopup mixtures;
- different anchors on one Edge with 20/50/80% tangent overlap (must pyramid);
- same-Edge intervals separated by more than the 24 px clearance (must remain independent);
- Join Edge at all four corners;
- top, bottom, left and right Edges;
- reduced/disabled motion;
- shrink/eviction pressure;
- hover transfer between source and popup;
- immediate input/focus revocation while the visual tail remains.

No acceptance item above is implied by source contracts alone.


## Entry arming

A newly opened pyramid tier must resolve its collapse origin before the first reveal frame. The host therefore computes the entry origin from the allocator's final `placement` / full record synchronously when that placement becomes available. It does **not** wait for the animated `visualPlacement` reflow and does not queue another `Qt.callLater` hop.

This removes a subtle ordering race: both generic and mature StyledPopup owners already delay reveal by one event-loop turn, but the previous Pyramid host delayed origin resolution by an additional turn. Under load, reveal could therefore begin from the physical Screen Edge for a frame before switching to the lower-popup boundary. The current contract arms the correct same-neighborhood origin during the allocator update itself; close snapshots still use the current visual state so mid-reflow close/reopen remains reversible.


## Overlapping transactions

Two additional motion invariants are enforced:

- **Entry origin is latched once reveal begins.** While progress is still at zero, allocator updates may re-arm the origin so the popup starts from the correct lower tier. Once progress is above the reveal threshold, peer reflow may change the final resting target but cannot rewrite the already-visible origin. This avoids a mid-flight discontinuity.
- **A lower popup that is already closing contributes its current visual boundary.** When another popup starts an overlapping open/close transaction, the coordinator samples the lower host's currently published geometry instead of using its old full resting record. The new transaction therefore meets the surface that is actually visible on that frame. The original full snapshot remains only as a fallback after the host stops publishing.
- **An exhausted lower tail is absent immediately.** If that live closing record has already reached the same 0.001 reveal threshold used by the host to finish the close, the coordinator ignores it even if transaction bookkeeping survives for the remainder of the current QML binding turn. A new popup therefore cannot collapse toward an invisible stale lower tier.
- **Reopen reverses both motions from their current frames.** The closing popup keeps its own O/F snapshot until its reveal scalar returns to 1. Semantic survivors are not transaction-frozen; when the closing request becomes open again, allocator targets change back and their placement Behaviors naturally reverse from their current reflow positions.

These rules are presentation-only and do not change allocator ordering or resting geometry.

## Reduced / disabled motion

Close cleanup cannot depend only on a future `progressChanged` callback. A popup owner may jump its reveal scalar directly to zero when motion is disabled, and that progress update can occur before Pyramid semantic-close bookkeeping arms the transaction. After `beginClose`, the host therefore evaluates the same completion predicate synchronously. If progress is already at or below 0.001, the closing popup's transaction snapshot is finished immediately. Surviving peers are already following live allocator targets, so there is no group freeze to release. The normal `onProgressChanged` path calls the same helper for animated closes.


## Reversal transaction

Reopen during a retract stays inside the same Pyramid visual transaction until reveal reaches 1. The coordinator changes phase from `closing` to `reopening` and keeps only the reopening popup's placement snapshot, collapsed origin and full record intact. The existing owner `revealProgress` reverses direction, while semantic survivors receive the allocator's restored targets and reverse their placement motion from the current frame.

Cancelling the transaction at semantic reopen would be geometrically unsafe if another popup changed allocator targets during the retract: a partially revealed surface could suddenly receive a different full target even though its scalar reversed smoothly. Keeping the closing popup's own snapshot guarantees that its reverse follows exactly the same `O <-> F` path. Surviving peers are deliberately live during that reversal: allocator targets switch back as soon as semantic reopen occurs, so their placement Behaviors reverse concurrently. At progress 1 the coordinator releases the closing popup's transaction snapshot.

If the popup closes again before the reverse completes, phase flips back to `closing` with the same snapshot. No new origin, no second clock and no content scale/fade are introduced. Reduced/disabled motion uses the same symmetric finish predicates, so a scalar that has already jumped to 0 or 1 cannot leave a stale transaction snapshot behind.


## Record-depth coherence

Pyramid interpolation now animates `record.depth` with the same normalized reveal scalar as `surface` and `content`. In the normal `Geometry.placedPanel()` path, `depth` is the current Edge-normal reach while `targetDepth` is the resting maximum; Pyramid snapshots must preserve that distinction.

The collapsed origin reconstructs its current depth from the invariant `surfaceCross = ownerExtent + currentDepth`. Therefore the lowest tier has depth 0 at the physical Edge, while a higher tier's collapsed depth reaches exactly to the lower popup boundary. This matters beyond painting: obstacle and layout consumers read `record.depth`. Keeping the old full depth during a visual retract made those consumers behave as if the popup were fully open until the final frame, producing premature/late reflow around animated popups.


## Deterministic resting-order grouping

The static allocator no longer mixes Pyramid area ordering and legacy priority/order in one pairwise sort comparator. That comparator could be non-transitive when two same-neighborhood pyramid peers had a third, different-anchor request between them: A could sort before B by area, B before C by activation order, and C before A by activation order. A non-transitive comparator makes the resting tier order engine/input-order dependent, which is unacceptable as an animation target.

The allocator now performs two deterministic stages. First it computes the unchanged legacy global order. Then each connected same-neighborhood Pyramid component reorders only the slots already occupied by that component, largest resting area first. Requests at other anchors never move slots because of Pyramid policy. This keeps the resting-layout/animation boundary stable and prevents apparent animation jumps caused by an unstable target order rather than by the motion layer itself.


## Tangent-neighborhood grouping experiment

The previous <=2 px anchor-center rule made Pyramid almost invisible in ordinary use because independent Bar modules rarely share an exact center. The current experiment promotes the allocator's actual interaction domain instead: requested popup content intervals on one Edge form a Pyramid neighborhood when they overlap or lie within 24 logical pixels. The threshold is carried on the placement request as `stackProximity`, so the resting allocator and animation coordinator use the same rule.

This does **not** relax the tangent-motion invariant. Group membership may come from another popup's interval, but every animated record still keeps its own `along/span`; a peer contributes only an Edge-normal collapse boundary. The expected visible change is therefore tiering/reflow for ordinary overlapping popup pairs, not a popup sliding sideways toward another module.


## Concurrent survivor reflow

The owner recording `recording_2026-09-29_01.40.56.mp4` exposed the most common close transition: one popup retracts while a surviving peer waits at its old inward tier and only moves after the first tail disappears. That sequencing was caused by the coordinator's `frozenPlacements` map, not by the allocator.

The current policy removes survivor freezing. A semantic close now has two simultaneous visual effects:

1. the closing popup keeps its own transaction snapshot and retracts along its existing `F -> O` path;
2. every still-open peer immediately consumes the allocator's new resting placement and begins its ordinary placement reflow.

For Pyramid participants, placement reflow uses `InOutCubic` with the existing Abyss normal duration so a common Utilities → Media transition reads as one coordinated glide. Non-Pyramid placement changes keep the prior `OutCubic` curve.

This change intentionally preserves the tangent invariant: the survivor moves only toward its own new allocator placement; it never borrows the closing popup's `along/span` or Screen-Edge origin.
