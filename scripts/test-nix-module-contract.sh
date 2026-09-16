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

for file in "$common" "$nixos" "$home"; do
  [[ -f "$file" ]] || fail "missing Nix module file: $file"
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

printf '%s\n' '1..1'
printf '%s\n' 'ok 1 - NixOS and Home Manager service package contracts are coherent'
