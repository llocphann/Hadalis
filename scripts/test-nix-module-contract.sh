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

for file in "$common" "$nixos" "$home" "$package" "$switchwall" "$color_generator"; do
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

printf '%s\n' '1..1'
printf '%s\n' 'ok 1 - NixOS, Home Manager, and packaged runtime contracts are coherent'
