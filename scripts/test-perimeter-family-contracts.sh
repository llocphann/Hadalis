#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
shell="$root/shell.qml"
critical="$root/modules/ii/critical/ShellIiCriticalPanels.qml"
abyss="$root/modules/abyss/critical/ShellAbyssCriticalPanels.qml"
waffle="$root/modules/waffle/critical/ShellWaffleCriticalPanels.qml"
backdrop="$root/modules/background/Backdrop.qml"
niri_layers="$root/defaults/niri/config.d/80-layer-rules.kdl"
migration="$root/sdata/migrations/052-abyss-overview-backdrop-layer-rule.sh"

fail() {
    printf 'FAIL: panel family contract: %s\n' "$1" >&2
    exit 1
}

for file in "$shell" "$critical" "$abyss" "$waffle" "$backdrop" "$niri_layers" "$migration"; do
    [[ -f "$file" ]] || fail "missing ${file#$root/}"
done

for token in \
    'source: "modules/ii/critical/ShellIiCriticalPanels.qml"' \
    'source: "ShellIiPanels.qml"' \
    'source: "modules/waffle/critical/ShellWaffleCriticalPanels.qml"' \
    'source: "ShellWafflePanels.qml"' \
    'property list<string> families: ["abyss", "waffle"]'; do
    grep -Fq "$token" "$shell" || fail "shell family routing missing: $token"
done

if grep -Fq 'iiPerimeter' "$shell" || grep -Fq 'PerimeterRuntime' "$shell"; then
    fail 'retired perimeter runtime must not become a shell panel family'
fi

for token in \
    '../../screenCorners/ScreenEdges.qml' \
    '../../background/Background.qml' \
    '../../bar/Bar.qml' \
    '../../verticalBar/VerticalBar.qml' \
    '../../dock/Dock.qml'; do
    grep -Fq "$token" "$critical" || fail "ii critical family lost supported surface: $token"
done

for token in \
    '../../background/Background.qml' \
    '../../background/Backdrop.qml' \
    'Config.options?.background?.backdrop?.enable ?? false'; do
    grep -Fq "$token" "$abyss" || fail "Abyss background lost stable overview wallpaper path: $token"
done

for token in \
    'WlrLayershell.namespace: "quickshell:iiBackdrop"' \
    'WlrLayershell.layer: WlrLayer.Background' \
    'WlrLayershell.exclusionMode: ExclusionMode.Ignore'; do
    grep -Fq "$token" "$backdrop" || fail "shared backdrop surface contract missing: $token"
done

for token in \
    'match namespace="quickshell:iiBackdrop"' \
    'place-within-backdrop true'; do
    grep -Fq "$token" "$niri_layers" || fail "Niri overview backdrop rule missing: $token"
done

for token in \
    'MIGRATION_REQUIRED=true' \
    'quickshell:iiBackdrop' \
    'quickshell:wBackdrop' \
    'place-within-backdrop true'; do
    grep -Fq "$token" "$migration" || fail "overview backdrop migration missing: $token"
done

migration_tmp="$(mktemp -d)"
trap 'rm -rf -- "$migration_tmp"' EXIT
mkdir -p "$migration_tmp/monolithic/niri"
cat > "$migration_tmp/monolithic/niri/config.kdl" <<'KDL'
// existing user Niri config
layout { background-color "transparent" }
// commented examples must not count as installed rules:
// match namespace="quickshell:iiBackdrop"
KDL
(
    export XDG_CONFIG_HOME="$migration_tmp/monolithic"
    # shellcheck source=/dev/null
    source "$migration"
    migration_check || fail 'migration must detect missing monolithic backdrop rules'
    migration_apply || fail 'migration failed to repair monolithic Niri config'
    if migration_check; then
        fail 'migration still reports missing rules after apply'
    fi
    migration_apply || fail 'migration must be idempotent'
    ii_count="$(grep -Fc 'match namespace="quickshell:iiBackdrop"' "$XDG_CONFIG_HOME/niri/config.kdl" || true)"
    waffle_count="$(grep -Fc 'match namespace="quickshell:wBackdrop"' "$XDG_CONFIG_HOME/niri/config.kdl" || true)"
    [[ "$ii_count" == 2 ]] || fail "expected one active iiBackdrop rule plus one commented fixture, got $ii_count total matches"
    [[ "$waffle_count" == 1 ]] || fail "expected exactly one wBackdrop rule, got $waffle_count"
)

mkdir -p "$migration_tmp/modular/niri/config.d"
cat > "$migration_tmp/modular/niri/config.kdl" <<'KDL'
include "config.d/80-layer-rules.kdl"
KDL
cat > "$migration_tmp/modular/niri/config.d/80-layer-rules.kdl" <<'KDL'
layer-rule {
    match namespace="quickshell:wBackdrop"
    place-within-backdrop true
    opacity 1.0
}
KDL
(
    export XDG_CONFIG_HOME="$migration_tmp/modular"
    # shellcheck source=/dev/null
    source "$migration"
    migration_check || fail 'migration must detect missing modular iiBackdrop rule'
    migration_apply || fail 'migration failed to repair modular Niri config'
    grep -Fq 'match namespace="quickshell:iiBackdrop"' "$XDG_CONFIG_HOME/niri/config.d/80-layer-rules.kdl" \
        || fail 'migration did not repair the active modular layer-rule file'
    if grep -Fq 'quickshell:iiBackdrop' "$XDG_CONFIG_HOME/niri/config.kdl"; then
        fail 'migration must not inject the rule into root config when 80-layer-rules.kdl exists'
    fi
)

if grep -Fq 'SidebarEdgeConnectors.qml' "$critical"; then
    fail 'critical ii family must not revive the retired standalone Sidebar bridge window'
fi

printf 'PASS: Material aliases to Abyss; Abyss keeps the stable Niri overview wallpaper backdrop; upgrade migration self-heals Niri layer rules; Waffle stays isolated\n'
