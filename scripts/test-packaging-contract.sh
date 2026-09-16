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
makefile="Makefile"
release_script="scripts/release.sh"
packaging_workflow=".github/workflows/packaging.yml"
audio_doc="docs/AUDIO_MEDIA.md"
uninstall_doc="docs/UNINSTALL.md"

for file in "$stable_pkg" "$stable_srcinfo" "$git_pkg" "$git_srcinfo" "$meta_pkg" "$meta_srcinfo" "$nix_pkg" "$stable_hook" "$git_hook" "$makefile" "$release_script" "$packaging_workflow" "$audio_doc" "$uninstall_doc"; do
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
  docs/AUDIO_MEDIA.md \
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

# The primary local aggregate should exercise the same fast release-boundary
# contracts even when hosted CI cannot start a runner.
grep -Fq 'test-optional-audio-deps test-equalizer-contracts test-docs' "$makefile" \
  || fail 'make test-local no longer includes optional-audio, Equalizer, and docs gates'
grep -Fq 'test-package-hooks test-battery-helper test-thinkfan-helper' "$makefile" \
  || fail 'make test-local no longer includes privileged helper contracts'
grep -Fq '@bash scripts/test-equalizer-boundary-contract.sh' "$makefile" \
  || fail 'make test-local no longer runs the Equalizer architecture boundary contract'
grep -Fq '@bash scripts/test-equalizer-service-contract.sh' "$makefile" \
  || fail 'make test-local no longer runs the Equalizer lifecycle/protocol contract'
grep -Fq '@bash scripts/verify-docs.sh' "$makefile" \
  || fail 'make test-local no longer runs documentation verification'

# Release publication is fail-closed: after tag/source identity checks and
# before draft creation, the helper must verify hosted publication prerequisites
# and run all packaging/dependency contracts.
grep -Fq 'require_release_host_features() {' "$release_script" \
  || fail 'release helper no longer defines hosted publication preflight'
grep -Fq '.has_wiki' "$release_script" \
  || fail 'release hosted preflight no longer verifies GitHub Wiki availability'
grep -Fq 'GitHub Wiki is disabled' "$release_script" \
  || fail 'release hosted preflight no longer fails clearly when Wiki is disabled'
grep -Fq 'GIT_TERMINAL_PROMPT=0 git ls-remote "$wiki_url" HEAD' "$release_script" \
  || fail 'release hosted preflight no longer verifies non-interactive Wiki Git access'
grep -Fq 'GitHub Wiki repository is not initialized' "$release_script" \
  || fail 'release hosted preflight no longer detects an uninitialized Wiki repository'
grep -Fq 'git user.name and git user.email must be configured' "$release_script" \
  || true
