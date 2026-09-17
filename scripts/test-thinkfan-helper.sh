#!/usr/bin/env bash

set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd)
helper="$repo_root/assets/helpers/inir-thinkfan"

tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
state_dir="$tmp/state"
bin_dir="$tmp/bin"
mkdir -p "$state_dir" "$bin_dir"

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

cat > "$bin_dir/id" <<'MOCK_ID'
#!/bin/sh
if [ "${1:-}" = "-u" ]; then
    printf '%s\n' 0
    exit 0
fi
exec /usr/bin/id "$@"
MOCK_ID

cat > "$bin_dir/thinkfan" <<'MOCK_THINKFAN'
#!/bin/sh
exit 0
MOCK_THINKFAN

cat > "$bin_dir/systemctl" <<'MOCK_SYSTEMCTL'
#!/usr/bin/env bash
set -euo pipefail
state_dir=${MOCK_THINKFAN_STATE:?}
command=${1:-}
shift || true

service_arg() {
  if [[ "${1:-}" == "--quiet" || "${1:-}" == "--now" ]]; then
    shift
  fi
  [[ "${1:-}" == "thinkfan.service" ]]
}

case "$command" in
  cat)
    service_arg "$@"
    ;;
  is-active)
    service_arg "$@" || exit 1
    [[ "$(cat "$state_dir/active")" == "active" ]]
    ;;
  is-enabled)
    service_arg "$@" || exit 1
    [[ "$(cat "$state_dir/enabled")" == "enabled" ]]
    ;;
  enable)
    service_arg "$@" || exit 1
    printf '%s\n' active > "$state_dir/active"
    printf '%s\n' enabled > "$state_dir/enabled"
    ;;
  disable)
    service_arg "$@" || exit 1
    printf '%s\n' inactive > "$state_dir/active"
    if [[ "${MOCK_THINKFAN_STICKY_DISABLE:-0}" != "1" ]]; then
      printf '%s\n' disabled > "$state_dir/enabled"
    fi
    ;;
  *)
    printf 'unsupported mock systemctl command: %s %s\n' "$command" "$*" >&2
    exit 64
    ;;
esac
MOCK_SYSTEMCTL

chmod 0755 "$bin_dir/id" "$bin_dir/thinkfan" "$bin_dir/systemctl"
export MOCK_THINKFAN_STATE="$state_dir"
export PATH="$bin_dir:$PATH"

printf '%s\n' inactive > "$state_dir/active"
printf '%s\n' disabled > "$state_dir/enabled"
managed_output=$("$helper" --apply managed)
[[ "$(cat "$state_dir/active")" == "active" ]] \
  || fail 'managed mode must start thinkfan.service'
[[ "$(cat "$state_dir/enabled")" == "enabled" ]] \
  || fail 'managed mode must enable thinkfan.service'
grep -Fq '"active":true' <<< "$managed_output" \
  || fail 'managed status must report active=true'
grep -Fq '"enabled":true' <<< "$managed_output" \
  || fail 'managed status must report enabled=true'
grep -Fq '"profile":"managed"' <<< "$managed_output" \
  || fail 'managed status must report the managed profile'

firmware_output=$("$helper" --apply firmware)
[[ "$(cat "$state_dir/active")" == "inactive" ]] \
  || fail 'firmware mode must stop thinkfan.service'
[[ "$(cat "$state_dir/enabled")" == "disabled" ]] \
  || fail 'firmware mode must disable thinkfan.service'
grep -Fq '"active":false' <<< "$firmware_output" \
  || fail 'firmware status must report active=false'
grep -Fq '"enabled":false' <<< "$firmware_output" \
  || fail 'firmware status must report enabled=false'
grep -Fq '"profile":"firmware"' <<< "$firmware_output" \
  || fail 'firmware status must report the firmware profile'

printf '%s\n' active > "$state_dir/active"
printf '%s\n' enabled > "$state_dir/enabled"
set +e
MOCK_THINKFAN_STICKY_DISABLE=1 "$helper" --apply firmware \
  > "$tmp/sticky.out" 2> "$tmp/sticky.err"
sticky_status=$?
set -e
[[ "$sticky_status" -eq 70 ]] \
  || fail "firmware mode must reject a still-enabled unit (got $sticky_status)"
grep -Fq 'service remained enabled after disable' "$tmp/sticky.err" \
  || fail 'firmware mode must explain a still-enabled service failure'

printf '%s\n' '1..3'
printf '%s\n' 'ok 1 - managed mode starts and enables ThinkFan'
printf '%s\n' 'ok 2 - firmware mode stops and disables ThinkFan'
printf '%s\n' 'ok 3 - firmware mode rejects a service that remains enabled'
