#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
shell_root="$root/shell.qml"
policy="$root/modules/common/perimeter/PerimeterCutoverPolicy.qml"
runtime_health="$root/modules/common/perimeter/PerimeterRuntimeHealth.qml"
runtime="$root/modules/perimeter/PerimeterRuntime.qml"
settings="$root/modules/settings/ShellLayoutConfig.qml"
route_controller="$root/modules/common/perimeter/SurfaceRouteController.qml"
critical="$root/modules/ii/critical/ShellIiCriticalPanels.qml"
ii_panels="$root/modules/ii/ShellIiPanelsImpl.qml"

fail() {
    printf 'FAIL: perimeter family contract: %s\n' "$1" >&2
    exit 1
}

for file in "$shell_root" "$policy" "$runtime_health" "$runtime" "$settings" \
        "$route_controller" "$critical" "$ii_panels"; do
    [[ -f "$file" ]] || fail "missing ${file#"$root/"}"
done

# The policy must mirror the exact ii/Waffle loader boundary owned by shell.qml.
grep -Fq '(Config.options?.panelFamily ?? "ii") !== "waffle"' "$shell_root" \
    || fail 'ii family loader boundary changed'
grep -Fq 'readonly property bool familyActive:' "$policy" \
    || fail 'cutover policy does not expose family activity'
grep -Fq '(Config.options?.panelFamily ?? "ii") !== "waffle"' "$policy" \
    || fail 'cutover policy does not match ii family loader semantics'
grep -Fq 'return "inactive-family"' "$policy" \
    || fail 'inactive family fallback has no status reason'

# Request intent persists across family switches; runtime activity does not.
grep -Fq 'readonly property bool perimeterRequested: PerimeterCutoverPolicy.requested' "$settings" \
    || fail 'settings no longer preserves perimeter request intent'
grep -Fq 'readonly property bool perimeterActive: PerimeterCutoverPolicy.enabled' "$settings" \
    || fail 'settings no longer reports policy runtime state'

# A family switch must tear down already-open connected perimeter routes.
grep -Fq 'target: PerimeterCutoverPolicy' "$route_controller" \
    || fail 'route controller does not observe cutover activity'
grep -Fq 'root._closePerimeterRoutesForFallback()' "$route_controller" \
    || fail 'family fallback cannot close perimeter routes'

# PerimeterRuntime belongs in the critical ii tree, but presentation QML is
# intentionally deferred behind a URL boundary. Scope policy assertions to the
# property expressions they protect: a matching token elsewhere in the singleton
# must not let activation/final-cutover requirements silently disappear.
grep -Fq 'readonly property bool activationEligible:' "$policy" \
    || fail 'cutover policy does not expose runtime activation eligibility'
grep -Fq 'readonly property bool runtimeReady: PerimeterRuntimeHealth.runtimeHostReady' "$policy" \
    || fail 'cutover policy does not consume the runtime-root handshake'
activation_block="$(sed -n '/readonly property bool activationEligible:/,/readonly property bool runtimeReady:/p' "$policy")"
[[ -n "$activation_block" ]] || fail 'activation eligibility expression is missing'
for dependency in \
    'root.requested' \
    'root.familyActive' \
    'root.compatibilityReady' \
    'root.configurationValid' \
    'root.sourcesReady'; do
    grep -Fq "$dependency" <<<"$activation_block" \
        || fail "activation eligibility lost dependency: $dependency"
done

enabled_block="$(sed -n '/readonly property bool enabled:/,/readonly property bool fallbackActive:/p' "$policy")"
[[ -n "$enabled_block" ]] || fail 'final cutover expression is missing'
for dependency in 'root.activationEligible' 'root.runtimeReady' 'root.runtimeHealthy'; do
    grep -Fq "$dependency" <<<"$enabled_block" \
        || fail "final cutover lost dependency: $dependency"
done

grep -Fq 'property bool runtimeHostReady: false' "$runtime_health" \
    || fail 'runtime health does not track root readiness'
grep -Fq 'PerimeterRuntimeHealth.setRuntimeHostReady(root.active && root.featuresReady)' "$runtime" \
    || fail 'perimeter runtime does not publish a successful root handshake'
grep -Fq 'Component.onDestruction: PerimeterRuntimeHealth.setRuntimeHostReady(false)' "$runtime" \
    || fail 'perimeter runtime does not clear root readiness on teardown'

# Verify the runtime URL loader and each legacy fallback loader independently.
# This prevents one correctly-gated Bar/Dock block from masking a sibling whose
# final-cutover gate or source boundary was accidentally removed.
python3 - "$critical" <<'PY'
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")
# Remove comments so documentation cannot satisfy behavioral source assertions.
text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
text = re.sub(r"//[^\n]*", "", text)

def compact(value: str) -> str:
    return " ".join(value.split())

runtime_blocks = re.findall(r"(?ms)^[ \t]*LazyLoader[ \t]*\{(.*?)^[ \t]*\}", text)
runtime_matches = [
    block for block in runtime_blocks
    if '../../perimeter/PerimeterRuntime.qml' in block
]
if len(runtime_matches) != 1:
    raise SystemExit("FAIL: expected exactly one URL-loaded PerimeterRuntime critical block")
runtime_block = compact(runtime_matches[0])
if 'active: Config.ready && root.perimeterActivationEligible' not in runtime_block:
    raise SystemExit("FAIL: critical runtime loader lost activation eligibility gate")
if 'source: Qt.resolvedUrl("../../perimeter/PerimeterRuntime.qml")' not in runtime_block:
    raise SystemExit("FAIL: critical runtime loader lost URL source boundary")

blocks = re.findall(r"(?ms)^[ \t]*CriticalPanelLoader[ \t]*\{(.*?)^[ \t]*\}", text)
by_id = {}
for block in blocks:
    match = re.search(r'identifier\s*:\s*"([^"]+)"', block)
    if match:
        by_id[match.group(1)] = compact(block)

expected = {
    "iiBar": (
        '../../bar/Bar.qml',
        ('!root.perimeterEnabled', '!root.barVertical'),
    ),
    "iiVerticalBar": (
        '../../verticalBar/VerticalBar.qml',
        ('!root.perimeterEnabled', 'root.barVertical'),
    ),
    "iiDock": (
        '../../dock/Dock.qml',
        ('!root.perimeterEnabled', 'Config.options?.dock?.enable'),
    ),
}
for identifier, (source, tokens) in expected.items():
    block = by_id.get(identifier)
    if block is None:
        raise SystemExit(f"FAIL: missing critical fallback loader: {identifier}")
    if f'source: Qt.resolvedUrl("{source}")' not in block:
        raise SystemExit(f"FAIL: {identifier} lost URL source boundary")
    for token in tokens:
        if token not in block:
            raise SystemExit(f"FAIL: {identifier} lost fallback gate token: {token}")
PY

mapped_block="$(sed -n '/readonly property bool mapped:/,/^[[:space:]]*screen:/p' "$runtime")"
[[ -n "$mapped_block" ]] || fail 'perimeter mapped expression is missing'
grep -Fq 'hostActive' <<<"$mapped_block" \
    || fail 'connected perimeter mapping no longer requires host activity'
grep -Fq 'PerimeterCutoverPolicy.enabled' <<<"$mapped_block" \
    || fail 'connected perimeter chrome can map before final cutover'
grep -Fq 'hasChrome' <<<"$mapped_block" \
    || fail 'connected perimeter mapping no longer requires rendered chrome'

# PerimeterRuntime must not become an executable dependency of the deferred ii
# presentation tree. Ignore comments and strings so explanatory text cannot turn
# into a false-red contract failure.
python3 - "$ii_panels" <<'PY'
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")
text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
text = re.sub(r"//[^\n]*", "", text)
text = re.sub(r'"(?:\\.|[^"\\])*"', '""', text)
text = re.sub(r"'(?:\\.|[^'\\])*'", "''", text)
if re.search(r"\bPerimeterRuntime\b", text):
    raise SystemExit("FAIL: PerimeterRuntime moved into deferred ii panels")
PY

printf 'PASS: perimeter family contracts\n'
