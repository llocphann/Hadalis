#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Translation File Maintenance Helper
Used to clean and organize translation files, removing unused keys
"""

import os
import sys
import json
import argparse
import importlib.util
from pathlib import Path
from typing import Set, List

# Import from the same directory using importlib
current_dir = os.path.dirname(os.path.abspath(__file__))
manager_path = os.path.join(current_dir, 'translation-manager.py')
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
            f"{CANONICAL_SOURCE_LANG}; run --sync before cleaning."
        )
        for lang, missing, extra in mismatches:
            print(f"  {lang}: {missing} missing, {extra} extra")
        raise ValueError("translation keysets are not in parity")


def clean_translation_files(
    translations_dir: str,
    source_dir: str,
    backup: bool = True,
    yes_mode: bool = False,
):
    """Remove canonical-source-orphaned keys consistently from every locale."""
    print("Starting translation file cleanup...")

    manager = TranslationManager(translations_dir, source_dir)

    print("Extracting currently used translatable texts...")
    current_texts = manager.extract_translatable_texts()
    print(f"Extracted {len(current_texts)} currently used texts")

    languages = manager.get_available_languages()
    if not languages:
        print("No translation files found")
        return
    if CANONICAL_SOURCE_LANG not in languages:
        raise ValueError(
            f"canonical source locale does not exist: {CANONICAL_SOURCE_LANG}"
        )

    print(f"Found language files: {', '.join(languages)}")

    source_translations = manager.load_translation_file(CANONICAL_SOURCE_LANG)
    source_keys = set(source_translations.keys())
    _assert_key_parity(manager, languages, source_keys)

    unused_keys = {
        key
        for key, value in source_translations.items()
        if key not in current_texts and not _is_keep_value(value)
    }

    if not unused_keys:
        print("No unused source keys found")
        return

    print(f"Found {len(unused_keys)} unused source keys:")
    for i, key in enumerate(sorted(unused_keys)[:10], 1):
        suffix = "..." if len(key) > 50 else ""
        print(f'  {i}. "{key[:50]}{suffix}"')
    if len(unused_keys) > 10:
        print(f"  ... and {len(unused_keys) - 10} more keys")

    if yes_mode:
        response = "y"
        print(
            f"Delete these {len(unused_keys)} keys from all locales? "
            "(auto-confirmed by --yes)"
        )
    else:
        response = input(
            f"Delete these {len(unused_keys)} keys from all locales? (y/n): "
        )

    if response.lower().strip() not in ["y", "yes"]:
        print("Skipped deletion")
        return

    total_removed = 0
    for lang in languages:
        translations = manager.load_translation_file(lang)
        keys_to_remove = unused_keys & set(translations.keys())
        if not keys_to_remove:
            continue

        if backup:
            backup_file = Path(translations_dir) / f"{lang}.json.bak"
            with open(backup_file, "w", encoding="utf-8") as f:
                json.dump(translations, f, ensure_ascii=False, indent=2)
            print(f"Created backup: {backup_file}")

        for key in keys_to_remove:
            del translations[key]

        manager.save_translation_file(lang, translations)
        total_removed += len(keys_to_remove)
        print(f"{lang}: deleted {len(keys_to_remove)} keys")

    final_source_keys = set(
        manager.load_translation_file(CANONICAL_SOURCE_LANG).keys()
    )
    _assert_key_parity(manager, languages, final_source_keys)

    print(
        "\nCleanup completed! "
        f"Deleted {len(unused_keys)} source keys across {len(languages)} locales "
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
            with open(backup_file, "w", encoding="utf-8") as f:
                json.dump(target_translations, f, ensure_ascii=False, indent=2)
                f.write("\n")
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
        help="Clean unused translation keys",
    )
    parser.add_argument(
        "--sync",
        action="store_true",
        help="Sync translation keys",
    )
    parser.add_argument(
        "--no-backup",
        action="store_true",
        help="Do not create backup files when cleaning or syncing",
    )
    parser.add_argument(
        "-y",
        "--yes",
        action="store_true",
        help="Skip all confirmation prompts (auto-confirm)",
    )

    args = parser.parse_args()

    translations_dir = os.path.abspath(args.translations_dir)
    source_dir = os.path.abspath(args.source_dir)

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
    else:
        print("Please specify an operation:")
        print("  --clean: Clean unused translation keys")
        print("  --sync: Sync translation keys")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"translation-cleaner: {exc}", file=sys.stderr)
        raise SystemExit(2)
