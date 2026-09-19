#!/usr/bin/env bash
set -euo pipefail
destination="${1:?Usage: build-pointer.sh BUILD_DIRECTORY}"
script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p -- "$destination"
curl --fail --location --silent --show-error \
    https://raw.githubusercontent.com/swaywm/wlr-protocols/b010a03648b88d143236de193bddbfea0c08bc84/unstable/wlr-virtual-pointer-unstable-v1.xml \
    -o "$destination/pointer.xml"
(cd -- "$destination" && printf '%s\n' '3ff6d540be0bc5228195bf072bde42117ea17945a5c2061add5d3cf97d6bb524  pointer.xml' | sha256sum --check --status)
wayland-scanner client-header "$destination/pointer.xml" "$destination/pointer-client.h"
wayland-scanner private-code "$destination/pointer.xml" "$destination/pointer-protocol.c"
cc -Wall -Wextra -Werror -O2 -I "$destination" \
    "$script_directory/virtual-pointer.c" "$destination/pointer-protocol.c" \
    $(pkg-config --cflags --libs wayland-client) -o "$destination/pointer"
printf '%s\n' "$destination/pointer"
