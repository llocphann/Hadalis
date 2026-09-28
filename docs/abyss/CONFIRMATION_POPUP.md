# Abyss confirmation and authentication popup architecture

Status: Phases A-D are implemented at the source/contract level on `dev`. Phase E live-desktop acceptance is still pending. Nothing in this document should be read as proof that compositor/runtime acceptance has completed.

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

### Native dispatch / desktop portal audit

The current `scripts/native-dispatch` surface routes keyboard/input helpers, Niri configuration, clipboard filtering, MPD/lyrics, theme generation and desktop-icon synchronization. It exposes no dialog interception, transient-window action bridge, portal request broker or generic app-confirmation transport.

The Niri portal configuration delegates portal implementations to GNOME/GTK, including `org.freedesktop.impl.portal.Access = gtk`. Hadalis is therefore not currently the portal backend that owns those confirmation semantics. Rehosting portal confirmations would require an explicit portal/backend integration rather than observing a GTK dialog after it appears.

Likewise, the shared System Tray menu renderer ultimately sends `QsMenuEntry.triggered()` for a selected menu row. The menu entry surface contains presentation state such as text/icon/enabled/check/children, but the repository has no additional action-role or confirmation-response channel layered on top of it.

These findings reinforce the safe boundary: current native-dispatch, portal and tray-menu paths can provide identity/anchor context or invoke an existing menu action, but they cannot generically replace an application's subsequent native confirmation while preserving its original semantics.

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

## Implementation status

### Phase B — foundation

Implemented:

- `ConfirmationService` owns runtime-only confirmation requests and callback closures; it does not serialize request state through Config, GlobalStates or generic IPC.
- `PopupAnchorRegistry` resolves only live Items that already belong to an Abyss connected surface.
- Implicit matching uses stable machine identities only. Human-facing app names, tray titles and tooltips are deliberately excluded from routing.
- Precedence is explicit source Item, then System Tray, then Bar taskbar, then Dock, then top-center fallback.
- Source removal cancels the attached request instead of switching anchors mid-flight.
- The active request is retained until its visual retract tail is released, so queued requests cannot inherit the previous geometry.
- If `abyssPerimeter` is disabled, the previous standalone confirmation/Polkit renderers remain available as a fail-safe rather than leaving an invisible request.

### Phase C — normal confirmation

Implemented for the Hadalis-owned `closeConfirm` backend:

- the request is presented through a focused `StyledPopup`;
- source app IDs can attach the popup to a matching Tray/Bar/Dock anchor;
- unresolved sources use the output top-center anchor;
- the real close callback still executes the existing Niri close/minimize path;
- cancel, close/reopen, long content and long action labels use the same Abyss primitives and popup geometry.

This does **not** claim generic interception of application-native confirmations. ChatGPT Quit remains blocked on a trustworthy backend/native bridge that can expose the application's real confirmation semantics and suppress the original dialog without bypassing or duplicating it.

### Phase D — Polkit

Implemented on the existing Quickshell `PolkitAgent/AuthFlow` backend:

- no second authorization queue is created; Quickshell remains queue authority;
- Enter/Escape, Cancel, Authenticate, identities, Details, failure messages and multi-turn prompts are preserved;
- pending state remains non-interactive until `AuthFlow` actually requires a response;
- the response field is cleared before handing the response to `AuthFlow.submit`;
- response text is not stored in Config, GlobalStates, the generic confirmation service, logs or persisted state;
- ordinary Polkit requests use top-center because `AuthFlow` does not expose a dependable requester app ID;
- a future trusted source hint can use the same anchor resolver without changing the authentication backend.

### Phase E — runtime acceptance

A synthetic Wayland/Quickshell harness now exists at `scripts/test-abyss-confirmation-runtime.sh`. When run in a real Wayland session with Quickshell available, it exercises real `StyledPopup`/Abyss popup slots and real confirmation callbacks for:

- Top/Bottom/Left/Right source attachment;
- Tray-over-Dock identity precedence and Dock-only fallback;
- top-center fallback when no source resolves;
- long content width capping;
- source removal without teleport;
- coexistence with another popup and survival while that peer retracts.

The script intentionally skips when Quickshell/Wayland is unavailable. A source-only pass or a skipped runtime harness is **not** runtime completion.

## Acceptance status

Source/contract coverage now exists for request ownership, conservative anchor resolution, popup/Pyramid reuse, fail-safe fallback renderers, Join Edge inheritance, action callbacks, queue ownership, Polkit focus/security state and multi-turn retry behavior.

Still requiring live desktop acceptance:

- the synthetic confirmation runtime harness on the target desktop/compositor;
- real Polkit password focus, wrong-password retry, Cancel, queued requests and successful authorization;
- multi-monitor/focus changes and source disappearance in the actual shell;
- ChatGPT Quit or any other application-native confirmation only after a reliable native/backend interception path exists.

Do not mark the feature `runtime complete` until those live checks are recorded.
