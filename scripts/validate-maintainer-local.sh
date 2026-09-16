#!/usr/bin/env bash
set -uo pipefail

repo_url="${HADALIS_VALIDATION_REPO_URL:-https://github.com/llocphann/Hadalis.git}"
branch="${HADALIS_VALIDATION_BRANCH:-dev}"
mode="remote"
strict_qml=0
original_args=("$@")

usage() {
    cat <<'USAGE'
Usage: bash scripts/validate-maintainer-local.sh [--current-repo] [--strict-qml]

Default mode clean-clones the configured dev branch into a temporary directory.
--current-repo  Validate a clean clone of the caller repository's exact HEAD.
--strict-qml    Require qmlformat >= 6.8 instead of allowing the parser pass to skip.
USAGE
}

while (($# > 0)); do
    case "$1" in
        --current-repo) mode="current-repo" ;;
        --strict-qml) strict_qml=1 ;;
        -h|--help) usage; exit 0 ;;
        *)
            printf 'FATAL: unknown argument: %s\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

workspace="$(mktemp -d "${TMPDIR:-/tmp}/hadalis-validation.XXXXXX")"
checkout="$workspace/Hadalis"
log_path="${HADALIS_VALIDATION_LOG:-${TMPDIR:-/tmp}/hadalis-maintainer-validation-$(date +%Y%m%d-%H%M%S).log}"

cleanup() { rm -rf -- "$workspace"; }
trap cleanup EXIT

mkdir -p "$(dirname -- "$log_path")"
: >"$log_path"

log_line() { printf '%s\n' "$*" >>"$log_path"; }
terminal_line() { printf '%s\n' "$*"; }

log_command() {
    printf 'Command:' >>"$log_path"
    printf ' %q' "$@" >>"$log_path"
    printf '\n' >>"$log_path"
}

fatal() {
    local message="$1"
    log_line "FATAL: $message"
    terminal_line "FATAL: $message"
    terminal_line "FINAL LOG: $log_path"
    exit 2
}

log_line 'Hadalis maintainer local validation'
log_line "Started: $(date -Iseconds)"
log_line "Mode: $mode"
log_line "Repository: $repo_url"
log_line "Branch: $branch"
log_line "Strict QML parser: $([[ $strict_qml -eq 1 ]] && printf yes || printf no)"
printf 'Invocation: bash scripts/validate-maintainer-local.sh' >>"$log_path"
printf ' %q' "${original_args[@]}" >>"$log_path"
printf '\n' >>"$log_path"
log_line "Log: $log_path"

terminal_line 'Hadalis maintainer local validation'
terminal_line "Log: $log_path"

if [[ "$mode" == "current-repo" ]]; then
    source_repo="$(git rev-parse --show-toplevel 2>/dev/null)" || fatal '--current-repo requires a Git working tree'
    source_sha="$(git -C "$source_repo" rev-parse HEAD)" || fatal 'could not resolve caller HEAD'
    if ! git clone --quiet --no-local "$source_repo" "$checkout" >>"$log_path" 2>&1; then
        fatal 'clean local clone failed'
    fi
    if ! git -C "$checkout" checkout --quiet --detach "$source_sha" >>"$log_path" 2>&1; then
        fatal "failed to detach clean clone at $source_sha"
    fi
else
    if ! git clone --quiet --single-branch --branch "$branch" "$repo_url" "$checkout" >>"$log_path" 2>&1; then
        fatal 'clean clone failed'
    fi
fi

cd "$checkout" || fatal 'could not enter clean checkout'
validation_sha="$(git rev-parse HEAD)"

log_line "Exact SHA: $validation_sha"
log_line "Validator commit: $validation_sha"
log_line "Hostname: $(hostname 2>/dev/null || printf unavailable)"
log_line "Kernel: $(uname -srmo 2>/dev/null || uname -a 2>/dev/null || printf unavailable)"
if [[ -r /etc/os-release ]]; then
    os_pretty="$(sed -n 's/^PRETTY_NAME=//p' /etc/os-release | head -n 1 | tr -d '"')"
    log_line "OS: ${os_pretty:-unknown}"
else
    log_line 'OS: unavailable'
fi
log_line 'Initial git status:'
if [[ -n "$(git status --short --untracked-files=all)" ]]; then
    git status --short --untracked-files=all >>"$log_path"
else
    log_line '  clean'
fi
log_line 'Tool versions:'
for tool in git bash python3 node fish make qmlformat qmlformat6; do
    if command -v "$tool" >/dev/null 2>&1; then
        case "$tool" in
            bash) version="$($tool --version 2>&1 | head -n 1)" ;;
            python3|node|fish|make|git|qmlformat|qmlformat6) version="$($tool --version 2>&1 | head -n 1)" ;;
        esac
        log_line "  $tool: $version"
    else
        log_line "  $tool: unavailable"
    fi
done
log_line 'Nix lane: deferred/non-blocking; dedicated Nix validation is intentionally skipped.'

checks=0
passes=0
failures=0
failed_checks=()
skipped_checks=()
failure_groups=()
environment_checks=(
    'actual Arch package build/install on a package-build host'
    'live Niri/Quickshell desktop acceptance'
    'multi-monitor/hotplug/suspend-resume/fractional-scaling/focus/fullscreen acceptance'
    'live audio/hardware behavior that requires the real desktop session'
    'GitHub release publication, Wiki remote access, and hosted release permissions'
)
qml_parser_status='QML parser: UNKNOWN (probe did not run)'
check_marked_skip=0

add_failure_group() {
    local group="$1" existing
    for existing in "${failure_groups[@]:-}"; do
        [[ "$existing" == "$group" ]] && return 0
    done
    failure_groups+=("$group")
}

classify_failure() {
    local label="$1"
    case "$label" in
        *translation*|*documentation*) add_failure_group 'translations / documentation drift' ;;
        *QML*|*qml*|*perimeter*|*Perimeter*) add_failure_group 'QML / module resolution / Connected Perimeter' ;;
        *install*|*relocation*|*package*) add_failure_group 'install / relocation / packaging' ;;
        *lifecycle*|*service*) add_failure_group 'service lifecycle / timeout / recovery' ;;
        *syntax*) add_failure_group 'tracked source syntax' ;;
        *) add_failure_group 'other regression contracts' ;;
    esac
}

record_skip() {
    skipped_checks+=("$1")
    check_marked_skip=1
}

run_check() {
    local label="$1" rc output_file
    shift
    checks=$((checks + 1))
    output_file="$workspace/check-${checks}.out"
    check_marked_skip=0

    log_line ''
    log_line "---- CHECK [$checks]: $label ----"
    log_command "$@"
    log_line "Working directory: $(pwd)"

    "$@" >"$output_file" 2>&1
    rc=$?

    if (( rc == 0 )) && (( check_marked_skip == 0 )); then
        passes=$((passes + 1))
        log_line 'Result: PASS'
        printf '[%02d] %-58s PASS\n' "$checks" "$label"
        return 0
    fi

    if (( rc == 0 )) && (( check_marked_skip == 1 )); then
        log_line 'Result: SKIP'
        if [[ -s "$output_file" ]]; then
            log_line 'Output:'
            cat "$output_file" >>"$log_path"
        fi
        printf '[%02d] %-58s SKIP\n' "$checks" "$label"
        return 0
    fi

    failures=$((failures + 1))
    failed_checks+=("$label (exit $rc)")
    classify_failure "$label"
    log_line "Result: FAIL (exit $rc)"
    log_line "BEGIN FAILURE: $label"
    log_command "$@"
    log_line "Exit code: $rc"
    log_line "Working directory: $(pwd)"
    log_line 'Output:'
    if [[ -s "$output_file" ]]; then
        cat "$output_file" >>"$log_path"
    else
        log_line '  <no output>'
    fi
    log_line "END FAILURE: $label"
    printf '[%02d] %-58s FAIL\n' "$checks" "$label"
    return 0
}

require_host_tools() {
    local tool missing=0
    for tool in git bash sh python3 make grep sed awk find sort fish node jq rsync cmp sha256sum realpath head cut tr; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            printf 'missing required host tool: %s\n' "$tool" >&2
            missing=1
        fi
    done
    return "$missing"
}

tracked_shell_syntax() {
    local file first_line failed=0
    while IFS= read -r -d '' file; do
        [[ -f "$file" ]] || continue
        first_line="$(head -n 1 "$file" 2>/dev/null || true)"
        if [[ "$first_line" =~ (^|/)(sh)([[:space:]]|$) ]] && [[ "$first_line" != *bash* ]]; then
            sh -n "$file" || failed=1
        else
            bash -n "$file" || failed=1
        fi
    done < <(git ls-files -z -- '*.sh' '*.install' 'setup' 'scripts/inir' '*/PKGBUILD' \
        'assets/helpers/inir-battery-charge-limit' 'assets/helpers/inir-thinkfan')
    return "$failed"
}

tracked_python_syntax() {
    python3 - <<'PY'
from pathlib import Path
import subprocess
raw = subprocess.check_output(["git", "ls-files", "-z", "--", "*.py"])
for name in raw.decode("utf-8").split("\0"):
    if name:
        compile(Path(name).read_text(encoding="utf-8"), name, "exec")
PY
}

tracked_json_syntax() {
    python3 - <<'PY'
from pathlib import Path
import json
import subprocess
raw = subprocess.check_output(["git", "ls-files", "-z", "--", "*.json"])
for name in raw.decode("utf-8").split("\0"):
    if name:
        json.loads(Path(name).read_text(encoding="utf-8"))
PY
}

tracked_js_syntax() {
    local file failed=0 node_count=0 qml_js_count=0
    while IFS= read -r -d '' file; do
        if grep -Eq '^[[:space:]]*\.(pragma|import)([[:space:]]|$)' "$file"; then
            qml_js_count=$((qml_js_count + 1))
            continue
        fi
        node_count=$((node_count + 1))
        node --check "$file" || failed=1
    done < <(git ls-files -z -- '*.js')
    printf 'Node/plain JavaScript checked: %d; QML JavaScript delegated to QML guards: %d\n' "$node_count" "$qml_js_count"
    return "$failed"
}

tracked_fish_syntax() {
    local file failed=0
    while IFS= read -r -d '' file; do
        fish -n "$file" || failed=1
    done < <(git ls-files -z -- '*.fish')
    return "$failed"
}

run_shell_regression() {
    local file="$1" first_line
    first_line="$(head -n 1 "$file" 2>/dev/null || true)"
    if [[ "$first_line" =~ (^|/)sh([[:space:]]|$) ]] && [[ "$first_line" != *bash* ]]; then
        sh "$file"
    else
        bash "$file"
    fi
}

probe_qml_parser() {
    local parser='' candidate version_text parser_version major minor
    for candidate in qmlformat qmlformat6 /usr/lib/qt6/bin/qmlformat /usr/lib/x86_64-linux-gnu/qt6/bin/qmlformat; do
        if [[ "$candidate" == /* ]]; then
            [[ -x "$candidate" ]] && { parser="$candidate"; break; }
        elif command -v "$candidate" >/dev/null 2>&1; then
            parser="$(command -v "$candidate")"
            break
        fi
    done

    if [[ -z "$parser" ]]; then
        if (( strict_qml == 1 )); then
            qml_parser_status='QML parser: FAIL (qmlformat unavailable; strict mode requires >= 6.8)'
            return 1
        fi
        qml_parser_status='QML parser: SKIPPED (qmlformat unavailable)'
        record_skip 'QML parser pass (qmlformat unavailable)'
        return 0
    fi

    version_text="$($parser --version 2>&1 || true)"
    parser_version="$(grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' <<<"$version_text" | head -n 1)"
    if [[ -z "$parser_version" ]]; then
        if (( strict_qml == 1 )); then
            qml_parser_status="QML parser: FAIL ($parser version unknown; strict mode requires >= 6.8)"
            return 1
        fi
        qml_parser_status="QML parser: SKIPPED ($parser; version unknown)"
        record_skip "QML parser pass ($parser version could not be determined)"
        return 0
    fi

    IFS=. read -r major minor _ <<<"$parser_version"
    if (( major * 100 + minor < 608 )); then
        if (( strict_qml == 1 )); then
            qml_parser_status="QML parser: FAIL (qmlformat $parser_version < required 6.8)"
            return 1
        fi
        qml_parser_status="QML parser: SKIPPED (qmlformat $parser_version is below required 6.8)"
        record_skip "QML parser pass (qmlformat $parser_version too old; need >= 6.8)"
        return 0
    fi

    qml_parser_status="QML parser: AVAILABLE (qmlformat $parser_version; parser pass runs inside qml-check)"
    return 0
}

run_qml_guards() {
    local output rc
    output="$(fish scripts/qml-check.fish --all 2>&1)"
    rc=$?
    printf '%s\n' "$output"
    if [[ "$qml_parser_status" == 'QML parser: AVAILABLE '* ]]; then
        if grep -Fq 'QML parser rejected the file' <<<"$output"; then
            qml_parser_status="${qml_parser_status/AVAILABLE/FAIL}"
        else
            qml_parser_status="${qml_parser_status/AVAILABLE/PASS}"
        fi
    fi
    return "$rc"
}

source_tree_clean() {
    git diff --exit-code -- . || return 1
    if [[ -n "$(git status --porcelain=v1 --untracked-files=all)" ]]; then
        printf 'validation mutated the clean clone:\n' >&2
        git status --short --untracked-files=all >&2
        return 1
    fi
}

run_check 'host tool preflight' require_host_tools
run_check 'build and baseline shell syntax' make build
run_check 'tracked shell/package syntax' tracked_shell_syntax
run_check 'tracked Python syntax' tracked_python_syntax
run_check 'tracked JSON syntax' tracked_json_syntax
run_check 'tracked JavaScript syntax' tracked_js_syntax
run_check 'tracked Fish syntax' tracked_fish_syntax
run_check 'translation catalog structure' python3 translations/tools/l10n.py audit-all
run_check 'translation source parity' python3 translations/tools/source-parity.py

while IFS= read -r -d '' test_file; do
    run_check "Python regression: $test_file" python3 "$test_file"
done < <(git ls-files -z -- ':(glob)**/test-*.py' 'test-*.py' | sort -z -u)

run_check 'IPC registry freshness' python3 scripts/lib/generate-ipc-registry.py --check
run_check 'documentation contracts' bash scripts/verify-docs.sh
run_check 'QML parser capability' probe_qml_parser
run_check 'QML/startup project guards' run_qml_guards

while IFS= read -r -d '' test_file; do
    case "$test_file" in
        test-nix-*.sh|*/test-nix-*.sh|*/nix/*)
            skipped_checks+=("NIX-DEFERRED: $test_file")
            continue
            ;;
    esac
    run_check "shell regression: $test_file" run_shell_regression "$test_file"
done < <(git ls-files -z -- ':(glob)**/test-*.sh' 'test-*.sh' | sort -z -u)

run_check 'Make contract: prefix/path relocation' make SHELL=/bin/bash '.SHELLFLAGS=-eu -o pipefail -c' test-prefix-install
run_check 'Make contract: package metadata' make SHELL=/bin/bash '.SHELLFLAGS=-eu -o pipefail -c' test-package-metadata
run_check 'Make contract: package lifecycle hooks' make SHELL=/bin/bash '.SHELLFLAGS=-eu -o pipefail -c' test-package-hooks
run_check 'source tree remains clean after validation' source_tree_clean

result='PASS'
(( failures > 0 )) && result='FAIL'

{
    printf '\n========================================\n'
    printf 'HADALIS VALIDATION SUMMARY\n'
    printf 'Exact SHA: %s\n' "$validation_sha"
    printf 'Result: %s\n' "$result"
    printf 'Checks run: %d\n' "$checks"
    printf 'Passed: %d\n' "$passes"
    printf 'Failed: %d\n' "$failures"
    printf 'Skipped: %d\n' "${#skipped_checks[@]}"
    printf '%s\n' "$qml_parser_status"
    printf 'Nix: DEFERRED / NON-BLOCKING (support retained; dedicated validation not run)\n'
    printf 'Source tree mutation: %s\n' "$([[ " ${failed_checks[*]-} " == *'source tree remains clean after validation'* ]] && printf FAIL || printf CLEAN)"
    if ((${#failed_checks[@]} > 0)); then
        printf 'Failed checks:\n'
        printf '  - %s\n' "${failed_checks[@]}"
    else
        printf 'Failed checks: none\n'
    fi
    if ((${#skipped_checks[@]} > 0)); then
        printf 'Skipped checks:\n'
        printf '  - %s\n' "${skipped_checks[@]}"
    else
        printf 'Skipped checks: none\n'
    fi
    if ((${#failure_groups[@]} > 0)); then
        printf 'Primary failure groups:\n'
        printf '  - %s\n' "${failure_groups[@]}"
    else
        printf 'Primary failure groups: none\n'
    fi
    printf 'Environment-dependent / release-only checks not run by daily validation:\n'
    printf '  - %s\n' "${environment_checks[@]}"
    printf 'FINAL LOG: %s\n' "$log_path"
    printf '========================================\n'
} >>"$log_path"

printf '\nHadalis validation: %s\n' "$result"
printf 'SHA: %s\n' "$validation_sha"
printf 'Passed: %d\n' "$passes"
printf 'Failed: %d\n' "$failures"
printf 'Skipped: %d\n' "${#skipped_checks[@]}"
printf 'FINAL LOG: %s\n' "$log_path"
printf 'Send this single log file for review.\n'

if (( failures > 0 )); then
    exit 1
fi
exit 0
