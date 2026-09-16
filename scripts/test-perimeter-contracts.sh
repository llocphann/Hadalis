#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
core_policy="$root/modules/common/perimeter/PerimeterCutoverPolicy.qml"
core_registry="$root/modules/common/perimeter/ModuleRegistry.qml"
perimeter_config="$root/modules/common/perimeter/PerimeterConfig.qml"
core_qmldir="$root/modules/common/perimeter/qmldir"
feature_qmldir="$root/modules/perimeter/qmldir"
presentation_policy="$root/modules/perimeter/PerimeterPresentationPolicy.qml"
reservation_policy="$root/modules/perimeter/PerimeterReservationPolicy.qml"
runtime="$root/modules/perimeter/PerimeterRuntime.qml"
sidebar_module="$root/modules/perimeter/SidebarModule.qml"
thinkfan_module="$root/modules/perimeter/ThinkFanModule.qml"
system_monitor_module="$root/modules/perimeter/SystemMonitorModule.qml"
workspaces_module="$root/modules/perimeter/WorkspacesModule.qml"
media_module="$root/modules/perimeter/MediaModule.qml"
weather_module="$root/modules/perimeter/WeatherModule.qml"
dock_module="$root/modules/perimeter/DockModule.qml"
critical="$root/modules/ii/critical/ShellIiCriticalPanels.qml"
ii_panels="$root/modules/ii/ShellIiPanelsImpl.qml"
left_sidebar="$root/modules/sidebarLeft/SidebarLeft.qml"
right_sidebar="$root/modules/sidebarRight/SidebarRight.qml"

fail() {
    printf 'FAIL: perimeter contract: %s\n' "$1" >&2
    exit 1
}

for file in "$core_policy" "$core_registry" "$perimeter_config" "$core_qmldir" \
        "$feature_qmldir" "$presentation_policy" "$reservation_policy" "$runtime" \
        "$sidebar_module" "$thinkfan_module" "$system_monitor_module" \
        "$workspaces_module" "$media_module" "$weather_module" "$dock_module" \
        "$critical" "$ii_panels" "$left_sidebar" "$right_sidebar"; do
    [[ -f "$file" ]] || fail "missing ${file#"$root/"}"
done

grep -Fxq 'singleton PerimeterCutoverPolicy 1.0 PerimeterCutoverPolicy.qml' \
    "$core_qmldir" || fail 'core cutover policy is not exported'
grep -Fxq 'singleton PerimeterRuntimeHealth 1.0 PerimeterRuntimeHealth.qml' \
    "$core_qmldir" || fail 'runtime health registry is not exported'
grep -Fxq 'singleton PerimeterReservationPolicy 1.0 PerimeterReservationPolicy.qml' \
    "$feature_qmldir" || fail 'feature reservation policy is not exported'
if grep -Fq 'PerimeterRuntimePolicy' "$feature_qmldir"; then
    fail 'feature package owns obsolete cutover policy'
fi

for token in \
    'readonly property bool requested:' \
    'readonly property bool compatibilityReady:' \
    'readonly property bool configurationValid:' \
    'readonly property bool sourcesReady:' \
    'readonly property bool enabled:' \
    'readonly property bool fallbackActive:' \
    'readonly property string statusReason:'; do
    grep -Fq "$token" "$core_policy" || fail "policy missing $token"
done
grep -Fq 'ModuleRegistry.validateConfiguredModules(' "$core_policy" \
    || fail 'policy does not require resolvable placed modules'
compatibility_block="$(sed -n '/readonly property bool compatibilityReady: {/,/^    }/p' "$core_policy")"
[[ -n "$compatibility_block" ]] || fail 'policy is missing compatibility readiness block'
enabled_block="$(sed -n '/readonly property bool enabled:/,/readonly property bool fallbackActive:/p' "$core_policy")"
[[ -n "$enabled_block" ]] || fail 'policy is missing cutover enablement block'
grep -Fq 'root.compatibilityReady' <<<"$enabled_block" \
    || fail 'cutover enablement ignores compatibility readiness'
for token in \
    'enabledPanels.includes(barIdentifier)' \
    'root.reservationKindPlacedAnywhere("bar")' \
    'Config.options?.bar?.autoHide?.enable' \
    'enabledPanels.includes("iiDock")' \
    'root.reservationKindPlacedAnywhere("dock")' \
    'Config.options?.dock?.enable' \
    'Config.options?.dock?.pinnedOnStartup' \
    'Config.options?.dock?.hoverToReveal' \
    'enabledPanels.includes("iiSidebarLeft")' \
    'root.modulePlacedAnywhere("left-sidebar")' \
    'enabledPanels.includes("iiSidebarRight")' \
    'root.modulePlacedAnywhere("right-sidebar")' \
    'Config.options?.sidebar?.edgeOpen?.enable'; do
    grep -Fq "$token" <<<"$compatibility_block" \
        || fail "compatibility readiness missing semantic input: $token"
done

for reset_fn in resetDefaultSlots resetOutputSlots; do
    reset_block="$(sed -n "/function ${reset_fn}(/,/^    }/p" "$perimeter_config")"
    [[ -n "$reset_block" ]] || fail "perimeter config missing $reset_fn"
    grep -Fq '!root.schemaSupported' <<<"$reset_block" \
        || fail "$reset_fn can mutate unsupported perimeter schema"
    grep -Fq '!root._configuredShapeValid()' <<<"$reset_block" \
        || fail "$reset_fn can mutate malformed perimeter config"
done

for reservation in \
    '"thinkfan": { moduleId: "thinkfan", preferredOrientation: "any", compact: true, expanded: true, reservationKind: "bar"' \
    '"left-sidebar": { moduleId: "left-sidebar", preferredOrientation: "vertical", compact: true, expanded: true, reservationKind: "overlay"' \
    '"right-sidebar": { moduleId: "right-sidebar", preferredOrientation: "vertical", compact: true, expanded: true, reservationKind: "overlay"' \
    '"dock": { moduleId: "dock", preferredOrientation: "horizontal", compact: true, expanded: true, reservationKind: "dock"'; do
    grep -Fq "$reservation" "$core_registry" \
        || fail 'module reservation metadata drifted'
done
register_block="$(sed -n '/function registerModule(/,/^    }/p' "$core_registry")"
[[ -n "$register_block" ]] || fail 'module registry missing registerModule'
grep -Fq 'const immutableMetadata = Object.assign({}, builtin)' <<<"$register_block" \
    || fail 'builtin module metadata can be replaced during feature registration'
grep -Fq 'delete immutableMetadata.source' <<<"$register_block" \
    || fail 'builtin source is accidentally treated as immutable metadata'
grep -Fq 'next[id] = Object.assign({}, merged, immutableMetadata' <<<"$register_block" \
    || fail 'builtin metadata is not reapplied after descriptor merge'

grep -Fq 'readonly property bool barPresented:' "$presentation_policy" \
    || fail 'presentation policy does not expose shared bar lifecycle'
grep -Fq 'function dockPresented(edge: string): bool {' "$presentation_policy" \
    || fail 'presentation policy does not expose dock lifecycle'
# Once Connected Perimeter is requested, PerimeterConfig is the sole placement
# authority. Legacy bar/dock output filters are migration inputs only and must
# not silently re-filter output placement at runtime. Match concrete legacy
# access paths rather than the generic word so comments cannot trip the guard.
for file in "$presentation_policy" "$reservation_policy" "$thinkfan_module" \
        "$system_monitor_module" "$workspaces_module" "$media_module" \
        "$weather_module" "$dock_module"; do
    if grep -Eq 'barOutputEnabled|dockOutputEnabled|barPresentedForOutput|dockPresentedForOutput' "$file"; then
        fail "$(basename "$file") bypasses perimeter-owned output placement"
    fi
    if grep -Fq 'Config.options?.bar?.screenList' "$file" \
            || grep -Fq 'Config.options?.dock?.screenList' "$file"; then
        fail "$(basename "$file") reads legacy bar/dock output placement"
    fi
done

grep -Fq 'function _barThickness(edge: string): real {' "$reservation_policy" \
    || fail 'bar reservation thickness is not edge-aware'
grep -Fq 'Appearance.sizes.baseVerticalBarWidth' "$reservation_policy" \
    || fail 'vertical bar reservation no longer matches vertical-bar width semantics'
grep -Fq 'root._barThickness(targetEdge)' "$reservation_policy" \
    || fail 'edge-aware bar thickness is not used by reservation routing'
grep -Fq 'function zoneForOutputEdge(outputName: string, edge: string): real {' \
    "$reservation_policy" || fail 'reservation policy does not derive zones per output edge'
grep -Fq 'GlobalStates.barOpen' "$reservation_policy" \
    || fail 'bar reservation no longer tracks bar semantic visibility'
grep -Fq 'GlobalStates.coverflowSelectorOpen' "$reservation_policy" \
    || fail 'bar reservation no longer releases for coverflow'

for bar_module in "$thinkfan_module" "$system_monitor_module" \
        "$workspaces_module" "$media_module" "$weather_module"; do
    grep -Fq 'PerimeterPresentationPolicy.barPresented' "$bar_module" \
        || fail "$(basename "$bar_module") bypasses shared bar presentation policy"
done
grep -Fq 'PerimeterPresentationPolicy.dockPresented(root.edge)' "$dock_module" \
    || fail 'DockModule bypasses shared dock presentation policy'

grep -Fq 'function sidebarSurfaceEnabled(featureRole: bool): bool {' \
    "$presentation_policy" || fail 'presentation policy does not expose sidebar ownership'
route_block="$(sed -n '/function syncSidebarRoute(/,/^    }/p' "$runtime")"
[[ -n "$route_block" ]] || fail 'runtime missing sidebar route synchronization'
grep -Fq '!PerimeterPresentationPolicy.sidebarSurfaceEnabled(featureRole)' <<<"$route_block" \
    || fail 'runtime can route a disabled sidebar'
grep -Fq '&& PerimeterPresentationPolicy.sidebarSurfaceEnabled(true)' "$runtime" \
    || fail 'runtime can focus a disabled left sidebar'
grep -Fq '&& PerimeterPresentationPolicy.sidebarSurfaceEnabled(false)' "$runtime" \
    || fail 'runtime can focus a disabled right sidebar'
grep -Fxq 'import qs.modules.common.widgets' "$runtime" \
    || fail 'runtime does not import common widgets for CompositorFocusGrab'
grep -Fq 'PerimeterPresentationPolicy.sidebarSurfaceEnabled(root.featureRole)' \
    "$sidebar_module" || fail 'sidebar module ignores panel ownership'
backdrop_block="$(sed -n '/id: dualSidebarBackdrop/,/^        }/p' "$ii_panels")"
[[ -n "$backdrop_block" ]] || fail 'ii panels missing dual sidebar backdrop'
grep -Fq 'includes("iiSidebarLeft")' <<<"$backdrop_block" \
    || fail 'left sidebar backdrop ignores panel ownership'
grep -Fq 'includes("iiSidebarRight")' <<<"$backdrop_block" \
    || fail 'right sidebar backdrop ignores panel ownership'

grep -Fq 'function syncResourceUsageLifecycle(): void {' "$system_monitor_module" \
    || fail 'system monitor no longer synchronizes resource polling with presentation'
grep -Fq 'onPresentedChanged: root.syncResourceUsageLifecycle()' "$system_monitor_module" \
    || fail 'system monitor does not release polling when presentation changes'
grep -Fq 'ResourceUsage.releaseKeepAlive()' "$system_monitor_module" \
    || fail 'system monitor cannot release its persistent resource consumer'
if grep -Fq 'Component.onCompleted: ResourceUsage.keepAlive()' "$system_monitor_module"; then
    fail 'hidden system monitor can keep resource polling alive unconditionally'
fi

grep -Fq 'component EdgeReservationWindow: PanelWindow {' "$runtime" \
    || fail 'runtime has no edge-specific reservation surface'
grep -Fq 'PerimeterReservationPolicy.zoneForOutputEdge(' "$runtime" \
    || fail 'runtime reservation surfaces bypass reservation policy'
grep -Fq 'WlrLayershell.keyboardFocus: WlrKeyboardFocus.None' "$runtime" \
    || fail 'reservation/runtime chrome may request keyboard focus unexpectedly'
grep -Fq 'mask: Region { item: emptyReservationInput }' "$runtime" \
    || fail 'reservation surfaces are not explicitly click-through'
for edge in top bottom left right; do
    grep -Fq "EdgeReservationWindow { edge: \"$edge\" }" "$runtime" \
        || fail "runtime missing $edge reservation surface"
done
# The visual host must stay non-exclusive. Reservation belongs only to the
# three-anchor edge surfaces because a four-anchor layer surface is ambiguous.
grep -Fq 'exclusionMode: ExclusionMode.Ignore' "$runtime" \
    || fail 'fullscreen visual host no longer ignores exclusion'
if [[ "$(grep -Fc 'exclusiveZone: 0' "$runtime")" -lt 1 ]]; then
    fail 'fullscreen visual host no longer keeps exclusive zone at zero'
fi

# Source registration is mutable after cutover. Runtime must heal both source
# overwrite and unregister events, not rely only on the critical bootstrap.
grep -Fq 'target: ModuleRegistry' "$runtime" \
    || fail 'runtime does not observe module registry drift'
grep -Fq 'function onModuleRegistered(moduleId: string): void {' "$runtime" \
    || fail 'runtime does not heal overwritten module sources'
grep -Fq 'function onModuleUnregistered(moduleId: string): void {' "$runtime" \
    || fail 'runtime does not heal removed module sources'
if [[ "$(grep -Fc 'Qt.callLater(root.ensureFeatureRegistry)' "$runtime")" -lt 2 ]]; then
    fail 'runtime registry self-heal is not deferred for both drift directions'
fi

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
