#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
service="$repo_root/services/ResourceUsage.qml"

fail() {
    printf 'resource usage lifecycle guard failed: %s\n' "$1" >&2
    exit 1
}

assert_contains() {
    local needle="$1" text="$2" message="$3"
    grep -Fq -- "$needle" <<<"$text" || fail "$message"
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

assert_contains 'root._gpuUsageSource = "none"' "$gpu_block" 'GPU startup failure must fail closed to no usage source'
assert_contains 'root._gpuUsagePath = ""' "$gpu_block" 'GPU startup failure must clear stale sysfs path'
assert_contains 'root._nvidiaSmiPath = ""' "$gpu_block" 'GPU startup failure must clear stale nvidia-smi path'
assert_contains 'root._intelGpuTopPath = ""' "$gpu_block" 'GPU startup failure must clear stale intel_gpu_top path'
assert_contains 'root._cpuTempPath = ""' "$temp_block" 'temperature startup failure must clear stale CPU sensor path'
assert_contains 'root._gpuTempPath = ""' "$temp_block" 'temperature startup failure must clear stale GPU sensor path'
assert_contains 'root._dGpuRuntimeStatusPath = ""' "$hybrid_block" 'hybrid GPU startup failure must clear stale runtime-status path'
assert_contains 'root.maxAvailableCpuString = "--"' "$cpu_block" 'CPU frequency startup failure must restore unknown display state'

printf 'resource usage initialization lifecycle guards: ok\n'
