#!/usr/bin/env bash
# Install the Hadalis Quickshell overlay required for true Niri per-window live
# previews. This is a package-manager-owned replacement for the stock quickshell
# package, not an unmanaged /usr/local binary.

MIGRATION_ID="046-niri-live-preview-quickshell"
MIGRATION_TITLE="Enable Niri live window previews"
MIGRATION_DESCRIPTION="Builds the pinned Quickshell 0.3.1 Hadalis runtime with ext-foreign-toplevel + ext-image-copy-capture support, enabling exact Niri window live previews."
MIGRATION_TARGET_FILE="/usr/share/inir/quickshell-niri-live"
MIGRATION_REQUIRED=true

_niri_live_arch_host() {
  command -v pacman >/dev/null 2>&1 && command -v makepkg >/dev/null 2>&1
}

_niri_live_relevant() {
  # Hadalis is Niri-first, but do not replace Quickshell on systems without Niri.
  command -v niri >/dev/null 2>&1 || [[ -n "${NIRI_SOCKET:-}" ]]
}

migration_check() {
  _niri_live_arch_host || return 1
  _niri_live_relevant || return 1

  [[ -f /usr/share/inir/quickshell-niri-live ]] || return 0
  grep -Fq 'hadalis_patch=foreign-toplevel-icc-v2' \
    /usr/share/inir/quickshell-niri-live || return 0
  pacman -Q inir-quickshell-niri >/dev/null 2>&1 || return 0
  return 1
}

migration_preview() {
  echo -e "${STY_GREEN}+ build/install inir-quickshell-niri 0.3.1-2${STY_RST}"
  echo "  Replaces stock quickshell through pacman Provides/Conflicts."
  echo "  Adds ext-foreign-toplevel → ext-image-copy-capture for exact Niri window IDs."
  echo "  Existing Hadalis snapshot previews remain the fallback if capture is unavailable."
}

migration_diff() {
  if [[ -f /usr/share/inir/quickshell-niri-live ]]       && pacman -Q inir-quickshell-niri >/dev/null 2>&1; then
    echo "Hadalis Niri live-preview Quickshell is already installed."
  else
    echo "Stock/unpatched Quickshell is active; Niri Overview can only use PNG snapshots."
  fi
}

migration_apply() {
  if ! migration_check; then
    return 0
  fi

  local package_src="${REPO_ROOT}/distro/arch/inir-quickshell-niri"
  [[ -f "${package_src}/PKGBUILD" ]] || {
    echo "Missing Hadalis Niri Quickshell package recipe: ${package_src}/PKGBUILD" >&2
    return 1
  }

  local work
  work="$(mktemp -d -t inir-quickshell-niri.XXXXXX)" || return 1
  trap 'rm -rf "$work"' RETURN
  cp -a "${package_src}/." "$work/" || return 1

  echo "Building Hadalis Quickshell Niri ICC runtime..."
  (
    cd "$work"
    makepkg --syncdeps --install --needed --noconfirm --cleanbuild
  ) || {
    echo -e "${STY_YELLOW}Could not install inir-quickshell-niri automatically.${STY_RST}" >&2
    echo "Retry with: cd '${package_src}' && makepkg -si --cleanbuild" >&2
    return 1
  }

  [[ -f /usr/share/inir/quickshell-niri-live ]] || {
    echo "inir-quickshell-niri installed without its capability marker." >&2
    return 1
  }

  echo "Niri live-preview Quickshell installed. The next Hadalis restart will enable ICC previews."
}
