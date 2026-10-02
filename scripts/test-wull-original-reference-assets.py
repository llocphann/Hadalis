#!/usr/bin/env python3
"""Exact-source read-only gate: immutable four real ORIGINAL Wull reference PNGs.

The manifest and the independently source-verified metadata projection must
agree verbatim on each row. This checks PNG signature, IHDR CRC, actual tracked
asset bytes, Git blob and SHA-256. It DOES NOT inspect visual resemblance.
"""
import hashlib
import json
from pathlib import Path
import struct
import zlib

ROOT=Path(__file__).resolve().parents[1]
REFERENCE=ROOT/"docs/wull-visual/reference"
ORIGINALS=(
 "assets/Water Droplet Companion.png",
 "assets/Water Droplet Companion Expression.png",
 "assets/Water Droplet Companion Animation.png",
 "assets/Water Droplet Companion Animation Plus.png",
)
META="docs/wull-visual/reference/source-metadata.json"
PREFIX="authentic-assets-sha256-"

def main():
    manifest=json.loads((REFERENCE/"manifest.json").read_text(encoding="utf-8"))
    source=json.loads((ROOT/META).read_text(encoding="utf-8"))
    assert manifest.get("schema")==2 and source.get("schema")==1, "REFERENCE_SCHEMA_INVALID"
    assert manifest.get("source_metadata")==META, "REFERENCE_SOURCE_METADATA_MISMATCH"
    assert source.get("kind")=="AUTHENTIC_TRACKED_WULL_REFERENCE_SOURCE_METADATA"
    assert source.get("original_assets_unchanged") is True, "SOURCE_PROVENANCE_UNQUALIFIED"
    assert source.get("identity_status")=="FOUR_SOURCE_BYTES_SHA256_IHDR_VERIFIED"
    assert source.get("visual_review")=="ORIGINAL_PIXELS_NOT_YET_VIEWED"
    assert manifest.get("visual_review")=="ORIGINAL_PIXELS_NOT_YET_VIEWED"
    assert manifest.get("identity_status")==source["identity_status"]
    a=manifest.get("files")
    b=source.get("assets")
    assert type(a)==type(b)==list and len(a)==len(b)==4, "REFERENCE_ROWS_INVALID"
    assert a==b, "REFERENCE_METADATA_ROW_MISMATCH"
    assert tuple(x.get("file") for x in a)==ORIGINALS, "REFERENCE_PATH_MISMATCH"
    version=PREFIX+hashlib.sha256(
        json.dumps(b,sort_keys=True,separators=(",",":")).encode("utf-8")).hexdigest()[:16]
    assert manifest.get("reference_version")==source.get("reference_version")==version, "REFERENCE_VERSION_MISMATCH"
    prov=manifest.get("provenance")
    assert type(prov)==dict
    assert (prov.get("source_job")==source["source_job"] and
            prov.get("source_evidence_id")==source["source_evidence_id"] and
            prov.get("source_sha")==source["source_job_sha"] and
            prov.get("observed_at_unix")==source["observed_at_unix"] and
            prov.get("stdout_digest_verified")==source["stdout_digest_verified"])
    assert (prov.get("published_metadata_receipt")==
            "JOB-WULL-ORIGINAL-METADATA-PUBLISH-P1E0042-20261003-54:0")
    for item,filename in zip(a,ORIGINALS):
        assert set(item)=={"file","git_blob","bytes","sha256","width","height","bit_depth","color_type"}
        path=ROOT/filename
        assert path.is_file() and not path.is_symlink(), "ORIGINAL_ASSET_NOT_FOUND"
        raw=path.read_bytes()
        assert len(raw)==item["bytes"] and 0<len(raw)<=16_000_000, "REFERENCE_BYTES_MISMATCH"
        blob=hashlib.sha1(("blob "+str(len(raw))+"\0").encode("ascii")+raw).hexdigest()
        assert blob==item["git_blob"], "REFERENCE_BLOB_MISMATCH"
        assert hashlib.sha256(raw).hexdigest()==item["sha256"], "REFERENCE_SHA256_MISMATCH"
        assert len(raw)>=33 and raw[:8]==b"\x89PNG\r\n\x1a\n" and raw[8:16]==b"\0\0\0\rIHDR", "REFERENCE_NOT_PNG"
        assert struct.unpack_from(">I",raw,29)[0]==zlib.crc32(raw[12:29])&0xffffffff, "REFERENCE_IHDR_CRC_INVALID"
        width,height=struct.unpack_from(">II",raw,16)
        assert 100<=width<=16000 and 100<=height<=16000
        assert (width,height,raw[24],raw[25])==(item["width"],item["height"],item["bit_depth"],item["color_type"])
        print("REFERENCE_SOURCE_MATCH="+filename)
    print("REFERENCE_ORIGINALS=4_OF_4_INTEGRITY_VERIFIED")
    print("REFERENCE_VERSION="+version)
    print("REFERENCE_ASSETS=SOURCE_ONLY_NOT_MODIFIED")
    print("REFERENCE_VISUAL_CONTENT=NOT_YET_INSPECTED")

if __name__=="__main__":
    main()
