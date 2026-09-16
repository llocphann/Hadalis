#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
core_policy="$root/modules/common/perimeter/PerimeterCutoverPolicy.qml"
core_qmldir="$root/modules/common/perimeter/qmldir"
feature_qmldir="$root/modules/perimeter/qmldir"
critical="$root/modules/ii/critical/ShellIiCriticalPanels.qml"
left_sidebar="$root/modules/sidebarLeft/SidebarLeft.qml"
right_sidebar="$root/modules/sidebarRight/SidebarRight.qml"

fail() {
    printf 'FAIL: perimeter contract: %s\n' "$1" >&2
    exit 1
}

for file in "$core_policy" "$core_qmldir" "$feature_qmldir" \
        "$critical" "$left_sidebar" "$right_sidebar"; do
    [[ -f "$file" ]] || fail "missing ${file#"$root/"}"
done

grep -Fxq 'singleton PerimeterCutoverPolicy 1.0 PerimeterCutoverPolicy.qml' \
    "$core_qmldir" || fail 'core cutover policy is not exported'
if grep -Fq 'PerimeterRuntimePolicy' "$feature_qmldir"; then
    fail 'feature package owns obsolete cutover policy'
fi

for token in \
    'readonly property bool requested:' \
    'readonly property bool configurationValid:' \
    'readonly property bool sourcesReady:' \
    'readonly property bool enabled:' \
    'readonly property bool fallbackActive:' \
    'readonly property string statusReason:'; do
    grep -Fq "$token" "$core_policy" || fail "policy missing $token"
done
grep -Fq 'ModuleRegistry.validateConfiguredModules(' "$core_policy" \
    || fail 'policy does not require resolvable placed modules'

grep -Fq 'readonly property bool perimeterEnabled: PerimeterCutoverPolicy.enabled' \
    "$critical" || fail 'critical chrome does not gate on cutover policy'
grep -Fq 'PerimeterFeatureRegistry.registerAll()' "$critical" \
    || fail 'critical chrome does not bootstrap perimeter feature sources'
grep -Fq 'function onModuleRegistered(moduleId: string): void {' "$critical" \
    || fail 'critical bootstrap does not heal overwritten sources'
grep -Fq 'function onModuleUnregistered(moduleId: string): void {' "$critical" \
    || fail 'critical bootstrap does not heal removed sources'

for sidebar in "$left_sidebar" "$right_sidebar"; do
    grep -Fq 'readonly property bool perimeterEnabled: PerimeterCutoverPolicy.enabled' \
        "$sidebar" || fail "$(basename "$sidebar") bypasses cutover policy"
    if grep -Fq 'includes("iiPerimeter")' "$sidebar"; then
        fail "$(basename "$sidebar") directly gates on perimeter sentinel"
    fi
done

printf 'PASS: perimeter cutover contracts\n'
