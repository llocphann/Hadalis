#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
service="$repo_root/services/Weather.qml"

fail() {
    printf 'weather request generation guard failed: %s\n' "$1" >&2
    exit 1
}

require_literal() {
    local literal="$1"
    local label="$2"
    grep -Fq -- "$literal" "$service" || fail "$label"
}

require_literal 'property int _requestGeneration: 0' 'request generation state is missing'
require_literal 'function _advanceRequestGeneration(): void' 'request generation invalidation helper is missing'
require_literal 'function _cancelRunningRequests(): void' 'stale request cancellation helper is missing'
require_literal 'requests[i].running = false' 'generation changes must terminate stale requests'
require_literal 'function _startRequest(proc): void' 'request stamping helper is missing'
require_literal 'function _requestIsCurrent(proc): bool' 'stale-request guard helper is missing'
require_literal 'property bool _locationRefreshPending: false' 'location refresh queue is missing'
require_literal 'property bool _unitRefreshPending: false' 'unit refresh queue is missing'
require_literal 'openMeteoFetcher.running || airQualityFetcher.running' 'pending refresh must wait for weather and AQI requests'
require_literal 'root._startRequest(fetcher)' 'primary weather fetch must be generation-stamped'
require_literal 'root._startRequest(openMeteoFetcher)' 'fallback weather fetch must be generation-stamped'
require_literal 'root._startRequest(airQualityFetcher)' 'AQI fetch must be generation-stamped'
require_literal 'if (!root._requestIsCurrent(fetcher))' 'primary weather callback must reject stale data'
require_literal 'if (!root._requestIsCurrent(openMeteoFetcher))' 'fallback weather callback must reject stale data'
require_literal 'if (!root._requestIsCurrent(airQualityFetcher))' 'AQI callback must reject stale data'
require_literal 'if (!root._requestIsCurrent(forwardGeocoder))' 'forward geocoder callback must reject stale data'
require_literal 'if (!root._requestIsCurrent(reverseGeocoder))' 'reverse geocoder callback must reject stale data'
require_literal 'if (!root._requestIsCurrent(gpsLocator))' 'GPS callback must reject stale data'
require_literal 'if (!root._requestIsCurrent(ipLocator))' 'IP geolocation callback must reject stale data'
require_literal 'if (!root._requestIsCurrent(fallbackLocator))' 'fallback geolocation callback must reject stale data'

printf 'weather request generation guards: ok\n'
