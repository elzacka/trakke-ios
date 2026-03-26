#!/usr/bin/env python3
"""
Fetch arter av nasjonal forvaltningsinteresse from Miljødirektoratet ArcGIS REST.

Combines two focused layers:
- Layer 3: Prioriterte_arter_pkt (~24k nationally) — priority species
- Layer 5: Fredete_arter_pkt (~19k nationally) — protected species

These are the most relevant for outdoor users (legal protection implications).
The full "alle arter" layer (800k+) is too large for mobile packs.

API base: https://kart.miljodirektoratet.no/arcgis/rest/services/artnasjonal2/MapServer/
Format: ArcGIS REST JSON (point features)
License: NLOD 2.0

Produces one SQLite pack per county: arterNasjonal-{county_code}.sqlite
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

API_PRIORITERTE = "https://kart.miljodirektoratet.no/arcgis/rest/services/artnasjonal2/MapServer/3/query"
API_FREDETE = "https://kart.miljodirektoratet.no/arcgis/rest/services/artnasjonal2/MapServer/5/query"
PAGE_SIZE = 200
MAX_PAGES = 100
USER_AGENT = "Trakke-DataPipeline/1.0 hei@tazk.no"
REQUEST_DELAY = 0.5

THEME = "arterNasjonal"
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


def fetch_from_layer(api_url: str, county_code: str, bbox: tuple, label: str) -> list[dict]:
    """Fetch all species records from a specific layer within a county bbox."""
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
            "outFields": "ArtNasjonalId,VitenskapeligNavn,NorskNavn,Kommune,Forvaltningskategori,Gruppe,Status,Faktaark,AntallObservasjoner,Krit_Kombinert",
            "returnGeometry": "true",
            "resultRecordCount": PAGE_SIZE,
            "resultOffset": offset,
        }
        headers = {"User-Agent": USER_AGENT}

        try:
            resp = requests.get(api_url, params=params, headers=headers, timeout=60)
            resp.raise_for_status()
            data = resp.json()
        except (requests.RequestException, json.JSONDecodeError) as e:
            print(f"  {label} error on page {page}: {e}")
            break

        if "error" in data:
            print(f"  {label} API error: {data['error'].get('message', '')}")
            break

        page_features = data.get("features", [])
        features.extend(page_features)

        returned = len(page_features)
        exceeded = data.get("exceededTransferLimit", False)

        if not exceeded and returned < PAGE_SIZE:
            break

        offset += PAGE_SIZE
        time.sleep(REQUEST_DELAY)

    return features


def build_county_pack(county_code: str, features: list[dict]) -> dict | None:
    """Build SQLite pack from combined species features."""
    if not features:
        return None

    pack_id = f"{THEME}-{county_code}"
    conn, db_path = create_pack_db(pack_id)

    seen_ids = set()
    count = 0

    for feature in features:
        attrs = feature.get("attributes", {})
        geom = feature.get("geometry") or {}

        art_id = attrs.get("ArtNasjonalId", "")
        if art_id in seen_ids:
            continue
        seen_ids.add(art_id)

        lon = geom.get("x")
        lat = geom.get("y")
        if lon is None or lat is None:
            continue

        norsk_navn = attrs.get("NorskNavn") or ""
        vit_navn = attrs.get("VitenskapeligNavn") or ""
        name = norsk_navn or vit_navn or "Ukjent art"

        # Description: scientific name + category
        parts = []
        if norsk_navn and vit_navn:
            parts.append(vit_navn)
        kategori = attrs.get("Krit_Kombinert") or ""
        if kategori:
            parts.append(kategori.capitalize())
        description = ". ".join(parts) if parts else None

        source_url = attrs.get("Faktaark")

        entry_attrs = {}
        if vit_navn:
            entry_attrs["vitenskapelig_navn"] = vit_navn
        if attrs.get("Gruppe"):
            entry_attrs["gruppe"] = attrs["Gruppe"]
        if attrs.get("Status"):
            entry_attrs["rodlistestatus"] = attrs["Status"]
        if attrs.get("Forvaltningskategori"):
            entry_attrs["forvaltningskategori"] = attrs["Forvaltningskategori"]
        if attrs.get("AntallObservasjoner"):
            entry_attrs["antall_observasjoner"] = str(attrs["AntallObservasjoner"])

        row_id = insert_entry(
            conn,
            external_id=art_id,
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

        # Fetch from both layers
        prioriterte = fetch_from_layer(API_PRIORITERTE, code, bbox, "prioriterte")
        print(f"  Prioriterte arter: {len(prioriterte)}")

        fredete = fetch_from_layer(API_FREDETE, code, bbox, "fredete")
        print(f"  Fredete arter: {len(fredete)}")

        all_features = prioriterte + fredete
        if all_features:
            info = build_county_pack(code, all_features)
            if info:
                pack_infos.append(info)
        else:
            print(f"  No features found")

        time.sleep(1)

    from pack_builder import OUTPUT_DIR
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    infos_path = OUTPUT_DIR / "arter_nasjonal_packs.json"
    with open(infos_path, "w") as f:
        json.dump(pack_infos, f, indent=2, ensure_ascii=False)
    print(f"\nDone. {len(pack_infos)} packs built.")
    return pack_infos


if __name__ == "__main__":
    main()
