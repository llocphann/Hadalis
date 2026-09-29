# Abyss confirmation and authentication popup architecture

Status: Phases A-D are complete at the source/contract level on `dev`. Phase E now has automated runtime acceptance for the synthetic confirmation path on real Quickshell under headless Weston, on two distinct virtual Wayland outputs, and inside a nested Niri compositor using software Mesa/EGL. Physical output hotplug/focus behavior and real Polkit authorization flows still require a target machine; application-native dialogs additionally require a trustworthy native/backend response channel.

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

Resolver precedence is explicit source Item, then live System Tray/Bar source, then Dock, then the top-center output fallback. When the same app identity is visible on more than one output, source/output affinity is evaluated before surface-kind priority so a remote Tray icon cannot steal a request from a same-output Bar/Dock anchor. Matching remains conservative and identity-based; UI label matching must not become an action interceptor.

Abyss Dock content is resident even while the Dock is visually closed. The resolver therefore rejects retained-but-not-presented Dock items. Conversely, once an attached popup legitimately opens from a live Dock app, the Dock is held open through the popup/retract lifecycle so its source icon does not disappear underneath the confirmation merely because pointer hover ended.

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
- Source removal cancels the attached request instead of switching anchors mid-flight. A source that remains registered but becomes non-presented is also treated as source loss; lifecycle cancellation is forced so a disabled/hidden UI cancel action cannot strand a request on stale geometry.
- Retained-but-closed Abyss source trees are excluded from initial routing.
- Requests resolve their output before implicit app-anchor lookup, so duplicated app surfaces prefer the source/request output while preserving Tray > Bar > Dock priority within that output.
- Equal-strength implicit anchor ties are treated as ambiguous and fall back instead of using registration order to guess which app instance owns a semantic prompt.
- If a top-center fallback output is hot-unplugged, the same request is retargeted to a remaining valid output. If the request had a real attached source on the removed output, it is cancelled instead of teleporting.
- The active request is retained until its visual retract tail is released, so queued requests cannot inherit the previous geometry. Owning-presenter teardown also releases an already-closing request so output/family removal cannot strand the queue.
- Renderer handoff can add a second semantic release gate on top of the visual-tail gate. A transferred request is hidden from the connected presenter without being semantically resolved; the standalone fail-safe later resolves/cancels that same `ConfirmationService` request, so `requestResolved` and the original action callback reflect the user's real choice. The queue slot remains held until both the old `StyledPopup` tail and the standalone semantic resolution are complete.
- Owner teardown uses forced lifecycle cancellation, so a disabled/hidden user cancel action cannot strand an owned request when its renderer disappears.
- Generic action semantics preserve enabled/visible state. Enter selects only a usable default/non-cancel action, user cancel does not invoke a disabled/hidden cancel action, and empty/duplicate action IDs are normalized so one visible button cannot resolve a different callback.
- `AbyssPromptHostRegistry` tracks concrete per-output prompt hosts only after their Abyss field has presented a usable frame. Configuration alone, or a mapped perimeter whose field/shader is not ready, never counts as a usable confirmation/authentication renderer.
- If `abyssPerimeter` is disabled or no frame-ready prompt host exists, the previous standalone confirmation/Polkit renderers remain available as a fail-safe rather than creating an invisible request.

### Phase C — normal confirmation

Implemented for the Hadalis-owned `closeConfirm` backend:

- the request is presented through a focused `StyledPopup`;
- source app IDs can attach the popup to a matching Tray/Bar/Dock anchor;
- same-app anchors on multiple outputs prefer the request/window output;
- a Dock source remains presented while its attached confirmation is active/retracting;
- unresolved or retained-but-closed sources use the output top-center anchor;
- top-center fallback ownership survives output hotplug by moving only to a remaining valid output, while attached-source loss still cancels;
- critical confirmation presentation keeps the popup field available over fullscreen and is not demoted beneath a native settings dialog;
- the real close callback still executes the existing Niri close/minimize path;
- repeated close triggers for the same window are deduplicated across visible, queued and retracting ownership, while different windows may still queue normally;
- all Abyss-family close confirmations enter the same semantic queue even when the connected host is temporarily unavailable; activation either uses the live connected host or transfers that exact request to the standalone renderer without dropping queued successors;
- renderer loss during an already-visible prompt transfers the same captured window identity and unresolved action transaction to standalone; accepting there invokes the original queued `close` callback rather than a second direct-close path, cancelling reports the original cancel action, and stale transferred prompts use lifecycle cancellation if their captured Niri window disappears;
- cancel, close/reopen, long content and long action labels use the same Abyss primitives and popup geometry; Details/Hide details labels follow the translation catalog.

This does **not** claim generic interception of application-native confirmations. ChatGPT Quit remains blocked on a trustworthy backend/native bridge that can expose the application's real confirmation semantics and suppress the original dialog without bypassing or duplicating it.

### Phase D — Polkit

Implemented on the existing Quickshell `PolkitAgent/AuthFlow` backend:

- no second authorization queue is created; Quickshell remains queue authority;
- Hadalis now lets Polkit perform the authoritative session-scoped agent registration instead of suppressing its agent from machine-global process-name guesses; this avoids false negatives when another user's/session's agent process exists;
- Enter/Escape, Cancel, Authenticate, identities, Details, failure messages and multi-turn prompts are preserved;
- pending state remains non-interactive until `AuthFlow` actually requires a response;
- the response field is cleared before handing the response to `AuthFlow.submit`, and is also cleared before switching authentication identity so a response cannot survive into the replacement PAM conversation;
- response text is not stored in Config, GlobalStates, the generic confirmation service, logs or persisted state;
- ordinary Polkit requests use top-center because `AuthFlow` does not expose a dependable requester app ID;
- Quickshell remains the authentication queue authority, while Abyss separately serializes only visual ownership: if the next AuthFlow starts synchronously, the previous popup keeps its latched model/anchor through retract before the successor latches its own output;
- source-loss cancellation is deduplicated so overlapping live-anchor and registry-removal signals cannot call the real AuthFlow cancel path twice;
- top-center Polkit fallback retargets to a remaining output after hotplug; an old output's retract callback cannot release presentation state now owned by the new output, and a trusted attached source disappearing with its output cancels the real AuthFlow instead of teleporting;
- the active critical prompt stays on the Overlay layer and keeps keyboard-focus eligibility even when a native settings dialog has made ordinary shell surfaces yield;
- Polkit prompt strings used by the Abyss renderer are registered in the English translation catalog;
- the legacy real-AuthFlow renderer is loaded from the Abyss critical host rather than the deferred `abyssPolkit` subtree, and it becomes active whenever the target output has no live connected prompt host; top-center Abyss presentation can therefore fail over without hiding an active authentication request;
- a future trusted source hint can use the same anchor resolver without changing the authentication backend, but hints are rejected while another AuthFlow/hint is already pending because current AuthFlow metadata provides no caller token that could safely bind a later hint to a queued request;
- trusted Polkit source hints can carry an output hint and receive the same same-output affinity as normal confirmations;
- if a trusted Polkit source disappears or becomes non-presented while authentication is active, the real AuthFlow is cancelled rather than moving the password prompt to another anchor.

### Phase E — runtime acceptance

A synthetic Wayland/Quickshell harness now exists at `scripts/test-abyss-confirmation-runtime.sh`. When run in a real Wayland session with Quickshell available, it exercises real `StyledPopup`/Abyss popup slots and real confirmation callbacks for:

- Top/Bottom/Left/Right source attachment and Join Edge inheritance;
- Tray-over-Dock identity precedence and Dock-only fallback;
- top-center fallback when no source resolves;
- long content width capping;
- source removal without teleport;
- coexistence with another popup and survival while that peer retracts;
- queued requests activating only after the predecessor's visual tail releases;
- close/reopen on the same source;
- retained-but-closed source rejection to top-center fallback;
- a still-registered source becoming non-presented while open, which cancels rather than teleporting;
- equal-strength duplicate source anchors falling back rather than choosing registration order;
- duplicate action IDs normalizing deterministically and invoking only the intended callback;
- renderer-handoff action semantics and queue gating: presentation transfer emits no fake cancel resolution; resolving the standalone handoff invokes exactly the original action callback/resolution, and its queued successor cannot activate until the old popup tail plus semantic handoff completion have both released ownership.

The script intentionally skips when Quickshell/Wayland is unavailable during ordinary local/static validation. The dedicated `.github/workflows/confirmation-runtime.yml` lane removes that ambiguity. Its runtime chain now validates: real Quickshell on headless Weston; a nested Weston compositor exposing two distinct Wayland outputs with layer-shell carriers bound to their real `ShellScreen`s; and the same single-output harness inside nested Niri on an Xvfb software-EGL parent. Source contracts, headless Wayland, two-output Wayland and nested-Niri jobs have all completed successfully on `dev`, including same-output Tray/Dock affinity, requested-output fallback, renderer-handoff and queue-gating cases.

This establishes automated Quickshell acceptance for source/output routing across two virtual Wayland outputs and automated Niri acceptance for the synthetic confirmation presenter. It is still not equivalent to physical monitor hotplug/focus changes or a real Polkit password exchange.

## Acceptance status

Source/contract coverage is complete for the currently trustworthy backends: request ownership, conservative identity/output anchor resolution, ambiguous-source fallback, live-source validity, Dock/Bar source hold, popup/Pyramid reuse, frame-ready prompt-host detection, fail-safe renderer handoff with preserved action semantics, two-gate visual/semantic queue release, fullscreen/native-dialog critical-prompt visibility, Join Edge inheritance, action availability/ID/callback safety, queue/reopen ownership, same-window close deduplication, stale-window rejection, output-hotplug policy, and Polkit focus/security, source-hint scoping, failover, queued-presentation and multi-turn retry behavior.

Automated confirmation runtime acceptance is now recorded on real Quickshell + headless Wayland, a two-output nested-Weston topology, and the same single-output harness inside nested Niri. Still requiring physical/system acceptance:

- physical monitor focus/output-hotplug behavior on target hardware (two-output routing itself is covered virtually);
- real Polkit password focus, wrong-password retry, Cancel, queued requests and successful authorization against the target system authentication stack;
- lock/unlock interaction with the actual login/lock stack;
- ChatGPT Quit or any other application-native confirmation only after a reliable native/backend interception path exists.

Do not mark the entire feature `production runtime complete` until those target-environment checks are recorded.
