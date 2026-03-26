#!/usr/bin/env python3
"""
Main pipeline script: fetches all data sources and generates catalog.json.

Usage:
    # Build all themes for all counties
    python build_all.py

    # Build all themes for specific counties
    python build_all.py --counties 46 11

    # Build specific themes only
    python build_all.py --themes kulturminner naturvernomrader

    # Build for a single county (fast test)
    python build_all.py --counties 46 --themes kulturminner

    # Custom R2 base URL
    python build_all.py --base-url https://r2.tazk.no/trakke/knowledge/packs
"""

import argparse
import json
import sys
from pathlib import Path

from pack_builder import OUTPUT_DIR, generate_catalog, save_catalog

# Base URL where packs will be hosted on Cloudflare R2
DEFAULT_BASE_URL = "https://r2.tazk.no/trakke/knowledge/packs"


def main():
    parser = argparse.ArgumentParser(description="Build Trakke knowledge packs")
    parser.add_argument("--counties", nargs="+", help="County codes to process (default: all)")
    parser.add_argument("--themes", nargs="+", help="Themes to build (default: all Phase 1)")
    parser.add_argument("--base-url", default=DEFAULT_BASE_URL, help="R2 base URL for downloads")
    args = parser.parse_args()

    available_themes = {
        "kulturminner": "fetch_kulturminner",
        "kulturmiljoer": "fetch_kulturmiljoer",
        "naturvernomrader": "fetch_naturvernomrader",
        "restriksjonsomrader": "fetch_restriksjonsomrader",
        "friluftslivsomrader": "fetch_friluftslivsomrader",
        "arter_nasjonal": "fetch_arter_nasjonal",
    }

    themes = args.themes if args.themes else list(available_themes.keys())
    county_args = args.counties or []

    all_pack_infos = []

    for theme in themes:
        if theme not in available_themes:
            print(f"Unknown theme: {theme}. Available: {', '.join(available_themes.keys())}")
            continue

        module_name = available_themes[theme]
        print(f"\n{'='*60}")
        print(f"Building theme: {theme}")
        print(f"{'='*60}")

        # Import and run the fetcher module
        try:
            module = __import__(module_name)
            # Override sys.argv for the sub-module
            old_argv = sys.argv
            sys.argv = [module_name] + county_args
            pack_infos = module.main()
            sys.argv = old_argv
            all_pack_infos.extend(pack_infos)
        except Exception as e:
            print(f"Error building {theme}: {e}")
            import traceback
            traceback.print_exc()
            continue

    if not all_pack_infos:
        print("\nNo packs were built. Check API availability.")
        return

    # Generate catalog
    print(f"\n{'='*60}")
    print(f"Generating catalog ({len(all_pack_infos)} packs)")
    print(f"{'='*60}")

    catalog = generate_catalog(all_pack_infos, args.base_url)
    save_catalog(catalog)

    # Print summary
    total_size = sum(p["file_size"] for p in all_pack_infos)
    total_entries = sum(p["entry_count"] for p in all_pack_infos)
    print(f"\nSummary:")
    print(f"  Packs: {len(all_pack_infos)}")
    print(f"  Total entries: {total_entries:,}")
    print(f"  Total size: {total_size / 1024 / 1024:.1f} MB")
    print(f"  Output: {OUTPUT_DIR}")

    # List files
    print(f"\nFiles:")
    for f in sorted(OUTPUT_DIR.iterdir()):
        size_kb = f.stat().st_size / 1024
        print(f"  {f.name} ({size_kb:.0f} KB)")


if __name__ == "__main__":
    main()
