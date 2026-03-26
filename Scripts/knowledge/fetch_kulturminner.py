#!/usr/bin/env python3
"""
Fetch kulturminner (cultural heritage sites) from Riksantikvaren OGC API Features.

API: https://api.ra.no/brukerminner/collections/brukerminner/items
Format: GeoJSON (OGC API Features)
License: NLOD 2.0

The API truncates JSON responses at ~53KB, which limits total results per bbox.
We subdivide county bounding boxes into a grid of smaller cells to get complete coverage,
then deduplicate by feature ID.

Produces one SQLite pack per county: kulturminnerLokaliteter-{county_code}.sqlite
"""

import json
import sys
import time

import requests

from pack_builder import (
    CURRENT_COUNTIES,
    create_pack_db,
    finalize_pack,
    insert_entry,
)

API_BASE = "https://api.ra.no/brukerminner/collections/brukerminner/items"
PAGE_SIZE = 50
MAX_PAGES_PER_CELL = 20  # Per grid cell
GRID_DIVISIONS = 4  # Split each county bbox into 4x4 = 16 cells
USER_AGENT = "Trakke-DataPipeline/1.0 hei@tazk.no"
REQUEST_DELAY = 0.3  # seconds between requests

# Approximate bounding boxes for each county (west, south, east, north)
COUNTY_BBOX = {
    "03": (10.5, 59.8, 10.9, 59.97),    # Oslo
    "11": (5.5, 58.8, 7.2, 59.8),       # Rogaland
    "15": (5.5, 61.8, 9.5, 63.5),       # Møre og Romsdal
    "18": (12.0, 66.0, 17.5, 69.5),     # Nordland
    "31": (10.5, 59.0, 12.0, 59.8),     # Østfold
    "32": (10.5, 59.7, 12.2, 60.6),     # Akershus
    "33": (7.5, 59.4, 10.5, 60.7),      # Buskerud
    "34": (7.5, 60.4, 12.5, 62.6),      # Innlandet
    "39": (9.0, 58.8, 10.5, 59.6),      # Vestfold
    "40": (7.5, 58.8, 10.0, 59.8),      # Telemark
    "42": (6.2, 57.9, 9.0, 59.2),       # Agder
    "46": (4.5, 59.5, 7.8, 62.0),       # Vestland
    "50": (9.5, 63.0, 15.0, 65.3),      # Trøndelag
    "55": (15.5, 68.3, 20.5, 70.2),     # Troms
    "56": (22.0, 69.0, 31.5, 71.2),     # Finnmark
}

THEME = "kulturminnerLokaliteter"
SOURCE = "Riksantikvaren"


def subdivide_bbox(bbox: tuple, divisions: int) -> list[tuple]:
    """Split a bbox into a grid of smaller cells."""
    west, south, east, north = bbox
    lon_step = (east - west) / divisions
    lat_step = (north - south) / divisions

    cells = []
    for i in range(divisions):
        for j in range(divisions):
            cell = (
                west + i * lon_step,
                south + j * lat_step,
                west + (i + 1) * lon_step,
                south + (j + 1) * lat_step,
            )
            cells.append(cell)
    return cells


def fetch_bbox(bbox: tuple) -> list[dict]:
    """Fetch all features within a single bounding box, paginating."""
    features = []
    offset = 0
    bbox_str = f"{bbox[0]},{bbox[1]},{bbox[2]},{bbox[3]}"

    for page in range(MAX_PAGES_PER_CELL):
        params = {
            "f": "json",
            "bbox": bbox_str,
            "limit": PAGE_SIZE,
            "offset": offset,
        }
        headers = {
            "User-Agent": USER_AGENT,
            "Accept": "application/geo+json",
        }

        try:
            resp = requests.get(API_BASE, params=params, headers=headers, timeout=30)
            resp.raise_for_status()
            data = resp.json()
        except (requests.RequestException, json.JSONDecodeError):
            break

        page_features = data.get("features", [])
        features.extend(page_features)

        if len(page_features) < PAGE_SIZE:
            break

        offset += PAGE_SIZE
        time.sleep(REQUEST_DELAY)

    return features


def fetch_county(county_code: str, bbox: tuple) -> list[dict]:
    """Fetch all kulturminner within a county by subdividing the bbox into cells."""
    cells = subdivide_bbox(bbox, GRID_DIVISIONS)
    seen_ids = set()
    unique_features = []

    for i, cell in enumerate(cells):
        cell_features = fetch_bbox(cell)
        new_count = 0
        for f in cell_features:
            fid = f.get("id") or id(f)
            if fid not in seen_ids:
                seen_ids.add(fid)
                unique_features.append(f)
                new_count += 1

        if cell_features:
            print(f"  Cell {i+1}/{len(cells)}: {len(cell_features)} fetched, {new_count} new (total: {len(unique_features)})")

        time.sleep(REQUEST_DELAY)

    return unique_features


def build_county_pack(county_code: str, features: list[dict]) -> dict | None:
    """Build a SQLite pack from GeoJSON features for a single county."""
    if not features:
        return None

    pack_id = f"{THEME}-{county_code}"
    conn, db_path = create_pack_db(pack_id)

    count = 0
    for feature in features:
        geom = feature.get("geometry") or {}
        props = feature.get("properties") or {}

        # Only point features
        if geom.get("type") != "Point":
            continue
        coords = geom.get("coordinates", [])
        if len(coords) < 2:
            continue

        lon, lat = coords[0], coords[1]
        name = props.get("tittel") or props.get("navn") or "Kulturminne"
        external_id = str(feature.get("id", ""))

        description = props.get("beskrivelse")
        source_url = props.get("linkkulturminnesok")

        attributes = {}
        if props.get("kommune"):
            attributes["kommune"] = props["kommune"]
        if props.get("fylke"):
            attributes["fylke"] = props["fylke"]
        if props.get("kategori"):
            attributes["kategori"] = props["kategori"]
        if props.get("vernetype"):
            attributes["vernetype"] = props["vernetype"]
        if props.get("datering"):
            attributes["datering"] = props["datering"]

        row_id = insert_entry(
            conn,
            external_id=external_id,
            theme=THEME,
            name=name,
            description=description,
            lat=lat,
            lon=lon,
            source=SOURCE,
            source_url=source_url,
            attributes=attributes if attributes else None,
        )
        if row_id > 0:
            count += 1

    if count == 0:
        conn.close()
        db_path.unlink(missing_ok=True)
        return None

    info = finalize_pack(conn, db_path)
    print(f"  Pack {pack_id}: {count} entries, {info['file_size']} bytes")
    return info


def main():
    counties = sys.argv[1:] if len(sys.argv) > 1 else list(COUNTY_BBOX.keys())

    pack_infos = []
    for code in counties:
        if code not in COUNTY_BBOX:
            print(f"Unknown county code: {code}")
            continue

        name = CURRENT_COUNTIES.get(code, code)
        print(f"\nFetching {name} ({code})...")
        bbox = COUNTY_BBOX[code]
        features = fetch_county(code, bbox)

        if features:
            info = build_county_pack(code, features)
            if info:
                pack_infos.append(info)
        else:
            print(f"  No features found")

        time.sleep(1)  # Courtesy delay between counties

    # Save pack infos for catalog generation
    from pack_builder import OUTPUT_DIR
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    infos_path = OUTPUT_DIR / "kulturminner_packs.json"
    with open(infos_path, "w") as f:
        json.dump(pack_infos, f, indent=2, ensure_ascii=False)
    print(f"\nDone. {len(pack_infos)} packs built.")
    return pack_infos


if __name__ == "__main__":
    main()
