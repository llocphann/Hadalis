#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

directories="modules/common/Directories.qml"
migration="sdata/migrations/019-config-dir-rename-compat.sh"
config_doc="docs/CONFIG_SYSTEM.md"
stable_hook="distro/arch/inir-shell/inir-shell.install"
git_hook="distro/arch/inir-shell-git/inir-shell-git.install"

for file in "$directories" "$migration" "$config_doc" "$stable_hook" "$git_hook"; do
  [[ -f "$file" ]] || fail "missing config namespace contract file: $file"
done

# The runtime still resolves its writable QML config through the historical
# namespace. Migration 019 is the compatibility boundary that makes that path
# resolve to the canonical Hadalis/iNiR directory instead of requiring a risky
# global runtime rename.
grep -Fq 'property string shellConfig: `${Directories.configPath}/illogical-impulse`' "$directories" \
  || fail 'live QML config path no longer matches the documented compatibility namespace'
grep -Fq 'MIGRATION_REQUIRED=true' "$migration" \
  || fail 'config directory compatibility migration is no longer required'
grep -Fq 'local config_new="${xdg_config_home}/inir"' "$migration" \
  || fail 'migration 019 no longer names ~/.config/inir as the canonical directory'
grep -Fq 'local config_legacy="${xdg_config_home}/illogical-impulse"' "$migration" \
  || fail 'migration 019 no longer recognizes the live QML compatibility directory'
grep -Fq 'ln -s "$config_new" "$config_legacy"' "$migration" \
  || fail 'migration 019 no longer links the QML compatibility path to the canonical directory'

# Documentation must distinguish the canonical post-migration directory from
# the path the current QML still opens, and must preserve the user-home ownership
# boundary for package/manual installs.
grep -Fq 'After required migration 019 has been applied, the canonical config file is:' "$config_doc" \
  || fail 'config docs no longer scope canonical ~/.config/inir to the migration boundary'
grep -Fq 'The live QML compatibility path is still `~/.config/illogical-impulse/config.json`.' "$config_doc" \
  || fail 'config docs no longer identify the current QML compatibility path'
grep -Fq 'Package managers and manual `make install` deliberately do not mutate arbitrary user home directories' "$config_doc" \
  || fail 'config docs no longer preserve package/manual user-home ownership'
grep -Fq 'run `inir migrate` before first launch' "$config_doc" \
  || fail 'config docs no longer tell package/manual users how to establish the canonical layout'

# Stable and VCS Arch packages must give the same ownership-safe lifecycle
# guidance. Pacman cannot apply a per-user migration from a root transaction.
cmp -s "$stable_hook" "$git_hook" \
  || fail 'stable/git Arch install hooks drifted'
for hook in "$stable_hook" "$git_hook"; do
  grep -Fq 'inir migrate' "$hook" \
    || fail "$hook no longer tells users to run the required config migration"
  grep -Fq 'Pacman does not mutate user home directories' "$hook" \
    || fail "$hook no longer explains the per-user migration ownership boundary"
  if grep -Fq 'Runtime migrations, when needed, are applied by Hadalis' "$hook"; then
    fail "$hook again implies the package transaction mutates per-user config"
  fi
done

printf '%s\n' '1..1'
printf '%s\n' 'ok 1 - config namespace migration and package ownership contracts are coherent'
