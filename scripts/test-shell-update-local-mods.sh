#!/usr/bin/env bash
set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd)
helper="$repo_root/scripts/check-local-modifications.sh"

tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
repo="$tmp/repo"
target="$tmp/target"
manifest="$tmp/manifest"
mkdir -p "$repo" "$target"

git init -q "$repo"
git -C "$repo" config user.email test@example.invalid
git -C "$repo" config user.name Test

printf 'same\n' > "$repo/same.qml"
printf 'old\n' > "$repo/changed.qml"
printf 'space\n' > "$repo/space name.qml"
printf 'legacy\n' > "$repo/legacy.txt"
printf 'legacy old\n' > "$repo/legacy changed.txt"
git -C "$repo" add .
git -C "$repo" commit -qm init

cp "$repo/same.qml" "$target/same.qml"
printf 'new\n' > "$target/changed.qml"
cp "$repo/space name.qml" "$target/space name.qml"
cp "$repo/legacy.txt" "$target/legacy.txt"
printf 'legacy new\n' > "$target/legacy changed.txt"
: > "$target/repo-missing-empty.txt"
printf 'not empty\n' > "$target/repo-missing-nonempty.txt"

same_hash=$(sha256sum "$repo/same.qml"); same_hash=${same_hash%% *}
changed_hash=$(sha256sum "$repo/changed.qml"); changed_hash=${changed_hash%% *}
space_hash=$(sha256sum "$repo/space name.qml"); space_hash=${space_hash%% *}
cat > "$manifest" <<EOF
# inir-manifest v2
same.qml:$same_hash
changed.qml:$changed_hash
space name.qml:$space_hash
legacy.txt:
legacy changed.txt:
repo-missing-empty.txt:
repo-missing-nonempty.txt:
missing-local.qml:$same_hash
EOF

expected=$'changed.qml\nlegacy changed.txt\nrepo-missing-nonempty.txt'
actual=$("$helper" "$manifest" "$target" "$repo")
[[ "$actual" == "$expected" ]] || {
    printf 'expected:\n%s\nactual:\n%s\n' "$expected" "$actual" >&2
    exit 1
}

missing=$("$helper" "$tmp/does-not-exist" "$target" "$repo")
[[ -z "$missing" ]] || {
    printf 'missing manifest must produce no modifications\n' >&2
    exit 1
}

printf 'shell update local modification batching: ok\n'
