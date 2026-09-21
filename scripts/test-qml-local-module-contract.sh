#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
scan_root="${1:-$repo_root}"

if [[ ! -d "$scan_root" ]]; then
    printf 'qml local module contract: root not found: %s\n' "$scan_root" >&2
    exit 2
fi

python3 - "$scan_root" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1]).resolve()
skip_parts = {'.git', 'node_modules', '.venv'}


def qml_files():
    for path in sorted(root.rglob('*.qml')):
        if any(part in skip_parts for part in path.parts):
            continue
        yield path


def code_only(text: str) -> str:
    """Remove comments and string contents while preserving line structure."""
    out = []
    i = 0
    state = 'code'
    quote = ''
    while i < len(text):
        ch = text[i]
        nxt = text[i + 1] if i + 1 < len(text) else ''
        if state == 'code':
            if ch == '/' and nxt == '/':
                out.extend((' ', ' '))
                i += 2
                state = 'line-comment'
                continue
            if ch == '/' and nxt == '*':
                out.extend((' ', ' '))
                i += 2
                state = 'block-comment'
                continue
            if ch in ('"', "'", '`'):
                out.append(' ')
                quote = ch
                state = 'string'
                i += 1
                continue
            out.append(ch)
            i += 1
            continue
        if state == 'line-comment':
            if ch == '\n':
                out.append('\n')
                state = 'code'
            else:
                out.append(' ')
            i += 1
            continue
        if state == 'block-comment':
            if ch == '*' and nxt == '/':
                out.extend((' ', ' '))
                i += 2
                state = 'code'
                continue
            out.append('\n' if ch == '\n' else ' ')
            i += 1
            continue
        if state == 'string':
            if ch == '\\' and nxt:
                out.append('\n' if ch == '\n' else ' ')
                out.append('\n' if nxt == '\n' else ' ')
                i += 2
                continue
            if ch == quote:
                out.append(' ')
                i += 1
                state = 'code'
                continue
            out.append('\n' if ch == '\n' else ' ')
            i += 1
    return ''.join(out)


import_re = re.compile(r'^\s*import\s+(qs(?:\.[A-Za-z_][A-Za-z0-9_]*)*)\b')
symbol_use = lambda name: re.compile(rf'\b{re.escape(name)}\b')
files = list(qml_files())
parsed = {}
errors = []

for path in files:
    try:
        code = code_only(path.read_text(encoding='utf-8'))
    except UnicodeDecodeError as exc:
        errors.append(f'{path.relative_to(root)}: unreadable QML source: {exc}')
        continue
    parsed[path] = code
    for lineno, line in enumerate(code.splitlines(), 1):
        match = import_re.match(line)
        if not match:
            continue
        uri = match.group(1)
        parts = uri.split('.')[1:]
        if not parts:
            continue
        module_dir = root.joinpath(*parts)
        if not module_dir.is_dir():
            errors.append(
                f'{path.relative_to(root)}:{lineno}: local QML import {uri} '
                f'maps to missing directory {module_dir.relative_to(root)}'
            )

# A retired type has no valid code-level reference once its implementation is
# absent. Scan all code tokens, not only object construction, so typed
# properties/functions and other symbol references cannot survive while an old
# parser is skipped. Comments and strings were removed above to avoid stale-doc
# false positives. If a type is intentionally restored, its implementation
# automatically disables the retired-type check and falls through to the owner-
# import contract below for critical exported types.
for type_name in ('MascotImage', 'MascotAnimation', 'CompositorFocusGrab'):
    implementations = [path for path in files if path.name == f'{type_name}.qml']
    if implementations:
        continue
    pattern = symbol_use(type_name)
    for path, code in parsed.items():
        for lineno, line in enumerate(code.splitlines(), 1):
            if pattern.search(line):
                errors.append(
                    f'{path.relative_to(root)}:{lineno}: {type_name} is referenced but '
                    f'{type_name}.qml is absent from the scanned tree'
                )

# Historical startup failures involved exported local types whose implementation
# lived in qs.modules.common.widgets. If one of these compatibility/critical types
# exists, every consumer outside the owning directory must import that owner
# module. This stays valid across retirement/restoration: absent implementations
# are handled above, while restored implementations cannot silently make an
# unqualified external type token resolvable without the corresponding import.
for type_name in ('MascotImage', 'CompositorFocusGrab'):
    implementations = [path for path in files if path.name == f'{type_name}.qml']
    if len(implementations) == 1:
        impl = implementations[0]
        module_rel = impl.parent.relative_to(root)
        expected_uri = 'qs' + ('.' + '.'.join(module_rel.parts) if module_rel.parts else '')
        pattern = symbol_use(type_name)
        for path, code in parsed.items():
            if path == impl or path.parent == impl.parent or not pattern.search(code):
                continue
            imports = {
                match.group(1)
                for line in code.splitlines()
                if (match := import_re.match(line))
            }
            if expected_uri not in imports:
                errors.append(
                    f'{path.relative_to(root)}: {type_name} consumer must import '
                    f'{expected_uri} (implementation: {impl.relative_to(root)})'
                )
    elif len(implementations) > 1:
        errors.append(
            f'multiple {type_name}.qml implementations make module ownership ambiguous'
        )

if errors:
    for error in errors:
        print(f'ERROR: {error}', file=sys.stderr)
    print(f'qml local module/type contract: {len(errors)} issue(s)', file=sys.stderr)
    raise SystemExit(1)

print('qml local module/type contract: ok')
PY
