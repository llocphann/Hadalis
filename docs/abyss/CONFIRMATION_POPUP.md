# Abyss confirmation and authentication popup architecture

Status: Phase A source audit complete. Foundation/runtime integration is intentionally split into later commits. Live desktop acceptance is **not** implied by this document.

## Goal

Confirmation and authentication prompts should use the existing Abyss connected-surface field instead of introducing another detached dialog renderer. Placement is source-owned when Hadalis can resolve a live Bar/System Tray/Dock anchor; otherwise the request uses a top-center fallback on the target output.

The intended flow is:

```text
request/backend
    -> runtime request state
    -> source/anchor resolver
       -> live source Item (Tray/Bar/Dock), or
       -> top-center fallback Item
    -> StyledPopup
    -> AbyssSurfaceController popup slot
    -> AbyssBodyHost / Pyramid placement + motion
```

This deliberately reuses `StyledPopup`, the stable popup slots in `AbyssSurfaceController`, and `AbyssBodyHost`'s Pyramid contract. Confirmation does not need a second placement or animation system.

## Source audit

### Hadalis close confirmation

`modules/closeConfirm/CloseConfirm.qml` is a Hadalis-owned confirmation path. It receives `closeConfirm` IPC, snapshots the focused Niri window and, after approval, performs the real close action through `niri msg action close-window --id ...` (with the existing Spotify minimize exception). This path is safe to rehost because Hadalis owns both the confirmation semantics and the final action.

The existing Material implementation is a fullscreen layer-shell window with a centered `WindowDialog`. Waffle has a separate supported renderer and must remain independent.

### Application-native dialogs

A compositor-visible transient window is not, by itself, an interceptable confirmation protocol. Hadalis can observe/focus/close windows, but that does not provide a reliable API for extracting button roles, invoking the application's original action, or suppressing the application's own dialog without changing behavior.

Accordingly, arbitrary application-native confirmations are **not** to be recreated from window title/text heuristics. In particular, a ChatGPT tray menu entry labelled `Quit` can be invoked through the StatusNotifier/DBusMenu surface, but that menu surface does not expose a standard semantic contract saying whether the application will subsequently create its own native confirmation. Triggering it and drawing a second Hadalis confirmation would risk duplicate prompts; replacing it by label matching would risk bypassing application semantics.

ChatGPT Quit therefore remains a runtime target for a future reliable app/native bridge, not a source-only claim of completed interception.

### StatusNotifier / DBusMenu

Quickshell exposes tray menu entries with presentation/action fields such as text, icon, enabled/check state, children and `triggered()`. There is no generic confirmation/action-role contract sufficient to classify every `Quit`-like item as a safely interceptable application confirmation.

The useful part for this project is the **live tray anchor** itself. A request that already has trustworthy backend semantics can resolve its source app to that anchor and let `StyledPopup` inherit the correct output and attachment Edge.

### Dock

Abyss Dock app buttons are real Items under the Dock's `AbyssBodyHost`. They already carry application identity and are valid fallback source anchors when no matching visible tray item exists.

Resolver precedence should therefore be explicit source Item, then live System Tray/Bar source, then Dock, then the top-center output fallback. Matching should remain conservative and identity-based; UI label matching must not become an action interceptor.

### Top-center fallback

Abyss OSDs already use the output field and `AbyssBodyHost`. Confirmation can use the same output geometry model without masquerading as an OSD: a tiny non-painted source Item at the top-center of the selected output can expose that output's `liquidController` and `attachedEdge: "top"`. Feeding it to `StyledPopup` keeps fallback prompts in the same placement/Pyramid machinery as attached prompts.

### Pyramid / motion

No Pyramid architecture change is required. A `StyledPopup` rehosted by `AbyssSurfaceController.presentPopup()` already receives:

- an anchor-derived Top/Bottom/Left/Right attachment Edge;
- anchor-preserving tangent placement;
- optional adjacent-Edge joining from the existing presentation contract;
- stable popup slots;
- immediate semantic input revocation on close;
- Pyramid entry origins, reversible close/reopen transactions and concurrent survivor reflow;
- the existing slide-under/clip content reveal rather than a confirmation-only fade/scale.

A confirmation presenter should therefore be an ordinary focused `StyledPopup`, not a new window type.

## Polkit feasibility and security

Hadalis already owns a real Polkit authentication agent through Quickshell's optional `Quickshell.Services.Polkit` module. `PolkitAgent` supplies an `AuthFlow`; Hadalis currently calls the real `submit(...)` and `cancelAuthenticationRequest()` operations. This is a reliable backend and is suitable for Abyss rehosting.

The flow can provide the authentication message, action ID, selected/available identities, prompt visibility, failure/completion state, icon, and supplementary/error message. Quickshell's Polkit agent queues incoming authorization requests; Hadalis should present the active flow rather than invent a second authorization queue.

Security contract:

- password/secret text stays only in the focused field long enough to call `AuthFlow.submit`;
- clear the field immediately after submission and on cancel/failure/new flow;
- never place secret text in `GlobalStates`, Config, a generic confirmation model, debug output, IPC payloads, or persisted state;
- keep action/message/identity metadata separate from the response string;
- disabling/bypassing Polkit authentication is out of scope;
- QML/JavaScript cannot guarantee cryptographic memory zeroization of immutable strings, so the implementation can minimize lifetime but must not claim stronger erasure.

If a trustworthy source-app hint becomes available, Polkit can use the same anchor resolver. The current `AuthFlow` does not by itself provide a dependable requesting desktop-app ID, so the default for ordinary Polkit requests is top-center rather than guessing from the human-readable message.

## Planned implementation boundaries

Phase B introduces a runtime-only request queue and a live popup-anchor registry. The registry stores Item references and identity providers, never secrets. Tray registration outranks Dock registration. Resolution is snapshotted when a request becomes active so a new request cannot inherit another popup's geometry.

Phase C rehosts the existing Hadalis `closeConfirm` path through an Abyss confirmation `StyledPopup`. Accept/Cancel invoke the existing real callbacks. Waffle keeps its own renderer. App-native confirmation interception is not claimed.

Phase D rehosts the existing Polkit `AuthFlow` through a focused Abyss `StyledPopup`, preserving Enter/Escape, retry/error, busy state, identities and Details metadata. The old fullscreen Polkit renderer remains only as a non-Abyss compatibility path.

## Acceptance status

Source/contract tests may establish routing, anchor precedence, focus, action callbacks, queue behavior and the absence of secret persistence. They do **not** establish live compositor acceptance.

The following remain live-desktop checks after implementation: tray attachment (including ChatGPT only once a trustworthy backend exists), Dock-only attachment, top-center fallback, all four Edges, Join Edge, concurrent/retracting Pyramid neighbors, close/cancel/reopen, source removal, long content/button labels, password focus, wrong-password retry, Polkit cancel, queued requests and real authorization completion.
