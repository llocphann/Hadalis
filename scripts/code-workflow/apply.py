#!/usr/bin/env python3
"""Prepare Code Workflow Apply artifacts without modifying QML source.

The helper re-validates one literal-property semantic command and writes an
exact rollback snapshot, candidate source, and manifest under Quickshell state.
It never writes the tracked source file. A later controller must perform the
final source identity check and atomic source replacement.
"""

from __future__ import annotations

import argparse
from hashlib import sha256
import json
import os
from pathlib import Path
import tempfile

from analyze import (
    PROTOCOL,
    QMLJS_VERSION,
    resolve_grammar,
    resolve_semantic_anchor,
    resolve_source,
)
from native import Parser, verify_ranges
from semantics import extract
from transaction import (
    LITERAL_VALUE_KINDS,
    digest,
    prepare_literal_patch,
)


def emit(payload: dict, exit_code: int) -> int:
    print(json.dumps({"protocol": PROTOCOL, **payload}, ensure_ascii=False))
    return exit_code


def atomic_state_write(path: Path, data: bytes, mode: int = 0o600) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(
        prefix="." + path.name + ".",
        dir=str(path.parent),
    )
    temp_path = Path(temporary)
    try:
        with os.fdopen(fd, "wb") as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(temp_path, mode)
        os.replace(temp_path, path)
        try:
            directory_fd = os.open(
                path.parent,
                os.O_RDONLY | getattr(os, "O_DIRECTORY", 0),
            )
        except OSError:
            directory_fd = -1
        if directory_fd >= 0:
            try:
                os.fsync(directory_fd)
            finally:
                os.close(directory_fd)
    finally:
        if temp_path.exists():
            temp_path.unlink()


def write_prepared_artifacts(
    state_dir: Path,
    source_path: str,
    base_sha256: str,
    candidate_sha256: str,
    semantic_anchor: str,
    replacement: str,
    source: bytes,
    candidate: bytes,
) -> dict:
    transaction_id = sha256(
        (
            source_path
            + "\0" + base_sha256
            + "\0" + candidate_sha256
            + "\0" + semantic_anchor
            + "\0" + replacement
        ).encode("utf-8")
    ).hexdigest()[:24]

    root = state_dir.expanduser().resolve() / transaction_id
    snapshot_path = root / "snapshot.qml"
    candidate_path = root / "candidate.qml"
    manifest_path = root / "manifest.json"

    metadata = {
        "version": 1,
        "transactionId": transaction_id,
        "sourcePath": source_path,
        "baseSha256": base_sha256,
        "candidateSha256": candidate_sha256,
        "semanticAnchor": semantic_anchor,
        "replacement": replacement,
        "snapshotPath": str(snapshot_path),
        "candidatePath": str(candidate_path),
        "applyEnabled": False,
    }

    atomic_state_write(snapshot_path, source)
    atomic_state_write(candidate_path, candidate)
    atomic_state_write(
        manifest_path,
        (json.dumps(metadata, indent=2, sort_keys=True) + "\n").encode("utf-8"),
    )

    return {
        **metadata,
        "manifestPath": str(manifest_path),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        default=str(Path(__file__).resolve().parents[2]),
    )
    parser.add_argument("--path", required=True)
    parser.add_argument("--base-sha256", required=True)
    parser.add_argument("--expected-candidate-sha256", required=True)
    parser.add_argument("--semantic-anchor", required=True)
    parser.add_argument("--replacement", required=True)
    parser.add_argument("--state-dir", required=True)
    parser.add_argument("--grammar", default="")
    parser.add_argument("--library", default="")
    args = parser.parse_args()

    root = Path(args.root).expanduser().resolve()
    if not root.is_dir():
        return emit({
            "status": "invalid-request",
            "reason": "runtime-root-missing",
        }, 4)

    try:
        source_path = resolve_source(root, args.path)
        source = source_path.read_bytes()
        source.decode("utf-8")
    except (ValueError, OSError, UnicodeError) as exc:
        return emit({
            "status": "invalid-request",
            "reason": str(exc),
        }, 4)

    current_sha = digest(source)
    if current_sha != args.base_sha256:
        return emit({
            "status": "conflict",
            "reason": "base-sha-mismatch",
            "expectedSha256": args.base_sha256,
            "currentSha256": current_sha,
        }, 6)

    if not os.access(source_path, os.W_OK):
        return emit({
            "status": "blocked",
            "reason": "source-read-only",
        }, 7)

    grammar = resolve_grammar(root, args.grammar)
    if grammar is None:
        return emit({
            "status": "unavailable",
            "reason": "grammar-missing",
        }, 3)

    library = (
        args.library
        or os.environ.get("HADALIS_TREE_SITTER_LIBRARY", "")
        or None
    )

    native_parser = None
    try:
        native_parser = Parser(grammar, library)

        with native_parser.parse(source) as (_, nodes):
            verify_ranges(source, nodes)
            semantic = extract(args.path, source, nodes)

        if semantic["diagnostics"]:
            return emit({
                "status": "blocked",
                "reason": "current-source-has-parser-diagnostics",
                "diagnostics": semantic["diagnostics"],
            }, 7)

        rebind = resolve_semantic_anchor(
            semantic["entries"],
            args.semantic_anchor,
        )
        if rebind.get("status") != "resolved":
            return emit({
                "status": "conflict",
                "reason": "semantic-anchor-" + str(
                    rebind.get("status", "unknown")),
                "semanticRebind": rebind,
            }, 6)

        matches = [
            entry for entry in semantic["entries"]
            if entry.get("anchor") == args.semantic_anchor
        ]
        if len(matches) != 1:
            return emit({
                "status": "conflict",
                "reason": "semantic-anchor-not-unique",
            }, 6)

        prepared, candidate = prepare_literal_patch(
            source,
            args.base_sha256,
            matches[0],
            args.replacement,
        )
        if candidate is None:
            status = str(prepared.get("status", "error"))
            return emit(
                prepared,
                6 if status == "conflict" else 7,
            )

        candidate_sha = digest(candidate)
        if candidate_sha != args.expected_candidate_sha256:
            return emit({
                "status": "conflict",
                "reason": "preview-candidate-drift",
                "expectedCandidateSha256":
                    args.expected_candidate_sha256,
                "currentCandidateSha256": candidate_sha,
            }, 6)

        with native_parser.parse(candidate) as (_, candidate_nodes):
            verify_ranges(candidate, candidate_nodes)
            candidate_semantic = extract(
                args.path,
                candidate,
                candidate_nodes,
            )

        if candidate_semantic["diagnostics"]:
            return emit({
                "status": "invalid-patch",
                "reason": "candidate-has-parser-diagnostics",
                "diagnostics": candidate_semantic["diagnostics"],
            }, 8)

        candidate_rebind = resolve_semantic_anchor(
            candidate_semantic["entries"],
            args.semantic_anchor,
        )
        if candidate_rebind.get("status") != "resolved":
            return emit({
                "status": "invalid-patch",
                "reason": "candidate-semantic-rebind-unresolved",
                "semanticRebind": candidate_rebind,
            }, 8)

        candidate_entry = next(
            entry for entry in candidate_semantic["entries"]
            if entry.get("anchor") == args.semantic_anchor
        )
        if (
            candidate_entry.get("kind") != "property"
            or candidate_entry.get("opaque_context", False)
            or candidate_entry.get("value_kind")
                not in LITERAL_VALUE_KINDS
        ):
            return emit({
                "status": "invalid-patch",
                "reason": "candidate-left-literal-property-subset",
            }, 8)

        value_range = candidate_entry.get("value_range")
        if not isinstance(value_range, list) or len(value_range) != 2:
            return emit({
                "status": "invalid-patch",
                "reason": "candidate-lost-value-range",
            }, 8)
        rendered = candidate[
            value_range[0]:value_range[1]
        ].decode("utf-8")
        if rendered != args.replacement:
            return emit({
                "status": "invalid-patch",
                "reason": "candidate-value-range-does-not-match-replacement",
            }, 8)

        artifacts = write_prepared_artifacts(
            Path(args.state_dir),
            args.path,
            args.base_sha256,
            candidate_sha,
            args.semantic_anchor,
            args.replacement,
            source,
            candidate,
        )
        return emit({
            "status": "prepared-artifacts",
            **artifacts,
            "sourceWritable": True,
            "semanticRebind": candidate_rebind,
            "parser": {
                "qmljsVersion": QMLJS_VERSION,
                "grammar": str(grammar),
                "treeSitterLibrary": library or "system",
            },
        }, 0)
    except OSError as exc:
        return emit({
            "status": "unavailable",
            "reason": "tree-sitter-library-missing",
            "detail": str(exc),
        }, 3)
    except (RuntimeError, AssertionError, UnicodeError) as exc:
        return emit({
            "status": "error",
            "reason": "prepare-apply-failed",
            "detail": str(exc),
        }, 8)
    finally:
        if native_parser is not None:
            native_parser.close()


if __name__ == "__main__":
    raise SystemExit(main())
