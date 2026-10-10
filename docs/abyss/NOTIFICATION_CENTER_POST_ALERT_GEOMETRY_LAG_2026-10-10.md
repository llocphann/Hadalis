# Notification Center: post-notification Popup size/placement jump and lag

**Status:** OPEN — owner-reported, visually confirmed, native cause undetermined.  
**Date:** 2026-10-10, owner recording named \`2026-10-10_21.55.09.mp4\`.  
**Scope:** iNiR / Niri / Abyss connected Notification Center Popup, on \`dev\` only.  
**Task authority:** [ISSUES.md](../../to-do/cloud-bot/ISSUES.md); this is technical research, not a separate checklist.  
**Related but distinct:** [Unresolved Screen Edge hover issue](POPUP_EDGE_HOVER_UNRESOLVED_2026-10-10.md). Do not conflate premature hover dismissal with incorrect popup geometry.

## Owner report and direct video evidence

Owner: after a notification arrives, opening the Notification Edgebar causes the Popup to **lag and display at the wrong size**.

Source: user-supplied video \`2026-10-10_21.55.09.mp4\`, 1920 × 1200, 30 fps, 263 frames, ~8.73 seconds. **The source video was shared in ChatGPT and is not a committed repository fixture.** Local agent should request the original recording if it is not available locally. The following is a visual reading of sampled frames, NOT Qt timestamps/IPC diagnostics:

| Relative video time | Observable |
| --- | --- |
| ~0.7–1.5 s | A small new notification/recording toast is visible at the top area. |
| ~1.7–2.5 s | The Notification Center's black connected surface appears unusually tall and narrow on the right, spanning from very near the top of the display almost to its bottom. Notification content is arranged at the top of this elongated panel. |
| ~2.7–2.9 s | The surface changes shape/extent noticeably; the Popup presentation shifts toward the bottom-right. |
| ~2.9–4.1 s | The Notifications/Activity tabbed Popup is now in a much shorter bottom-right footprint, distinctly different from the earlier tall one. The apparent snap/change is visually significant, not merely a slow moving pointer. |
| ~4.3–4.7 s | Notification items are cleared (the Popup displays an empty-state indicator) while the Popup remains visible. Do not assume this content action is the initiating cause of the earlier geometry jump. |
| ~5–5.6 s | The Notification Center closes; other popup interactions occur later in the recording. |

Exact pixel edges, Qt frame rate, memory/CPU/GPU utilization, effective user config and pointer route were NOT measured from this recording. In particular, **do not call this a proven 420×560 → other-size regression**: those are the repository defaults, not independently verified current user settings.

## What the checked-in source supports (not a root-cause finding)

Examined \`dev\` HEAD \`2a830cc22a364dc284fe780db9ddf1fda9f42d3a\` after the user's previously requested hover-experiment revert.

- \`modules/notificationCenter/NotificationCenterPopup.qml\`: requested width \`max(320,min(760, popupWidth ?? 420))\`; requested height \`max(260,min(900,popupHeight ?? 560))\`. \`contentRoot.implicitWidth/implicitHeight\` subtract twice \`_contentPadding\`, and its notification \`Loader\` is conditional on \`presentationActive && selectedTab === 0\`.
- \`modules/abyss/AbyssPerimeter.qml\`: \`styledPopupHosts\` uses \`embeddedItem: hostedPopup?.contentItem\`, derives \`span\` and \`depth\` from the embedded item's implicit dimensions and the current \`edge\`, uses \`stackPolicy: "pyramid"\`, \`animatePresentation: true\`, \`externalProgress\`, \`joinedEdge\`, \`positionAlong\` and a computed \`anchorBounds\`. On \`popupEntryChanged\`, it resets retained placement and pyramid motion.
- \`modules/abyss/AbyssBodyHost.qml\`: placement and visual placement are separate. By default \`placementCanResize\` and \`animatePlacementChanges\` are enabled for normal bodies; \`minimumSpan/minimumDepth\` can be smaller than requested; it uses \`retainedPlacement\`, \`pyramid\` origin/reveal and its \`contentFrame\` clips contents. These are valid features, not demonstrated bugs.
- \`modules/abyss/looks/AbyssBodyPlacement.js\`: allocator can shrink, stack inward or evict participants based on conflicts. Possible peer occupancy includes toast or other surface participants, but **no evidence yet** identifies an actual participant collision during the video.
- \`modules/abyss/looks/AbyssGeometry.js\`: \`joinCorner\` can extend the visual union to an adjacent physical edge if within a bounded gap. Incorrect \`edge\`/\`joinedEdge\` input could alter the silhouette; the video does not establish this.
- \`modules/notificationCenter/NotificationCenterContent.qml\`: actual notification list, compact mode, tabs, placeholder and conditional search; asynchronous changes may affect child layout, although the parent declares requested implicit dimensions.

The video therefore indicates a **size/placement transition defect that requires native tracing**. It does NOT prove that the notification toast, list Loader, SDF shader, geometry allocator, pyramid motion or hover bridge is the causal component. Avoid applying another speculative source patch.

## Local chatbot's next steps

1. Follow \`AGENTS.md\`, \`to-do/README.md\` and \`to-do/cloud-bot/README.md\`. Refetch \`dev\` and verify the installed/running QML matches the exact checkout. Never edit \`stable\`. This issue is independently OPEN even if Screen Edge hover becomes stable.
2. Reproduce **twice on the same physical output** using the owner's exact \`notificationCenter.popupWidth\`, \`popupHeight\`, DPI/output scale and existing Screen Edge position: (a) clean/empty notification history, open/close; (b) deliver a new notification/recording toast and open immediately or as its toast exits. Repeat after all toast surfaces are gone. Mark whether the bug is cold-only, recent-notification-only or any open.
3. Collect bounded, timestamped measurements during **the actual 1.7–2.9 s transition**. Capture \`hostedPopup\` identity, requestedVisible, presentationActive, revealProgress, explicit/hover ownership; actual configured width/height, \`contentItem.implicitWidth/implicitHeight\`, content Loader status; host \`edge\`, \`joinedEdge\`, \`anchorBounds\`, \`along\`, \`span\`, \`depth\`, \`requestedRecord\`, \`placement\` (\`shrunk\`/\`evicted\`), \`visualPlacement\`, \`record.content/surface\`, \`targetRecord\`, \`inputBounds\` and pyramid/retained-placement states; simultaneous toast/other Popup ownership.
4. For lag: correlate Qt \`frameSwapped\` and the opt-in 50 ms heartbeat with **actual Notification Center reveal and placement changes**. Existing \`scripts/collect-abyss-hover-frames.sh\` separates frame and hover phases; a new bounded **same-phase** capture may be required for correlation. Snapshot-only/synthetic test green is not GPU compositor evidence.
5. Distinguish whether the long right-side silhouette is a genuine layout height, wrong initial edge, temporary \`joinCorner\` extension, allocator \`shrunk\`/relocation, an intermediate pyramid frame or a stale visual rendering artifact. Inspect the state **before** changing clipping/motion/size.
6. Once a root cause is confirmed, make the smallest source correction. Preserve source-anchor and corner ownership, popup connection geometry, visual color/shadow, other Popup slots, notification history actions, Quick Notes/keyboard focus, desktop click-through and the previously owner-accepted fullscreen fix. Add regression cases for a new notification vs no notification and for opening while a toast is visible.
7. Execute targeted tests and \`bash scripts/validate-maintainer-local.sh\` on the exact SHA; then seek independent local Niri reproduction and owner approval. **Do not mark fixed solely from source-level tests.**

## Acceptance

- [ ] Default and customized Notification Center sizes are correct from the **first visible frame**, without transient full-height side bars or a jump between edges.
- [ ] No perceptible stall, sudden relocation or mid-reveal resize when opening immediately after a new notification arrives.
- [ ] Empty history, one notification, multiple notifications, and clearing notification history do not break size or placement.
- [ ] Same behavior on repeated warm opens and after restart, with correct corner/Screen Edge and output scaling.
- [ ] No regressions to hover ownership, click-through, keyboard focus, other Popup kinds, multiple output layouts or fullscreen handling.
- [ ] Native Niri evidence and **owner-confirmed acceptance**. Until then: OPEN.

**Work boundary:** This intake documents a new video-confirmed bug. It does not undo the earlier exact hover revert and does not ship a speculative performance/layout fix.
