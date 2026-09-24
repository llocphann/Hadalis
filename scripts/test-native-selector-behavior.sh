#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
trial="$(mktemp -d "${TMPDIR:-/tmp}/inir-selector-test.XXXXXX")"
trap 'rm -rf -- "$trial"' EXIT
mkdir -p "$trial/runtime/scripts" "$trial/state/inir" "$trial/home" "$trial/rust-a" "$trial/rust-b"
cp "$root/scripts/native-dispatch" "$trial/runtime/scripts/native-dispatch"
cat > "$trial/runtime/scripts/niri-config.py" <<'PY'
import sys
print("python:" + " ".join(sys.argv[1:]))
PY
cat > "$trial/rust-a/inir-native" <<'SH'
#!/usr/bin/env bash
printf 'rust-a:%s\n' "$*"
SH
cat > "$trial/rust-b/inir-native" <<'SH'
#!/usr/bin/env bash
printf 'rust-b:%s\n' "$*"
SH
chmod +x "$trial/rust-a/inir-native" "$trial/rust-b/inir-native"

dispatch="$trial/runtime/scripts/native-dispatch"
base_env=(env -u INIR_NATIVE_BACKEND -u INIR_NATIVE_BIN_DIR -u INIR_NATIVE_STRICT
    XDG_STATE_HOME="$trial/state" HOME="$trial/home")
assert_equal() {
    [[ "$1" == "$2" ]] || { printf 'expected <%s>, got <%s>\n' "$2" "$1" >&2; exit 1; }
}
assert_status() {
    local expected="$1"
    shift
    local actual
    if "$@" >"$trial/stdout" 2>"$trial/stderr"; then actual=0; else actual=$?; fi
    [[ "$actual" == "$expected" ]] || {
        printf 'expected exit %s, got %s; stdout=%s stderr=%s\n' \
            "$expected" "$actual" "$(cat "$trial/stdout")" "$(cat "$trial/stderr")" >&2
        exit 1
    }
}

assert_equal "$("${base_env[@]}" "$dispatch" niri get-hot-corners)" 'python:get-hot-corners'
printf 'rust\n' > "$trial/state/inir/native-backend"
printf '%s\n' "$trial/rust-a" > "$trial/state/inir/native-bin-dir"
assert_equal "$("${base_env[@]}" "$dispatch" niri get-hot-corners)" 'rust-a:niri get-hot-corners'
assert_equal "$("${base_env[@]}" INIR_NATIVE_BACKEND=python "$dispatch" niri get-hot-corners)" 'python:get-hot-corners'
assert_equal "$("${base_env[@]}" INIR_NATIVE_BIN_DIR="$trial/rust-b" "$dispatch" niri get-hot-corners)" 'rust-b:niri get-hot-corners'
assert_equal "$("${base_env[@]}" "$dispatch" backend-info | sed -n '1,2p')" \
    "$(printf 'mode=rust\nbin_dir=%s' "$trial/rust-a")"

for command in input-lock input-keys niri diagnostics clipboard-store mpd mpd-daemon mpd-subscribe theme desktop-icons; do
    assert_status 127 "${base_env[@]}" INIR_NATIVE_BACKEND=rust INIR_NATIVE_STRICT=1 \
        INIR_NATIVE_BIN_DIR="$trial/missing" "$dispatch" "$command" fake
    [[ ! -s "$trial/stdout" ]] || { echo "strict $command fell back to Python" >&2; exit 1; }
    grep -Fq 'missing Rust binary' "$trial/stderr"
done

assert_equal "$("${base_env[@]}" INIR_NATIVE_BACKEND=auto \
    INIR_NATIVE_BIN_DIR="$trial/missing" "$dispatch" niri get-hot-corners)" 'python:get-hot-corners'
cat > "$trial/rust-b/inir-native" <<'SH'
#!/usr/bin/env bash
exit 42
SH
chmod +x "$trial/rust-b/inir-native"
assert_status 0 "${base_env[@]}" INIR_NATIVE_BACKEND=rust \
    INIR_NATIVE_BIN_DIR="$trial/rust-b" "$dispatch" niri get-hot-corners
assert_equal "$(cat "$trial/stdout")" 'python:get-hot-corners'
grep -Fq 'falling back to Python' "$trial/stderr"
assert_status 42 "${base_env[@]}" INIR_NATIVE_BACKEND=rust INIR_NATIVE_STRICT=1 \
    INIR_NATIVE_BIN_DIR="$trial/rust-b" "$dispatch" niri get-hot-corners
[[ ! -s "$trial/stdout" ]] || { echo 'strict Rust failure fell back to Python' >&2; exit 1; }

assert_status 64 "${base_env[@]}" INIR_NATIVE_BACKEND=invalid "$dispatch" niri get-hot-corners
[[ ! -s "$trial/stdout" ]] || { echo 'invalid mode fell back to Python' >&2; exit 1; }
grep -Fq 'invalid INIR_NATIVE_BACKEND' "$trial/stderr"

echo 'PASS: native selector state, precedence, strict failure, and fallback behavior'
