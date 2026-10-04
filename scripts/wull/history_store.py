#!/usr/bin/env python3
"""Crash-safe local persistence for Wull explicit-chat transcripts.

Transcript persistence is deliberately separate from inference context. SQLite
stores messages incrementally under XDG_STATE_HOME; callers choose a bounded
recent window for model input and page older rows only for the UI.
"""
from __future__ import annotations

import os
from pathlib import Path
import sqlite3
import stat
import time

MAX_ROWS = 2000
MAX_CONTENT = 6000


class HistoryError(Exception):
    pass


def path() -> Path:
    override = os.environ.get("INIR_WULL_HISTORY_DB")
    if override:
        return Path(override).expanduser()
    base = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state")))
    return base / "inir/wull/chat.sqlite3"


def _connect() -> sqlite3.Connection:
    target = path()
    try:
        target.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        parent = target.parent.stat()
        if parent.st_uid != os.getuid():
            raise HistoryError("history_owner_mismatch")
        os.chmod(target.parent, 0o700)
        if not target.exists():
            fd = os.open(target, os.O_RDWR | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
            os.close(fd)
        info = target.lstat()
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid():
            raise HistoryError("history_file_unsafe")
        os.chmod(target, 0o600)
        db = sqlite3.connect(target, timeout=1.5)
        db.execute("PRAGMA journal_mode=WAL")
        db.execute("PRAGMA synchronous=NORMAL")
        db.execute("PRAGMA busy_timeout=1500")
        db.execute(
            """CREATE TABLE IF NOT EXISTS messages(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                role TEXT NOT NULL CHECK(role IN ('user','assistant')),
                content TEXT NOT NULL,
                created_ms INTEGER NOT NULL,
                model TEXT NOT NULL DEFAULT ''
            )"""
        )
        db.execute("CREATE INDEX IF NOT EXISTS messages_recent ON messages(id DESC)")
        db.commit()
        return db
    except HistoryError:
        raise
    except (OSError, sqlite3.Error) as exc:
        raise HistoryError("history_open_failed") from exc


def load(limit: int = 60, before_id: int = 0) -> list[dict]:
    limit = max(1, min(100, int(limit)))
    before = max(0, int(before_id or 0))
    db = _connect()
    try:
        if before:
            rows = db.execute(
                "SELECT id,role,content,created_ms,model FROM messages "
                "WHERE id<? ORDER BY id DESC LIMIT ?",
                (before, limit),
            ).fetchall()
        else:
            rows = db.execute(
                "SELECT id,role,content,created_ms,model FROM messages "
                "ORDER BY id DESC LIMIT ?",
                (limit,),
            ).fetchall()
        return [
            {
                "id": row[0],
                "role": row[1],
                "content": row[2],
                "createdMs": row[3],
                "model": row[4],
            }
            for row in reversed(rows)
        ]
    except sqlite3.Error as exc:
        raise HistoryError("history_read_failed") from exc
    finally:
        db.close()


def _trim(db: sqlite3.Connection) -> None:
    cutoff = db.execute(
        "SELECT id FROM messages ORDER BY id DESC LIMIT 1 OFFSET ?",
        (MAX_ROWS - 1,),
    ).fetchone()
    if cutoff:
        db.execute("DELETE FROM messages WHERE id<?", (cutoff[0],))


def append(role: str, content: str, model: str = "") -> int:
    if role not in ("user", "assistant"):
        raise HistoryError("invalid_role")
    value = str(content).strip()
    if not value:
        raise HistoryError("empty_content")
    value = value[:MAX_CONTENT]
    model = str(model)[:160]
    db = _connect()
    try:
        with db:
            cursor = db.execute(
                "INSERT INTO messages(role,content,created_ms,model) VALUES(?,?,?,?)",
                (role, value, int(time.time() * 1000), model),
            )
            _trim(db)
        return int(cursor.lastrowid)
    except sqlite3.Error as exc:
        raise HistoryError("history_write_failed") from exc
    finally:
        db.close()


def append_exchange(user_text: str, assistant_text: str, model: str = "") -> tuple[int, int]:
    user = str(user_text).strip()[:MAX_CONTENT]
    assistant = str(assistant_text).strip()[:MAX_CONTENT]
    if not user or not assistant:
        raise HistoryError("empty_content")
    model = str(model)[:160]
    db = _connect()
    try:
        now = int(time.time() * 1000)
        with db:
            user_cursor = db.execute(
                "INSERT INTO messages(role,content,created_ms,model) VALUES('user',?,?,?)",
                (user, now, model),
            )
            assistant_cursor = db.execute(
                "INSERT INTO messages(role,content,created_ms,model) VALUES('assistant',?,?,?)",
                (assistant, now + 1, model),
            )
            _trim(db)
        return int(user_cursor.lastrowid), int(assistant_cursor.lastrowid)
    except sqlite3.Error as exc:
        raise HistoryError("history_write_failed") from exc
    finally:
        db.close()


def clear() -> None:
    db = _connect()
    try:
        with db:
            db.execute("DELETE FROM messages")
    except sqlite3.Error as exc:
        raise HistoryError("history_clear_failed") from exc
    finally:
        db.close()
