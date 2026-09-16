#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
runtime_root="$(cd -- "$script_dir/.." && pwd)"
service="$runtime_root/services/deferred/NewsService.qml"

python3 - "$service" <<'PY'
import pathlib
import sys

service = pathlib.Path(sys.argv[1])
text = service.read_text(encoding="utf-8")

parse_marker = 'const parsed = root._parseRss(xhr.responseText)'
guard_marker = 'if (generation !== root._requestGeneration)'
cache_marker = 'root._cache[url] = parsed'
timestamp_marker = 'root._cacheTimestamps[url] = Date.now()'
articles_marker = 'root.articles = parsed'

try:
    parsed = text.index(parse_marker)
    guard = text.index(guard_marker, parsed)
    cache = text.index(cache_marker, parsed)
    timestamp = text.index(timestamp_marker, parsed)
    articles = text.index(articles_marker, parsed)
except ValueError as exc:
    raise SystemExit(f"FAIL: NewsService response contract marker missing: {exc}")

if not parsed < guard < cache < timestamp < articles:
    raise SystemExit(
        "FAIL: stale NewsService responses can mutate cache before the generation guard"
    )

print("PASS: NewsService rejects stale responses before cache mutation")
PY
