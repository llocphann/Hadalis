#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_PARENT="$PWD"
SETTLE_SECONDS="0.8"
KEEP_WINDOW=0

usage() {
    cat <<'EOF'
Usage: scripts/capture-code-workflow-ui.sh [options]

Automate the real Hadalis Code Workflow Settings page on Niri, capture a
deterministic screenshot/state bundle, and package it as a .tar.gz for review.

Options:
  --output-dir DIR   Parent directory for the capture folder/archive (default: $PWD)
  --settle SECONDS   Delay after each UI action before capture (default: 0.8)
  --keep-window      Leave the capture Settings window open after packaging
  -h, --help         Show this help

The script:
  * launches the repo's settings.qml directly on Code Workflow (page 30)
  * enables the opt-in QS_CODE_WORKFLOW_CAPTURE harness only for that process
  * fullscreens only the Settings window before grim capture
  * exercises baseline/filter/keyboard/edge/connect/parser-source states
  * restores the pre-capture Code Workflow session state
  * writes screenshots, IPC state, Niri geometry, logs, source snapshots and metadata
  * creates hadalis-code-workflow-capture-<timestamp>.tar.gz
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output-dir)
            [[ $# -ge 2 ]] || { echo "Missing value for --output-dir" >&2; exit 2; }
            OUT_PARENT="$2"
            shift 2
            ;;
        --settle)
            [[ $# -ge 2 ]] || { echo "Missing value for --settle" >&2; exit 2; }
            SETTLE_SECONDS="$2"
            shift 2
            ;;
        --keep-window)
            KEEP_WINDOW=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

for cmd in jq niri grim tar git sha256sum python3; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "Missing required command: $cmd" >&2
        exit 1
    }
done

if command -v quickshell >/dev/null 2>&1; then
    QS_BIN="$(command -v quickshell)"
elif command -v qs >/dev/null 2>&1; then
    QS_BIN="$(command -v qs)"
else
    echo "Missing Quickshell CLI (quickshell/qs)" >&2
    exit 1
fi

WTYPE_BIN=""
if command -v wtype >/dev/null 2>&1; then
    WTYPE_BIN="$(command -v wtype)"
fi

[[ -x "$ROOT/scripts/inir" ]] || {
    echo "Expected executable launcher: $ROOT/scripts/inir" >&2
    exit 1
}
[[ -f "$ROOT/settings.qml" ]] || {
    echo "Expected settings entrypoint: $ROOT/settings.qml" >&2
    exit 1
}

mkdir -p "$OUT_PARENT"
OUT_PARENT="$(cd -- "$OUT_PARENT" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
BUNDLE_NAME="hadalis-code-workflow-capture-$STAMP"
BUNDLE_DIR="$OUT_PARENT/$BUNDLE_NAME"
ARCHIVE="$OUT_PARENT/$BUNDLE_NAME.tar.gz"
mkdir -p "$BUNDLE_DIR"/{screenshots,state,logs,source,meta}

SETTINGS_PID=""
WINDOW_ID=""
OUTPUT_NAME=""
RESTORED=0

log() {
    printf '[capture] %s\n' "$*" | tee -a "$BUNDLE_DIR/logs/runner.log"
}

ipc() {
    "$QS_BIN" -p "$ROOT/settings.qml" ipc call codeWorkflowCapture "$@"
}

settings_window_json() {
    niri msg -j windows | jq --argjson id "$WINDOW_ID" \
        '[.[] | select(.id == $id)]'
}

cleanup() {
    local rc=$?
    set +e

    if [[ -n "$SETTINGS_PID" && "$RESTORED" -eq 0 ]]; then
        ipc restore >>"$BUNDLE_DIR/logs/restore.log" 2>&1
        if [[ $? -eq 0 ]]; then
            RESTORED=1
        fi
    fi

    if [[ "$KEEP_WINDOW" -eq 0 && -n "$SETTINGS_PID" ]]; then
        kill "$SETTINGS_PID" >/dev/null 2>&1 || true
        wait "$SETTINGS_PID" >/dev/null 2>&1 || true
    fi

    if [[ $rc -ne 0 ]]; then
        printf '[capture] FAILED with exit code %d\n' "$rc" | tee -a "$BUNDLE_DIR/logs/runner.log" >&2
        printf '[capture] Partial bundle retained at: %s\n' "$BUNDLE_DIR" >&2
    fi
}
trap cleanup EXIT INT TERM

log "repo: $ROOT"
log "bundle: $BUNDLE_DIR"

git -C "$ROOT" rev-parse HEAD >"$BUNDLE_DIR/meta/git-head.txt"
git -C "$ROOT" status --short \
    | grep -vF "?? $BUNDLE_NAME/" \
    >"$BUNDLE_DIR/meta/git-status.txt" || true
git -C "$ROOT" diff --stat >"$BUNDLE_DIR/meta/git-diff-stat.txt"
(niri --version || true) >"$BUNDLE_DIR/meta/niri-version.txt" 2>&1
("$QS_BIN" --version || true) >"$BUNDLE_DIR/meta/quickshell-version.txt" 2>&1
{
    printf 'path: %s\n' "$(command -v grim)"
    if command -v pacman >/dev/null 2>&1; then
        pacman -Q grim 2>/dev/null || true
    fi
} >"$BUNDLE_DIR/meta/grim-version.txt"
if [[ -n "$WTYPE_BIN" ]]; then
    {
        printf 'path: %s\n' "$WTYPE_BIN"
        if command -v pacman >/dev/null 2>&1; then
            pacman -Q wtype 2>/dev/null || true
        fi
    } >"$BUNDLE_DIR/meta/wtype-version.txt"
else
    printf 'wtype unavailable; filter keyboard step will use IPC fallback\n' \
        >"$BUNDLE_DIR/meta/wtype-version.txt"
fi

cp "$ROOT/modules/settings/CodeWorkflow.qml" "$BUNDLE_DIR/source/"
cp "$ROOT/modules/settings/CodeWorkflowIrCanvas.qml" "$BUNDLE_DIR/source/"
cp "$ROOT/services/CodeWorkflowSession.qml" "$BUNDLE_DIR/source/"
cp "$ROOT/defaults/code-workflow-ir.json" "$BUNDLE_DIR/source/"
cp "$0" "$BUNDLE_DIR/source/capture-code-workflow-ui.sh"

log "launching standalone Settings directly on Code Workflow page 30"
QS_SETTINGS_PAGE=30 \
QS_CODE_WORKFLOW_CAPTURE=1 \
"$ROOT/scripts/inir" settings-window -c "$ROOT" \
    >"$BUNDLE_DIR/logs/settings-window.log" 2>&1 &
SETTINGS_PID=$!

for _ in $(seq 1 80); do
    if ! kill -0 "$SETTINGS_PID" >/dev/null 2>&1; then
        log "Settings process exited before capture harness became ready"
        tail -n 80 "$BUNDLE_DIR/logs/settings-window.log" >&2 || true
        exit 1
    fi
    if ipc status >"$BUNDLE_DIR/state/00-ready.txt" 2>>"$BUNDLE_DIR/logs/ipc-errors.log"; then
        break
    fi
    sleep 0.15
done

if ! ipc status >/dev/null 2>&1; then
    log "Timed out waiting for codeWorkflowCapture IPC"
    exit 1
fi

ipc begin >"$BUNDLE_DIR/state/00-baseline-before-capture.txt" \
    2>>"$BUNDLE_DIR/logs/ipc-errors.log"

for _ in $(seq 1 80); do
    WINDOW_ID="$(niri msg -j windows | jq -r '
        [.[] | select(.title == "illogical-impulse Settings")]
        | sort_by(.id) | last | .id // empty
    ')"
    [[ -n "$WINDOW_ID" ]] && break
    sleep 0.15
done

[[ -n "$WINDOW_ID" ]] || {
    log "Could not locate the standalone Settings window in niri"
    exit 1
}
log "settings window id: $WINDOW_ID"

WINDOW_FOCUSED="$(niri msg -j windows | jq -r --argjson id "$WINDOW_ID" '
    .[] | select(.id == $id) | .is_focused // false
')"
if [[ "$WINDOW_FOCUSED" != "true" ]]; then
    niri msg action focus-window --id "$WINDOW_ID" \
        >>"$BUNDLE_DIR/logs/niri-actions.log" 2>&1 || {
        log "Could not focus Settings window; refusing to fullscreen another window"
        exit 1
    }
    sleep 0.2
fi

WINDOW_FULLSCREEN="$(niri msg -j windows | jq -r --argjson id "$WINDOW_ID" '
    .[] | select(.id == $id) | .is_fullscreen // false
')"
if [[ "$WINDOW_FULLSCREEN" != "true" ]]; then
    niri msg action fullscreen-window --id "$WINDOW_ID" \
        >>"$BUNDLE_DIR/logs/niri-actions.log" 2>&1 || {
        log "Could not fullscreen Settings window"
        exit 1
    }
    sleep 0.35
fi

WORKSPACE_ID="$(niri msg -j windows | jq -r --argjson id "$WINDOW_ID" '
    .[] | select(.id == $id) | .workspace_id // empty
')"
[[ -n "$WORKSPACE_ID" ]] || {
    log "Settings window has no workspace_id"
    exit 1
}

OUTPUT_NAME="$(niri msg -j workspaces | jq -r --argjson id "$WORKSPACE_ID" '
    .[] | select(.id == $id) | .output // empty
')"
[[ -n "$OUTPUT_NAME" ]] || {
    log "Could not resolve output for Settings workspace"
    exit 1
}
log "capture output: $OUTPUT_NAME"

niri msg -j outputs >"$BUNDLE_DIR/meta/niri-outputs.json"
niri msg -j workspaces | jq --argjson id "$WORKSPACE_ID" \
    '[.[] | select(.id == $id)]' >"$BUNDLE_DIR/meta/niri-workspace.json"
settings_window_json >"$BUNDLE_DIR/meta/niri-settings-window.json"

capture_step() {
    local index="$1"
    local name="$2"
    local scenario="${3:-}"
    local state_file="$BUNDLE_DIR/state/${index}-${name}.txt"
    local png_file="$BUNDLE_DIR/screenshots/${index}-${name}.png"

    if [[ -n "$scenario" ]]; then
        ipc scenario "$scenario" >"$state_file" \
            2>>"$BUNDLE_DIR/logs/ipc-errors.log"
    else
        ipc status >"$state_file" \
            2>>"$BUNDLE_DIR/logs/ipc-errors.log"
    fi

    sleep "$SETTLE_SECONDS"
    ipc status >>"$state_file" \
        2>>"$BUNDLE_DIR/logs/ipc-errors.log" || true
    settings_window_json >"$BUNDLE_DIR/state/${index}-${name}-window.json"

    grim -o "$OUTPUT_NAME" "$png_file"
    log "captured ${index}-${name}.png"
}

capture_step "01" "overview" "overview"

# Exercise the actual TextField path when wtype is installed. The harness only
# places focus; typing and focus traversal are delivered through Wayland input.
ipc scenario filter-input >"$BUNDLE_DIR/state/02-filter-input-setup.txt" \
    2>>"$BUNDLE_DIR/logs/ipc-errors.log"
sleep "$SETTLE_SECONDS"
if [[ -n "$WTYPE_BIN" ]]; then
    "$WTYPE_BIN" "sidebar"
    sleep "$SETTLE_SECONDS"
    capture_step "02" "filter-typed"

    "$WTYPE_BIN" -k Tab
    sleep "$SETTLE_SECONDS"
    capture_step "03" "filter-next-focus"

    "$WTYPE_BIN" -k Tab
    "$WTYPE_BIN" -k Return
    sleep "$SETTLE_SECONDS"
    capture_step "04" "filter-keyboard-select"
else
    capture_step "02" "filter-ipc-fallback" "filter-sidebar"
fi

capture_step "05" "edge-detour" "edge-detour"
capture_step "06" "edge-readonly-binding" "edge-readonly-binding"
capture_step "07" "connect-candidate" "connect-candidate"
capture_step "08" "pane-resize" "pane-resize"

# Parser/source scenario may need a short analysis cycle. Re-issue the idempotent
# scenario until analyzer READY has had enough time to select an entry.
for _ in $(seq 1 12); do
    ipc scenario semantic-source \
        >"$BUNDLE_DIR/state/09-semantic-source-attempt.txt" \
        2>>"$BUNDLE_DIR/logs/ipc-errors.log" || true
    sleep 0.25
done
capture_step "09" "semantic-source"
ipc status >"$BUNDLE_DIR/meta/parser-capability.json" \
    2>>"$BUNDLE_DIR/logs/ipc-errors.log" || true
PARSER_STATUS="$(jq -r '.analyzerStatus // "unknown"' \
    "$BUNDLE_DIR/meta/parser-capability.json" 2>/dev/null || printf 'unknown')"
PARSER_ERROR="$(jq -r '.analyzerError // ""' \
    "$BUNDLE_DIR/meta/parser-capability.json" 2>/dev/null || true)"

python3 - "$BUNDLE_DIR/state" \
    "$BUNDLE_DIR/meta/route-diagnostics.json" <<'PY'
import json
import sys
from pathlib import Path

state_dir = Path(sys.argv[1])
output = Path(sys.argv[2])
rows = []
for path in sorted(state_dir.glob("[0-9][0-9]-*.txt")):
    latest = None
    for line in path.read_text(
        encoding="utf-8", errors="replace"
    ).splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            payload = json.loads(line)
        except json.JSONDecodeError:
            continue
        candidate = payload.get("status", payload)
        if isinstance(candidate, dict) and "routeDiagnostics" in candidate:
            latest = candidate
    if latest is None:
        continue
    rows.append({
        "step": path.stem,
        "subflowTargetId": latest.get("subflowTargetId", ""),
        "zoom": latest.get("zoom"),
        "targetsPaneWidth": latest.get("targetsPaneWidth"),
        "inspectorPaneWidth": latest.get("inspectorPaneWidth"),
        "sourcePreviewHeight": latest.get("sourcePreviewHeight"),
        "routeDiagnostics": latest.get("routeDiagnostics", {}),
    })

output.write_text(
    json.dumps({"steps": rows}, indent=2, ensure_ascii=False) + "\n",
    encoding="utf-8",
)
PY

ipc restore >"$BUNDLE_DIR/state/99-restored.txt" \
    2>>"$BUNDLE_DIR/logs/ipc-errors.log"
RESTORED=1
sleep 0.25

cat >"$BUNDLE_DIR/README.txt" <<EOF
Hadalis Code Workflow UI capture
================================

Created: $(date --iso-8601=seconds)
Git HEAD: $(cat "$BUNDLE_DIR/meta/git-head.txt")
Niri output: $OUTPUT_NAME
Settings window id: $WINDOW_ID

Screenshots:
  01-overview
      Bar workflow baseline after Fit graph.
  02-filter-typed / 02-filter-ipc-fallback
      Targets filtered to "sidebar". wtype is preferred so the real TextField
      input path is exercised.
  03-filter-next-focus
      Keyboard Tab focus after the filtered TextField.
  04-filter-keyboard-select
      Second Tab + Return from the filtered list path.
  05-edge-detour
      resources.action.keepAlive selected; exercises obstacle-aware route.
  06-edge-readonly-binding
      media.data.player selected; exercises read-only edge -> binding context.
  07-connect-candidate
      clock.connect.rootVisible selected.
  08-pane-resize
      Targets/Inspector/Source Preview expanded to persisted non-default sizes;
      validates both horizontal and vertical split handles.
  09-semantic-source
      Source Preview after parser polling.
      Parser status: $PARSER_STATUS
      Parser detail: $PARSER_ERROR
      READY includes semantic selection; UNAVAILABLE/ERROR intentionally records
      the read-only source fallback instead.

Routing diagnostics:
  meta/route-diagnostics.json summarizes smart-lane style, collisions,
  crossings, non-endpoint overlap, bends, zoom and persisted pane dimensions
  for every captured state.

Privacy:
  grim captures only the Niri output containing the Settings window, after the
  script fullscreens that Settings window. The bundle stores only the selected
  Settings window's Niri window record rather than the full window list.

Runtime scope:
  This runner launches standalone settings.qml. That process has isolated
  Quickshell singletons, so live shell runtime records/picker can legitimately
  appear as UNLOADED / STATIC SOURCE. The bundle validates rendering, target
  navigation, graph geometry, source preview and parser capability; live picker
  acceptance still requires an in-shell/overlay run.

State safety:
  Code Workflow session state is snapshotted through the opt-in capture harness
  and restored before packaging. No source mutation or Apply action is invoked.
EOF

{
    printf '{\n'
    printf '  "created": %s,\n' "$(date --iso-8601=seconds | jq -R .)"
    printf '  "gitHead": %s,\n' "$(cat "$BUNDLE_DIR/meta/git-head.txt" | jq -R .)"
    printf '  "output": %s,\n' "$(printf '%s' "$OUTPUT_NAME" | jq -R .)"
    printf '  "windowId": %s,\n' "$WINDOW_ID"
    printf '  "wtypeAvailable": %s,\n' "$([[ -n "$WTYPE_BIN" ]] && echo true || echo false)"
    printf '  "settleSeconds": %s\n' "$(printf '%s' "$SETTLE_SECONDS" | jq -R .)"
    printf '}\n'
} >"$BUNDLE_DIR/meta/capture.json"

python3 - "$BUNDLE_DIR/logs/settings-window.log" \
    "$BUNDLE_DIR/meta/code-workflow-runtime-warnings.txt" <<'PY'
import re
import sys
from pathlib import Path

source = Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
source = re.sub(r"\x1b\[[0-9;]*m", "", source)
matches = []
for line in source.splitlines():
    if (
        "CodeWorkflow" in line
        and (
            "ReferenceError:" in line
            or "TypeError:" in line
            or "Unable to assign [undefined]" in line
        )
    ):
        matches.append(line)
Path(sys.argv[2]).write_text(
    "\n".join(matches) + ("\n" if matches else ""),
    encoding="utf-8",
)
PY

(
    cd "$BUNDLE_DIR"
    find . -type f ! -name SHA256SUMS -print0 \
        | sort -z \
        | xargs -0 sha256sum >SHA256SUMS
)

tar -C "$OUT_PARENT" -czf "$ARCHIVE" "$BUNDLE_NAME"

log "archive ready: $ARCHIVE"
printf '\n%s\n' "$ARCHIVE"

trap - EXIT INT TERM
cleanup
