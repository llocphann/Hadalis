# Migration: make Niri iNiR keybinds independent of the compositor PATH.
# Developer installs place the launcher in XDG_BIN_HOME (normally ~/.local/bin),
# while package-managed installs place it in a system bin directory. Niri's
# `spawn` does not invoke a shell, so a bare `spawn "inir" ...` silently fails
# when the compositor PATH does not include XDG_BIN_HOME.

MIGRATION_ID="040-niri-inir-keybind-path"
MIGRATION_TITLE="Repair iNiR Niri keybind launcher lookup"
MIGRATION_DESCRIPTION="Makes iNiR Niri keybinds find the launcher in both developer and package-managed installs, even when the compositor PATH omits ~/.local/bin."
MIGRATION_TARGET_FILE="~/.config/niri/config.d/70-binds.kdl"
MIGRATION_REQUIRED=true

migration_bind_file() {
  local niri_dir="${XDG_CONFIG_HOME:-$HOME/.config}/niri"
  if [[ -f "$niri_dir/config.d/70-binds.kdl" ]]; then
    printf '%s' "$niri_dir/config.d/70-binds.kdl"
  else
    printf '%s' "$niri_dir/config.kdl"
  fi
}

migration_check() {
  local config
  config="$(migration_bind_file)"
  [[ -f "$config" ]] || return 1
  grep -Fq 'spawn "inir"' "$config"
}

migration_preview() {
  echo -e "${STY_RED}- spawn \"inir\" ... (depends on Niri PATH)${STY_RST}"
  echo -e "${STY_GREEN}+ /bin/sh wrapper prepending XDG_BIN_HOME before exec inir${STY_RST}"
}

migration_apply() {
  local config
  config="$(migration_bind_file)"
  [[ -f "$config" ]] || return 0

  INIR_MIGRATION_BIND_FILE="$config" python3 <<'PY'
import os
from pathlib import Path

path = Path(os.environ["INIR_MIGRATION_BIND_FILE"])
text = path.read_text(encoding="utf-8")
old = 'spawn "inir"'
new = (
    'spawn "/bin/sh" "-c" '
    '"PATH=\\"${XDG_BIN_HOME:-$HOME/.local/bin}:$PATH\\"; '
    'exec inir \\"$@\\"" "inir-keybind"'
)
if old in text:
    path.write_text(text.replace(old, new), encoding="utf-8")
PY
}
