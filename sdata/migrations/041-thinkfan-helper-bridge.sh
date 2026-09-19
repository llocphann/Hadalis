# Keep the Hadalis-owned ThinkFan helper/polkit bridge synchronized for
# repo-managed installs. This required migration is intentionally state-based:
# run_migrations_auto() re-runs it whenever either system payload is missing or
# differs from the repository asset, including installs that predate the bridge.

MIGRATION_ID="041-thinkfan-helper-bridge"
MIGRATION_TITLE="Reconcile Hadalis ThinkFan bridge"
MIGRATION_DESCRIPTION="Installs or repairs the Hadalis-owned ThinkFan helper and polkit action without modifying upstream ThinkFan packages, services, or configuration."
MIGRATION_TARGET_FILE="/usr/libexec/inir-thinkfan"
MIGRATION_REQUIRED=true

thinkfan_bridge_package_managed() {
  [[ "$(get_installed_update_strategy 2>/dev/null || true)" == "package-manager" ]]
}

migration_check() {
  local helper_src="${REPO_ROOT}/assets/helpers/inir-thinkfan"
  local policy_src="${REPO_ROOT}/assets/polkit/org.inir.thinkfan.policy"
  local helper_dst="/usr/libexec/inir-thinkfan"
  local policy_dst="/usr/share/polkit-1/actions/org.inir.thinkfan.policy"

  # Externally managed installs own their system payload through the package
  # manager. The source checkout must not overwrite those files.
  thinkfan_bridge_package_managed && return 1

  [[ -f "$helper_src" && -f "$policy_src" ]] || return 0
  [[ -x "$helper_dst" && -f "$policy_dst" ]] || return 0
  cmp -s "$helper_src" "$helper_dst" || return 0
  cmp -s "$policy_src" "$policy_dst" || return 0
  return 1
}

migration_preview() {
  echo -e "${STY_GREEN}+ sync /usr/libexec/inir-thinkfan${STY_RST}"
  echo -e "${STY_GREEN}+ sync /usr/share/polkit-1/actions/org.inir.thinkfan.policy${STY_RST}"
  echo -e "${STY_FAINT}  upstream thinkfan package/service/config: unchanged${STY_RST}"
}

migration_diff() {
  local helper_src="${REPO_ROOT}/assets/helpers/inir-thinkfan"
  local policy_src="${REPO_ROOT}/assets/polkit/org.inir.thinkfan.policy"
  local helper_dst="/usr/libexec/inir-thinkfan"
  local policy_dst="/usr/share/polkit-1/actions/org.inir.thinkfan.policy"

  echo "Current:"
  if [[ -x "$helper_dst" ]] && cmp -s "$helper_src" "$helper_dst"; then
    echo "  helper: up to date"
  elif [[ -e "$helper_dst" ]]; then
    echo "  helper: outdated"
  else
    echo "  helper: missing"
  fi

  if [[ -f "$policy_dst" ]] && cmp -s "$policy_src" "$policy_dst"; then
    echo "  polkit action: up to date"
  elif [[ -e "$policy_dst" ]]; then
    echo "  polkit action: outdated"
  else
    echo "  polkit action: missing"
  fi

  echo ""
  echo "After migration:"
  echo "  Hadalis helper + polkit action: synchronized"
  echo "  upstream ThinkFan package/service/config: unchanged"
}

migration_apply() {
  local helper_src="${REPO_ROOT}/assets/helpers/inir-thinkfan"
  local policy_src="${REPO_ROOT}/assets/polkit/org.inir.thinkfan.policy"
  local helper_dst="/usr/libexec/inir-thinkfan"
  local policy_dst="/usr/share/polkit-1/actions/org.inir.thinkfan.policy"

  if thinkfan_bridge_package_managed; then
    echo "ThinkFan bridge is package-managed; source migration left it untouched."
    return 0
  fi

  if ! migration_check; then
    return 0
  fi

  [[ -f "$helper_src" ]] || {
    echo "Hadalis ThinkFan helper asset is missing: $helper_src" >&2
    return 1
  }
  [[ -f "$policy_src" ]] || {
    echo "Hadalis ThinkFan polkit policy asset is missing: $policy_src" >&2
    return 1
  }

  pkg_sudo install -Dm755 "$helper_src" "$helper_dst" || return 1
  pkg_sudo install -Dm644 "$policy_src" "$policy_dst" || return 1

  echo "Hadalis ThinkFan helper and polkit action synchronized; upstream ThinkFan state was not changed."
}
