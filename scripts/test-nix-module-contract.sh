#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

common="nix/module-common.nix"
nixos="nix/nixos-module.nix"
home="nix/home-module.nix"
package="nix/package.nix"
switchwall="scripts/colors/switchwall.sh"
color_generator="scripts/colors/generate_colors_material.py"
zed_module="scripts/colors/modules/31-zed.sh"
easyeffects_service="services/deferred/EasyEffects.qml"

for file in "$common" "$nixos" "$home" "$package" "$switchwall" "$color_generator" "$zed_module" "$easyeffects_service"; do
  [[ -f "$file" ]] || fail "missing Nix/runtime contract file: $file"
done

grep -Fq 'extraPackages = lib.mkOption {' "$common" \
  || fail 'programs.inir.extraPackages option is missing'
grep -Fq 'description = "Extra runtime packages made available to the Hadalis shell service.";' "$common" \
  || fail 'extraPackages no longer documents its service PATH contract'

grep -Fq 'path = [ cfg.package ] ++ cfg.extraPackages;' "$nixos" \
  || fail 'NixOS service no longer exposes extraPackages on PATH'

grep -Fq 'lib.optionalAttrs (cfg.extraPackages != [ ])' "$home" \
  || fail 'Home Manager no longer guards the extraPackages PATH override'
grep -Fq 'PATH = lib.makeBinPath ([ cfg.package ] ++ cfg.extraPackages);' "$home" \
  || fail 'Home Manager service no longer exposes extraPackages on PATH'

grep -Fq 'flock -w 5 200' "$switchwall" \
  || fail 'switchwall no longer exercises the flock runtime dependency contract'
grep -Fq '++ optionalTop "util-linux"' "$package" \
  || fail 'Nix runtime no longer provides util-linux for switchwall flock locking'

grep -Fq 'import numpy as np' "$color_generator" \
  || fail 'color generator no longer exercises the numpy runtime contract'
grep -Fq 'from PIL import Image' "$color_generator" \
  || fail 'color generator no longer exercises the Pillow runtime contract'
grep -Fq 'from materialyoucolor.quantize import QuantizeCelebi' "$color_generator" \
  || fail 'color generator no longer exercises the materialyoucolor runtime contract'
grep -Fq '(python3.withPackages (pythonPackages: with pythonPackages; [' "$package" \
  || fail 'Nix runtime no longer uses a packaged Python environment'
for python_package in materialyoucolor numpy pillow; do
  grep -Eq "^[[:space:]]+${python_package}$" "$package" \
    || fail "Nix runtime Python environment is missing ${python_package}"
done

grep -Fq 'colorPython = with pkgs;' "$package" \
  || fail 'Nix runtime no longer names the packaged color Python environment'
grep -Eq '^[[:space:]]+colorPython$' "$package" \
  || fail 'Nix runtime no longer exposes colorPython on the wrapped runtime PATH'
[[ "$(grep -Fc '${colorPython}/bin/python3' "$package")" -ge 2 ]] \
  || fail 'Nix package no longer pins switchwall to the packaged color Python interpreter'
grep -Fq '_ii_python="{color_python}"' "$package" \
  || fail 'Nix package no longer rewrites switchwall to the pinned color Python interpreter'

grep -Fq 'Quickshell.execDetached(["/usr/bin/env", "easyeffects", "--service-mode"])' "$easyeffects_service" \
  || fail 'EasyEffects service no longer exercises the PATH-resolved native runtime contract'
grep -Fq '++ optionalTop "easyeffects"' "$package" \
  || fail 'Nix runtime no longer provides EasyEffects for the default audio integration'

bash -n "$zed_module" || fail 'Zed theming module has invalid Bash syntax'
grep -Fq 'python_cmd="$(venv_python)"' "$zed_module" \
  || fail 'packaged Zed theming no longer resolves the managed/package Python runtime'
grep -Fq '"$python_cmd" "$SCRIPT_DIR/generate_terminal_configs.py"' "$zed_module" \
  || fail 'packaged Zed theming no longer falls back to the shipped Python generator'
grep -Fq -- '--zed >> "$ZED_THEMEGEN_LOG" 2>&1' "$zed_module" \
  || fail 'packaged Zed Python fallback no longer requests Zed theme generation'

printf '%s\n' '1..1'
printf '%s\n' 'ok 1 - NixOS, Home Manager, and packaged runtime contracts are coherent'
