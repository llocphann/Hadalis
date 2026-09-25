#!/usr/bin/env bash
set -euo pipefail

# Lightweight static audit helper for the QML lifecycle optimization phase.
# It does not modify runtime behaviour; it highlights likely retained-work hotspots.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

printf 'QML lifecycle audit: %s\n\n' "$repo_root"

printf '== Timers ==\n'
grep -RIn --include='*.qml' 'Timer {' "$repo_root" | sed "s#$repo_root/##" | head -80 || true

printf '\n== Loader / LazyLoader ==\n'
grep -RIn --include='*.qml' -E 'Loader \{|LazyLoader \{' "$repo_root" | sed "s#$repo_root/##" | head -80 || true

printf '\n== Animations ==\n'
grep -RIn --include='*.qml' -E 'Animation \{|NumberAnimation|SequentialAnimation|ParallelAnimation' "$repo_root" | sed "s#$repo_root/##" | head -80 || true

printf '\n== Global state consumers ==\n'
grep -RIn --include='*.qml' 'GlobalStates\.' "$repo_root" | sed "s#$repo_root/##" | wc -l | awk '{print "GlobalStates references:",$1}'

grep -RIn --include='*.qml' 'Config\.' "$repo_root" | sed "s#$repo_root/##" | wc -l | awk '{print "Config references:",$1}'

printf '\nAudit complete. Use this output to select measured optimization targets.\n'
