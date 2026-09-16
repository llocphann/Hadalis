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

grep -Fq '&& root.reservationKindPlacedAnywhere("bar")' "$policy" \
    || fail 'unplaced bar modules can still trigger compatibility fallback'
grep -Fq '&& root.reservationKindPlacedAnywhere("dock")' "$policy" \
    || fail 'unplaced dock can still trigger compatibility fallback'
grep -Fq '&& root.modulePlacedAnywhere("left-sidebar")' "$policy" \
    || fail 'unplaced left sidebar can still trigger compatibility fallback'
grep -Fq '&& root.modulePlacedAnywhere("right-sidebar")' "$policy" \
    || fail 'unplaced right sidebar can still trigger compatibility fallback'

# enabledPanels remains the feature/presentation enable source. Placement must
# refine that state rather than replace it, so disabled surfaces never block
# cutover and enabled-but-unplaced surfaces never resurrect legacy chrome.
grep -Fq 'const barOwned = enabledPanels.includes(barIdentifier)' "$policy" \
    || fail 'bar compatibility lost feature-enable ownership'
grep -Fq 'const dockOwned = enabledPanels.includes("iiDock")' "$policy" \
    || fail 'dock compatibility lost feature-enable ownership'
grep -Fq 'const sidebarOwned = enabledPanels.includes("iiSidebarLeft")' "$policy" \
    || fail 'sidebar compatibility lost feature-enable ownership'
grep -Fq '|| enabledPanels.includes("iiSidebarRight")' "$policy" \
    || fail 'right sidebar compatibility lost feature-enable ownership'

printf 'PASS: perimeter compatibility placement contracts\n'
