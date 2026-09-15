#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Translation File Maintenance Helper.

Static source extraction is intentionally advisory for deletion because runtime
code can translate dynamic values that cannot be enumerated safely. Catalog
pruning therefore requires an explicit reviewed key list.
"""

import argparse
import importlib.util
import json
import os
import sys
from pathlib import Path
from typing import List, Set

# Import from the same directory using importlib
current_dir = os.path.dirname(os.path.abspath(__file__))
manager_path = os.path.join(current_dir, "translation-manager.py")
spec = importlib.util.spec_from_file_location("translation_manager", manager_path)
translation_manager = importlib.util.module_from_spec(spec)
spec.loader.exec_module(translation_manager)
TranslationManager = translation_manager.TranslationManager

DEFAULT_TRANSLATIONS_DIR = str(Path(current_dir).parent)
DEFAULT_SOURCE_DIR = str(Path(current_dir).parents[1])
CANONICAL_SOURCE_LANG = "en_US"


def _is_keep_value(value) -> bool:
    return isinstance(value, str) and value.strip().endswith("/*keep*/")


def _assert_key_parity(
    manager: TranslationManager,
    languages: List[str],
    source_keys: Set[str],
) -> None:
    mismatches = []
    for lang in languages:
        if lang == CANONICAL_SOURCE_LANG:
            continue
        keys = set(manager.load_translation_file(lang).keys())
        missing = source_keys - keys
        extra = keys - source_keys
        if missing or extra:
            mismatches.append((lang, len(missing), len(extra)))

    if mismatches:
        print(
            "Error: Translation keysets already differ from "
            f"{CANONICAL_SOURCE_LANG}; run --sync before pruning."
        )
        for lang, missing, extra in mismatches:
            print(f"  {lang}: {missing} missing, {extra} extra")
        raise ValueError("translation keysets are not in parity")


def _catalog_context(
    translations_dir: str,
    source_dir: str,
    yes_mode: bool = False,
):
    manager = TranslationManager(translations_dir, source_dir, yes_mode=yes_mode)
    languages = manager.get_available_languages()
    if not languages:
        raise ValueError("no translation files found")
    if CANONICAL_SOURCE_LANG not in languages:
        raise ValueError(
            f"canonical source locale does not exist: {CANONICAL_SOURCE_LANG}"
        )

    source_translations = manager.load_translation_file(CANONICAL_SOURCE_LANG)
    source_keys = set(source_translations.keys())
    _assert_key_parity(manager, languages, source_keys)
    return manager, languages, source_translations, source_keys


def clean_translation_files(
    translations_dir: str,
    source_dir: str,
    backup: bool = True,
    yes_mode: bool = False,
) -> Set[str]:
    """Report static-orphan candidates without mutating any locale file.

    ``backup`` and ``yes_mode`` remain accepted for call compatibility. They no
    longer enable deletion; exact pruning is a separate explicit operation.
    """
    del backup, yes_mode
    print("Analyzing translation cleanup candidates...")
    manager, languages, source_translations, _ = _catalog_context(
        translations_dir, source_dir
    )

    print("Extracting statically discoverable Translation.tr(...) texts...")
    current_texts = manager.extract_translatable_texts()
    print(f"Extracted {len(current_texts)} statically discoverable texts")
    print(f"Found language files: {', '.join(languages)}")

    unused_keys = {
        key
        for key, value in source_translations.items()
        if key not in current_texts and not _is_keep_value(value)
    }

    if not unused_keys:
        print("No static-orphan candidates found")
        return set()

    print(f"Found {len(unused_keys)} static-orphan candidates:")
    for i, key in enumerate(sorted(unused_keys), 1):
        print(f'{i}. "{key}"')

    print(
        "\nNo files changed. Static extraction cannot prove that a catalog key is "
        "unused because Translation.tr(...) also accepts runtime values. Review the "
        "candidates against live dynamic callsites, then prune only an exact reviewed "
        "set with --prune-file or --prune-key."
    )
    return unused_keys


def _load_prune_file(path: str) -> Set[str]:
    prune_path = Path(path)
    with prune_path.open("r", encoding="utf-8") as handle:
        data = json.load(handle)
    if not isinstance(data, list):
        raise ValueError(f"prune file must contain a JSON array of exact keys: {path}")

    keys = set()
    for value in data:
        if not isinstance(value, str) or not value:
            raise ValueError(f"prune file contains a non-string or empty key: {path}")
        keys.add(value)
    return keys


def _write_backup(path: Path, translations) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        json.dump(translations, handle, ensure_ascii=False, indent=2)
        handle.write("\n")


def prune_translation_keys(
    translations_dir: str,
    source_dir: str,
    requested_keys: Set[str],
    backup: bool = True,
    yes_mode: bool = False,
) -> None:
    """Remove one explicitly reviewed exact keyset from every locale."""
    requested_keys = {key for key in requested_keys if key}
    if not requested_keys:
        raise ValueError("no exact translation keys were supplied for pruning")

    manager, languages, source_translations, source_keys = _catalog_context(
        translations_dir, source_dir, yes_mode=yes_mode
    )

    unknown = requested_keys - source_keys
    if unknown:
        print("Error: Refusing to prune keys absent from the canonical catalog:")
        for key in sorted(unknown):
            print(f'  "{key}"')
        raise ValueError("prune set contains unknown canonical keys")

    kept = {
        key
        for key in requested_keys
        if _is_keep_value(source_translations.get(key))
    }
    if kept:
        print("Error: Refusing to prune keys explicitly protected by /*keep*/:")
        for key in sorted(kept):
            print(f'  "{key}"')
        raise ValueError("prune set contains protected keys")

    print(
        f"Reviewed prune set: {len(requested_keys)} exact keys across "
        f"{len(languages)} locales"
    )
    for i, key in enumerate(sorted(requested_keys), 1):
        print(f'{i}. "{key}"')

    if not manager.ask_yes_no(
        f"\nDelete exactly these {len(requested_keys)} keys from all locales?"
    ):
        print("Skipped pruning")
        return

    translations_path = Path(translations_dir)
    total_removed = 0
    for lang in languages:
        translations = manager.load_translation_file(lang)
        missing = requested_keys - set(translations.keys())
        if missing:
            raise ValueError(
                f"{lang} lost parity before pruning; missing {len(missing)} requested keys"
            )

        if backup:
            backup_file = translations_path / f"{lang}.json.bak"
            _write_backup(backup_file, translations)
            print(f"Created backup: {backup_file}")

        for key in requested_keys:
            del translations[key]
        manager.save_translation_file(lang, translations)
        total_removed += len(requested_keys)
        print(f"{lang}: deleted {len(requested_keys)} reviewed keys")

    final_source_keys = set(
        manager.load_translation_file(CANONICAL_SOURCE_LANG).keys()
    )
    _assert_key_parity(manager, languages, final_source_keys)
    print(
        "\nPrune completed! "
        f"Deleted {len(requested_keys)} reviewed keys across {len(languages)} locales "
        f"({total_removed} entries)."
    )


def sync_translations(
    translations_dir: str,
    target_langs: List[str] = None,
    yes_mode: bool = False,
    source_dir: str = DEFAULT_SOURCE_DIR,
    backup: bool = True,
):
    """Sync every target locale to the canonical English keyset."""
    print(
        "Starting translation key sync using "
        f"{CANONICAL_SOURCE_LANG} as canonical source..."
    )

    translations_path = Path(translations_dir)
    manager = TranslationManager(translations_dir, source_dir)

    source_file = translations_path / f"{CANONICAL_SOURCE_LANG}.json"
    if not source_file.exists():
        raise ValueError(f"canonical source locale does not exist: {source_file}")

    source_translations = manager.load_translation_file(CANONICAL_SOURCE_LANG)
    source_keys = set(source_translations.keys())
    print(
        f"Source language {CANONICAL_SOURCE_LANG} has {len(source_keys)} keys"
    )

    if target_langs is None:
        target_langs = []
        for file_path in translations_path.glob("*.json"):
            lang_code = file_path.stem
            if lang_code != CANONICAL_SOURCE_LANG:
                target_langs.append(lang_code)

    if not target_langs:
        print("No target language files found")
        return

    print(f"Target languages: {', '.join(target_langs)}")

    for target_lang in target_langs:
        print(f"\nSyncing language: {target_lang}")

        target_file = translations_path / f"{target_lang}.json"
        target_translations = manager.load_translation_file(target_lang)
        target_keys = set(target_translations.keys())

        missing_keys = source_keys - target_keys
        extra_keys = target_keys - source_keys

        print(f"  Missing keys: {len(missing_keys)}")
        print(f"  Extra keys: {len(extra_keys)}")

        delete_extra = False
        if extra_keys:
            if yes_mode:
                response = "y"
                print(
                    f"  Delete {len(extra_keys)} extra keys? "
                    "(auto-confirmed by --yes)"
                )
            else:
                response = input(
                    f"  Delete {len(extra_keys)} extra keys? (y/n): "
                )
            delete_extra = response.lower().strip() in ["y", "yes"]

        if not missing_keys and not delete_extra:
            print("  No changes needed")
            continue

        if backup and target_file.exists():
            backup_file = translations_path / f"{target_lang}.json.bak"
            _write_backup(backup_file, target_translations)
            print(f"  Created backup: {backup_file}")

        if missing_keys:
            for key in missing_keys:
                target_translations[key] = source_translations[key]
            print(f"  Added {len(missing_keys)} missing keys")

        if delete_extra:
            for key in extra_keys:
                del target_translations[key]
            print(f"  Deleted {len(extra_keys)} extra keys")

        manager.save_translation_file(target_lang, target_translations)


def main():
    parser = argparse.ArgumentParser(
        description="Translation File Maintenance Helper"
    )
    parser.add_argument(
        "--translations-dir",
        "-t",
        default=DEFAULT_TRANSLATIONS_DIR,
        help=f"Translation files directory (default: {DEFAULT_TRANSLATIONS_DIR})",
    )
    parser.add_argument(
        "--source-dir",
        "-s",
        default=DEFAULT_SOURCE_DIR,
        help=f"Source code directory (default: {DEFAULT_SOURCE_DIR})",
    )
    parser.add_argument(
        "--clean",
        "-c",
        action="store_true",
        help="Report static-orphan candidates without deleting catalog keys",
    )
    parser.add_argument(
        "--sync",
        action="store_true",
        help="Sync translation keys",
    )
    parser.add_argument(
        "--prune-file",
        action="append",
        default=[],
        metavar="PATH",
        help="JSON array of exact reviewed keys to prune from every locale",
    )
    parser.add_argument(
        "--prune-key",
        action="append",
        default=[],
        metavar="KEY",
        help="Exact reviewed key to prune from every locale; may be repeated",
    )
    parser.add_argument(
        "--no-backup",
        action="store_true",
        help="Do not create backup files when syncing or pruning",
    )
    parser.add_argument(
        "-y",
        "--yes",
        action="store_true",
        help="Skip confirmation prompts for mutating operations",
    )

    args = parser.parse_args()

    translations_dir = os.path.abspath(args.translations_dir)
    source_dir = os.path.abspath(args.source_dir)
    prune_requested = bool(args.prune_file or args.prune_key)
    operation_count = int(args.clean) + int(args.sync) + int(prune_requested)
    if operation_count > 1:
        raise ValueError("choose exactly one of --clean, --sync, or an exact prune operation")

    if args.clean:
        clean_translation_files(
            translations_dir,
            source_dir,
            backup=not args.no_backup,
            yes_mode=args.yes,
        )
    elif args.sync:
        sync_translations(
            translations_dir,
            source_dir=source_dir,
            backup=not args.no_backup,
            yes_mode=args.yes,
        )
    elif prune_requested:
        prune_keys = set(args.prune_key)
        for prune_file in args.prune_file:
            prune_keys.update(_load_prune_file(prune_file))
        prune_translation_keys(
            translations_dir,
            source_dir,
            prune_keys,
            backup=not args.no_backup,
            yes_mode=args.yes,
        )
    else:
        print("Please specify an operation:")
        print("  --clean: Report static-orphan candidates (read-only)")
        print("  --sync: Sync keys across locale files")
        print("  --prune-file PATH / --prune-key KEY: Prune exact reviewed keys")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"translation-cleaner: {exc}", file=sys.stderr)
        raise SystemExit(2)
