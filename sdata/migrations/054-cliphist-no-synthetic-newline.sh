#!/usr/bin/env bash

MIGRATION_ID="054-cliphist-no-synthetic-newline"
MIGRATION_TITLE="Preserve clipboard text payloads"
MIGRATION_DESCRIPTION="Adds wl-paste --no-newline to active Niri text-history watchers so cliphist round trips do not accumulate synthetic trailing newlines."
MIGRATION_TARGET_FILE="~/.config/niri/config.d/50-startup.kdl"
MIGRATION_REQUIRED=true

MIGRATION_SESSION_IMPACT=true
MIGRATION_SESSION_REFERENCE="Niri clipboard text watcher"
MIGRATION_SESSION_REASON="The corrected watcher is spawned by Niri at login, so the current wl-paste process keeps the old arguments until the session is restarted."
MIGRATION_SESSION_EFFECT="Clipboard history can keep accumulating visually duplicate text entries for the rest of the current login session."
MIGRATION_SESSION_ACTION="Log out and back in to restart the clipboard watcher with the corrected arguments."

migration_check() {
  local xdg_config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  local startup_cfg="${xdg_config_home}/niri/config.d/50-startup.kdl"
  local monolithic_cfg="${xdg_config_home}/niri/config.kdl"

  python3 - "$startup_cfg" "$monolithic_cfg" <<'PY'
from pathlib import Path
import re
import sys

spawn = re.compile(r'^[ \t]*(?:spawn-at-startup|spawn-sh-at-startup)\b')
text_type = re.compile(r'--type[ \t]+text(?:/plain)?\b')

def active_text_watcher(line: str) -> bool:
    stripped = line.lstrip()
    return (
        not stripped.startswith("//")
        and spawn.search(line) is not None
        and "wl-paste" in line
        and text_type.search(line) is not None
        and "--watch" in line
    )

for raw in sys.argv[1:]:
    path = Path(raw)
    if not path.is_file():
        continue
    for line in path.read_text(encoding="utf-8").splitlines():
        if active_text_watcher(line) and "--no-newline" not in line:
            raise SystemExit(0)

raise SystemExit(1)
PY
}

migration_preview() {
  echo -e "${STY_RED}- wl-paste --type text --watch ...${STY_RST}"
  echo -e "${STY_GREEN}+ wl-paste --no-newline --type text --watch ...${STY_RST}"
  echo ""
  echo "wl-paste otherwise synthesizes a trailing newline for text selections."
  echo "Reusing a history entry can therefore change its payload and bypass cliphist"
  echo "deduplication. Existing history is left untouched."
}

migration_apply() {
  local xdg_config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  local startup_cfg="${xdg_config_home}/niri/config.d/50-startup.kdl"
  local monolithic_cfg="${xdg_config_home}/niri/config.kdl"

  python3 - "$startup_cfg" "$monolithic_cfg" <<'PY' || return 1
from pathlib import Path
import re
import sys

spawn = re.compile(r'^[ \t]*(?:spawn-at-startup|spawn-sh-at-startup)\b')
text_type = re.compile(r'--type[ \t]+text(?:/plain)?\b')

def active_text_watcher(line: str) -> bool:
    stripped = line.lstrip()
    return (
        not stripped.startswith("//")
        and spawn.search(line) is not None
        and "wl-paste" in line
        and text_type.search(line) is not None
        and "--watch" in line
    )

found = False
for raw in sys.argv[1:]:
    path = Path(raw)
    if not path.is_file():
        continue

    lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
    changed = False
    for index, line in enumerate(lines):
        if not active_text_watcher(line):
            continue
        found = True
        if "--no-newline" in line:
            continue
        if "wl-paste " not in line:
            raise SystemExit(f"cannot patch clipboard watcher in {path}")
        lines[index] = line.replace("wl-paste ", "wl-paste --no-newline ", 1)
        changed = True

    if changed:
        path.write_text("".join(lines), encoding="utf-8")

if not found:
    raise SystemExit("no active Niri clipboard text watcher found")

for raw in sys.argv[1:]:
    path = Path(raw)
    if not path.is_file():
        continue
    for line in path.read_text(encoding="utf-8").splitlines():
        if active_text_watcher(line) and "--no-newline" not in line:
            raise SystemExit(f"clipboard watcher still lacks --no-newline in {path}")
PY
}
