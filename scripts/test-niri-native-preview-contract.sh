#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
backend="$repo_root/distro/arch/inir-niri-preview/plugin/capture_backend.cpp"
cmake="$repo_root/distro/arch/inir-niri-preview/plugin/CMakeLists.txt"
pkg="$repo_root/distro/arch/inir-niri-preview/PKGBUILD"
migration="$repo_root/sdata/migrations/046-niri-native-window-preview.sh"
launcher="$repo_root/scripts/inir"
renderer="$repo_root/modules/overview/NiriAdaptiveWindowPreview.qml"
config="$repo_root/modules/common/Config.qml"
service="$repo_root/services/AdaptivePreviewService.qml"

fail() {
    printf 'niri native preview contract failed: %s\n' "$1" >&2
    exit 1
}

require() {
    local needle="$1"
    local file="$2"
    local message="$3"
    grep -Fq -- "$needle" "$file" || fail "$message"
}

require 'find_package(Qt6 6.8 REQUIRED COMPONENTS Core DBus Gui Qml Quick)' "$cmake" \
    'native preview plugin must link QtDBus'
require 'pkg_check_modules(PIPEWIRE REQUIRED IMPORTED_TARGET libpipewire-0.3)' "$cmake" \
    'native preview plugin must link libpipewire'

require 'QStringLiteral("CreateSession")' "$backend" \
    'backend must create a Niri ScreenCast session'
require 'QStringLiteral("RecordWindow")' "$backend" \
    'backend must request the exact Niri window ID'
require 'QStringLiteral("PipeWireStreamAdded")' "$backend" \
    'backend must subscribe to the per-window PipeWire node signal'
require 'PW_KEY_TARGET_OBJECT' "$backend" \
    'PipeWire consumer must target the node published by Niri'
require 'pw_stream_connect(' "$backend" \
    'backend must connect a PipeWire input stream'
require 'PW_STREAM_FLAG_MAP_BUFFERS' "$backend" \
    'PipeWire SHM buffers must be mapped for QImage consumption'
require 'SPA_VIDEO_FORMAT_BGRx' "$backend" \
    'backend must accept Niri BGRx frames'
require 'SPA_VIDEO_FORMAT_BGRA' "$backend" \
    'backend must accept Niri BGRA frames'
require 'requiredBytes > static_cast<uint64_t>(plane.maxsize) - offset' "$backend" \
    'mapped PipeWire frame bounds must be validated'
require 'sampleLuma(' "$backend" \
    'motion probing must analyze in-memory frames'
require 'motionScore(' "$backend" \
    'motion probing must score frame changes'

if grep -Fq 'screenshot-window' "$backend"; then
    fail 'native live backend must not poll screenshot-window'
fi
if grep -Fq 'ext_foreign_toplevel_image_capture_source_manager_v1' "$backend" \
        || grep -Fq 'ext_image_copy_capture_session_v1' "$backend"; then
    fail 'native live backend must not depend on unsupported Niri foreign-toplevel ICC'
fi

require 'pkgver=0.2.0' "$pkg" 'native package version must be 0.2.0'
require 'pkgrel=2' "$pkg" 'native package release must force replacement of the retired backend'
require 'pipewire' "$pkg" 'native package must depend on PipeWire'
require 'backend=mutter-screencast' "$pkg" 'package marker must identify RecordWindow backend'
require 'transport=pipewire-shm' "$pkg" 'package marker must identify PipeWire SHM transport'

require 'version=0.2.0-2' "$migration" \
    'migration must require the current native plugin build'
require "grep -Fq 'backend=mutter-screencast'" "$migration" \
    'migration state check must reject a retired backend marker'
require "grep -Fq 'transport=pipewire-shm'" "$migration" \
    'migration state check must reject the wrong transport marker'
require 'pkg_sudo pacman -U --noconfirm "$built_pkg"' "$migration" \
    'migration must install the built package through the Hadalis privilege boundary'

require 'backend=mutter-screencast' "$launcher" \
    'launcher must gate native loading on the RecordWindow backend marker'
require 'transport=pipewire-shm' "$launcher" \
    'launcher must gate native loading on the PipeWire transport marker'
require 'export INIR_NIRI_PREVIEW_PLUGIN=1' "$launcher" \
    'launcher must expose the native capability only after validation'

require 'property int niriProbeMaxFps: 6' "$config" \
    'probe streams must default to a low maximum framerate'
require 'property int niriPreviewMaxFps: 18' "$config" \
    'promoted live streams must retain their bounded framerate'
require 'readonly property int niriProbeMaxFps:' "$service" \
    'scheduler must expose the low-FPS probe cadence'
require 'AdaptivePreviewService.niriProbeMaxFps' "$renderer" \
    'Niri renderer must use probe cadence before live promotion'
require 'AdaptivePreviewService.niriPreviewMaxFps' "$renderer" \
    'Niri renderer must switch promoted streams to live cadence'
require 'console.warn("[NiriAdaptivePreview] window"' "$renderer" \
    'native runtime failures must be visible in the shell journal'

bash -n "$launcher"
bash -n "$migration"

echo 'niri native preview contract: PASS'
