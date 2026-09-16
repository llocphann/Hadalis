#!/usr/bin/env bash
set -uo pipefail

repo_url="${HADALIS_VALIDATION_REPO_URL:-https://github.com/llocphann/Hadalis.git}"
branch="${HADALIS_VALIDATION_BRANCH:-dev}"
mode="remote"
strict_qml=0

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
        --current-repo)
            mode="current-repo"
            ;;
        --strict-qml)
            strict_qml=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
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

cleanup() {
    rm -rf -- "$workspace"
}
trap cleanup EXIT

mkdir -p "$(dirname -- "$log_path")"
exec > >(tee "$log_path") 2>&1

printf 'Hadalis maintainer local validation\n'
printf 'Mode: %s\n' "$mode"
printf 'Repository: %s\n' "$repo_url"
printf 'Branch: %s\n' "$branch"
printf 'Strict QML parser: %s\n' "$([[ $strict_qml -eq 1 ]] && printf yes || printf no)"
printf 'Log: %s\n\n' "$log_path"

if [[ "$mode" == "current-repo" ]]; then
    source_repo="$(git rev-parse --show-toplevel 2>/dev/null)" || {
        printf 'FATAL: --current-repo requires a Git working tree\n' >&2
        exit 2
    }
    source_sha="$(git -C "$source_repo" rev-parse HEAD)" || exit 2
    if ! git clone --quiet --no-local "$source_repo" "$checkout"; then
        printf 'FATAL: clean local clone failed\n' >&2
        exit 2
    fi
    if ! git -C "$checkout" checkout --quiet --detach "$source_sha"; then
        printf 'FATAL: failed to detach clean clone at %s\n' "$source_sha" >&2
        exit 2
    fi
else
    if ! git clone --quiet --single-branch --branch "$branch" "$repo_url" "$checkout"; then
        printf 'FATAL: clean clone failed\n' >&2
        exit 2
    fi
fi

cd "$checkout" || exit 2
validation_sha="$(git rev-parse HEAD)"
printf 'Exact SHA: %s\n' "$validation_sha"
printf 'Nix lane: deferred/non-blocking; dedicated Nix validation is intentionally skipped.\n'

checks=0
passes=0
failures=0
failed_checks=()
skipped_checks=()
environment_checks=(
    'actual Arch package build/install on a package-build host'
    'live Niri/Quickshell desktop acceptance'
    'multi-monitor/hotplug/suspend-resume/fractional-scaling acceptance'
    'GitHub release publication, Wiki remote access, and hosted release permissions'
)
qml_parser_status='QML parser: UNKNOWN (probe did not run)'

run_check() {
    local label="$1"
    shift
    checks=$((checks + 1))
    printf '\n== [%d] %s ==\n' "$checks" "$label"
    if "$@"; then
        passes=$((passes + 1))
        printf 'PASS: %s\n' "$label"
    else
        local rc=$?
        failures=$((failures + 1))
        failed_checks+=("$label (exit $rc)")
        printf 'FAIL: %s (exit %d)\n' "$label" "$rc" >&2
    fi
}

record_skip() {
    skipped_checks+=("$1")
    printf 'SKIP: %s\n' "$1"
}

require_host_tools() {
    local tool
    local missing=0
    for tool in git bash sh python3 make grep sed awk find sort fish node jq rsync cmp sha256sum realpath head cut tr; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            printf 'missing required host tool: %s\n' "$tool" >&2
            missing=1
        fi
    done
    return "$missing"
}

tracked_shell_syntax() {
    local file first_line
    local failed=0
    while IFS= read -r -d '' file; do
        [[ -f "$file" ]] || continue
        first_line="$(head -n 1 "$file" 2>/dev/null || true)"
        if [[ "$first_line" =~ (^|/)(sh)([[:space:]]|$) ]] && [[ "$first_line" != *bash* ]]; then
            sh -n "$file" || failed=1
        else
            bash -n "$file" || failed=1
        fi
    done < <(git ls-files -z -- \
        '*.sh' '*.install' 'setup' 'scripts/inir' '*/PKGBUILD' \
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
    local file failed=0
    while IFS= read -r -d '' file; do
        node --check "$file" || failed=1
    done < <(git ls-files -z -- '*.js')
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
        qml_parser_status='QML parser: SKIPPED (qmlformat unavailable)'
        record_skip 'QML parser pass (qmlformat unavailable)'
        [[ $strict_qml -eq 0 ]]
        return
    fi

    version_text="$($parser --version 2>&1 || true)"
    parser_version="$(grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' <<<"$version_text" | head -n 1)"
    if [[ -z "$parser_version" ]]; then
        qml_parser_status="QML parser: SKIPPED ($parser; version unknown)"
        record_skip "QML parser pass ($parser version could not be determined)"
        [[ $strict_qml -eq 0 ]]
        return
    fi

    IFS=. read -r major minor _ <<<"$parser_version"
    if (( major * 100 + minor < 608 )); then
        qml_parser_status="QML parser: SKIPPED (qmlformat $parser_version is below required 6.8)"
        record_skip "QML parser pass (qmlformat $parser_version too old; need >= 6.8)"
        [[ $strict_qml -eq 0 ]]
        return
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
            record_skip "NIX-DEFERRED: $test_file"
            continue
            ;;
    esac
    run_check "shell regression: $test_file" run_shell_regression "$test_file"
done < <(git ls-files -z -- ':(glob)**/test-*.sh' 'test-*.sh' | sort -z -u)

# These Make targets carry unique staged-prefix/package assertions that are not
# represented by a standalone test-*.sh contract.
run_check 'Make contract: prefix/path relocation' make test-prefix-install
run_check 'Make contract: package metadata' make test-package-metadata
run_check 'Make contract: package lifecycle hooks' make test-package-hooks

run_check 'source tree remains clean after validation' source_tree_clean

printf '\n========================================\n'
printf 'Hadalis maintainer validation summary\n'
printf 'Exact SHA: %s\n' "$validation_sha"
printf 'Result: %s\n' "$([[ $failures -eq 0 ]] && printf PASS || printf FAIL)"
printf 'Checks run: %d\n' "$checks"
printf 'PASS: %d\n' "$passes"
printf 'FAIL: %d\n' "$failures"
printf 'Skipped checks: %d\n' "${#skipped_checks[@]}"
printf '%s\n' "$qml_parser_status"
printf 'Nix: DEFERRED / NON-BLOCKING (support retained; dedicated validation not run)\n'
printf 'Log: %s\n' "$log_path"

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

printf 'Environment-dependent / release-only checks not run by daily validation:\n'
printf '  - %s\n' "${environment_checks[@]}"

if (( failures > 0 )); then
    exit 1
fi

printf 'Validated: all REQUIRED LOCAL non-Nix gates passed for exact SHA %s\n' "$validation_sha"
