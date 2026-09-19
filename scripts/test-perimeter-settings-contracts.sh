#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
settings="$root/modules/settings/ShellLayoutConfig.qml"
registry="$root/modules/settings/SettingsPageRegistryData.qml"

fail() {
    printf 'FAIL: perimeter settings retirement contract: %s\n' "$1" >&2
    exit 1
}

[[ -f "$settings" ]] || fail 'missing modules/settings/ShellLayoutConfig.qml'
[[ -f "$registry" ]] || fail 'missing modules/settings/SettingsPageRegistryData.qml'

grep -Fq 'component: "modules/settings/ShellLayoutConfig.qml"' "$registry" \
    || fail 'Shell Layout page is no longer routed through the settings registry'
grep -Fq 'title: Translation.tr("Live shell layout")' "$settings" \
    || fail 'supported live shell layout controls were removed'
grep -Fq 'ShellLayoutController.surfacesForFamily' "$settings" \
    || fail 'Shell Layout no longer uses the supported live layout controller'
grep -Fq 'ShellEditSession.enter("")' "$settings" \
    || fail 'live desktop editor entrypoint was removed'
grep -Fq 'visible: surfaceSection.sidebarRole' "$settings" \
    || fail 'sidebar sizing controls were removed with perimeter cleanup'

for retired in \
    'Connected Perimeter' \
    'Use Connected Perimeter runtime' \
    'PerimeterCutoverPolicy' \
    'PerimeterConfig' \
    'PerimeterTopology' \
    'iiPerimeter' \
    'qs.modules.common.perimeter'; do
    if grep -Fq "$retired" "$settings"; then
        fail "retired cutover setting/API remains in ShellLayoutConfig.qml: $retired"
    fi
done

printf 'PASS: perimeter settings retirement contracts\n'
