#!/usr/bin/env python3
"""
Fetch restriksjonsområder for naturvern from Miljødirektoratet ArcGIS REST.

API: https://kart.miljodirektoratet.no/arcgis/rest/services/vern_restriksjonsomrader/MapServer/0/query
Format: ArcGIS REST JSON
License: NLOD 2.0

Areas within nature reserves that have specific restrictions (e.g. no-go zones,
landing prohibitions). Uses polygon centroid as point representation.

Produces one SQLite pack per county: restriksjonsomraderNaturvern-{county_code}.sqlite
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

API_BASE = "https://kart.miljodirektoratet.no/arcgis/rest/services/vern_restriksjonsomrader/MapServer/0/query"
PAGE_SIZE = 200
MAX_PAGES = 50
USER_AGENT = "Trakke-DataPipeline/1.0 hei@tazk.no"
REQUEST_DELAY = 0.5

THEME = "restriksjonsomraderNaturvern"
SOURCE = "Miljødirektoratet"

COUNTY_BBOX = {
    "03": (10.5, 59.8, 10.9, 59.97),
    "11": (5.5, 58.8, 7.2, 59.8),
    "15": (5.5, 61.8, 9.5, 63.5),
    "18": (12.0, 66.0, 17.5, 69.5),
    "31": (10.5, 59.0, 12.0, 59.8),
    "32": (10.5, 59.7, 12.2, 60.6),
    "33": (7.5, 59.4, 10.5, 60.7),
    "34": (7.5, 60.4, 12.5, 62.6),
    "39": (9.0, 58.8, 10.5, 59.6),
    "40": (7.5, 58.8, 10.0, 59.8),
    "42": (6.2, 57.9, 9.0, 59.2),
    "46": (4.5, 59.5, 7.8, 62.0),
    "50": (9.5, 63.0, 15.0, 65.3),
    "55": (15.5, 68.3, 20.5, 70.2),
    "56": (22.0, 69.0, 31.5, 71.2),
}


def centroid_from_rings(rings: list) -> tuple[float, float] | None:
    """Calculate centroid from ArcGIS polygon rings."""
    if not rings or not rings[0]:
        return None
    ring = rings[0]
    lons = [p[0] for p in ring if len(p) >= 2]
    lats = [p[1] for p in ring if len(p) >= 2]
    if not lats or not lons:
        return None
    return sum(lats) / len(lats), sum(lons) / len(lons)


def fetch_county(county_code: str, bbox: tuple) -> list[dict]:
    """Fetch all restriksjonsområder within a county bbox."""
    features = []
    offset = 0
    geometry = f"{bbox[0]},{bbox[1]},{bbox[2]},{bbox[3]}"

    for page in range(MAX_PAGES):
        params = {
            "f": "json",
            "where": "1=1",
            "geometry": geometry,
            "geometryType": "esriGeometryEnvelope",
            "spatialRel": "esriSpatialRelIntersects",
            "inSR": "4326",
            "outSR": "4326",
            "outFields": "vernRestriksjonId,navn,verneform,faktaark,restriksjoner,restriksjonerBeskrivelse",
            "returnGeometry": "true",
            "resultRecordCount": PAGE_SIZE,
            "resultOffset": offset,
        }
        headers = {"User-Agent": USER_AGENT}

        try:
            resp = requests.get(API_BASE, params=params, headers=headers, timeout=60)
            resp.raise_for_status()
            data = resp.json()
        except (requests.RequestException, json.JSONDecodeError) as e:
            print(f"  Error on page {page}: {e}")
            break

        if "error" in data:
            print(f"  API error: {data['error'].get('message', '')}")
            break

        page_features = data.get("features", [])
        features.extend(page_features)

        returned = len(page_features)
        exceeded = data.get("exceededTransferLimit", False)
        print(f"  Page {page}: {returned} features (total: {len(features)})")

        if not exceeded and returned < PAGE_SIZE:
            break

        offset += PAGE_SIZE
        time.sleep(REQUEST_DELAY)

    return features


def build_county_pack(county_code: str, features: list[dict]) -> dict | None:
    """Build SQLite pack from ArcGIS REST features."""
    if not features:
        return None

    pack_id = f"{THEME}-{county_code}"
    conn, db_path = create_pack_db(pack_id)

    seen_ids = set()
    count = 0

    for feature in features:
        attrs = feature.get("attributes", {})
        geom = feature.get("geometry", {})

        vr_id = attrs.get("vernRestriksjonId", "")
        if vr_id in seen_ids:
            continue
        seen_ids.add(vr_id)

        rings = geom.get("rings", [])
        centroid = centroid_from_rings(rings)
        if centroid is None:
            continue

        lat, lon = centroid

        name = attrs.get("navn") or "Restriksjonsområde"
        description = attrs.get("restriksjonerBeskrivelse") or attrs.get("restriksjoner")
        source_url = attrs.get("faktaark")

        entry_attrs = {}
        if attrs.get("verneform"):
            entry_attrs["verneform"] = attrs["verneform"]
        if attrs.get("restriksjoner"):
            entry_attrs["restriksjoner"] = attrs["restriksjoner"]

        row_id = insert_entry(
            conn,
            external_id=vr_id,
            theme=THEME,
            name=name,
            description=description,
            lat=lat,
            lon=lon,
            source=SOURCE,
            source_url=source_url,
            attributes=entry_attrs if entry_attrs else None,
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

        time.sleep(1)

    from pack_builder import OUTPUT_DIR
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    infos_path = OUTPUT_DIR / "restriksjonsomrader_packs.json"
    with open(infos_path, "w") as f:
        json.dump(pack_infos, f, indent=2, ensure_ascii=False)
    print(f"\nDone. {len(pack_infos)} packs built.")
    return pack_infos


if __name__ == "__main__":
    main()
