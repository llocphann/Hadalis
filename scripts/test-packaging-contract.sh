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

for file in "$stable_pkg" "$stable_srcinfo" "$git_pkg" "$git_srcinfo" "$meta_pkg" "$meta_srcinfo" "$nix_pkg"; do
  [[ -f "$file" ]] || fail "missing packaging file: $file"
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
  sdata/lib/runtime-payload.py \
  docs/INSTALL.md \
  docs/PACKAGES.md \
  docs/RELEASING.md; do
  git cat-file -e "$source_ref:$required_path" 2>/dev/null \
    || fail "inir-shell source snapshot lacks $required_path"
done

srcinfo_source="$(srcinfo_value "$stable_srcinfo" source)"
[[ "$srcinfo_source" == *"/archive/${source_ref}.tar.gz" ]] \
  || fail 'inir-shell .SRCINFO source archive drifted from _source_ref'

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

cmp -s distro/arch/inir-shell/inir-shell.install distro/arch/inir-shell-git/inir-shell-git.install \
  || fail 'stable/git Arch lifecycle hooks differ'

# NixOS/Home Manager own inir.service declaratively. The Nix packaging patch
# must prevent the packaged launcher from creating/removing a competing mutable
# user unit while keeping operational start/restart commands on the provisioned unit.
grep -Fq 'Nix-managed installations keep inir.service declarative' "$nix_pkg" \
  || fail 'Nix package no longer blocks mutable service ownership commands'
grep -Fq 'systemctl --user cat inir.service' "$nix_pkg" \
  || fail 'Nix package no longer validates the declarative inir.service before start/restart'
grep -Fq 'install|uninstall|remove|enable|disable)' "$nix_pkg" \
  || fail 'Nix service ownership guard no longer covers all mutating service commands'

printf '%s\n' '1..1'
printf '%s\n' 'ok 1 - packaging metadata and distribution contracts are coherent'
