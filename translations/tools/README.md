# Translation Management Tool Suite

`translations/en_US.json` is the canonical runtime catalog. Every other locale must keep the same key set and translate only the values.

All commands below are run from the repository root. The tools resolve `translations/` and the source tree relative to the repository, so they do not depend on an installed iNiR/Hadalis config path.

## Tool roles

### `l10n.py` — structural audit and reviewed localization

Use this for locale contract checks and contextual review batches.

```bash
python3 translations/tools/l10n.py audit-all
python3 translations/tools/l10n.py audit es_AR --strict-terms
python3 translations/tools/l10n.py extract es_AR /tmp/es_AR-review.json --limit 200
python3 translations/tools/l10n.py apply /tmp/es_AR-review.json
```

`audit-all` validates key parity, placeholder structure, and locale-guide coverage against `en_US.json`. See `translations/l10n/README.md` for the reviewed translation workflow.

### `translation-manager.py` — source extraction and catalog-wide missing-key updates

The manager scans repository `*.qml` and `*.js` files for static `Translation.tr(...)` strings.

```bash
translations/tools/translation-manager.py --extract-only
translations/tools/translation-manager.py --yes
```

Before updating, the manager requires every locale keyset to match `en_US.json`. New static keys are then added to every locale together after one confirmation. It **does not prune extra keys**. Extra keys are only reported so cleanup cannot diverge locale keysets one language at a time.

### `translation-cleaner.py` — cleanup reporting, reviewed pruning, and synchronization

Static extraction is useful for finding candidates, but it cannot prove a key is unused because runtime code can call `Translation.tr(variable)`. Therefore `--clean` is deliberately **read-only**.

```bash
translations/tools/translation-cleaner.py --clean
translations/tools/translation-cleaner.py --sync
```

After reviewing candidates against dynamic callsites, prune only an explicit exact keyset:

```bash
# reviewed-keys.json must be a JSON array of exact canonical keys.
translations/tools/translation-cleaner.py --prune-file reviewed-keys.json

# Small reviewed sets can be supplied directly; --prune-key may be repeated.
translations/tools/translation-cleaner.py --prune-key "Retired label" --prune-key "Retired description"
```

Exact pruning requires every locale to match the canonical keyset before mutation, rejects unknown and `/*keep*/`-protected keys, removes the same keys from every locale through the atomic writer, and verifies parity again. Use `--yes` only after reviewing the exact set; `--no-backup` is available for controlled environments where repository history is the recovery mechanism.

### `manage-translations.sh` — wrapper

```bash
translations/tools/manage-translations.sh status
translations/tools/manage-translations.sh extract
translations/tools/manage-translations.sh update
translations/tools/manage-translations.sh clean
translations/tools/manage-translations.sh candidates
translations/tools/manage-translations.sh sync
```

`clean` prints a human-readable candidate report. `candidates` emits the same source/catalog boundary as machine-readable JSON through `source-parity.py --json`; its `orphans` array is still only an advisory static-orphan set, not an approved deletion list. Reviewed deletion intentionally stays on the explicit `translation-cleaner.py --prune-file/--prune-key` interface so a wrapper command cannot accidentally turn a heuristic orphan scan into deletion.

Custom paths remain available through `--trans-dir` and `--source-dir`.

### `auto-translate.js` — rough draft helper

This helper can fill untranslated values through Google Translate. Its output is not an approval step and must still pass the localization audits and human review.

```bash
node translations/tools/auto-translate.js es_AR
```

## Safe workflow after source changes

For ordinary source additions:

```bash
translations/tools/manage-translations.sh update
python3 translations/tools/l10n.py audit-all
```

For cleanup after deleting or retiring runtime features:

```bash
# 1. Confirm the catalog is structurally aligned before deletion.
python3 translations/tools/l10n.py audit-all

# 2. Add any newly introduced static Translation.tr(...) strings.
translations/tools/manage-translations.sh update

# 3. Capture the read-only source/catalog report and candidate list.
translations/tools/manage-translations.sh candidates > /tmp/source-parity.json
jq '.orphans' /tmp/source-parity.json > /tmp/static-orphan-candidates.json

# 4. Review those candidates against dynamic Translation.tr(...) callsites.
#    Put only proven-retired exact keys in a separate reviewed JSON array.

# 5. Prune only the reviewed exact keyset.
python3 translations/tools/translation-cleaner.py --prune-file /tmp/reviewed-retired-keys.json

# 6. Verify the resulting locale contract again.
python3 translations/tools/l10n.py audit-all
```

Do not pass `/tmp/static-orphan-candidates.json` directly to `--prune-file`. Static extraction cannot prove that every candidate is unused. Do not manually add or delete a key in only one locale either: new keys are catalog-wide updates, and retired-feature keys must be explicitly reviewed before the same exact set is removed from every locale.

## Dynamic translation keys

Static extraction cannot discover strings constructed or selected dynamically at runtime. A key that must survive cleanup analysis can also be documented in the canonical source locale with `/*keep*/` at the end of its value.

```json
{
  "dynamic_key": "Some dynamic value /*keep*/"
}
```

The preservation marker belongs in the source locale (`en_US.json`). Exact pruning refuses to remove a source key marked `/*keep*/`.

## Supported static forms

```qml
Translation.tr("Hello, world!")
Translation.tr('Hello, world!')
Translation.tr(`Hello, world!`)
Translation.tr("Line 1\nLine 2")
Translation.tr("Hello, %1!").arg(name)
```

Dynamic expressions such as `Translation.tr(variable)` are not proof of a particular key, which is why heuristic cleanup never deletes automatically.

## Backups and recovery

The manager, sync path, and exact-prune path create `*.json.bak` files before catalog mutations. For a larger refactor, an explicit repository-local backup is also reasonable:

```bash
cp -r translations translations.backup
```

Restore a locale or the whole catalog with:

```bash
cp translations.backup/zh_CN.json translations/zh_CN.json
cp translations.backup/*.json translations/
```

After recovery, run:

```bash
python3 translations/tools/l10n.py audit-all
```

## CI expectations

Translation tooling should remain shell/Python-syntax clean, locale and localization metadata must remain valid JSON, source parity must not lose live literal keys, and locale key/placeholder contracts should be checked with `l10n.py audit-all` whenever the catalog changes. Blanket strict-orphan deletion is intentionally not a CI gate because dynamic runtime translation keys cannot be proven unused by static extraction alone.
