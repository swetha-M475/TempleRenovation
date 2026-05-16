"""
Temple Heritage Monitoring — SQLite Persistence Layer

Manages activity history for the Flutter mobile app:
- Stores detection results, quality metrics, and annotated images
- Enables /compare with previous_activity_id (single-image lookup mode)
- Lightweight, file-based — no external DB server required

Database file: data/temple_heritage.db
"""

import json
import os
import sqlite3
import uuid
from datetime import datetime, timezone
from pathlib import Path

# ─── Database path ─────────────────────────────────────────
DB_DIR = Path(__file__).parent / "data"
DB_PATH = DB_DIR / "temple_heritage.db"


def _get_connection() -> sqlite3.Connection:
    """Get a SQLite connection with row_factory for dict-like access."""
    DB_DIR.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(DB_PATH), timeout=10)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")  # Better concurrent read perf
    conn.execute("PRAGMA foreign_keys=ON")
    return conn


def init_db():
    """
    Create the activities table if it does not exist.
    Called once at application startup.
    """
    conn = _get_connection()
    try:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS activities (
                id              TEXT PRIMARY KEY,
                image_hash      TEXT NOT NULL,
                detection_results TEXT NOT NULL,
                quality_results   TEXT NOT NULL,
                orientation_results TEXT,
                domain_results    TEXT,
                annotated_image_b64 TEXT,
                original_image_b64  TEXT,
                image_width     INTEGER,
                image_height    INTEGER,
                created_at      TEXT NOT NULL
            )
        """)
        conn.execute("""
            CREATE INDEX IF NOT EXISTS idx_activities_hash
            ON activities(image_hash)
        """)
        conn.execute("""
            CREATE INDEX IF NOT EXISTS idx_activities_created
            ON activities(created_at DESC)
        """)
        conn.commit()
        print(f"[database] Initialized at {DB_PATH}")
    finally:
        conn.close()


def generate_session_id() -> str:
    """Generate a unique session/activity ID."""
    return str(uuid.uuid4())


def store_activity(
    session_id: str,
    image_hash: str,
    detection_results: dict,
    quality_results: dict,
    orientation_results: dict = None,
    domain_results: dict = None,
    annotated_image_b64: str = "",
    original_image_b64: str = "",
    image_width: int = 0,
    image_height: int = 0,
) -> str:
    """
    Store a completed analysis activity in the database.

    Args:
        session_id: UUID string identifying this activity
        image_hash: Perceptual hash (pHash) hex string
        detection_results: Full detection dict from detector.detect()
        quality_results: Quality assessment dict from quality.assess()
        orientation_results: Orientation dict from orientation.check()
        domain_results: Domain-validated detection dict from domain.validate()
        annotated_image_b64: Base64-encoded annotated JPEG
        original_image_b64: Base64-encoded original image (for accurate SSIM)
        image_width: Original image width in pixels
        image_height: Original image height in pixels

    Returns:
        The session_id that was stored
    """
    now = datetime.now(timezone.utc).isoformat()
    conn = _get_connection()
    try:
        conn.execute(
            """
            INSERT INTO activities
                (id, image_hash, detection_results, quality_results,
                 orientation_results, domain_results, annotated_image_b64,
                 original_image_b64, image_width, image_height, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                session_id,
                image_hash,
                json.dumps(detection_results, default=str),
                json.dumps(quality_results, default=str),
                json.dumps(orientation_results, default=str) if orientation_results else "{}",
                json.dumps(domain_results, default=str) if domain_results else "{}",
                annotated_image_b64,
                original_image_b64,
                image_width,
                image_height,
                now,
            ),
        )
        conn.commit()
        print(f"[database] Stored activity {session_id} (hash={image_hash[:16]}...)")
    finally:
        conn.close()

    return session_id


def get_activity(activity_id: str) -> dict | None:
    """
    Retrieve a single activity by its session ID.

    Returns:
        dict with all stored fields, or None if not found
    """
    conn = _get_connection()
    try:
        row = conn.execute(
            "SELECT * FROM activities WHERE id = ?", (activity_id,)
        ).fetchone()
        if row is None:
            return None
        return _row_to_dict(row)
    finally:
        conn.close()


def get_activity_by_hash(image_hash: str) -> dict | None:
    """
    Retrieve the most recent activity matching a given image hash.

    Returns:
        dict with all stored fields, or None if not found
    """
    conn = _get_connection()
    try:
        row = conn.execute(
            "SELECT * FROM activities WHERE image_hash = ? ORDER BY created_at DESC LIMIT 1",
            (image_hash,),
        ).fetchone()
        if row is None:
            return None
        return _row_to_dict(row)
    finally:
        conn.close()


def list_activities(limit: int = 50, offset: int = 0) -> list[dict]:
    """
    List recent activities, ordered by creation time descending.

    Args:
        limit: Maximum number of records to return
        offset: Number of records to skip

    Returns:
        List of activity dicts (without large Base64 fields for efficiency)
    """
    conn = _get_connection()
    try:
        rows = conn.execute(
            """
            SELECT id, image_hash, detection_results, quality_results,
                   image_width, image_height, created_at
            FROM activities
            ORDER BY created_at DESC
            LIMIT ? OFFSET ?
            """,
            (limit, offset),
        ).fetchall()
        results = []
        for row in rows:
            d = dict(row)
            # Parse JSON fields
            d["detection_results"] = json.loads(d.get("detection_results", "{}"))
            d["quality_results"] = json.loads(d.get("quality_results", "{}"))
            results.append(d)
        return results
    finally:
        conn.close()


def get_activity_count() -> int:
    """Return total number of stored activities."""
    conn = _get_connection()
    try:
        row = conn.execute("SELECT COUNT(*) as cnt FROM activities").fetchone()
        return row["cnt"] if row else 0
    finally:
        conn.close()


def _row_to_dict(row: sqlite3.Row) -> dict:
    """Convert a sqlite3.Row to a plain dict with parsed JSON fields."""
    d = dict(row)
    # Parse stored JSON strings back to dicts
    for key in ("detection_results", "quality_results", "orientation_results", "domain_results"):
        val = d.get(key)
        if val and isinstance(val, str):
            try:
                d[key] = json.loads(val)
            except json.JSONDecodeError:
                d[key] = {}
    return d
