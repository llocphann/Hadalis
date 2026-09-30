#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
lease="$repo_root/modules/common/widgets/ServiceLease.qml"
cava="$repo_root/modules/common/widgets/CavaProcess.qml"
resource="$repo_root/modules/common/widgets/ResourceUsageMonitor.qml"
lyrics="$repo_root/modules/mediaControls/components/PlayerLyrics.qml"

fail() {
    printf 'service lease lifecycle guard failed: %s\n' "$1" >&2
    exit 1
}

require_literal() {
    local literal="$1" file="$2" label="$3"
    grep -Fq -- "$literal" "$file" || fail "$label"
}

require_literal 'property bool active: false' "$lease" 'ServiceLease active demand is missing'
require_literal 'property var acquire: null' "$lease" 'ServiceLease acquire callback is missing'
require_literal 'property var update: null' "$lease" 'ServiceLease update callback is missing'
require_literal 'property var release: null' "$lease" 'ServiceLease release callback is missing'
require_literal 'const heldValue = root._heldValue' "$lease" 'ServiceLease must remember the acquired value for symmetric release'
require_literal 'Component.onDestruction: root._release()' "$lease" 'ServiceLease must auto-release on destruction'
require_literal 'onActiveChanged: root.sync()' "$lease" 'ServiceLease must react to demand changes'
require_literal 'onValueChanged: root.syncValue()' "$lease" 'ServiceLease must update active parameterized leases'
require_literal 'ServiceLease {' "$cava" 'CavaProcess must use ServiceLease'
require_literal 'ServiceLease {' "$resource" 'ResourceUsageMonitor must use ServiceLease'
require_literal 'ServiceLease {' "$lyrics" 'PlayerLyrics must use ServiceLease'
require_literal 'LyricsService.subscribe()' "$lyrics" 'PlayerLyrics lease must acquire LyricsService'
require_literal 'LyricsService.unsubscribe()' "$lyrics" 'PlayerLyrics lease must release LyricsService'

printf 'service lease lifecycle guards: ok\n'
