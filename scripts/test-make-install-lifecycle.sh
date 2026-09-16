#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

stage="$(mktemp -d)"
trap 'rm -rf -- "$stage"' EXIT

source_fingerprint() {
  {
    git status --porcelain=v1 --untracked-files=all
    git diff --no-ext-diff --binary -- .
  } | sha256sum | awk '{print $1}'
}

source_before="$(source_fingerprint)"

prefix=/opt/inir
systemd_user_dir="$prefix/lib/systemd/user"
libexecdir="$prefix/libexec"
polkit_actions_dir="$prefix/share/polkit-1/actions"
tlp_confdir="$prefix/etc/tlp.d"
system_share="$prefix/share/inir"

make_args=(
  "DESTDIR=$stage"
  "PREFIX=$prefix"
  "SYSTEMD_USER_DIR=$systemd_user_dir"
  "LIBEXECDIR=$libexecdir"
  "POLKIT_ACTIONS_DIR=$polkit_actions_dir"
  "TLP_CONFDIR=$tlp_confdir"
  "INIR_SYSTEM_SHAREDIR=$system_share"
)

make -s install "${make_args[@]}"

source_after_install="$(source_fingerprint)"
if [[ "$source_after_install" != "$source_before" ]]; then
  printf 'FAIL: make install mutated the source checkout\n' >&2
  git status --short --untracked-files=all >&2 || true
  git diff --summary -- . >&2 || true
  exit 1
fi

expected_files=(
  "$stage$prefix/bin/inir"
  "$stage$prefix/share/quickshell/inir/shell.qml"
  "$stage$prefix/share/quickshell/inir/qmldir"
  "$stage$prefix/share/quickshell/inir/version.json"
  "$stage$systemd_user_dir/inir.service"
  "$stage$prefix/share/applications/inir.desktop"
  "$stage$prefix/share/applications/inir-settings.desktop"
  "$stage$prefix/share/icons/hicolor/scalable/apps/inir.svg"
  "$stage$prefix/share/doc/inir-shell/README.md"
  "$stage$prefix/share/doc/inir-shell/AUDIO_MEDIA.md"
  "$stage$prefix/share/doc/inir-shell/INSTALL.md"
  "$stage$prefix/share/doc/inir-shell/PACKAGES.md"
  "$stage$prefix/share/doc/inir-shell/RELEASING.md"
  "$stage$prefix/share/doc/inir-shell/UNINSTALL.md"
  "$stage$prefix/share/licenses/inir-shell/LICENSE"
  "$stage$libexecdir/inir-battery-charge-limit"
  "$stage$libexecdir/inir-thinkfan"
  "$stage$polkit_actions_dir/org.inir.battery-charge-limit.policy"
  "$stage$polkit_actions_dir/org.inir.thinkfan.policy"
  "$stage$system_share/tlp-settings-schema.json"
)

for path in "${expected_files[@]}"; do
  [[ -e "$path" ]] || {
    printf 'FAIL: staged install missing %s\n' "$path" >&2
    exit 1
  }
done

battery_helper="$stage$libexecdir/inir-battery-charge-limit"
battery_policy="$stage$polkit_actions_dir/org.inir.battery-charge-limit.policy"
thinkfan_policy="$stage$polkit_actions_dir/org.inir.thinkfan.policy"
grep -Fxq "config_dir=$tlp_confdir" "$battery_helper" || {
  printf 'FAIL: staged battery helper does not use configured TLP directory\n' >&2
  exit 1
}
grep -Fxq "tlp_settings_schema=$system_share/tlp-settings-schema.json" "$battery_helper" || {
  printf 'FAIL: staged battery helper does not use configured TLP schema path\n' >&2
  exit 1
}
grep -Fq ">${libexecdir}/inir-battery-charge-limit</annotate>" "$battery_policy" || {
  printf 'FAIL: staged battery polkit policy does not use configured helper path\n' >&2
  exit 1
}
grep -Fq ">${libexecdir}/inir-thinkfan</annotate>" "$thinkfan_policy" || {
  printf 'FAIL: staged ThinkFan polkit policy does not use configured helper path\n' >&2
  exit 1
}

# Exercise teardown of managed TLP drop-ins inside the staging root. Package
# installation does not create them, but a live source install can own them.
printf '%s\n' '# staged battery lifecycle contract' > "$stage$tlp_confdir/99-inir-battery-charge-limit.conf"
printf '%s\n' '# staged TLP settings lifecycle contract' > "$stage$tlp_confdir/99-inir-tlp-settings.conf"

# The staged install must remain entirely inside DESTDIR. This catches install
# targets that accidentally write to the host when packagers use a staging root.
if find "$stage" -mindepth 1 -maxdepth 1 ! -name opt -print -quit | grep -q .; then
  printf 'FAIL: staged install wrote outside the configured /opt prefix\n' >&2
  find "$stage" -mindepth 1 -maxdepth 2 -print >&2
  exit 1
fi

make -s uninstall "${make_args[@]}"

source_after_uninstall="$(source_fingerprint)"
if [[ "$source_after_uninstall" != "$source_before" ]]; then
  printf 'FAIL: make uninstall mutated the source checkout\n' >&2
  git status --short --untracked-files=all >&2 || true
  git diff --summary -- . >&2 || true
  exit 1
fi

for path in "${expected_files[@]}"; do
  if [[ -e "$path" || -L "$path" ]]; then
    printf 'FAIL: staged uninstall left %s\n' "$path" >&2
    exit 1
  fi
done

for dropin in \
  "$stage$tlp_confdir/99-inir-battery-charge-limit.conf" \
  "$stage$tlp_confdir/99-inir-tlp-settings.conf"; do
  if [[ -e "$dropin" || -L "$dropin" ]]; then
    printf 'FAIL: staged uninstall left managed TLP drop-in %s\n' "$dropin" >&2
    exit 1
  fi
done

# Empty parent directories are harmless, but no managed payload file may remain.
if find "$stage$prefix" -type f -o -type l 2>/dev/null | grep -q .; then
  printf 'FAIL: staged uninstall left managed files behind\n' >&2
  find "$stage$prefix" \( -type f -o -type l \) -print >&2
  exit 1
fi

printf '%s\n' '1..1'
printf '%s\n' 'ok 1 - make install/uninstall staging lifecycle is coherent'
