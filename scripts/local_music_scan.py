#!/usr/bin/env python3
"""Scan a local music library and emit a compact JSON index for Hadalis."""
from __future__ import annotations
import json, os, sys
from pathlib import Path
from typing import Any

AUDIO_EXTENSIONS = {".mp3",".flac",".ogg",".oga",".opus",".m4a",".aac",".wav",".wma",".alac",".ape",".aiff",".aif"}
PLAYLIST_EXTENSIONS = {".m3u",".m3u8"}
ART_NAMES = ("cover","folder","front","album","artwork")
ART_EXTENSIONS = (".jpg",".jpeg",".png",".webp",".avif")
try:
    from mutagen import File as MutagenFile  # type: ignore
except Exception:
    MutagenFile = None

def first_tag(tags: Any, keys: tuple[str, ...]) -> str:
    if not tags: return ""
    for key in keys:
        try: value = tags.get(key)
        except Exception: value = None
        if value is None: continue
        if isinstance(value, (list, tuple)): value = value[0] if value else ""
        value = str(value).strip()
        if value: return value
    return ""

def folder_art(directory: Path) -> str:
    try: entries = {p.name.lower(): p for p in directory.iterdir() if p.is_file()}
    except OSError: return ""
    for base in ART_NAMES:
        for ext in ART_EXTENSIONS:
            candidate = entries.get(base + ext)
            if candidate: return str(candidate.resolve())
    return ""

def metadata(path: Path, root: Path) -> dict[str, Any]:
    title, artist = path.stem.replace("_", " ").strip(), ""
    album = path.parent.name if path.parent != root else ""
    duration, track_no, disc_no = 0.0, 0, 0
    if MutagenFile is not None:
        try:
            audio = MutagenFile(path, easy=True)
            if audio is not None:
                title = first_tag(audio.tags, ("title",)) or title
                artist = first_tag(audio.tags, ("artist","albumartist"))
                album = first_tag(audio.tags, ("album",)) or album
                for attr, keys in (("track",("tracknumber",)),("disc",("discnumber",))):
                    raw = first_tag(audio.tags, keys)
                    if raw:
                        try:
                            if attr == "track": track_no = int(raw.split("/",1)[0])
                            else: disc_no = int(raw.split("/",1)[0])
                        except ValueError: pass
                info = getattr(audio, "info", None)
                if info is not None: duration = float(getattr(info, "length", 0.0) or 0.0)
        except Exception:
            pass
    try:
        rel = path.parent.relative_to(root)
        folder = "" if str(rel) == "." else str(rel)
    except ValueError:
        folder = path.parent.name
    return {"path":str(path.resolve()),"title":title,"artist":artist,"album":album,
            "duration":round(duration,3),"track":track_no,"disc":disc_no,
            "art":folder_art(path.parent),"folder":folder}

def parse_playlist(path: Path, root: Path, by_path: dict[str, dict[str, Any]]):
    tracks, seen = [], set()
    try: lines = path.read_text(encoding="utf-8-sig", errors="replace").splitlines()
    except OSError: return None
    for raw in lines:
        line = raw.strip()
        if not line or line.startswith("#"): continue
        candidate = Path(os.path.expanduser(line))
        if not candidate.is_absolute(): candidate = path.parent / candidate
        try: candidate = candidate.resolve()
        except OSError: continue
        if candidate.suffix.lower() not in AUDIO_EXTENSIONS or not candidate.is_file(): continue
        key = str(candidate)
        if key in seen: continue
        seen.add(key)
        item = by_path.get(key)
        if item is None:
            item = metadata(candidate, root)
            by_path[key] = item
        tracks.append(item)
    if not tracks: return None
    return {"id":"m3u:"+str(path.resolve()),"name":path.stem,"kind":"playlist",
            "path":str(path.resolve()),"tracks":tracks}

def scan(root_path: str):
    root = Path(os.path.expanduser(root_path)).resolve()
    if not root.is_dir():
        return {"root":str(root),"tracks":[],"playlists":[],"folders":[],"error":"not_directory"}
    audio_paths, playlist_paths = [], []
    for current, dirnames, filenames in os.walk(root):
        dirnames[:] = sorted(d for d in dirnames if not d.startswith("."))
        base = Path(current)
        for name in sorted(filenames):
            if name.startswith("."): continue
            path = base / name
            if path.suffix.lower() in AUDIO_EXTENSIONS: audio_paths.append(path)
            elif path.suffix.lower() in PLAYLIST_EXTENSIONS: playlist_paths.append(path)
    tracks = [metadata(path, root) for path in audio_paths]
    tracks.sort(key=lambda item:(str(item["artist"]).casefold(),str(item["album"]).casefold(),
        int(item["disc"] or 0),int(item["track"] or 0),str(item["title"]).casefold(),str(item["path"]).casefold()))
    by_path = {str(item["path"]):item for item in tracks}
    playlists = [p for p in (parse_playlist(path, root, by_path) for path in playlist_paths) if p]
    playlists.sort(key=lambda item:str(item["name"]).casefold())
    folders_map: dict[str,list[dict[str,Any]]] = {}
    for item in tracks:
        folder = str(item.get("folder",""))
        if folder: folders_map.setdefault(folder,[]).append(item)
    folders = [{"id":"folder:"+folder,"name":Path(folder).name or folder,"subtitle":folder,
                "kind":"folder","tracks":values}
               for folder,values in sorted(folders_map.items(), key=lambda pair:pair[0].casefold())
               if len(values) >= 2]
    return {"root":str(root),"tracks":tracks,"playlists":playlists,"folders":folders,"error":""}

def main() -> int:
    if len(sys.argv) != 2:
        print(json.dumps({"error":"usage","tracks":[],"playlists":[],"folders":[]}))
        return 2
    print(json.dumps(scan(sys.argv[1]), ensure_ascii=False, separators=(",",":")))
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
