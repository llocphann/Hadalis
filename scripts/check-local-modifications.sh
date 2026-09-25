#!/usr/bin/env bash
set -u

manifest=${1:-}
target=${2:-}
repo=${3:-}

[[ -n "$manifest" && -n "$target" && -n "$repo" ]] || exit 0
[[ -f "$manifest" ]] || exit 0

declare -a manifest_paths=()
declare -a checksum_files=()
declare -a legacy_paths=()
declare -A expected_by_file=()
declare -A relative_by_file=()
declare -A modified=()

mark_legacy_fallback() {
    local path repo_hash local_hash
    for path in "$@"; do
        repo_hash=$(git -C "$repo" show HEAD:"$path" 2>/dev/null | sha256sum | cut -d' ' -f1)
        local_hash=$(sha256sum "$target/$path" 2>/dev/null | cut -d' ' -f1)
        [[ -n "$repo_hash" && "$repo_hash" != "$local_hash" ]] && modified["$path"]=1
    done
}

while IFS=: read -r path checksum; do
    [[ "$path" =~ ^# ]] && continue
    [[ -z "$path" ]] && continue
    file="$target/$path"
    [[ -f "$file" ]] || continue
    manifest_paths+=("$path")

    # Preserve the old per-file sha256sum/cut result for the one filename form
    # that GNU sha256sum escapes in its normal text output.
    if [[ "$path" == *\\* ]]; then
        if [[ -n "$checksum" || -d "$repo/.git" ]]; then
            modified["$path"]=1
        fi
        continue
    fi

    if [[ -n "$checksum" ]]; then
        checksum_files+=("$file")
        expected_by_file["$file"]="$checksum"
        relative_by_file["$file"]="$path"
    elif [[ -d "$repo/.git" ]]; then
        legacy_paths+=("$path")
    fi
done < "$manifest"

# Keep argv comfortably bounded while replacing one sha256sum+cut pair per v2
# code file with a small number of checksum batches.
chunk_size=128
for ((offset=0; offset<${#checksum_files[@]}; offset+=chunk_size)); do
    chunk=("${checksum_files[@]:offset:chunk_size}")
    chunk_output=$(sha256sum "${chunk[@]}" 2>/dev/null)
    chunk_rc=$?
    if (( chunk_rc != 0 )); then
        # Preserve fail-soft behavior if a file disappears during the scan.
        for file in "${chunk[@]}"; do
            current=$(sha256sum "$file" 2>/dev/null | cut -d' ' -f1)
            [[ "$current" != "${expected_by_file[$file]-}" ]] \
                && modified["${relative_by_file[$file]}"]=1
        done
        continue
    fi

    while IFS= read -r entry; do
        [[ -n "$entry" ]] || continue
        hash=${entry%% *}
        file=${entry#*  }
        [[ "$hash" != "${expected_by_file[$file]-}" ]] \
            && modified["${relative_by_file[$file]}"]=1
    done <<< "$chunk_output"
done

if (( ${#legacy_paths[@]} > 0 )); then
    repo_specs=""
    local_paths=""
    sep=""
    for path in "${legacy_paths[@]}"; do
        repo_specs+="${sep}HEAD:$path"
        local_paths+="${sep}$target/$path"
        sep=$'\n'
    done

    # For blank-checksum/legacy entries, compare Git blob IDs in two batched
    # commands. --no-filters hashes the installed bytes as-is, matching the old
    # git-show -> sha256sum versus local-file -> sha256sum equality test.
    repo_hash_output=$(git -C "$repo" cat-file --batch-check='%(objectname)' <<< "$repo_specs" 2>/dev/null)
    repo_rc=$?
    local_hash_output=$(git -C "$repo" hash-object --no-filters --stdin-paths <<< "$local_paths" 2>/dev/null)
    local_rc=$?

    if (( repo_rc != 0 || local_rc != 0 )); then
        mark_legacy_fallback "${legacy_paths[@]}"
    else
        mapfile -t repo_hashes <<< "$repo_hash_output"
        mapfile -t local_hashes <<< "$local_hash_output"
        if (( ${#repo_hashes[@]} != ${#legacy_paths[@]} || ${#local_hashes[@]} != ${#legacy_paths[@]} )); then
            mark_legacy_fallback "${legacy_paths[@]}"
        else
            for i in "${!legacy_paths[@]}"; do
                path=${legacy_paths[$i]}
                repo_hash=${repo_hashes[$i]}
                local_hash=${local_hashes[$i]}
                if [[ "$repo_hash" == *" missing" ]]; then
                    # git show of a missing path previously fed empty stdout to
                    # sha256sum, so only an empty local file compared equal.
                    [[ -s "$target/$path" ]] && modified["$path"]=1
                elif [[ -n "$repo_hash" && "$repo_hash" != "$local_hash" ]]; then
                    modified["$path"]=1
                fi
            done
        fi
    fi
fi

# The overlay has always shown modifications in manifest order.
for path in "${manifest_paths[@]}"; do
    [[ -n "${modified[$path]-}" ]] && printf '%s\n' "$path"
done
exit 0
