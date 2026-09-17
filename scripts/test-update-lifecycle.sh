#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() {
    printf 'not ok - %s\n' "$1" >&2
    exit 1
}

setup_file="$repo_root/setup"
robust="$repo_root/sdata/lib/robust-update.sh"
snapshots="$repo_root/sdata/lib/snapshots.sh"
payload_tool="$repo_root/sdata/lib/runtime-payload.py"
updates_service="$repo_root/services/Updates.qml"
release_script="$repo_root/scripts/release.sh"
nix_package="$repo_root/nix/package.nix"
arch_package="$repo_root/distro/arch/inir-shell/PKGBUILD"
arch_package_srcinfo="$repo_root/distro/arch/inir-shell/.SRCINFO"
arch_git_package="$repo_root/distro/arch/inir-shell-git/PKGBUILD"
arch_git_srcinfo="$repo_root/distro/arch/inir-shell-git/.SRCINFO"
arch_meta_package="$repo_root/distro/arch/inir-meta/PKGBUILD"
arch_meta_srcinfo="$repo_root/distro/arch/inir-meta/.SRCINFO"
arch_dependency_installer="$repo_root/sdata/dist-arch/install-deps.sh"
arch_dependency_meta="$repo_root/sdata/dist-arch/inir-deps/PKGBUILD"

for required in \
    "$setup_file" "$robust" "$snapshots" "$payload_tool" "$updates_service" "$release_script" \
    "$nix_package" \
    "$arch_package" "$arch_package_srcinfo" \
    "$arch_git_package" "$arch_git_srcinfo" \
    "$arch_meta_package" "$arch_meta_srcinfo" \
    "$arch_dependency_installer" "$arch_dependency_meta"; do
    [[ -f "$required" ]] || fail "missing lifecycle file: ${required#$repo_root/}"
done

# The generic Wayland variable must never be used as the update/rollback
# compositor gate; KDE and GNOME export it too.
if grep -Fq '[[ -n "$NIRI_SOCKET" ]] || [[ -n "$WAYLAND_DISPLAY" ]]' "$setup_file"; then
    fail 'setup still treats WAYLAND_DISPLAY as a supported compositor gate'
fi
if grep -Fq '[[ -n "$NIRI_SOCKET" ]] || [[ -n "$WAYLAND_DISPLAY" ]]' "$snapshots"; then
    fail 'snapshot restore still treats WAYLAND_DISPLAY as a supported compositor gate'
fi

# Restart and rollback must go through the lifecycle owner, never fire-and-forget.
if grep -Fq 'nohup systemctl --user restart inir.service' "$setup_file" \
        || grep -Fq 'nohup qs -p "${II_TARGET}"' "$setup_file"; then
    fail 'setup update still performs an asynchronous unverified restart'
fi
if grep -Fq 'nohup qs -p "$runtime_target"' "$snapshots"; then
    fail 'snapshot restore still starts an unsupervised Quickshell instance'
fi

grep -Fq 'restart_updated_shell "$II_TARGET"' "$setup_file" \
    || fail 'setup update does not use the verified launcher restart helper'
grep -Fq 'sync_launcher_from_repo' "$setup_file" \
    || fail 'setup update does not preserve repo-link launcher topology'
grep -Fq 'runtime-payload.py" sync-dir' "$setup_file" \
    || fail 'setup update does not use the canonical runtime payload policy'

# Package-managed payloads must preserve package-manager launcher ownership.
# Otherwise `inir migrate` can materialize a stale raw launcher in ~/.local/bin
# and shadow the launcher that pacman/Nix updates on the next package upgrade.
for package_recipe in "$arch_package" "$arch_git_package"; do
    grep -Fq 'get_installed_update_strategy 2>/dev/null || true' "$package_recipe" \
        || fail "Arch package can shadow its packaged launcher during migrate: ${package_recipe#$repo_root/}"
done

# Every committed Arch PKGBUILD must agree with its generated .SRCINFO on the
# version tuple. A stale pkgrel/pkgver here makes AUR/package-manager metadata
# disagree with the recipe that will actually be built.
check_arch_srcinfo() {
    local recipe="$1"
    local srcinfo="$2"
    local recipe_ver recipe_rel srcinfo_ver srcinfo_rel
    recipe_ver="$(grep -m1 '^pkgver=' "$recipe" | cut -d= -f2-)"
    recipe_rel="$(grep -m1 '^pkgrel=' "$recipe" | cut -d= -f2-)"
    srcinfo_ver="$(sed -n 's/^[[:space:]]*pkgver = //p' "$srcinfo" | head -1)"
    srcinfo_rel="$(sed -n 's/^[[:space:]]*pkgrel = //p' "$srcinfo" | head -1)"
    [[ "$recipe_ver" == "$srcinfo_ver" ]] \
        || fail "Arch pkgver drift: ${recipe#$repo_root/}=$recipe_ver, ${srcinfo#$repo_root/}=$srcinfo_ver"
    [[ "$recipe_rel" == "$srcinfo_rel" ]] \
        || fail "Arch pkgrel drift: ${recipe#$repo_root/}=$recipe_rel, ${srcinfo#$repo_root/}=$srcinfo_rel"
}
check_arch_srcinfo "$arch_package" "$arch_package_srcinfo"
check_arch_srcinfo "$arch_git_package" "$arch_git_srcinfo"
check_arch_srcinfo "$arch_meta_package" "$arch_meta_srcinfo"

# The non-VCS Arch package's generated metadata must use the same immutable
# source ref as the PKGBUILD. This catches source URL drift even between releases.
arch_source_ref="$(sed -n 's/^_source_ref="${INIR_SOURCE_REF:-\([^}]*\)}"$/\1/p' "$arch_package")"
arch_srcinfo_source="$(sed -n 's/^[[:space:]]*source = //p' "$arch_package_srcinfo" | head -1)"
[[ -n "$arch_source_ref" && -n "$arch_srcinfo_source" ]] \
    || fail 'could not resolve Arch non-VCS package source metadata'
[[ "$arch_srcinfo_source" == *"/archive/${arch_source_ref}.tar.gz" ]] \
    || fail 'Arch .SRCINFO source URL drifted from PKGBUILD _source_ref'
[[ "${arch_srcinfo_source%%::*}" == *"-${arch_source_ref}.tar.gz" ]] \
    || fail 'Arch .SRCINFO archive filename drifted from PKGBUILD _source_ref'

# The dependency tracker is built during setup. Version injection must happen in
# a temporary staged recipe so installation cannot dirty a source checkout.
repo_version="$(tr -d '[:space:]' < "$repo_root/VERSION")"
dependency_meta_version="$(grep -m1 '^pkgver=' "$arch_dependency_meta" | cut -d= -f2-)"
[[ "$dependency_meta_version" == "$repo_version" ]] \
    || fail "inir-deps pkgver=$dependency_meta_version does not match VERSION=$repo_version"
grep -Fqx "url='https://github.com/llocphann/Hadalis'" "$arch_dependency_meta" \
    || fail 'inir-deps still advertises a non-Hadalis repository'
grep -Fq 'inir-deps) continue ;;' "$arch_dependency_installer" \
    || fail 'Arch installer can resolve aggregate tracker dependencies as an install group'
grep -Fq '_meta_build_dir="$(mktemp -d)"' "$arch_dependency_installer" \
    || fail 'Arch installer does not stage the dependency meta-package build'
grep -Fq 'cp -- "$_meta_dir/PKGBUILD" "$_meta_build_dir/PKGBUILD"' "$arch_dependency_installer" \
    || fail 'Arch installer does not copy the dependency meta recipe into staging'
grep -Fq 'sed -i "s/^pkgver=.*/pkgver=${_inir_ver}/" "$_meta_build_dir/PKGBUILD"' "$arch_dependency_installer" \
    || fail 'Arch installer does not patch the staged dependency meta recipe'
grep -Fq 'for _meta_dep in "${depends[@]}"; do' "$arch_dependency_installer" \
    || fail 'Arch installer does not filter dependency tracker entries by installed packages'
grep -Fq 'pacman -Q "$_meta_pkg"' "$arch_dependency_installer" \
    || fail 'Arch installer does not verify tracked packages are installed'
grep -Fq 'pkg_sudo pacman -U --noconfirm "${local_pkg[0]}"' "$arch_dependency_installer" \
    || fail 'Arch installer does not refresh dependency tracker metadata on rerun'
grep -Fq 'rm -rf -- "$_meta_build_dir"' "$arch_dependency_installer" \
    || fail 'Arch installer does not clean the dependency meta staging directory'
if grep -Fq 'sed -i "s/^pkgver=.*/pkgver=${_inir_ver}/" "$_meta_dir/PKGBUILD"' "$arch_dependency_installer"; then
    fail 'Arch installer still mutates the tracked dependency meta PKGBUILD'
fi
if grep -Fq 'pacman -Udd' "$arch_dependency_installer"; then
    fail 'Arch dependency tracker still bypasses dependency verification'
fi
if grep -Fq 'pacman -U --noconfirm --needed "${local_pkg[0]}"' "$arch_dependency_installer"; then
    fail 'Arch dependency tracker can skip same-version metadata refreshes'
fi

# Nix packages are immutable/package-managed. Their runtime metadata must make
# setup/status defer payload updates to Nix, and packaged migrate must not copy
# the raw launcher into ~/.local/bin where it would shadow the wrapped launcher.
grep -Fq '"installMode": "package-managed"' "$nix_package" \
    || fail 'Nix package does not emit package-managed runtime metadata'
grep -Fq '"updateStrategy": "package-manager"' "$nix_package" \
    || fail 'Nix package does not defer updates to the package manager'
grep -Fq '"packageManager": "nix"' "$nix_package" \
    || fail 'Nix package metadata does not identify Nix ownership'
grep -Fq 'get_installed_update_strategy 2>/dev/null || true' "$nix_package" \
    || fail 'Nix package can shadow its wrapped launcher during migrate'

# Release tooling must be location-independent: callers commonly invoke the
# script by absolute path from outside the checkout. Publishing is fail-closed:
# validate first, stage/reuse a draft, sync the Wiki, then make the release public.
release_version="$(tr -d '[:space:]' < "$repo_root/VERSION")"
release_notes="$tmp/release-notes.md"
(
    cd "$tmp"
    bash "$release_script" notes "$release_version" release-notes.md
)
grep -Fq 'Update: https://github.com/llocphann/Hadalis/blob/stable/docs/SETUP.md#update' "$release_notes" \
    || fail 'release notes generation lost the update documentation link'
grep -Fq 'Fresh install: https://github.com/llocphann/Hadalis/blob/stable/docs/INSTALL.md' "$release_notes" \
    || fail 'release notes generation lost the install documentation link'
python3 - "$release_script" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text()
version_consistency = text.split('require_release_version_consistency() {', 1)[1].split('\n}\n\nrequire_release_source_pin() {', 1)[0]
if 'sdata/dist-arch/inir-deps/PKGBUILD' not in version_consistency:
    raise SystemExit('release version preflight must include the dependency tracker package')

source_pin = text.split('require_release_source_pin() {', 1)[1].split('\n}\n\nrequire_release_checkout() {', 1)[0]
if '[[ "$source_ref" == "$tag" ]]' not in source_pin:
    raise SystemExit('release package source pin must equal the immutable release tag')
if '.SRCINFO' not in source_pin or '/archive/${tag}.tar.gz' not in source_pin:
    raise SystemExit('release source preflight must verify tagged .SRCINFO archive metadata')

stage = text.split('stage_release_draft() {', 1)[1].split('\n}\n\npublish_release() {', 1)[0]
state_probe = stage.find('gh release view "$tag"')
reuse = stage.find('gh release edit "$tag"')
create = stage.find('gh release create "$tag"')
draft_flag = stage.find('--draft', create)
verify = stage.rfind('gh release view "$tag"')
if min(state_probe, reuse, create, draft_flag, verify) < 0:
    raise SystemExit('release draft staging must probe state, reuse drafts, create drafts, and verify draft state')
if state_probe >= verify:
    raise SystemExit('release draft state must be verified after staging')
if 'already exists and is published' not in stage:
    raise SystemExit('release draft staging must refuse to overwrite a published release')

publish = text.split('publish_release() {', 1)[1].split('\n}\n\nmain() {', 1)[0]
preflight = publish.find('require_release_version_consistency "$version"')
tag_check = publish.find('rev-parse --verify "$tag"')
checkout = publish.find('require_release_checkout "$tag"')
source_pin_call = publish.find('require_release_source_pin "$tag"')
stage_call = publish.find('stage_release_draft "$tag" "$notes_file"')
wiki = publish.find('"$script_dir/wiki-sync.sh" publish')
make_public = publish.find('gh release edit "$tag" --repo "$github_repo" --draft=false')
positions = (preflight, tag_check, checkout, source_pin_call, stage_call, wiki, make_public)
if min(positions) < 0 or list(positions) != sorted(positions):
    raise SystemExit('release publish ordering must be preflight -> tag -> checkout -> source pin -> draft -> Wiki -> public release')
PY

# Inspect the exact already-up-to-date and completion ordering rather than just
# grepping for functions that may occur in unrelated commands.
python3 - "$setup_file" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text()
marker = 'elif [[ "$installed_commit" == "$repo_commit" ]]; then'
if marker not in text:
    raise SystemExit('missing already-up-to-date branch')
block = text.split(marker, 1)[1].split('# Local repo ahead of installed - create snapshot', 1)[0]
if 'run_migrations_auto' not in block:
    raise SystemExit('required migrations are not applied in already-up-to-date branch')
if '_write_update_status "success"' not in block:
    raise SystemExit('already-up-to-date branch has no terminal success marker')
if block.index('run_migrations_auto') > block.index('_write_update_status "success"'):
    raise SystemExit('success is written before required migrations')

run = text.split('run_update() {', 1)[1].split('\n###############################################################################\n# Doctor', 1)[0]
restart = run.rfind('restart_updated_shell "$II_TARGET"')
version = run.rfind('set_installed_version "$repo_ver" "$repo_commit" "update"')
success = run.rfind('_write_update_status "success"')
if restart < 0 or version < restart or success < version:
    raise SystemExit('update completion ordering must be restart -> version metadata -> success')
PY

# Arch's checkupdates uses exit 2 for the normal "nothing to update" state.
# Keep the availability probe self-contained in the declared shell dependency
# instead of requiring the separate `which` package.
grep -Fq 'command: ["/usr/bin/sh", "-c", "command -v checkupdates >/dev/null 2>&1"]' "$updates_service" \
    || fail 'updates availability probe still depends on an external which executable'
if grep -Fq 'command: ["which", "checkupdates"]' "$updates_service"; then
    fail 'updates availability probe regressed to the undeclared which dependency'
fi
python3 - "$updates_service" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text()
process = text.split('id: checkUpdatesProc', 1)[1]
on_exit = process.split('onExited:', 1)[1]
no_updates = on_exit.find('if (exitCode === 2)')
clear_count = on_exit.find('root.count = 0;', no_updates)
error_branch = on_exit.find('if (exitCode !== 0)', no_updates)
if no_updates < 0 or clear_count < no_updates or error_branch < clear_count:
    raise SystemExit('checkupdates exit 2 must clear stale count before the genuine error branch')
PY

# Runtime payload manifest must exclude source-only tests/tooling while retaining
# actual launch/runtime files. This prevents install/update payload drift.
python3 "$payload_tool" manifest --root "$repo_root" > "$tmp/manifest"
grep -q '^shell.qml:' "$tmp/manifest" || fail 'runtime manifest is missing shell.qml'
grep -q '^scripts/inir:' "$tmp/manifest" || fail 'runtime manifest is missing scripts/inir'
for excluded in \
    scripts/qml-check.fish \
    scripts/test-local-distribution.sh \
    scripts/test-battery-charge-limit-helper.sh \
    scripts/test-tlp-integration-lifecycle.sh \
    scripts/test-tlp-settings-ui-guards.sh \
    scripts/test-update-lifecycle.sh; do
    if grep -q "^${excluded}:" "$tmp/manifest"; then
        fail "source-only file leaked into runtime manifest: $excluded"
    fi
done

# Exercise the verifier with a fake qs process. A fatal startup must fail, a
# startup marker followed by a long-running shell succeeds, and a silent hang
# must fail rather than being treated as healthy.
mkdir -p "$tmp/bin" "$tmp/xdg/quickshell/inir" "$tmp/state"
printf '%s\n' '// probe shell' > "$tmp/xdg/quickshell/inir/shell.qml"
cat > "$tmp/bin/qs" <<'EOF_QS'
#!/usr/bin/env bash
case "${MOCK_QS_MODE:-fatal}" in
    fatal)
        printf '%s\n' 'Error: Type MissingSingleton unavailable'
        exit 1
        ;;
    boot)
        printf '%s\n' '[Boot] T+0ms: Component.onCompleted (shell.qml ready)'
        sleep 5
        ;;
    silent)
        sleep 5
        ;;
    *) exit 2 ;;
esac
EOF_QS
chmod +x "$tmp/bin/qs"

export PATH="$tmp/bin:$PATH"
export XDG_CONFIG_HOME="$tmp/xdg"
export XDG_STATE_HOME="$tmp/state"
export REPO_ROOT="$repo_root"
log_info() { :; }
log_success() { :; }
log_warning() { :; }
log_error() { :; }
# shellcheck disable=SC1090
source "$robust"

export MOCK_QS_MODE=fatal
if verify_qs_loads 1 "$tmp/xdg/quickshell/inir" >/dev/null 2>&1; then
    fail 'fatal Quickshell probe was accepted'
fi

export MOCK_QS_MODE=boot
if ! verify_qs_loads 1 "$tmp/xdg/quickshell/inir" >/dev/null 2>&1; then
    fail 'healthy startup marker was rejected'
fi

export MOCK_QS_MODE=silent
if verify_qs_loads 1 "$tmp/xdg/quickshell/inir" >/dev/null 2>&1; then
    fail 'silent Quickshell timeout was accepted'
fi

printf '%s\n' '1..1'
printf '%s\n' 'ok 1 - updater lifecycle is fail-closed and payload policy is consistent'
