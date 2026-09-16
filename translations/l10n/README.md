# Runtime localization

`en_US.json` is canonical. Other locales keep the same keys and translate only the values.

The localization helper does not call a translation service. It prepares contextual review batches and rejects unsafe results.

## Audit locales

```bash
python3 translations/tools/l10n.py audit-all
python3 translations/tools/l10n.py audit es_AR --strict-terms
```

The repository gate checks key parity plus placeholders and markup for every locale. A focused audit also reports untranslated values and protected product-name drift; `--strict-terms` turns those product-name warnings into errors for an actively reviewed locale. Commands, paths, codecs and common acronyms are excluded through `glossary.json`.

## Prepare a review batch

```bash
python3 translations/tools/l10n.py extract es_AR /tmp/es_AR-001.json --limit 200
```

Each entry contains:

- the stable translation key
- the English source
- the current value
- a blank `translated` field
- QML locations when they can be found
- the locale writing guide

Translate only `translated`. Keep the other fields unchanged.

## Apply a reviewed batch

```bash
python3 translations/tools/l10n.py apply /tmp/es_AR-001.json
bash scripts/verify-docs.sh
```

The apply command refuses unknown or duplicate keys, changed English source text, modified placeholders or markup such as `%1`, `{0}`, `<i>` and `</i>`, and translations that rename protected product terms.

## Apply an exact reviewed repair

For a small correction to existing locale values that has already been reviewed, use a provenance-backed replacement manifest instead of regenerating or rewriting the locale. Each manifest records the target locale and an exact `from`/`to` pair for every stable key, so applying it fails closed if the catalog changed after review.

Inspect the manifest state before writing:

```bash
python3 translations/tools/apply-reviewed-replacements.py \
  translations/l10n/tr_TR-placeholder-repairs.json --status
```

`pending` means every catalog value still matches its reviewed `from` value. `applied` means every entry already matches its reviewed `to` value. A mixed, partially applied, or otherwise drifted manifest exits non-zero instead of guessing which values are safe to change.

When the state is `pending`, the currently reviewed Turkish placeholder repair can be checked without writing first:

```bash
python3 translations/tools/apply-reviewed-replacements.py \
  translations/l10n/tr_TR-placeholder-repairs.json --check
```

After that check succeeds, apply only those reviewed values:

```bash
python3 translations/tools/apply-reviewed-replacements.py \
  translations/l10n/tr_TR-placeholder-repairs.json
```

The exact-repair helper is byte-preserving outside the reviewed value literals: it does not reformat or reorder the catalog, normalize line endings, or replace the same text under unrelated keys. `--check` validates the same exact serialized key/value literals that apply will edit, so it fails before writing if the raw catalog representation has drifted. The tool also rejects missing keys, changed reviewed source values, partially applied manifests, or replacements that violate the canonical placeholder/markup contract. A manifest is not permission to prune historical translations or bulk-rewrite a locale.

After an exact repair, confirm the manifest reports `applied`, then rerun both catalog and source-boundary checks:

```bash
python3 translations/tools/apply-reviewed-replacements.py \
  translations/l10n/tr_TR-placeholder-repairs.json --status
python3 translations/tools/l10n.py audit-all
python3 translations/tools/source-parity.py
```

## Rules

- Keep product names and commands unchanged.
- Use natural desktop terminology, not literal machine translation.
- Keep labels short enough for the UI.
- Adapt dry jokes instead of translating them word for word.
- Finish and validate one locale before moving to the next.
