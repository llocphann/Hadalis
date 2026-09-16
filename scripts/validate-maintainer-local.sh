#!/usr/bin/env bash
set -uo pipefail

repo_url="${HADALIS_VALIDATION_REPO_URL:-https://github.com/llocphann/Hadalis.git}"
branch="${HADALIS_VALIDATION_BRANCH:-dev}"
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
printf 'Repository: %s\n' "$repo_url"
printf 'Branch: %s\n' "$branch"
printf 'Log: %s\n\n' "$log_path"

if ! git clone --quiet --single-branch --branch "$branch" "$repo_url" "$checkout"; then
    printf 'FATAL: clean clone failed\n' >&2
    exit 2
fi

cd "$checkout" || exit 2
validation_sha="$(git rev-parse HEAD)"
printf 'Exact SHA: %s\n' "$validation_sha"
printf 'Nix lane: deferred/non-blocking; dedicated Nix validation is intentionally skipped.\n'

checks=0
failures=0
failed_checks=()

run_check() {
    local label="$1"
    shift
    checks=$((checks + 1))
    printf '\n== [%d] %s ==\n' "$checks" "$label"
    if "$@"; then
        printf 'PASS: %s\n' "$label"
    else
        local rc=$?
        failures=$((failures + 1))
        failed_checks+=("$label (exit $rc)")
        printf 'FAIL: %s (exit %d)\n' "$label" "$rc" >&2
    fi
}

require_host_tools() {
    local tool
    local missing=0
    for tool in git bash sh python3 make grep sed awk find sort fish node jq; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            printf 'missing required host tool: %s\n' "$tool" >&2
            missing=1
        fi
    done
    return "$missing"
}

tracked_shell_syntax() {
    local file
    local failed=0
    while IFS= read -r -d '' file; do
        bash -n "$file" || failed=1
    done < <(git ls-files -z -- '*.sh' '*.install' 'setup' 'scripts/inir' 'distro/arch/*/PKGBUILD')
    return "$failed"
}

tracked_python_syntax() {
    python3 - <<'PY'
from pathlib import Path
import subprocess

raw = subprocess.check_output(["git", "ls-files", "-z", "--", "*.py"])
for name in raw.decode("utf-8").split("\0"):
    if not name:
        continue
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
    if not name:
        continue
    json.loads(Path(name).read_text(encoding="utf-8"))
PY
}

tracked_js_syntax() {
    node --check translations/tools/auto-translate.js
}

tracked_fish_syntax() {
    local file
    local failed=0
    while IFS= read -r -d '' file; do
        fish -n "$file" || failed=1
    done < <(git ls-files -z -- '*.fish')
    return "$failed"
}

run_shell_regression() {
    local file="$1"
    local first_line
    first_line="$(head -n 1 "$file")"
    if [[ "$first_line" =~ (^|/)sh$ ]] && [[ "$first_line" != *bash* ]]; then
        sh "$file"
    else
        bash "$file"
    fi
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
done < <(find scripts translations/tools -type f -name 'test-*.py' -print0 | sort -z)

run_check 'IPC registry freshness' python3 scripts/lib/generate-ipc-registry.py --check
run_check 'documentation contracts' bash scripts/verify-docs.sh
run_check 'QML/startup guards' fish scripts/qml-check.fish --all

while IFS= read -r -d '' test_file; do
    case "$test_file" in
        scripts/test-nix-module-contract.sh|scripts/test-make-install-lifecycle.sh)
            continue
            ;;
    esac
    run_check "shell regression: $test_file" run_shell_regression "$test_file"
done < <(find scripts -maxdepth 1 -type f -name 'test-*.sh' -print0 | sort -z)

run_check 'staged install/uninstall lifecycle' bash scripts/test-make-install-lifecycle.sh
run_check 'source tree remains clean after validation' source_tree_clean

printf '\n========================================\n'
printf 'Hadalis maintainer validation summary\n'
printf 'Exact SHA: %s\n' "$validation_sha"
printf 'Checks run: %d\n' "$checks"
printf 'Failures: %d\n' "$failures"
printf 'Log: %s\n' "$log_path"
printf 'Dedicated Nix validation: skipped (deferred compatibility lane)\n'

if (( failures > 0 )); then
    printf 'Failed checks:\n'
    printf '  - %s\n' "${failed_checks[@]}"
    exit 1
fi

printf 'Result: all required clean-clone non-Nix checks passed for exact SHA %s\n' "$validation_sha"
