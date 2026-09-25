#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
service="$repo_root/services/ResourceUsage.qml"
resources_popup="$repo_root/modules/bar/ResourcesPopup.qml"
status_rings="$repo_root/modules/sidebarLeft/widgets/StatusRings.qml"
overlay_resources="$repo_root/modules/ii/overlay/resources/Resources.qml"
sysmon_widget="$repo_root/modules/sidebarRight/sysmon/SysMonWidget.qml"
waffle_widgets="$repo_root/modules/waffle/widgets/WidgetsContent.qml"
dash_system="$repo_root/modules/dashboard/DashSystem.qml"
bar_resources="$repo_root/modules/bar/Resources.qml"
vertical_bar_resources="$repo_root/modules/verticalBar/Resources.qml"

fail() {
    printf 'resource usage lifecycle guard failed: %s\n' "$1" >&2
    exit 1
}

assert_contains() {
    local needle="$1" text="$2" message="$3"
    grep -Fq -- "$needle" <<<"$text" || fail "$message"
}

assert_not_contains() {
    local needle="$1" text="$2" message="$3"
    if grep -Fq -- "$needle" <<<"$text"; then
        fail "$message"
    fi
}

assert_guarded_probe() {
    local id="$1" block="$2"
    [[ -n "$block" ]] || fail "$id process block is missing"
    assert_contains 'property bool startObserved: false' "$block" "$id startup guard state is missing"
    assert_contains 'onRunningChanged:' "$block" "$id startup failure path is missing"
    assert_contains "onStarted: $id.startObserved = true" "$block" "$id must distinguish a successful start"
    assert_contains 'root._releaseInitRequest(' "$block" "$id failed start must make initialization retryable"
}

gpu_block="$(sed -n '/id: detectGpuUsageSource/,/id: nvidiaGpuProc/p' "$service")"
temp_block="$(sed -n '/id: detectTempSensors/,/id: detectHybridGpu/p' "$service")"
hybrid_block="$(sed -n '/id: detectHybridGpu/,/id: findCpuMaxFreqProc/p' "$service")"
cpu_block="$(sed -n '/id: findCpuMaxFreqProc/,/id: diskProc/p' "$service")"
helper_block="$(sed -n '/function _releaseInitRequest/,/function ensureRunning/p' "$service")"
ensure_block="$(sed -n '/function ensureRunning/,/property bool _primed/p' "$service")"
poll_block="$(sed -n '/function _pollSensors/,/function _pollDisk/p' "$service")"

assert_guarded_probe detectGpuUsageSource "$gpu_block"
assert_guarded_probe detectTempSensors "$temp_block"
assert_guarded_probe detectHybridGpu "$hybrid_block"
assert_guarded_probe findCpuMaxFreqProc "$cpu_block"

assert_contains 'root._initRequested = false' "$helper_block" 'failed startup must release the initialization latch'
assert_contains 'root._initRequested = true' "$ensure_block" 'initialization must latch before launching probes'
assert_contains 'detectTempSensors.running = true' "$ensure_block" 'temperature probe must participate in initialization'
assert_contains 'detectGpuUsageSource.running = true' "$ensure_block" 'GPU usage probe must participate in initialization'
assert_contains 'detectHybridGpu.running = true' "$ensure_block" 'hybrid GPU probe must participate in initialization'
assert_contains 'findCpuMaxFreqProc.running = true' "$ensure_block" 'CPU frequency probe must participate in initialization'
assert_contains 'autoStopTimer.restart();' "$ensure_block" 'transient consumer request must arm the auto-stop lease'
assert_not_contains 'autoStopTimer.restart();' "$poll_block" 'sensor polling must not renew the transient lease forever'
assert_contains 'readonly property int _effectiveUpdateIntervalMs:' "$(cat "$service")" 'resource polling must expose a power-aware effective cadence'
assert_contains '? Math.max(6000, root._configuredUpdateIntervalMs)' "$(cat "$service")" 'Low Power resource polling must not run faster than 6 seconds'
assert_contains 'interval: root._effectiveUpdateIntervalMs' "$(cat "$service")" 'sensor timer must use the power-aware cadence'
assert_contains 'readonly property int _expensiveGpuUpdateIntervalMs:' "$(cat "$service")" 'process-backed GPU polling must have an independent cadence'
assert_contains '? Math.max(15000, root._effectiveUpdateIntervalMs)' "$(cat "$service")" 'Low Power process-backed GPU sampling must slow to at least 15 seconds'
assert_contains 'function _expensiveGpuPollDue(nowMs: real): bool {' "$(cat "$service")" 'expensive GPU polling must be cadence-gated'
assert_contains 'root._lastExpensiveGpuPollMs = nowMs' "$poll_block" 'process-backed GPU polling must record its last launch time'
assert_contains 'if (memTotalMatch && memAvailableMatch)' "$poll_block" 'transient meminfo reads must preserve the last good RAM sample'
assert_contains 'if (totalDiff > 0)' "$poll_block" 'duplicate/stale proc stat reads must preserve the last good CPU sample'
assert_not_contains 'cpuUsage = totalDiff > 0 ?' "$poll_block" 'stale CPU samples must not collapse usage to zero'
assert_contains 'if (!isNaN(cpuTempRaw))' "$poll_block" 'transient CPU hwmon reads must preserve the last good temperature'
assert_contains 'if (!isNaN(gpuTempRaw))' "$poll_block" 'transient GPU hwmon reads must preserve the last good temperature'
assert_not_contains 'if (isNaN(gpuBusyPercent)) {' "$poll_block" 'transient GPU sysfs reads must not collapse usage to zero'
assert_contains 'if (!isNaN(rawUsage))' "$(cat "$service")" 'transient nvidia-smi reads must preserve the last good GPU usage sample'
assert_not_contains 'root.gpuUsage = !isNaN(rawUsage) ?' "$(cat "$service")" 'invalid nvidia-smi output must not collapse GPU usage to zero'
assert_contains 'if (maxBusy >= 0)' "$(cat "$service")" 'transient intel_gpu_top reads must preserve the last good GPU usage sample'
assert_not_contains 'root.gpuUsage = maxBusy < 0 ? 0' "$(cat "$service")" 'invalid intel_gpu_top output must not collapse GPU usage to zero'
assert_contains 'function _appendHistorySnapshot(history, value): var {' "$(cat "$service")" 'Resource history updates must build bounded snapshots off-property'
assert_contains 'const next = [...history, value]' "$(cat "$service")" 'Resource history snapshots must preserve append order'
history_property_shifts="$(grep -Ec '(cpuUsageHistory|gpuUsageHistory|gpuTempHistory|memoryUsageHistory|swapUsageHistory)\.shift\(' "$service" || true)"
if (( history_property_shifts != 0 )); then
    fail "Resource history properties must not be mutated twice per poll; found $history_property_shifts direct shift calls"
fi

assert_contains 'root._gpuUsageSource = "none"' "$gpu_block" 'GPU startup failure must fail closed to no usage source'
assert_contains 'root._gpuUsagePath = ""' "$gpu_block" 'GPU startup failure must clear stale sysfs path'
assert_contains 'root._nvidiaSmiPath = ""' "$gpu_block" 'GPU startup failure must clear stale nvidia-smi path'
assert_contains 'root._intelGpuTopPath = ""' "$gpu_block" 'GPU startup failure must clear stale intel_gpu_top path'
assert_contains 'root._cpuTempPath = ""' "$temp_block" 'temperature startup failure must clear stale CPU sensor path'
assert_contains 'root._gpuTempPath = ""' "$temp_block" 'temperature startup failure must clear stale GPU sensor path'
assert_contains 'root._dGpuRuntimeStatusPath = ""' "$hybrid_block" 'hybrid GPU startup failure must clear stale runtime-status path'
assert_contains 'root.maxAvailableCpuString = "--"' "$cpu_block" 'CPU frequency startup failure must restore unknown display state'

for lifecycle_file in "$resources_popup" "$status_rings" "$overlay_resources" "$sysmon_widget" "$waffle_widgets" "$dash_system" "$bar_resources" "$vertical_bar_resources"; do
    lifecycle_text="$(cat "$lifecycle_file")"
    assert_contains 'ResourceUsage.keepAlive()' "$lifecycle_text" "$lifecycle_file must acquire resource polling only while presented"
    assert_contains 'ResourceUsage.releaseKeepAlive()' "$lifecycle_text" "$lifecycle_file must release resource polling when hidden or destroyed"
done

assert_contains 'root.visible && !GameMode.active' "$(cat "$bar_resources")" \
    'horizontal Bar resource polling must pause during GameMode'
assert_contains 'root.visible && !GameMode.active' "$(cat "$vertical_bar_resources")" \
    'vertical Bar resource polling must pause during GameMode'
assert_not_contains 'root.visible && root.presentationActive' "$(cat "$bar_resources")" \
    'horizontal Bar telemetry must not become hover/presentation gated'
assert_not_contains 'root.visible && root.presentationActive' "$(cat "$vertical_bar_resources")" \
    'vertical Bar telemetry must not become hover/presentation gated'

printf 'resource usage and visual idle lifecycle guards: ok\n'
