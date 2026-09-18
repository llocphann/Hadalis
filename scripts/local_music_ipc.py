#!/usr/bin/env python3
"""Tiny stdlib-only mpv IPC helper for Hadalis LocalMusic."""
from __future__ import annotations
import json, socket, sys, time
from typing import Any

PROPERTIES = ("pause","time-pos","duration","volume","path","media-title","playlist-pos","playlist-count","playlist")

def connect(path: str, timeout: float = 1.0) -> socket.socket:
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.settimeout(timeout)
    sock.connect(path)
    return sock

def request(sock: socket.socket, command: list[Any], request_id: int):
    payload = json.dumps({"command":command,"request_id":request_id}, separators=(",",":")) + "\n"
    sock.sendall(payload.encode("utf-8"))
    buffer = b""
    while b"\n" not in buffer:
        chunk = sock.recv(65536)
        if not chunk: raise ConnectionError("mpv IPC closed")
        buffer += chunk
    line, _rest = buffer.split(b"\n", 1)
    return json.loads(line.decode("utf-8", errors="replace"))

def status(path: str):
    result = {}
    with connect(path) as sock:
        for i, name in enumerate(PROPERTIES, 1):
            reply = request(sock, ["get_property",name], i)
            if reply.get("error") == "success": result[name] = reply.get("data")
    return result

def command(path: str, raw: str) -> int:
    cmd = json.loads(raw)
    if not isinstance(cmd, list) or not cmd: raise ValueError("command must be a non-empty JSON array")
    with connect(path) as sock: reply = request(sock, cmd, 1)
    return 0 if reply.get("error") == "success" else 1

def watch(path: str, interval: float) -> int:
    interval = max(0.25, interval)
    while True:
        try: payload = status(path)
        except (OSError, ConnectionError, ValueError, json.JSONDecodeError):
            payload = {"unavailable":True}
        print(json.dumps(payload, ensure_ascii=False, separators=(",",":")), flush=True)
        time.sleep(interval)

def main() -> int:
    if len(sys.argv) < 3: return 2
    mode, path = sys.argv[1], sys.argv[2]
    if mode == "status":
        print(json.dumps(status(path), ensure_ascii=False, separators=(",",":")))
        return 0
    if mode == "watch":
        return watch(path, float(sys.argv[3]) if len(sys.argv) > 3 else 0.75)
    if mode == "command" and len(sys.argv) > 3:
        return command(path, sys.argv[3])
    return 2

if __name__ == "__main__":
    raise SystemExit(main())
