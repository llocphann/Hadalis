#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Translation file management helper.

`translations/en_US.json` is the canonical runtime catalog. Source extraction
may add new static keys, but additions are applied to every locale together so
the catalog cannot drift one locale at a time.
"""

import argparse
import json
import os
import re
import sys
import tempfile
from pathlib import Path
from typing import Dict, List, Set

CURRENT_DIR = Path(__file__).resolve().parent
DEFAULT_TRANSLATIONS_DIR = str(CURRENT_DIR.parent)
DEFAULT_SOURCE_DIR = str(CURRENT_DIR.parents[1])
CANONICAL_SOURCE_LANG = "en_US"


def _decode_static_literal(text: str) -> str:
    """Decode QML/JavaScript string escapes without re-decoding real Unicode.

    Decoding the complete UTF-8 byte sequence with ``unicode_escape`` corrupts
    non-ASCII text when the same literal also contains a ``\\u`` or ``\\x``
    escape. Walk escape sequences instead so already-decoded Unicode stays
    untouched and escaped backslashes retain their literal meaning.
    """
    simple_escapes = {
        "n": "\n",
        "t": "\t",
        "r": "\r",
        '"': '"',
        "'": "'",
        "f": "\f",
        "b": "\b",
        "`": "`",
        "$": "$",
        "\\": "\\",
    }
    hex_digits = set("0123456789abcdefABCDEF")
    decoded = []
    index = 0

    while index < len(text):
        char = text[index]
        if char != "\\":
            decoded.append(char)
            index += 1
            continue

        if index + 1 >= len(text):
            decoded.append("\\")
            break

        escape = text[index + 1]
        if escape in simple_escapes:
            decoded.append(simple_escapes[escape])
            index += 2
            continue

        if escape == "x" and index + 4 <= len(text):
            digits = text[index + 2:index + 4]
            if len(digits) == 2 and all(ch in hex_digits for ch in digits):
                decoded.append(chr(int(digits, 16)))
                index += 4
                continue

        if escape == "u":
            if index + 3 < len(text) and text[index + 2] == "{":
                end = text.find("}", index + 3)
                if end != -1:
                    digits = text[index + 3:end]
                    if (
                        1 <= len(digits) <= 6
                        and all(ch in hex_digits for ch in digits)
                    ):
                        codepoint = int(digits, 16)
                        if codepoint <= 0x10FFFF and not 0xD800 <= codepoint <= 0xDFFF:
                            decoded.append(chr(codepoint))
                            index = end + 1
                            continue

            if index + 6 <= len(text):
                digits = text[index + 2:index + 6]
                if len(digits) == 4 and all(ch in hex_digits for ch in digits):
                    codepoint = int(digits, 16)
                    if 0xD800 <= codepoint <= 0xDBFF and index + 12 <= len(text):
                        low_prefix = text[index + 6:index + 8]
                        low_digits = text[index + 8:index + 12]
                        if (
                            low_prefix == "\\u"
                            and len(low_digits) == 4
                            and all(ch in hex_digits for ch in low_digits)
                        ):
                            low = int(low_digits, 16)
                            if 0xDC00 <= low <= 0xDFFF:
                                combined = 0x10000 + ((codepoint - 0xD800) << 10) + (low - 0xDC00)
                                decoded.append(chr(combined))
                                index += 12
                                continue
                    elif not 0xD800 <= codepoint <= 0xDFFF:
                        decoded.append(chr(codepoint))
                        index += 6
                        continue

        # Preserve malformed or unsupported escapes verbatim rather than
        # silently changing the catalog key that runtime code would request.
        decoded.append("\\")
        decoded.append(escape)
        index += 2

    return "".join(decoded)


def _has_template_interpolation(text: str) -> bool:
    """Return whether a template body contains an unescaped ``${...}`` start."""
    index = 0
    while True:
        index = text.find("${", index)
        if index < 0:
            return False

        backslashes = 0
        cursor = index - 1
        while cursor >= 0 and text[cursor] == "\\":
            backslashes += 1
            cursor -= 1

        if backslashes % 2 == 0:
            return True
        index += 2


class TranslationManager:
    def __init__(self, translations_dir: str, source_dir: str, yes_mode: bool = False):
        self.translations_dir = Path(translations_dir)
        self.source_dir = Path(source_dir)
        self.temp_extracted_file = None
        self.yes_mode = yes_mode
        self.translations_dir.mkdir(parents=True, exist_ok=True)

    def extract_translatable_texts(self) -> Set[str]:
        """Extract static Translation.tr(...) strings from QML and JavaScript."""
        translatable_texts: Set[str] = set()

        patterns = [
            (r'Translation\.tr\s*\(\s*(["\'])(((?!\1)[^\\]|\\.)*)(\1)\s*\)', False),
            (r'Translation\.tr\s*\(\s*`([^`]*(?:\\.[^`]*)*?)`\s*\)', True),
        ]

        for ext in ("*.qml", "*.js"):
            for file_path in self.source_dir.rglob(ext):
                try:
                    with open(file_path, "r", encoding="utf-8") as f:
                        content = f.read()

                    for pattern, is_template in patterns:
                        matches = re.findall(pattern, content, re.MULTILINE | re.DOTALL)
                        for match in matches:
                            if isinstance(match, tuple):
                                text = match[1] if len(match) >= 3 else (match[0] if match else "")
                            else:
                                text = match

                            if is_template and _has_template_interpolation(text):
                                continue

                            clean_text = _decode_static_literal(text).strip()
                            if clean_text:
                                translatable_texts.add(clean_text)
                except (UnicodeDecodeError, OSError) as exc:
                    print(f"Warning: Cannot read file {file_path}: {exc}")

        return translatable_texts

    def create_temp_translation_file(self, texts: Set[str]) -> str:
        """Create a temporary JSON file containing extracted source strings."""
        temp_data = {text: text for text in sorted(texts)}
        with tempfile.NamedTemporaryFile(
            mode="w",
            suffix=".json",
            delete=False,
            encoding="utf-8",
        ) as f:
            json.dump(temp_data, f, ensure_ascii=False, indent=2)
            self.temp_extracted_file = f.name
        return self.temp_extracted_file

    def load_translation_file(self, lang_code: str) -> Dict[str, str]:
        """Load one locale JSON file."""
        file_path = self.translations_dir / f"{lang_code}.json"
        if not file_path.exists():
            return {}
        with open(file_path, "r", encoding="utf-8") as f:
            data = json.load(f)
        if not isinstance(data, dict):
            raise ValueError(f"translation file must contain a JSON object: {file_path}")
        return data

    def save_translation_file(self, lang_code: str, translations: Dict[str, str]) -> None:
        """Atomically save one locale JSON file without exposing a partial write."""
        file_path = self.translations_dir / f"{lang_code}.json"
        target_mode = (file_path.stat().st_mode & 0o777) if file_path.exists() else 0o644
        temp_path = None
        try:
            with tempfile.NamedTemporaryFile(
                mode="w",
                dir=self.translations_dir,
                prefix=f".{lang_code}.",
                suffix=".tmp",
                delete=False,
                encoding="utf-8",
                newline="",
            ) as f:
                json.dump(translations, f, ensure_ascii=False, indent=2)
                f.write("\n")
                f.flush()
                os.fsync(f.fileno())
                temp_path = Path(f.name)

            os.chmod(temp_path, target_mode)
            os.replace(temp_path, file_path)
        finally:
            if temp_path is not None and temp_path.exists():
                temp_path.unlink()
        print(f"Translation file saved: {file_path}")

    def get_available_languages(self) -> List[str]:
        """Return tracked locale codes from the translation directory."""
        return sorted(path.stem for path in self.translations_dir.glob("*.json"))

    def assert_key_parity(self, languages: List[str]) -> Set[str]:
        """Require every target locale to match the canonical English keyset."""
        if CANONICAL_SOURCE_LANG not in languages:
            raise ValueError(
                f"canonical source locale does not exist: {CANONICAL_SOURCE_LANG}"
            )

        source_keys = set(self.load_translation_file(CANONICAL_SOURCE_LANG).keys())
        mismatches = []
        for lang in languages:
            if lang == CANONICAL_SOURCE_LANG:
                continue
            keys = set(self.load_translation_file(lang).keys())
            missing = source_keys - keys
            extra = keys - source_keys
            if missing or extra:
                mismatches.append((lang, len(missing), len(extra)))

        if mismatches:
            print(
                "Error: Translation keysets differ from "
                f"{CANONICAL_SOURCE_LANG}; run translation-cleaner.py --sync first."
            )
            for lang, missing, extra in mismatches:
                print(f"  {lang}: {missing} missing, {extra} extra")
            raise ValueError("translation keysets are not in parity")

        return source_keys

    def add_missing_keys_all(self, languages: List[str], missing_keys: Set[str]) -> None:
        """Add one exact missing-key set to every locale after one confirmation."""
        if not missing_keys:
            return

        print(f"\nFound {len(missing_keys)} missing translation keys:")
        for i, key in enumerate(sorted(missing_keys), 1):
            print(f'{i}. "{key}"')

        if not self.ask_yes_no(
            f"\nAdd these {len(missing_keys)} keys to all {len(languages)} locales?"
        ):
            print("Skipped key addition")
            return

        for lang in languages:
            translations = self.load_translation_file(lang)
            backup_file = self.translations_dir / f"{lang}.json.bak"
            with open(backup_file, "w", encoding="utf-8") as f:
                json.dump(translations, f, ensure_ascii=False, indent=2)
                f.write("\n")

            for key in missing_keys:
                translations[key] = key

            self.save_translation_file(lang, translations)
            print(f"{lang}: added {len(missing_keys)} keys")

        self.assert_key_parity(languages)

    def report_extra_keys(
        self,
        source_translations: Dict[str, str],
        extra_keys: Set[str],
    ) -> None:
        """Report canonical source-orphan candidates without deleting them."""
        filtered = [
            key
            for key in extra_keys
            if not (
                isinstance(source_translations.get(key, ""), str)
                and source_translations.get(key, "").strip().endswith("/*keep*/")
            )
        ]
        ignored = extra_keys - set(filtered)

        print(f"  Extra keys: {len(filtered)}")
        if ignored:
            print(f"  Ignored keys: {len(ignored)} (marked with /*keep*/)")

        if not filtered:
            return

        print("\nCanonical source-orphan candidates:")
        for i, key in enumerate(sorted(filtered), 1):
            print(f'{i}. "{key}" -> "{source_translations.get(key, "")}"')
        print(
            "Not deleting extra keys here. Static extraction cannot prove a key is "
            "unused when runtime code translates dynamic values. Run "
            "translation-cleaner.py --clean for a read-only candidate report, then "
            "prune only an exact reviewed set with --prune-file or --prune-key."
        )

    def ask_yes_no(self, question: str) -> bool:
        """Ask for confirmation, or auto-confirm in --yes mode."""
        if self.yes_mode:
            print(f"{question} (auto-confirmed by --yes)")
            return True

        while True:
            response = input(f"{question} (y/n): ").lower().strip()
            if response in ("y", "yes"):
                return True
            if response in ("n", "no"):
                return False
            print("Please enter y/yes or n/no")

    def cleanup(self) -> None:
        """Remove temporary extraction output."""
        if self.temp_extracted_file and os.path.exists(self.temp_extracted_file):
            os.unlink(self.temp_extracted_file)


def main() -> None:
    parser = argparse.ArgumentParser(description="Translation file management tool")
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
        "--extract-only",
        "-e",
        action="store_true",
        help="Only extract translatable texts to a temporary file",
    )
    parser.add_argument(
        "--show-temp",
        action="store_true",
        help="Show temporary extracted file content",
    )
    parser.add_argument(
        "-y",
        "--yes",
        action="store_true",
        help="Skip the single catalog-wide confirmation prompt",
    )

    args = parser.parse_args()
    translations_dir = os.path.abspath(args.translations_dir)
    source_dir = os.path.abspath(args.source_dir)

    print(f"Translation directory: {translations_dir}")
    print(f"Source code directory: {source_dir}")

    if not os.path.exists(source_dir):
        raise ValueError(f"source code directory does not exist: {source_dir}")

    manager = TranslationManager(translations_dir, source_dir, yes_mode=args.yes)

    try:
        print("\nExtracting translatable texts...")
        extracted_texts = manager.extract_translatable_texts()
        print(f"Extracted {len(extracted_texts)} translatable texts")

        temp_file = manager.create_temp_translation_file(extracted_texts)
        print(f"Created temporary file: {temp_file}")

        if args.show_temp:
            print("\nTemporary file contents:")
            with open(temp_file, "r", encoding="utf-8") as f:
                print(f.read())

        if args.extract_only:
            print("Extract-only mode, program finished")
            return

        languages = manager.get_available_languages()
        if not languages:
            raise ValueError("no translation files found")

        print(f"\nAvailable languages: {', '.join(languages)}")
        source_keys = manager.assert_key_parity(languages)
        source_translations = manager.load_translation_file(CANONICAL_SOURCE_LANG)

        missing_keys = extracted_texts - source_keys
        extra_keys = source_keys - extracted_texts

        print("Analysis results:")
        print(f"  Missing keys: {len(missing_keys)}")
        manager.report_extra_keys(source_translations, extra_keys)
        manager.add_missing_keys_all(languages, missing_keys)

    finally:
        manager.cleanup()


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"translation-manager: {exc}", file=sys.stderr)
        raise SystemExit(2)
