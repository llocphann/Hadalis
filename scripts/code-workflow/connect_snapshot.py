#!/usr/bin/env python3
"""Read-only freshness check for a promoted Connect safety snapshot.

This helper does not generate or promote type/cycle proofs. It only re-hashes
the already-qualified primary QML source and retained external QML dependency
for one Connect history snapshot.

Candidate identity is echoed and validated syntactically so the caller can bind
the freshness result to one exact preview command. Candidate bytes are not
reconstructed here; any future Connect artifact-staging gate must independently
re-run/reverify the qualified proof and candidate semantics before staging.
"""

from __future__ import annotations

import argparse
from hashlib import sha256
import json
from pathlib import Path

PROTOCOL = 1


def emit(payload: dict, exit_code: int) -> int:
    print(json.dumps({"protocol": PROTOCOL, **payload}, ensure_ascii=False))
    return exit_code


def _valid_sha(value: str) -> bool:
    return (
        isinstance(value, str)
        and len(value) == 64
        and all(ch in "0123456789abcdef" for ch in value.lower())
    )


def _runtime_qml_path(root: Path, relative: str) -> Path:
    request = Path(str(relative))
    if request.is_absolute():
        raise ValueError("snapshot source path must be runtime-relative")
    candidate = (root / request).resolve()
    try:
        candidate.relative_to(root)
    except ValueError as exc:
        raise ValueError("snapshot source path escapes runtime root") from exc
    if candidate.suffix != ".qml" or not candidate.is_file():
        raise ValueError("snapshot source path must name an existing .qml file")
    return candidate


def _hash(path: Path) -> str:
    return sha256(path.read_bytes()).hexdigest()


def verify_connect_safety_snapshot(
    root: Path,
    source_path: str,
    base_sha256: str,
    candidate_sha256: str,
    external_source_path: str,
    external_source_sha256: str,
) -> dict:
    if not _valid_sha(base_sha256):
        return {
            "status": "invalid-request",
            "reason": "base-sha256-invalid",
            "writeAuthorized": False,
            "applyEnabled": False,
            "artifactsStaged": False,
        }
    if not _valid_sha(candidate_sha256):
        return {
            "status": "invalid-request",
            "reason": "candidate-sha256-invalid",
            "writeAuthorized": False,
            "applyEnabled": False,
            "artifactsStaged": False,
        }
    if not _valid_sha(external_source_sha256):
        return {
            "status": "invalid-request",
            "reason": "external-source-sha256-invalid",
            "writeAuthorized": False,
            "applyEnabled": False,
            "artifactsStaged": False,
        }

    try:
        source = _runtime_qml_path(root, source_path)
        external = _runtime_qml_path(root, external_source_path)
        source_relative = source.relative_to(root).as_posix()
        external_relative = external.relative_to(root).as_posix()
        source_sha = _hash(source)
        external_sha = _hash(external)
    except (ValueError, OSError) as exc:
        return {
            "status": "invalid-request",
            "reason": str(exc),
            "writeAuthorized": False,
            "applyEnabled": False,
            "artifactsStaged": False,
        }

    common = {
        "sourcePath": source_relative,
        "baseSha256": base_sha256,
        "candidateSha256": candidate_sha256,
        "currentSourceSha256": source_sha,
        "externalSourcePath": external_relative,
        "externalSourceSha256": external_source_sha256,
        "currentExternalSourceSha256": external_sha,
        "writeAuthorized": False,
        "applyEnabled": False,
        "artifactsStaged": False,
    }

    if source_relative != source_path or source_sha != base_sha256:
        return {
            "status": "stale",
            "reason": "source-sha-drift",
            **common,
        }
    if (
        external_relative != external_source_path
        or external_sha != external_source_sha256
    ):
        return {
            "status": "stale",
            "reason": "external-source-sha-drift",
            **common,
        }

    return {
        "status": "fresh",
        "reason": "qualified-sources-match-snapshot",
        "sourceFresh": True,
        "externalSourceFresh": True,
        **common,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        default=str(Path(__file__).resolve().parents[2]),
    )
    parser.add_argument("--path", required=True)
    parser.add_argument("--base-sha256", required=True)
    parser.add_argument("--candidate-sha256", required=True)
    parser.add_argument("--external-path", required=True)
    parser.add_argument("--external-sha256", required=True)
    args = parser.parse_args()

    root = Path(args.root).expanduser().resolve()
    if not root.is_dir():
        return emit({
            "status": "invalid-request",
            "reason": "runtime-root-missing",
            "writeAuthorized": False,
            "applyEnabled": False,
            "artifactsStaged": False,
        }, 4)

    result = verify_connect_safety_snapshot(
        root,
        args.path,
        args.base_sha256,
        args.candidate_sha256,
        args.external_path,
        args.external_sha256,
    )
    status = result.get("status")
    return emit(result, 0 if status == "fresh" else 7)


if __name__ == "__main__":
    raise SystemExit(main())
