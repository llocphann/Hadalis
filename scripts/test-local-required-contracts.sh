#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

fail() {
    printf 'FAIL: local required contract: %s\n' "$1" >&2
    exit 1
}

require_contains() {
    local needle="$1" file="$2" message="$3"
    grep -Fq -- "$needle" "$file" || fail "$message"
}

require_exact() {
    local line="$1" file="$2" message="$3"
    grep -Fxq -- "$line" "$file" || fail "$message"
}

printf '== translation runtime boundary ==\n'
generator=scripts/ai/gemini-translate.sh
translation_service=services/Translation.qml
require_contains 'SOURCE_FILE="${TRANSLATIONS_DIR}/en_US.json"' "$generator" \
    'runtime locale generation no longer anchors to en_US.json'
require_contains 'if [[ ! "$TARGET_LOCALE" =~ ^[A-Za-z]{2,3}([_-][A-Za-z0-9]{2,8})*$ ]]; then' "$generator" \
    'runtime locale generation no longer validates locale identifiers'
require_contains '--slurpfile source "$SOURCE_FILE"' "$generator" \
    'runtime locale generation no longer merges against the source catalog'
require_contains '"translations/tools"' sdata/runtime-exclusions.json \
    'source-only translation tooling leaked into runtime payload policy'
if grep -Fq 'translations/tools/manage-translations.sh' "$generator"; then
    fail 'runtime locale generator depends on source-only translation tooling'
fi
require_contains 'scanLanguagesProcess.running || scanGeneratedLanguagesProcess.running' "$translation_service" \
    'Translation service no longer represents both locale scan processes'
require_contains 'fallbackLanguages: []' "$translation_service" \
    'Translation service fallback locale contract drifted'
require_contains 'scanGeneratedLanguagesProcess.running = true' "$translation_service" \
    'Translation service no longer starts generated-locale discovery'

printf '== package and release source identity ==\n'
for pkg in \
    distro/arch/inir-shell/PKGBUILD \
    distro/arch/inir-shell-git/PKGBUILD \
    distro/arch/inir-meta/PKGBUILD; do
    require_contains "url='https://github.com/llocphann/Hadalis'" "$pkg" \
        "$pkg no longer identifies the Hadalis repository"
    if grep -Fqi 'github.com/snowarch/inir' "$pkg"; then
        fail "$pkg still sources the upstream iNiR repository"
    fi
done
require_contains 'github.com/llocphann/Hadalis/archive/${_source_ref}.tar.gz' distro/arch/inir-shell/PKGBUILD \
    'stable Arch source archive no longer points at Hadalis'
require_contains 'git+https://github.com/llocphann/Hadalis.git#branch=dev' distro/arch/inir-shell-git/PKGBUILD \
    'git Arch package no longer tracks Hadalis dev'
require_exact 'install=inir-shell.install' distro/arch/inir-shell/PKGBUILD \
    'stable Arch package install hook identity drifted'
require_exact 'install=inir-shell-git.install' distro/arch/inir-shell-git/PKGBUILD \
    'git Arch package install hook identity drifted'

for info in \
    distro/arch/inir-shell/.SRCINFO \
    distro/arch/inir-shell-git/.SRCINFO \
    distro/arch/inir-meta/.SRCINFO; do
    require_contains 'url = https://github.com/llocphann/Hadalis' "$info" \
        "$info no longer identifies the Hadalis repository"
    if grep -Fqi 'github.com/snowarch/inir' "$info"; then
        fail "$info still advertises the upstream iNiR repository"
    fi
done
require_contains 'install = inir-shell.install' distro/arch/inir-shell/.SRCINFO \
    'stable .SRCINFO install hook identity drifted'
require_contains 'install = inir-shell-git.install' distro/arch/inir-shell-git/.SRCINFO \
    'git .SRCINFO install hook identity drifted'
require_contains 'license = GPL-3.0-only' distro/arch/inir-shell-git/.SRCINFO \
    'git .SRCINFO license metadata drifted'
require_contains 'source = inir::git+https://github.com/llocphann/Hadalis.git#branch=dev' distro/arch/inir-shell-git/.SRCINFO \
    'git .SRCINFO source identity drifted'
require_contains 'optdepends = thinkfan: managed fan-control integration' distro/arch/inir-shell/.SRCINFO \
    'stable package no longer advertises ThinkFan integration'
require_contains 'optdepends = thinkfan: managed fan-control integration' distro/arch/inir-shell-git/.SRCINFO \
    'git package no longer advertises ThinkFan integration'

for pkg in inir-shell inir-meta; do
    pkgbuild="distro/arch/$pkg/PKGBUILD"
    srcinfo="distro/arch/$pkg/.SRCINFO"
    pkgver="$(grep -m1 '^pkgver=' "$pkgbuild" | cut -d= -f2-)"
    pkgrel="$(grep -m1 '^pkgrel=' "$pkgbuild" | cut -d= -f2-)"
    require_contains "pkgver = $pkgver" "$srcinfo" "$pkg srcinfo pkgver drifted"
    require_contains "pkgrel = $pkgrel" "$srcinfo" "$pkg srcinfo pkgrel drifted"
done

for install_hook in \
    distro/arch/inir-shell/inir-shell.install \
    distro/arch/inir-shell-git/inir-shell-git.install; do
    require_contains 'inir service enable' "$install_hook" \
        "$install_hook no longer enables the user service"
    require_contains 'inir service start' "$install_hook" \
        "$install_hook no longer starts the user service"
    require_contains 'The running QML shell currently stores user config in:' "$install_hook" \
        "$install_hook no longer explains the live QML config path"
    require_contains '~/.config/illogical-impulse/config.json' "$install_hook" \
        "$install_hook live QML config path drifted"
    if grep -Fq 'Package-managed installs keep user config in:' "$install_hook"; then
        fail "$install_hook misstates the live QML config path"
    fi
done

release_script=scripts/release.sh
wiki_script=scripts/wiki-sync.sh
require_contains 'https://github.com/llocphann/Hadalis/blob/stable/docs/SETUP.md#update' "$release_script" \
    'release helper update documentation URL drifted'
require_contains 'https://github.com/llocphann/Hadalis/blob/stable/docs/INSTALL.md' "$release_script" \
    'release helper install documentation URL drifted'
require_contains 'https://github.com/llocphann/Hadalis/blob/stable/CHANGELOG.md' "$release_script" \
    'release helper changelog URL drifted'
require_contains 'wiki_url="https://github.com/llocphann/Hadalis.wiki.git"' "$wiki_script" \
    'Wiki publication target drifted'
if grep -Fqi 'github.com/snowarch/inir' "$release_script" "$wiki_script"; then
    fail 'release tooling still targets the upstream iNiR repository'
fi

printf '== non-Nix package documentation payload ==\n'
require_contains 'for doc in docs/*.md; do' Makefile \
    'make install no longer installs the documentation set'
require_contains 'for doc in "$srcroot"/docs/*.md; do' distro/arch/inir-shell/PKGBUILD \
    'stable Arch package no longer installs the documentation set'
require_contains 'for doc in "$srcroot"/docs/*.md; do' distro/arch/inir-shell-git/PKGBUILD \
    'git Arch package no longer installs the documentation set'

printf '== privileged integration package payload ==\n'
require_contains 'org.freedesktop.policykit.exec.path">/usr/libexec/inir-thinkfan' \
    assets/polkit/org.inir.thinkfan.policy \
    'ThinkFan polkit action no longer targets the installed helper'
for pkg in distro/arch/inir-shell/PKGBUILD distro/arch/inir-shell-git/PKGBUILD; do
    for marker in \
        'assets/applications/inir-settings.desktop' \
        '$pkgdir/usr/share/applications/inir-settings.desktop' \
        'distro/arch/inir-shell/inir-quickshell-rebuild.hook' \
        '$pkgdir/usr/share/libalpm/hooks/inir-quickshell-rebuild.hook' \
        'assets/helpers/inir-battery-charge-limit' \
        '$pkgdir/usr/libexec/inir-battery-charge-limit' \
        'assets/polkit/org.inir.battery-charge-limit.policy' \
        'assets/tlp/tlp-settings-schema.json' \
        'assets/helpers/inir-thinkfan' \
        '$pkgdir/usr/libexec/inir-thinkfan' \
        'assets/polkit/org.inir.thinkfan.policy'; do
        require_contains "$marker" "$pkg" "$pkg is missing packaged integration marker: $marker"
    done
done

printf '== ThinkFan process timeout lifecycle ==\n'
python3 - services/ThinkFanService.qml <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")
required = [
    "detectorTimeout.restart()",
    'root._clearStatus("status-timeout")',
    "id: detectorTimeout",
    "interval: 5000",
    "detector.timedOut = true",
    "detector.running = false",
    "applyTimeout.restart()",
    "root.lastApplySucceeded = exitCode === 0 && !applyProcess.timedOut",
    '? "apply-timeout"',
    "id: applyTimeout",
    "interval: 60000",
    "applyProcess.timedOut = true",
    "applyProcess.running = false",
]
missing = [marker for marker in required if marker not in text]
if missing:
    raise SystemExit("FAIL: ThinkFan timeout/recovery contract missing: " + ", ".join(missing))
PY

printf '== non-Nix startup and staged install plan ==\n'
service_unit=assets/systemd/inir.service
require_exact 'Type=dbus' "$service_unit" 'canonical user service must remain D-Bus activated'
require_exact 'BusName=org.kde.StatusNotifierWatcher' "$service_unit" 'canonical user service bus ownership drifted'
require_exact 'After=graphical-session-pre.target' "$service_unit" 'canonical user service startup ordering drifted'
require_exact 'Before=graphical-session.target' "$service_unit" 'canonical user service no longer gates graphical-session startup'
if grep -Fxq 'After=graphical-session.target' "$service_unit"; then
    fail 'canonical user service starts too late for tray ownership'
fi

install_plan="$(make -n install PREFIX=/usr DESTDIR=/tmp/inir-stage-test)"
for staged_path in \
    /tmp/inir-stage-test/usr/bin/inir \
    /tmp/inir-stage-test/usr/share/quickshell/inir \
    /tmp/inir-stage-test/usr/lib/systemd/user/inir.service \
    /tmp/inir-stage-test/usr/share/applications/inir.desktop \
    /tmp/inir-stage-test/usr/share/doc/inir-shell/README.md \
    /tmp/inir-stage-test/usr/share/licenses/inir-shell/LICENSE \
    /tmp/inir-stage-test/usr/libexec/inir-battery-charge-limit \
    /tmp/inir-stage-test/usr/libexec/inir-thinkfan; do
    grep -Fq "$staged_path" <<<"$install_plan" \
        || fail "make install dry-run omits staged path: $staged_path"
done

printf '== Arch dependency recipe identity ==\n'
repo_version="$(tr -d '[:space:]' < VERSION)"
deps_version="$(grep -m1 '^pkgver=' sdata/dist-arch/inir-deps/PKGBUILD | cut -d= -f2-)"
[[ "$deps_version" == "$repo_version" ]] \
    || fail "inir-deps pkgver=$deps_version does not match VERSION=$repo_version"

printf '%s\n' '1..1'
printf '%s\n' 'ok 1 - formerly hosted-only required local contracts are enforced in-repo'
