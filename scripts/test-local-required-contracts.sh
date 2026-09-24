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
translation_service=services/Translation.qml
[[ ! -e scripts/ai/gemini-translate.sh ]] \
    || fail 'retired multilingual Gemini runtime generator was restored'
require_contains 'readonly property var availableLanguages: ["en_US"]' "$translation_service" \
    'Translation service must expose only canonical en_US'
require_contains 'readonly property string languageCode: "en_US"' "$translation_service" \
    'Translation service languageCode must remain canonical en_US'
require_contains 'path: `${Quickshell.shellPath("translations")}/en_US.json`' "$translation_service" \
    'Translation service must load the canonical en_US catalog directly'
require_contains 'property bool isLoading: translationFileView.loadPending' "$translation_service" \
    'Translation service must preserve catalog load state'
require_contains 'root.translations?.[key] ?? key' "$translation_service" \
    'Translation service must fall back to source strings for missing English entries'
require_contains '"translations/tools"' sdata/runtime-exclusions.json \
    'source-only translation tooling leaked into runtime payload policy'
for retired in \
    TranslationScanner \
    scanGeneratedLanguagesProcess \
    availableGeneratedLanguages \
    allAvailableLanguages \
    isScanning; do
    if grep -Fq "$retired" "$translation_service"; then
        fail "English-only Translation service restored multilingual runtime machinery: $retired"
    fi
done

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
    require_contains 'Pacman does not modify user home directories. The live QML compatibility path is:' "$install_hook" \
        "$install_hook no longer explains the live QML config path and ownership boundary"
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
for policy in \
    assets/polkit/org.inir.thinkfan.policy \
    assets/polkit/org.inir.battery-charge-limit.policy; do
    require_contains '<allow_any>no</allow_any>' "$policy" \
        "$policy must deny non-local/non-session authorization"
    require_contains '<allow_inactive>no</allow_inactive>' "$policy" \
        "$policy must deny inactive-session authorization"
    require_contains '<allow_active>yes</allow_active>' "$policy" \
        "$policy must allow the active local session without a password prompt"
    if grep -Fq 'auth_admin' "$policy"; then
        fail "$policy must not restore password-gated administrator authorization"
    fi
done

require_contains 'cmp -s "$policy" "$installed_policy"' \
    sdata/migrations/037-battery-charge-limit-helper.sh \
    'battery helper migration must detect a changed installed polkit policy'
require_contains 'pkg_sudo install -Dm644 "$policy" /usr/share/polkit-1/actions/org.inir.battery-charge-limit.policy' \
    sdata/migrations/037-battery-charge-limit-helper.sh \
    'battery helper migration must refresh the installed polkit policy'
require_contains 'cmp -s "$policy_src" "$policy_dst"' \
    sdata/migrations/041-thinkfan-helper-bridge.sh \
    'ThinkFan bridge migration must detect a changed installed polkit policy'
require_contains 'pkg_sudo install -Dm644 "$policy_src" "$policy_dst"' \
    sdata/migrations/041-thinkfan-helper-bridge.sh \
    'ThinkFan bridge migration must refresh the installed polkit policy'

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
