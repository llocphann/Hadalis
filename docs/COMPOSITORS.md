# Compositor Integration

Hadalis is a **Niri-only** Quickshell desktop shell. Historical fork provenance may mention Hyprland, but there is no supported Hyprland runtime, fallback backend, package dependency, or compositor-specific feature branch in the current product.

## Runtime contract

`NiriService` owns compositor IPC. It opens the socket exposed through `$NIRI_SOCKET`, subscribes to Niri's JSON event stream, and updates reactive QML state for:

- workspaces and their output assignment;
- windows, focus, layout and workspace membership;
- outputs, scale and geometry;
- keyboard layout state;
- Overview state and config reload events.

Commands such as focusing workspaces/windows, moving windows, closing windows, monitor power and config reload are sent through the Niri IPC/action path.

`CompositorService` is now a small shared façade over Niri. It keeps common shell consumers decoupled from sorting/filtering implementation details, but it is **not** a compositor selector.

## Startup requirement

The shell must receive a valid `NIRI_SOCKET` before Quickshell instantiates compositor-dependent services. `scripts/inir` recovers the socket from the runtime directory when the systemd user environment has not imported it yet.

If `NIRI_SOCKET` is unavailable, Hadalis may start in a degraded/disconnected state for diagnostics, but that is not an alternate compositor mode.

## Niri configuration

Hadalis manages Niri configuration through modular KDL files under `~/.config/niri/config.d/`:

| File | What it controls |
|---|---|
| `10-input-and-cursor.kdl` | Mouse, touchpad, keyboard and cursor |
| `20-layout-and-overview.kdl` | Workspace layout, gaps and struts |
| `30-window-rules.kdl` | Window rules |
| `40-environment.kdl` | Session environment |
| `50-startup.kdl` | Managed startup entries |
| `60-animations.kdl` | Niri animations |
| `70-binds.kdl` | Hadalis/Niri keybinds |
| `80-layer-rules.kdl` | Layer-shell rules |
| `90-user-extra.kdl` | User-owned overrides |

`scripts/niri-config.py` performs surgical edits and preserves comments and unknown settings.

## Contributor rules

- Do not add compositor detection branches or alternate compositor backends.
- Use `NiriService` for Niri-specific state/actions.
- Use `CompositorService` only where its shared sorting/filtering/monitor helpers are the appropriate API.
- Niri-only features may still gate on `CompositorService.isNiri` when they need to distinguish a connected IPC session from a disconnected startup state.
- Test compositor-facing work on Niri. There is no secondary compositor smoke-test requirement.

Historical migrations can still contain retired compositor names because migrations are append-only. Migration `051-niri-only-compositor` removes obsolete service wiring from upgraded installations.
