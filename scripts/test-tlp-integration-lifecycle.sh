#!/usr/bin/env bash

set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd)
migration="$repo_root/sdata/migrations/038-tlp-profile-backend.sh"
pkgbuild="$repo_root/sdata/dist-arch/inir-deps/PKGBUILD"
tlp_service="$repo_root/services/TlpService.qml"
power_persistence="$repo_root/services/PowerProfilePersistence.qml"

tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

assert_state() {
  local unit=$1 expected=$2 actual
  actual=$(cat "$tmp/state/$unit")
  [[ "$actual" == "$expected" ]] \
    || fail "$unit state: expected $expected, got $actual"
}

assert_log() {
  local needle=$1
  grep -Fqx -- "$needle" "$tmp/systemctl.log" \
    || fail "missing systemctl action: $needle"
}

assert_file_contains() {
  local needle=$1 file=$2 message=$3
  grep -Fq -- "$needle" "$file" || fail "$message"
}

assert_text_contains() {
  local needle=$1 text=$2 message=$3
  grep -Fq -- "$needle" <<<"$text" || fail "$message"
}

# The UI exposes the Radio Device Wizard, so Arch installs must include the
# package which actually consumes those settings.
grep -Eq '^[[:space:]]*tlp-rdw[[:space:]]*$' "$pkgbuild" \
  || fail 'inir-deps must install tlp-rdw'

# Battery policy status/apply calls cross the privileged helper boundary. Keep
# both process paths bounded so a wedged helper or pkexec prompt cannot leave
# TLP reconciliation or Settings permanently busy.
assert_file_contains 'detectorTimeout.restart()' "$tlp_service" \
  'TLP battery status detection must arm its timeout'
assert_file_contains 'id: detectorTimeout' "$tlp_service" \
  'TLP battery status detection must define a timeout timer'
assert_file_contains 'interval: 5000' "$tlp_service" \
  'TLP battery status detection timeout must remain bounded'
assert_file_contains 'detector.timedOut = true' "$tlp_service" \
  'TLP battery status timeout must mark the process as timed out'
assert_file_contains 'detector.running = false' "$tlp_service" \
  'TLP battery status timeout must stop the helper process'
assert_file_contains 'applyTimeout.restart()' "$tlp_service" \
  'TLP battery policy apply must arm its timeout'
assert_file_contains 'id: applyTimeout' "$tlp_service" \
  'TLP battery policy apply must define a timeout timer'
assert_file_contains 'interval: 60000' "$tlp_service" \
  'TLP battery policy apply timeout must remain bounded'
assert_file_contains 'applyProcess.timedOut = true' "$tlp_service" \
  'TLP battery policy apply timeout must mark the process as timed out'
assert_file_contains 'applyProcess.running = false' "$tlp_service" \
  'TLP battery policy apply timeout must stop the helper process'
assert_file_contains 'root.busy = false' "$tlp_service" \
  'TLP battery policy apply exit must release the busy state'

# Power profile restore must fail closed while tlp-pd ownership is unknown. A
# Process startup failure must cancel the timeout without pretending the probe
# completed; a real start arms the timeout, and the timeout must not stop an
# already-failed/not-running process.
tlp_probe_running_block="$(sed -n '/^[[:space:]]*onRunningChanged: {/,/^[[:space:]]*onStarted: {/p' "$power_persistence")"
tlp_probe_started_block="$(sed -n '/^[[:space:]]*onStarted: {/,/^[[:space:]]*onExited:/p' "$power_persistence")"
tlp_probe_timeout_block="$(sed -n '/^[[:space:]]*id: tlpPdTimeout$/,/^[[:space:]]*\/\/ Re-probe/p' "$power_persistence")"
[[ -n "$tlp_probe_running_block" && -n "$tlp_probe_started_block" && -n "$tlp_probe_timeout_block" ]] \
  || fail 'PowerProfilePersistence tlp-pd lifecycle blocks are missing'
assert_text_contains 'tlpPdProbe.startObserved = false' "$tlp_probe_running_block" \
  'tlp-pd startup attempt must begin unobserved'
assert_text_contains 'if (tlpPdProbe.startObserved)' "$tlp_probe_running_block" \
  'tlp-pd startup-failure handling must distinguish a real process start'
assert_text_contains 'tlpPdTimeout.stop()' "$tlp_probe_running_block" \
  'tlp-pd startup failure must cancel its timeout'
assert_text_contains 'root._tlpProbeDone = false' "$tlp_probe_running_block" \
  'tlp-pd startup failure must keep ownership unknown'
if grep -Fq 'root._tlpProbeDone = true' <<<"$tlp_probe_running_block"; then
  fail 'tlp-pd startup failure must not mark ownership probing complete'
fi
assert_text_contains 'tlpPdProbe.startObserved = true' "$tlp_probe_started_block" \
  'tlp-pd process start must be observed before timeout handling'
assert_text_contains 'tlpPdTimeout.restart()' "$tlp_probe_started_block" \
  'tlp-pd process start must arm its timeout'
assert_text_contains 'if (!tlpPdProbe.running)' "$tlp_probe_timeout_block" \
  'tlp-pd timeout must ignore an already-stopped process'
assert_text_contains 'tlpPdProbe.timedOut = true' "$tlp_probe_timeout_block" \
  'tlp-pd timeout must mark an actually running probe as timed out'

mkdir -p "$tmp/bin" "$tmp/state"
: > "$tmp/systemctl.log"

cat > "$tmp/bin/systemctl" <<'MOCK_SYSTEMCTL'
#!/usr/bin/env bash
set -u
state_dir=${MOCK_SYSTEMD_STATE:?}
log=${MOCK_SYSTEMD_LOG:?}
command=${1:-}
shift || true

unit_exists() {
  [[ -f "$state_dir/$1" ]]
}

case "$command" in
  cat)
    unit_exists "${1:-}"
    ;;
  is-enabled)
    quiet=0
    if [[ "${1:-}" == "--quiet" ]]; then
      quiet=1
      shift
    fi
    unit=${1:-}
    unit_exists "$unit" || exit 1
    state=$(cat "$state_dir/$unit")
    [[ $quiet -eq 1 ]] || printf '%s\n' "$state"
    case "$state" in
      enabled|enabled-runtime|linked|linked-runtime|alias|masked|masked-runtime|static|indirect|generated|transient)
        exit 0
        ;;
      *) exit 1 ;;
    esac
    ;;
  enable)
    now=0
    if [[ "${1:-}" == "--now" ]]; then
      now=1
      shift
    fi
    unit=${1:-}
    unit_exists "$unit" || exit 1
    printf 'enabled\n' > "$state_dir/$unit"
    if [[ $now -eq 1 ]]; then
      printf 'enable --now %s\n' "$unit" >> "$log"
    else
      printf 'enable %s\n' "$unit" >> "$log"
    fi
    ;;
  mask)
    now=0
    if [[ "${1:-}" == "--now" ]]; then
      now=1
      shift
    fi
    unit=${1:-}
    unit_exists "$unit" || exit 1
    printf 'masked\n' > "$state_dir/$unit"
    if [[ $now -eq 1 ]]; then
      printf 'mask --now %s\n' "$unit" >> "$log"
    else
      printf 'mask %s\n' "$unit" >> "$log"
    fi
    ;;
  *)
    printf 'unsupported mock systemctl command: %s %s\n' "$command" "$*" >&2
    exit 64
    ;;
esac
MOCK_SYSTEMCTL
chmod 0755 "$tmp/bin/systemctl"

cat > "$tmp/bin/tlp" <<'EOF_TLP'
#!/bin/sh
printf '%s\n' 'TLP version 1.10.2'
EOF_TLP
cat > "$tmp/bin/tlp-rdw" <<'EOF_RDW'
#!/bin/sh
exit 0
EOF_RDW
cat > "$tmp/bin/tlp-stat" <<'EOF_STAT'
#!/bin/sh
printf '%s\n' '--- TLP mock status ---'
EOF_STAT
chmod 0755 "$tmp/bin/tlp" "$tmp/bin/tlp-rdw" "$tmp/bin/tlp-stat"

for spec in \
  'tlp.service:disabled' \
  'tlp-pd.service:disabled' \
  'power-profiles-daemon.service:enabled' \
  'tuned-ppd.service:masked' \
  'NetworkManager-dispatcher.service:disabled' \
  'systemd-rfkill.service:enabled' \
  'systemd-rfkill.socket:enabled'; do
  unit=${spec%%:*}
  state=${spec#*:}
  printf '%s\n' "$state" > "$tmp/state/$unit"
done

export MOCK_SYSTEMD_STATE="$tmp/state"
export MOCK_SYSTEMD_LOG="$tmp/systemctl.log"
export PATH="$tmp/bin:$PATH"

# Migration files are sourced by the setup framework. Provide the same small
# surface they expect while keeping the test fully unprivileged.
STY_GREEN=''
STY_RST=''
pkg_sudo() { "$@"; }

# shellcheck disable=SC1090
source "$migration"

if ! migration_check; then
  fail 'migration must be pending with conflicting/disabled service state'
fi

migration_apply >/dev/null || fail 'migration_apply failed in mocked service environment'

assert_state tlp.service enabled
assert_state tlp-pd.service enabled
assert_state power-profiles-daemon.service masked
assert_state tuned-ppd.service masked
assert_state NetworkManager-dispatcher.service enabled
assert_state systemd-rfkill.service masked
assert_state systemd-rfkill.socket masked

assert_log 'mask --now power-profiles-daemon.service'
assert_log 'enable --now tlp.service'
assert_log 'enable --now tlp-pd.service'
assert_log 'enable NetworkManager-dispatcher.service'
assert_log 'mask --now systemd-rfkill.service'
assert_log 'mask --now systemd-rfkill.socket'

if migration_check; then
  fail 'migration must be satisfied after applying all required service state'
fi

printf '%s\n' '1..1'
printf '%s\n' 'ok 1 - TLP lifecycle and power-profile probe guards are present'
