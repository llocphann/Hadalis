#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
policy="$root/modules/common/perimeter/PerimeterCutoverPolicy.qml"

fail() {
    printf 'FAIL: perimeter compatibility placement contract: %s\n' "$1" >&2
    exit 1
}

[[ -f "$policy" ]] || fail 'missing PerimeterCutoverPolicy.qml'

grep -Fq 'function modulePlacedAnywhere(moduleId: string): bool {' "$policy" \
    || fail 'semantic compatibility ownership is not placement-aware'
grep -Fq 'function reservationKindPlacedAnywhere(reservationKind: string): bool {' "$policy" \
    || fail 'reservation compatibility ownership is not placement-aware'
grep -Fq 'PerimeterConfig.validate(outputName)' "$policy" \
    || fail 'compatibility ownership can inspect invalid output placement'
grep -Fq 'PerimeterConfig.slotInstanceIds(outputName, slotId)' "$policy" \
    || fail 'compatibility ownership does not walk effective perimeter slots'
grep -Fq 'PerimeterConfig.instanceDescriptor(outputName, instanceId)' "$policy" \
    || fail 'compatibility ownership does not resolve placed instance descriptors'
grep -Fq 'ModuleRegistry.resolve(instance?.moduleId)' "$policy" \
    || fail 'reservation compatibility ignores core module metadata'

# Assert each compatibility owner from its semantic inputs rather than the
# exact choice of intermediate variable names. Equivalent refactors must stay
# green as long as feature enablement is refined by effective placement.
bar_ownership_block="$(sed -n '/enabledPanels.includes(barIdentifier)/,/const barAutoHide =/p' "$policy")"
[[ -n "$bar_ownership_block" ]] || fail 'bar compatibility ownership block is missing'
grep -Fq 'enabledPanels.includes(barIdentifier)' <<<"$bar_ownership_block" \
    || fail 'bar compatibility lost feature-enable ownership'
grep -Fq 'root.reservationKindPlacedAnywhere("bar")' <<<"$bar_ownership_block" \
    || fail 'unplaced bar modules can still trigger compatibility fallback'

dock_ownership_block="$(sed -n '/enabledPanels.includes("iiDock")/,/const dockEnabled =/p' "$policy")"
[[ -n "$dock_ownership_block" ]] || fail 'dock compatibility ownership block is missing'
grep -Fq 'enabledPanels.includes("iiDock")' <<<"$dock_ownership_block" \
    || fail 'dock compatibility lost feature-enable ownership'
grep -Fq 'root.reservationKindPlacedAnywhere("dock")' <<<"$dock_ownership_block" \
    || fail 'unplaced dock can still trigger compatibility fallback'

sidebar_ownership_block="$(sed -n '/enabledPanels.includes("iiSidebarLeft")/,/const sidebarEdgeOpen =/p' "$policy")"
[[ -n "$sidebar_ownership_block" ]] || fail 'sidebar compatibility ownership block is missing'
grep -Fq 'enabledPanels.includes("iiSidebarLeft")' <<<"$sidebar_ownership_block" \
    || fail 'left sidebar compatibility lost feature-enable ownership'
grep -Fq 'root.modulePlacedAnywhere("left-sidebar")' <<<"$sidebar_ownership_block" \
    || fail 'unplaced left sidebar can still trigger compatibility fallback'
grep -Fq 'enabledPanels.includes("iiSidebarRight")' <<<"$sidebar_ownership_block" \
    || fail 'right sidebar compatibility lost feature-enable ownership'
grep -Fq 'root.modulePlacedAnywhere("right-sidebar")' <<<"$sidebar_ownership_block" \
    || fail 'unplaced right sidebar can still trigger compatibility fallback'

printf 'PASS: perimeter compatibility placement contracts\n'
