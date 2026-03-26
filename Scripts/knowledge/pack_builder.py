#!/usr/bin/env python3
"""
Shared utilities for building knowledge pack SQLite databases.

Each pack is a SQLite file with:
- entries table: id, external_id, theme, name, description, lat, lon, geometry, source, source_url, attributes
- entries_spatial: R-tree virtual table for viewport queries (id, min_lat, max_lat, min_lon, max_lon)
- articles table (optional): id, theme, category, title, body, source, source_url, verified_at, sort_order

Pack ID format: {theme}-{county_code}  (e.g., kulturminnerLokaliteter-46)
Filename: {pack_id}.sqlite
"""

import hashlib
import json
import os
import sqlite3
from datetime import datetime, timezone
from pathlib import Path

# Norwegian counties (fylker) with codes used by data sources
COUNTIES = {
    "03": "Oslo",
    "11": "Rogaland",
    "15": "Møre og Romsdal",
    "18": "Nordland",
    "30": "Viken",        # dissolved 2024 but still used by some data sources
    "31": "Østfold",
    "32": "Akershus",
    "33": "Buskerud",
    "34": "Innlandet",
    "38": "Vestfold og Telemark",  # dissolved 2024
    "39": "Vestfold",
    "40": "Telemark",
    "42": "Agder",
    "46": "Vestland",
    "50": "Trøndelag",
    "55": "Troms",
    "56": "Finnmark",
}

# Current county codes (post-2024 restructuring)
CURRENT_COUNTIES = {
    "03": "Oslo",
    "11": "Rogaland",
    "15": "Møre og Romsdal",
    "18": "Nordland",
    "31": "Østfold",
    "32": "Akershus",
    "33": "Buskerud",
    "34": "Innlandet",
    "39": "Vestfold",
    "40": "Telemark",
    "42": "Agder",
    "46": "Vestland",
    "50": "Trøndelag",
    "55": "Troms",
    "56": "Finnmark",
}

OUTPUT_DIR = Path(__file__).parent / "output"
SCHEMA_VERSION = 1


def create_pack_db(pack_id: str) -> tuple[sqlite3.Connection, Path]:
    """Create a new SQLite database for a knowledge pack."""
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    db_path = OUTPUT_DIR / f"{pack_id}.sqlite"

    # Remove existing file
    if db_path.exists():
        db_path.unlink()

    conn = sqlite3.connect(str(db_path))
    conn.execute("PRAGMA journal_mode=DELETE")
    conn.execute("PRAGMA synchronous=NORMAL")

    # Create entries table
    conn.execute("""
        CREATE TABLE entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            external_id TEXT,
            theme TEXT NOT NULL,
            name TEXT NOT NULL,
            description TEXT,
            lat REAL NOT NULL,
            lon REAL NOT NULL,
            geometry TEXT,
            source TEXT NOT NULL,
            source_url TEXT,
            attributes TEXT
        )
    """)

    # Create R-tree spatial index
    conn.execute("""
        CREATE VIRTUAL TABLE entries_spatial USING rtree(
            id,
            min_lat, max_lat,
            min_lon, max_lon
        )
    """)

    # Index for theme filtering
    conn.execute("CREATE INDEX idx_entries_theme ON entries(theme)")

    return conn, db_path


def insert_entry(
    conn: sqlite3.Connection,
    *,
    external_id: str | None,
    theme: str,
    name: str,
    description: str | None,
    lat: float,
    lon: float,
    geometry: str | None = None,
    source: str,
    source_url: str | None = None,
    attributes: dict | None = None,
) -> int:
    """Insert a single entry and its spatial index row. Returns the row id."""
    # Validate coordinates
    if not (-90 <= lat <= 90 and -180 <= lon <= 180):
        return -1
    if not (name and name.strip()):
        return -1

    attrs_json = json.dumps(attributes, ensure_ascii=False) if attributes else None

    cursor = conn.execute(
        """INSERT INTO entries
           (external_id, theme, name, description, lat, lon, geometry, source, source_url, attributes)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
        (external_id, theme, name.strip(), description, lat, lon, geometry, source, source_url, attrs_json),
    )
    row_id = cursor.lastrowid

    # Insert into R-tree (point: min=max)
    conn.execute(
        "INSERT INTO entries_spatial (id, min_lat, max_lat, min_lon, max_lon) VALUES (?, ?, ?, ?, ?)",
        (row_id, lat, lat, lon, lon),
    )

    return row_id


def create_articles_table(conn: sqlite3.Connection):
    """Create the articles table for packs that include articles."""
    conn.execute("""
        CREATE TABLE IF NOT EXISTS articles (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            theme TEXT NOT NULL,
            category TEXT NOT NULL,
            title TEXT NOT NULL,
            body TEXT NOT NULL,
            source TEXT NOT NULL,
            source_url TEXT,
            verified_at TEXT NOT NULL,
            sort_order INTEGER NOT NULL DEFAULT 0
        )
    """)


def insert_article(
    conn: sqlite3.Connection,
    *,
    theme: str,
    category: str,
    title: str,
    body: str,
    source: str,
    source_url: str | None = None,
    verified_at: str | None = None,
    sort_order: int = 0,
):
    """Insert a single article."""
    if verified_at is None:
        verified_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    conn.execute(
        """INSERT INTO articles (theme, category, title, body, source, source_url, verified_at, sort_order)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
        (theme, category, title, body, source, source_url, verified_at, sort_order),
    )


def finalize_pack(conn: sqlite3.Connection, db_path: Path) -> dict:
    """Finalize a pack: commit, vacuum, compute stats. Returns pack info dict."""
    conn.commit()

    # Get entry count
    entry_count = conn.execute("SELECT COUNT(*) FROM entries").fetchone()[0]

    # Vacuum for minimal file size
    conn.execute("VACUUM")
    conn.close()

    # Compute SHA-256 checksum
    file_size = db_path.stat().st_size
    checksum = sha256_file(db_path)

    pack_id = db_path.stem
    parts = pack_id.rsplit("-", 1)
    theme = parts[0] if len(parts) == 2 else pack_id
    county_code = parts[1] if len(parts) == 2 else None

    county_name = CURRENT_COUNTIES.get(county_code) if county_code else None

    return {
        "id": pack_id,
        "name": f"{theme} – {county_name}" if county_name else theme,
        "theme": theme,
        "county": county_code,
        "file_size": file_size,
        "entry_count": entry_count,
        "schema_version": SCHEMA_VERSION,
        "min_schema_version": SCHEMA_VERSION,
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "checksum": checksum,
    }


def sha256_file(path: Path) -> str:
    """Compute SHA-256 hex digest of a file."""
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()


def generate_catalog(pack_infos: list[dict], base_url: str) -> dict:
    """Generate a catalog.json from a list of pack info dicts."""
    packs = []
    for info in pack_infos:
        info_copy = dict(info)
        info_copy["download_url"] = f"{base_url}/{info['id']}.sqlite"
        packs.append(info_copy)

    return {
        "version": 1,
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "packs": packs,
    }


def save_catalog(catalog: dict, output_dir: Path | None = None):
    """Save catalog.json to disk."""
    out = output_dir or OUTPUT_DIR
    out.mkdir(parents=True, exist_ok=True)
    catalog_path = out / "catalog.json"
    with open(catalog_path, "w") as f:
        json.dump(catalog, f, indent=2, ensure_ascii=False)
    print(f"Catalog saved: {catalog_path} ({len(catalog['packs'])} packs)")
