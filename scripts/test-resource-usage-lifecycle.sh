#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
service="$repo_root/services/ResourceUsage.qml"
resources_popup="$repo_root/modules/bar/ResourcesPopup.qml"
status_rings="$repo_root/modules/sidebarLeft/widgets/StatusRings.qml"
overlay_resources="$repo_root/modules/ii/overlay/resources/Resources.qml"
sysmon_widget="$repo_root/modules/sidebarRight/sysmon/SysMonWidget.qml"
waffle_widgets="$repo_root/modules/waffle/widgets/WidgetsContent.qml"
overview_dashboard="$repo_root/modules/overview/OverviewDashboard.qml"
inner_tube_thumbnail="$repo_root/modules/sidebarLeft/innertune/ITThumbnail.qml"
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

assert_contains 'root._gpuUsageSource = "none"' "$gpu_block" 'GPU startup failure must fail closed to no usage source'
assert_contains 'root._gpuUsagePath = ""' "$gpu_block" 'GPU startup failure must clear stale sysfs path'
assert_contains 'root._nvidiaSmiPath = ""' "$gpu_block" 'GPU startup failure must clear stale nvidia-smi path'
assert_contains 'root._intelGpuTopPath = ""' "$gpu_block" 'GPU startup failure must clear stale intel_gpu_top path'
assert_contains 'root._cpuTempPath = ""' "$temp_block" 'temperature startup failure must clear stale CPU sensor path'
assert_contains 'root._gpuTempPath = ""' "$temp_block" 'temperature startup failure must clear stale GPU sensor path'
assert_contains 'root._dGpuRuntimeStatusPath = ""' "$hybrid_block" 'hybrid GPU startup failure must clear stale runtime-status path'
assert_contains 'root.maxAvailableCpuString = "--"' "$cpu_block" 'CPU frequency startup failure must restore unknown display state'

for lifecycle_file in "$resources_popup" "$status_rings" "$overlay_resources" "$sysmon_widget" "$waffle_widgets" "$overview_dashboard" "$bar_resources" "$vertical_bar_resources"; do
    lifecycle_text="$(cat "$lifecycle_file")"
    assert_contains 'ResourceUsage.keepAlive()' "$lifecycle_text" "$lifecycle_file must acquire resource polling only while presented"
    assert_contains 'ResourceUsage.releaseKeepAlive()' "$lifecycle_text" "$lifecycle_file must release resource polling when hidden or destroyed"
done

assert_contains 'running: root.panelVisible && root.effectiveIsPlaying' "$(cat "$overview_dashboard")" \
    'hidden Overview dashboard must stop its media position timer'
assert_contains 'running: root.isActive && root.isPlaying && root.visible && GlobalStates.sidebarLeftOpen' "$(cat "$inner_tube_thumbnail")" \
    'hidden InnerTune thumbnail must stop its decorative equalizer timer'
assert_contains 'root.visible && !GameMode.active' "$(cat "$bar_resources")" \
    'horizontal Bar resource polling must pause during GameMode'
assert_contains 'root.visible && !GameMode.active' "$(cat "$vertical_bar_resources")" \
    'vertical Bar resource polling must pause during GameMode'

printf 'resource usage and visual idle lifecycle guards: ok\n'
