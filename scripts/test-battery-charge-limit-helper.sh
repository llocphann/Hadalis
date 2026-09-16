#!/usr/bin/env bash

set -u

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd)
helper="$repo_root/assets/helpers/inir-battery-charge-limit"
installed_helper=${INIR_TLP_HELPER:-/usr/libexec/inir-battery-charge-limit}
live_tmp=""

live_fail() {
    printf 'FAIL: %s\n' "$1" >&2
    return 1
}

live_usage() {
    printf '%s\n' 'Live lifecycle checks (run as the desktop user):'
    printf '%s\n' '  test-battery-charge-limit-helper.sh --live-restart'
    printf '%s\n' '  test-battery-charge-limit-helper.sh --live-display'
    printf '%s\n' '  test-battery-charge-limit-helper.sh --live-suspend'
    printf '%s\n' ''
    printf '%s\n' '--live-display waits while you turn the display off and wake it.'
    printf '%s\n' '--live-suspend requires typing SUSPEND before invoking systemctl suspend.'
}

live_file_fingerprint() {
    local path=$1 checksum metadata

    if [ ! -e "$path" ]; then
        printf 'missing\n'
        return 0
    fi
    [ -f "$path" ] || {
        printf 'not-a-regular-file\n'
        return 0
    }
    checksum=$(sha256sum "$path" 2>/dev/null | awk '{ print $1 }') || return 1
    metadata=$(stat -Lc '%d:%i:%s:%Y:%Z:%a:%U:%G' "$path" 2>/dev/null) || return 1
    printf '%s %s\n' "$checksum" "$metadata"
}

live_capture() {
    local destination=$1

    mkdir -p "$destination" || return 1
    "$installed_helper" --status > "$destination/charge.json" || return 1
    "$installed_helper" --config-status > "$destination/settings.json" || return 1
    jq -e '.schema == 1' "$destination/charge.json" >/dev/null || return 1
    jq -e '.schema == 1' "$destination/settings.json" >/dev/null || return 1
    live_file_fingerprint /etc/tlp.d/99-inir-battery-charge-limit.conf \
        > "$destination/battery-dropin.fingerprint" || return 1
    live_file_fingerprint /etc/tlp.d/99-inir-tlp-settings.conf \
        > "$destination/settings-dropin.fingerprint" || return 1
    systemctl is-active tlp.service > "$destination/tlp-service" 2>/dev/null || true
}

live_wait_for_status() {
    local attempts=0

    while [ "$attempts" -lt 40 ]; do
        if "$installed_helper" --status > "$live_tmp/wait-charge.json" 2>/dev/null \
            && "$installed_helper" --config-status > "$live_tmp/wait-settings.json" 2>/dev/null \
            && jq -e '.schema == 1' "$live_tmp/wait-charge.json" >/dev/null \
            && jq -e '.schema == 1' "$live_tmp/wait-settings.json" >/dev/null \
            && jq -e '
                if .managed == true and .supported == true and .stateKnown == true
                then (.currentLimit == .managedLimit and
                    (.managedStart == null or .currentStart == .managedStart))
                else true
                end
            ' "$live_tmp/wait-charge.json" >/dev/null; then
                return 0
        fi
        attempts=$((attempts + 1))
        sleep 1
    done
    return 1
}

live_compare() {
    local before=$1 after=$2 before_service after_service
    local before_charge after_charge before_settings after_settings

    cmp -s "$before/battery-dropin.fingerprint" "$after/battery-dropin.fingerprint" || {
        live_fail 'battery-care drop-in was rewritten or replaced during the lifecycle event'
        return 1
    }
    cmp -s "$before/settings-dropin.fingerprint" "$after/settings-dropin.fingerprint" || {
        live_fail 'general TLP settings drop-in was rewritten or replaced during the lifecycle event'
        return 1
    }

    before_charge=$(jq -Sc '{managed, managedBattery, managedStart, managedLimit}' "$before/charge.json") || return 1
    after_charge=$(jq -Sc '{managed, managedBattery, managedStart, managedLimit}' "$after/charge.json") || return 1
    [ "$before_charge" = "$after_charge" ] || {
        live_fail 'iNiR battery-care ownership changed during the lifecycle event'
        return 1
    }

    before_settings=$(jq -Sc '.managed' "$before/settings.json") || return 1
    after_settings=$(jq -Sc '.managed' "$after/settings.json") || return 1
    [ "$before_settings" = "$after_settings" ] || {
        live_fail 'iNiR general TLP overrides changed during the lifecycle event'
        return 1
    }

    if jq -e '.managed == true and .supported == true and .stateKnown == true' "$after/charge.json" >/dev/null; then
        jq -e '
            .currentLimit == .managedLimit and
            (.managedStart == null or .currentStart == .managedStart)
        ' "$after/charge.json" >/dev/null || {
            live_fail 'managed battery thresholds did not recover after the lifecycle event'
            return 1
        }
    fi

    before_service=$(cat "$before/tlp-service")
    after_service=$(cat "$after/tlp-service")
    if [ "$before_service" = active ] && [ "$after_service" != active ]; then
        live_fail 'tlp.service was active before the event but is not active afterwards'
        return 1
    fi

    printf '%s\n' 'ok - TLP ownership, drop-ins and effective charge limit remained consistent'
    printf 'charge:  %s\n' "$after_charge"
    printf 'settings: %s\n' "$after_settings"
    printf 'service:  %s\n' "${after_service:-unknown}"
}

run_live_lifecycle() {
    local event=$1 launcher reply

    [ "$(id -u)" -ne 0 ] || live_fail 'run live lifecycle checks as the desktop user, not root' || return 1
    [ -x "$installed_helper" ] || live_fail "installed helper is missing: $installed_helper" || return 1
    command -v jq >/dev/null 2>&1 || live_fail 'jq is required' || return 1
    command -v sha256sum >/dev/null 2>&1 || live_fail 'sha256sum is required' || return 1

    live_tmp=$(mktemp -d) || return 1
    trap '[ -z "${live_tmp:-}" ] || rm -rf -- "$live_tmp"' EXIT
    trap '[ -z "${live_tmp:-}" ] || rm -rf -- "$live_tmp"; exit 1' HUP INT TERM

    live_capture "$live_tmp/before" || live_fail 'could not capture the pre-event TLP state' || return 1
    jq -e '
        if .managed == true and .supported == true and .stateKnown == true
        then (.currentLimit == .managedLimit and
            (.managedStart == null or .currentStart == .managedStart))
        else true
        end
    ' "$live_tmp/before/charge.json" >/dev/null || {
        live_fail 'the battery policy is already out of sync; wait for iNiR reconciliation before testing a lifecycle event'
        return 1
    }

    case "$event" in
        restart)
            if command -v inir >/dev/null 2>&1; then
                launcher=$(command -v inir)
            else
                launcher="$repo_root/scripts/inir"
            fi
            [ -x "$launcher" ] || live_fail 'could not resolve the iNiR launcher' || return 1
            printf '%s\n' 'Restarting Quickshell through iNiR...'
            "$launcher" restart || live_fail 'iNiR restart failed' || return 1
            sleep 5
            ;;
        display)
            printf '%s\n' 'Turn the display off, wait a few seconds, then wake it again.' > /dev/tty
            printf '%s' 'Type DONE after the display is awake: ' > /dev/tty
            IFS= read -r reply < /dev/tty || return 1
            [ "$reply" = DONE ] || live_fail 'display lifecycle check cancelled' || return 1
            sleep 2
            ;;
        suspend)
            printf '%s\n' 'This will suspend the machine. Save open work first.' > /dev/tty
            printf '%s' 'Type SUSPEND to continue: ' > /dev/tty
            IFS= read -r reply < /dev/tty || return 1
            [ "$reply" = SUSPEND ] || live_fail 'suspend lifecycle check cancelled' || return 1
            systemctl suspend || live_fail 'system suspend failed' || return 1
            sleep 5
            ;;
        *) live_usage; return 2 ;;
    esac

    live_wait_for_status || live_fail 'TLP status did not become readable after the event' || return 1
    live_capture "$live_tmp/after" || live_fail 'could not capture the post-event TLP state' || return 1
    live_compare "$live_tmp/before" "$live_tmp/after"
}

case "${1:-}" in
    --live-restart) run_live_lifecycle restart; exit $? ;;
    --live-display) run_live_lifecycle display; exit $? ;;
    --live-suspend) run_live_lifecycle suspend; exit $? ;;
    --live-help) live_usage; exit 0 ;;
esac

# The helper deliberately exposes no privileged test mode. Source its functions
# under this different basename and replace only the hardware/TLP boundaries.
# shellcheck disable=SC1090
. "$helper"

suite_tmp=$(mktemp -d)
trap 'rm -rf -- "$suite_tmp"' EXIT
trap 'rm -rf -- "$suite_tmp"; exit 1' HUP INT TERM

tests_run=0

fail() {
    printf 'not ok - %s\n' "$1" >&2
    return 1
}

assert_eq() {
    local expected=$1 actual=$2 message=$3
    [ "$expected" = "$actual" ] || fail "$message (expected '$expected', got '$actual')"
}

assert_contains() {
    local needle=$1 file=$2 message=$3
    grep -Fq -- "$needle" "$file" || fail "$message"
}

assert_not_contains() {
    local needle=$1 file=$2 message=$3
    if grep -Fq -- "$needle" "$file"; then
        fail "$message"
    fi
}

reset_case() {
    case_dir=$(mktemp -d "$suite_tmp/case.XXXXXX")
    config_dir="$case_dir/etc/tlp.d"
    config_file="$config_dir/99-inir-battery-charge-limit.conf"
    tlp_settings_config_file="$config_dir/99-inir-tlp-settings.conf"
    tlp_settings_schema="$repo_root/assets/tlp/tlp-settings-schema.json"
    tlp_settings_lock="$case_dir/inir-tlp-settings.lock"
    platform_profile_choices_file="$case_dir/platform_profile_choices"
    mkdir -p "$config_dir"
    printf '%s\n' 'performance balanced low-power balanced-performance quiet cool' > "$platform_profile_choices_file"

    test_version=1.10.2
    export test_version
    test_enabled=1
    test_plugin=dell
    test_method=natacpi
    test_variant=1
    test_battery=BAT1
    test_config_battery=BAT1
    test_start_values=""
    test_stop_values=""
    test_behavior=success
    test_fullcharge_rc=0
    test_runtime_available=1
    test_probe_rc=0
    test_config_probe_rc=0

    state_start="$case_dir/current-start"
    state_stop="$case_dir/current-stop"
    calls_file="$case_dir/start-calls"
    resume_calls_file="$case_dir/resume-calls"
    printf '95\n' > "$state_start"
