# Desktop-wide Vietnamese Telex (Fcitx5)

Hadalis integrates the native Fcitx5 + Unikey input method at the Niri/Wayland session level, rather than implementing a Telex algorithm separately in QML. The same engine is available to QuickShell and supported Qt, GTK, browser, terminal, and XWayland applications.

## Setup

On Arch, run the normal Hadalis setup/update to install fcitx5, fcitx5-qt, fcitx5-gtk, fcitx5-unikey and fcitx5-configtool. The default Niri session exports QT_IM_MODULE=fcitx and XMODIFIERS=@im=fcitx, imports these into the systemd user manager, and starts the helper through the launcher command: inir input-method start. Native GTK on Wayland retains its text-input-v3 path; GTK_IM_MODULE is not forced globally.

The helper creates an initial English-US + Unikey profile and Unicode Telex settings only if the respective files are absent. It preserves existing Fcitx profiles, Unikey preferences, and other IME frameworks; it does not restart an already running daemon. Existing users with a custom Fcitx profile must add Unikey using fcitx5-configtool if it is not already configured.

The updater patches preserved Niri configurations only when their relevant values/commands are missing. Existing IME values remain authoritative. For currently running sessions, setup invokes the helper immediately if possible. Log out/in and restart already-running applications to adopt new desktop environment variables.

## Hadalis Keyboard Settings

Open Hadalis Settings → Compositor → Input → Keyboard, then expand
**Vietnamese input · Fcitx5**. This is an embedded settings section, not a
second Fcitx tray app.

- Read the live Fcitx5 status and start it if necessary.
- Add Unikey to an existing default group on explicit request, preserving other
  input methods and the rest of the profile. Custom profiles that cannot be
  edited safely direct you to Advanced Settings.
- Switch the current input context between English and Unikey, choose Telex
  or VNI, and restore Unicode (UTF-8) output.
- Type directly into the test field, refresh status, or open the upstream
  Fcitx5 configuration UI for global shortcuts and advanced engine options.

Changes are written to the user's Fcitx configuration under
~/.config/fcitx5/ only; Niri's physical XKB layout stays independent.
The backend updates only the targeted option and requests a D-Bus reload
without killing the daemon or replacing the rest of the Unikey preferences.
If the reload is unavailable, Settings reports that the saved change needs
a later reload. A missing package is displayed in place rather than
silently presenting an inactive toggle.

Focused regression: python3 scripts/test-fcitx5-settings-integration.py

## Bar icon and operation

The icon is the single native Fcitx5 StatusNotifierItem in Hadalis's existing System Tray, pinned inline with neighboring status indicators. The ii Bar tints it monochrome; Waffle pins the same native item in its own tray. Click/right-click uses Fcitx's real actions and menu, not a separate simulated icon. The normal Ctrl+Space shortcut switches between English and Unikey; customize it and the engine in fcitx5-configtool.

The Hadalis on-screen keyboard still sends keycodes via ydotool; the focused application's native input context handles composition. Code Workflow retains NORMAL/VISUAL hjkl navigation; Unicode/IME composition belongs to INSERT. AI Chat prevents Enter/Tab submit actions during a pending preedit.

## Acceptance

Run the focused regression with: python3 scripts/test-fcitx5-session-integration.py
Run the full local validator with: bash scripts/validate-maintainer-local.sh

Then verify on a live Niri desktop: a single interactive icon in both tray families; Vietnamese composition and caret edits in Quick Notes, Notepad, AI Chat, Settings, a Qt/GTK application and Firefox; native keyboard plus OSK input; Code Workflow hjkl navigation and INSERT Telex; and idempotent setup. Electron/Flatpak and proprietary apps may require application-specific Wayland/IME configuration. A static PASS does not substitute for live compositor testing.

Upstream guidance: https://fcitx-im.org/wiki/Using_Fcitx_5_on_Wayland/en
