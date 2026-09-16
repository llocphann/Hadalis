#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

recipe_value() {
  local file="$1"
  local key="$2"
  grep -m1 "^${key}=" "$file" | cut -d= -f2-
}

srcinfo_value() {
  local file="$1"
  local key="$2"
  sed -n "s/^[[:space:]]*${key} = //p" "$file" | head -1
}

repo_version="$(tr -d '[:space:]' < VERSION)"
stable_pkg="distro/arch/inir-shell/PKGBUILD"
stable_srcinfo="distro/arch/inir-shell/.SRCINFO"
git_pkg="distro/arch/inir-shell-git/PKGBUILD"
git_srcinfo="distro/arch/inir-shell-git/.SRCINFO"
meta_pkg="distro/arch/inir-meta/PKGBUILD"
meta_srcinfo="distro/arch/inir-meta/.SRCINFO"
nix_pkg="nix/package.nix"
stable_hook="distro/arch/inir-shell/inir-shell.install"
git_hook="distro/arch/inir-shell-git/inir-shell-git.install"
release_script="scripts/release.sh"
uninstall_doc="docs/UNINSTALL.md"

for file in "$stable_pkg" "$stable_srcinfo" "$git_pkg" "$git_srcinfo" "$meta_pkg" "$meta_srcinfo" "$nix_pkg" "$stable_hook" "$git_hook" "$release_script" "$uninstall_doc"; do
  [[ -f "$file" ]] || fail "missing packaging file: $file"
done

payload_list="$(python3 sdata/lib/runtime-payload.py list --root .)"
for test_script in scripts/test-*.sh; do
  [[ -e "$test_script" ]] || continue
  if grep -Fqx "$test_script" <<<"$payload_list"; then
    fail "runtime payload includes repository test script: $test_script"
  fi
done

for pair in \
  "$stable_pkg:$stable_srcinfo" \
  "$git_pkg:$git_srcinfo" \
  "$meta_pkg:$meta_srcinfo"; do
  recipe="${pair%%:*}"
  srcinfo="${pair#*:}"
  recipe_ver="$(recipe_value "$recipe" pkgver)"
  recipe_rel="$(recipe_value "$recipe" pkgrel)"
  srcinfo_ver="$(srcinfo_value "$srcinfo" pkgver)"
  srcinfo_rel="$(srcinfo_value "$srcinfo" pkgrel)"
  [[ "$recipe_ver" == "$srcinfo_ver" ]] || fail "$recipe pkgver differs from $srcinfo"
  [[ "$recipe_rel" == "$srcinfo_rel" ]] || fail "$recipe pkgrel differs from $srcinfo"
done

[[ "$(recipe_value "$stable_pkg" pkgver)" == "$repo_version" ]] \
  || fail 'inir-shell pkgver does not match VERSION'
[[ "$(recipe_value "$meta_pkg" pkgver)" == "$repo_version" ]] \
  || fail 'inir-meta pkgver does not match VERSION'

git_version="$(recipe_value "$git_pkg" pkgver)"
case "$git_version" in
  "$repo_version".r*) ;;
  *) fail "inir-shell-git pkgver seed does not follow VERSION: $git_version" ;;
esac

source_ref="$(sed -n 's/^_source_ref="${INIR_SOURCE_REF:-\([^}]*\)}"$/\1/p' "$stable_pkg")"
[[ -n "$source_ref" ]] || fail 'cannot read inir-shell default _source_ref'
git cat-file -e "${source_ref}^{commit}" 2>/dev/null \
  || fail "inir-shell source ref is not a local commit: $source_ref"
git merge-base --is-ancestor "$source_ref" HEAD \
  || fail "inir-shell source ref is not an ancestor of HEAD: $source_ref"
source_version="$(git show "$source_ref:VERSION" | tr -d '[:space:]')"
[[ "$source_version" == "$repo_version" ]] \
  || fail "inir-shell source snapshot VERSION=$source_version, repository VERSION=$repo_version"
for required_path in \
  shell.qml \
  qmldir \
  sdata/lib/runtime-payload.py \
  docs/INSTALL.md \
  docs/PACKAGES.md \
  docs/RELEASING.md; do
  git cat-file -e "$source_ref:$required_path" 2>/dev/null \
    || fail "inir-shell source snapshot lacks $required_path"
done

source_root_manifest="$(git show "$source_ref:sdata/runtime-root-files.txt")"
if ! grep -Fxq 'qmldir' <<<"$source_root_manifest"; then
  grep -Fq 'install -Dm644 "$srcroot/qmldir" "$shellroot/qmldir"' "$stable_pkg" \
    || fail 'inir-shell pinned snapshot omits qmldir and the package compatibility copy is missing'
fi

srcinfo_source="$(srcinfo_value "$stable_srcinfo" source)"
[[ "$srcinfo_source" == *"/archive/${source_ref}.tar.gz" ]] \
  || fail 'inir-shell .SRCINFO source archive drifted from _source_ref'

# The packaged color pipeline runs without the source installer's managed venv.
# Both direct Arch shell packages therefore need the generator's Python imports
# as package dependencies, with committed .SRCINFO kept in lockstep.
arch_python_required=(python-materialyoucolor python-numpy python-pillow)
for pair in \
  "$stable_pkg:$stable_srcinfo" \
  "$git_pkg:$git_srcinfo"; do
  recipe="${pair%%:*}"
  srcinfo="${pair#*:}"
  for package in "${arch_python_required[@]}"; do
    grep -Eq "^[[:space:]]+${package}$" "$recipe" \
      || fail "$recipe is missing color generator Python dependency: $package"
    grep -Fqx $'\tdepends = '"$package" "$srcinfo" \
      || fail "$srcinfo is missing color generator Python dependency: $package"
  done
done

# Release publication is fail-closed: after tag/source identity checks and
# before draft creation, the helper must run both packaging contract suites.
grep -Fq '"$script_dir/test-packaging-contract.sh"' "$release_script" \
  || fail 'release publish preflight no longer includes the packaging contract'
grep -Fq '"$script_dir/test-nix-module-contract.sh"' "$release_script" \
  || fail 'release publish preflight no longer includes the Nix module contract'
grep -Fq '  require_release_contracts' "$release_script" \
  || fail 'release publish path no longer executes release packaging contracts'

# inir-meta promises the full desktop experience. These packages represent
# default source-installer supplements across shell utilities, visuals, login,
# wallpaper tooling, task management, and critical fonts.
meta_required=(
  adwaita-icon-theme
  eza
  frameworkintegration
  gowall-bin
  hicolor-icon-theme
  kdecoration
  mission-center
  papirus-icon-theme
  qt6-avif-image-plugin
  sddm
  starship
  ttf-gabarito-git
)
for package in "${meta_required[@]}"; do
  grep -Eq "^[[:space:]]+${package}$" "$meta_pkg" \
    || fail "inir-meta is missing default full-experience dependency: $package"
  grep -Fqx $'\tdepends = '"$package" "$meta_srcinfo" \
    || fail "inir-meta .SRCINFO is missing dependency: $package"
done

cmp -s "$stable_hook" "$git_hook" || fail 'stable/git Arch lifecycle hooks differ'
for hook in "$stable_hook" "$git_hook"; do
  grep -Fq 'post_remove() {' "$hook" \
    || fail "$hook no longer explains per-user service cleanup after package removal"
  grep -Fq "-path '*.wants/inir.service' -type l -delete" "$hook" \
    || fail "$hook no longer provides dangling service-link cleanup"
  grep -Fq "run 'inir service disable' as each affected user" "$hook" \
    || fail "$hook no longer documents the safe pre-removal service step"
done

# Pacman owns the canonical user unit under /usr/lib/systemd/user. Both Arch
# recipes must patch their packaged launchers so compositor wiring targets that
# unit directly, legacy identical user copies are migrated away, custom user
# overrides are never silently deleted, and service uninstall stays package-owned.
for pkg in "$stable_pkg" "$git_pkg"; do
  grep -Fq 'local package_unit="/usr/lib/systemd/user/inir.service"' "$pkg" \
    || fail "$pkg no longer binds service lifecycle to the package-owned unit"
  grep -Fq 'cmp -s "$user_unit" "$package_unit"' "$pkg" \
    || fail "$pkg no longer safely migrates identical legacy user units"
  grep -Fq 'custom user inir.service shadows the package unit' "$pkg" \
    || fail "$pkg no longer preserves custom user service overrides"
  grep -Fq 'ln -sf "$package_unit" "$correct_link"' "$pkg" \
    || fail "$pkg no longer retargets existing enabled wiring during legacy-unit migration"
  grep -Fq 'ln -sf "/usr/lib/systemd/user/inir.service"' "$pkg" \
    || fail "$pkg no longer wires compositor startup to the package-owned unit"
  grep -Fq 'inir.service is owned by the pacman package' "$pkg" \
    || fail "$pkg can again uninstall package-owned service state through the launcher"
  grep -Fq 'install_end = text.find(install_next_marker, install_start)' "$pkg" \
    || fail "$pkg no longer replaces the complete install_user_service function"
  grep -Fq 'text = text[:install_start] + install_guard + text[install_end:]' "$pkg" \
    || fail "$pkg no longer slices out the legacy install_user_service body"
  grep -Fq 'bash -n "$launcher" || return' "$pkg" \
    || fail "$pkg no longer syntax-checks the transformed launcher"
  if grep -Fq 'text = text.replace(install_marker, install_guard, 1)' "$pkg"; then
    fail "$pkg again replaces only the install_user_service opening marker"
  fi
done

# NixOS/Home Manager own inir.service declaratively. The Nix packaging patch
# must prevent the packaged launcher from creating/removing a competing mutable
# user unit while keeping operational start/restart commands on the provisioned unit.
grep -Fq 'Nix-managed installations keep inir.service declarative' "$nix_pkg" \
  || fail 'Nix package no longer blocks mutable service ownership commands'
grep -Fq 'systemctl --user cat inir.service' "$nix_pkg" \
  || fail 'Nix package no longer validates the declarative inir.service before start/restart'
grep -Fq 'install|uninstall|remove|enable|disable)' "$nix_pkg" \
  || fail 'Nix service ownership guard no longer covers all mutating service commands'

# Teardown docs must preserve the ownership boundary across all install modes.
grep -Fq 'inir service disable' "$uninstall_doc" \
  || fail 'uninstall docs no longer remove per-user service wiring before manual/package removal'
grep -Fq 'inir service uninstall' "$uninstall_doc" \
  || fail 'uninstall docs no longer remove the manual make-install user unit before launcher removal'
grep -Fq 'sudo make uninstall' "$uninstall_doc" \
  || fail 'uninstall docs no longer document Makefile teardown'
grep -Fq '/usr/lib/systemd/user/inir.service' "$uninstall_doc" \
  || fail 'uninstall docs no longer identify pacman service ownership'
grep -Fq 'NixOS/Home Manager modules own `inir.service` declaratively' "$uninstall_doc" \
  || fail 'uninstall docs no longer preserve declarative Nix service ownership'
grep -Fq 'Run it as the user whose iNiR service was configured' "$uninstall_doc" \
  || fail 'uninstall docs no longer warn against root cross-home cleanup'
grep -Fq "-type l -path '*.wants/inir.service' -delete" "$uninstall_doc" \
  || fail 'uninstall docs no longer use the working stale wants-link cleanup glob'

printf '%s\n' '1..1'
printf '%s\n' 'ok 1 - packaging metadata and distribution contracts are coherent'
