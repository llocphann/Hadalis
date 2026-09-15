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

`audit-all` validates key parity and placeholder structure against `en_US.json`. See `translations/l10n/README.md` for the reviewed translation workflow.

### `translation-manager.py` — source extraction and missing-key updates

The manager scans repository `*.qml` and `*.js` files for static `Translation.tr(...)` strings.

```bash
translations/tools/translation-manager.py --extract-only
translations/tools/translation-manager.py --language zh_CN
translations/tools/translation-manager.py --yes
```

The manager may add missing static keys. It **does not prune extra keys**. Extra keys are only reported so cleanup cannot diverge locale keysets one language at a time.

### `translation-cleaner.py` — canonical pruning and synchronization

The cleaner owns deletion of unused translation keys. Both cleanup and sync always use `en_US.json` as the canonical key source.

```bash
translations/tools/translation-cleaner.py --clean
translations/tools/translation-cleaner.py --clean --yes --no-backup
translations/tools/translation-cleaner.py --sync
```

Before pruning, the cleaner requires every locale keyset to match the canonical source locale. It derives one orphan set from the source locale and removes exactly that set from every locale, then verifies parity again.

### `manage-translations.sh` — wrapper

```bash
translations/tools/manage-translations.sh status
translations/tools/manage-translations.sh extract
translations/tools/manage-translations.sh update
translations/tools/manage-translations.sh update -l zh_CN
translations/tools/manage-translations.sh clean
translations/tools/manage-translations.sh sync
```

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

# 3. Prune source-orphaned keys consistently from every locale.
translations/tools/manage-translations.sh clean

# 4. Verify the resulting locale contract again.
python3 translations/tools/l10n.py audit-all
```

Do not manually delete a key from only one generated locale. If a retired-feature key is being removed, prove it is no longer a live source string and let the source-driven cleaner apply the same deletion across all locales.

## Dynamic translation keys

Static extraction cannot discover strings constructed or selected dynamically at runtime. A key that must survive static cleanup should be retained in the canonical source locale with `/*keep*/` at the end of its value.

```json
{
  "dynamic_key": "Some dynamic value /*keep*/"
}
```

Because pruning is source-driven, the preservation marker belongs in the source locale (`en_US.json`). A marker present only in a target translation does not override the canonical orphan decision.

## Supported static forms

```qml
Translation.tr("Hello, world!")
Translation.tr('Hello, world!')
Translation.tr(`Hello, world!`)
Translation.tr("Line 1\nLine 2")
Translation.tr("Hello, %1!").arg(name)
```

Dynamic expressions such as `Translation.tr(variable)` require explicit catalog preservation because the extractor cannot infer their possible values.

## Backups and recovery

The cleaner creates `*.json.bak` files by default before mutations. For a larger refactor, an explicit repository-local backup is also reasonable:

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

Translation tooling should remain shell/Python-syntax clean, locale and localization metadata must remain valid JSON, and locale key/placeholder contracts should be checked with `l10n.py audit-all` whenever the catalog changes.
