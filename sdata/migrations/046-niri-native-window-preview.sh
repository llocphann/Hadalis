#!/usr/bin/env bash
# Build/install the Hadalis-owned Niri preview plugin for repo-managed Arch
# installs. This adds one QML module; it does not replace or patch Quickshell.

MIGRATION_ID="046-niri-native-window-preview"
MIGRATION_TITLE="Enable native Niri window previews"
MIGRATION_DESCRIPTION="Builds the Hadalis ext-image-copy-capture QML plugin used for adaptive live Overview previews on Niri."
MIGRATION_TARGET_FILE="/usr/share/inir/niri-preview-plugin"
MIGRATION_REQUIRED=true

_niri_preview_package_managed() {
  [[ "$(get_installed_update_strategy 2>/dev/null || true)" == "package-manager" ]]
}

_niri_preview_supported_host() {
  command -v pacman >/dev/null 2>&1 \
    && command -v makepkg >/dev/null 2>&1 \
    && { command -v niri >/dev/null 2>&1 || [[ -n "${NIRI_SOCKET:-}" ]]; }
}

_niri_preview_expected() {
  [[ -f /usr/share/inir/niri-preview-plugin ]] \
    && grep -Fq 'version=0.1.0-4' /usr/share/inir/niri-preview-plugin \
    && [[ -f /usr/lib/qt6/qml/Hadalis/NiriPreview/qmldir ]] \
    && [[ -f /usr/lib/qt6/qml/Hadalis/NiriPreview/libhadalisniripreviewplugin.so ]]
}

migration_check() {
  # Package-managed installs must gain this through their package metadata; a
  # source checkout must never overwrite package-manager ownership.
  _niri_preview_package_managed && return 1
  _niri_preview_supported_host || return 1
  _niri_preview_expected && return 1
  return 0
}

migration_preview() {
  echo -e "${STY_GREEN}+ build/install inir-niri-preview 0.1.0-4${STY_RST}"
  echo "  Native protocols: ext-foreign-toplevel-list + ext-image-copy-capture"
  echo "  Quickshell package/runtime: unchanged"
  echo "  Existing PNG previews remain the fallback"
}

migration_diff() {
  if _niri_preview_expected; then
    echo "Hadalis native Niri preview plugin is already up to date."
  elif _niri_preview_package_managed; then
    echo "Package-managed install: native plugin ownership is left to the package manager."
  elif _niri_preview_supported_host; then
    echo "Native Niri preview plugin is missing or outdated."
  else
    echo "Automatic native Niri preview installation is only enabled on repo-managed Arch/Niri systems."
  fi
}

migration_apply() {
  if ! migration_check; then
    return 0
  fi

  local package_src="${REPO_ROOT}/distro/arch/inir-niri-preview"
  [[ -f "${package_src}/PKGBUILD" && -d "${package_src}/plugin" ]] || {
    echo "Missing native Niri preview package sources: ${package_src}" >&2
    return 1
  }

  local work
  work="$(mktemp -d -t inir-niri-preview.XXXXXX)" || return 1
  trap 'rm -rf "$work"' RETURN
  cp -a "${package_src}/." "$work/" || return 1

  echo "Building Hadalis native Niri preview plugin..."
  (
    cd "$work"
    makepkg --syncdeps --install --needed --noconfirm --cleanbuild
  ) || {
    echo -e "${STY_YELLOW}Could not build/install inir-niri-preview automatically.${STY_RST}" >&2
    echo "Retry with: cd '${package_src}' && makepkg -si --cleanbuild" >&2
    return 1
  }

  _niri_preview_expected || {
    echo "inir-niri-preview installed without the expected QML capability payload." >&2
    return 1
  }

  echo "Native Niri preview plugin installed; the next Hadalis restart will enable adaptive capture."
}
