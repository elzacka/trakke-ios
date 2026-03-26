#!/usr/bin/env python3
"""
Upload knowledge packs to GitHub Releases.

Creates a release tagged 'knowledge-v{N}' and attaches all .sqlite packs
plus catalog.json as release assets.

Usage:
    python upload_release.py                    # Upload all packs in output/
    python upload_release.py --dry-run          # Show what would be uploaded
    python upload_release.py --tag knowledge-v2 # Custom tag

Requires: gh CLI authenticated (gh auth login)
"""

import argparse
import json
import subprocess
import sys
from pathlib import Path

OUTPUT_DIR = Path(__file__).parent / "output"
REPO = "elzacka/trakke-ios"


def get_base_url(tag: str) -> str:
    return f"https://github.com/{REPO}/releases/download/{tag}"


def find_next_tag() -> str:
    """Find the next knowledge-vN tag."""
    result = subprocess.run(
        ["gh", "release", "list", "--repo", REPO, "--limit", "50"],
        capture_output=True, text=True,
    )
    existing = []
    for line in result.stdout.strip().split("\n"):
        if line.strip():
            parts = line.split("\t")
            tag = parts[0] if parts else ""
            if tag.startswith("knowledge-v"):
                try:
                    n = int(tag.replace("knowledge-v", ""))
                    existing.append(n)
                except ValueError:
                    pass
    next_n = max(existing) + 1 if existing else 1
    return f"knowledge-v{next_n}"


def regenerate_catalog(tag: str, packs_dir: Path) -> Path:
    """Regenerate catalog.json with GitHub Release download URLs."""
    base_url = get_base_url(tag)

    # Load pack info — prefer all_packs.json (merged), fall back to individual files
    all_packs_file = packs_dir / "all_packs.json"
    if all_packs_file.exists():
        with open(all_packs_file) as f:
            all_packs = json.load(f)
    else:
        all_packs = []
        for info_file in packs_dir.glob("*_packs.json"):
            with open(info_file) as f:
                packs = json.load(f)
                all_packs.extend(packs)

    if not all_packs:
        print("No pack info files found in output/")
        sys.exit(1)

    # Deduplicate by pack id
    seen = set()
    unique_packs = []
    for p in all_packs:
        if p["id"] not in seen:
            seen.add(p["id"])
            unique_packs.append(p)
    all_packs = unique_packs

    # Set download URLs to GitHub Release assets
    for pack in all_packs:
        pack["download_url"] = f"{base_url}/{pack['id']}.sqlite"

    from datetime import datetime, timezone
    catalog = {
        "version": 1,
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "packs": all_packs,
    }

    catalog_path = packs_dir / "catalog.json"
    with open(catalog_path, "w") as f:
        json.dump(catalog, f, indent=2, ensure_ascii=False)

    print(f"Catalog regenerated with {len(all_packs)} packs -> {base_url}")
    return catalog_path


def main():
    parser = argparse.ArgumentParser(description="Upload knowledge packs to GitHub Releases")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be uploaded")
    parser.add_argument("--tag", help="Release tag (default: auto-increment)")
    args = parser.parse_args()

    # Find files to upload
    sqlite_files = sorted(OUTPUT_DIR.glob("*.sqlite"))
    if not sqlite_files:
        print(f"No .sqlite files found in {OUTPUT_DIR}")
        sys.exit(1)

    tag = args.tag or find_next_tag()
    print(f"Release tag: {tag}")
    print(f"Repo: {REPO}")
    print()

    # Regenerate catalog with correct URLs
    catalog_path = regenerate_catalog(tag, OUTPUT_DIR)

    # List all files
    files_to_upload = sqlite_files + [catalog_path]
    total_size = sum(f.stat().st_size for f in files_to_upload)

    print(f"\nFiles to upload ({total_size / 1024 / 1024:.1f} MB total):")
    for f in files_to_upload:
        size_kb = f.stat().st_size / 1024
        print(f"  {f.name} ({size_kb:.0f} KB)")

    if args.dry_run:
        print("\n[dry-run] Would create release and upload files.")
        print(f"Catalog URL: {get_base_url(tag)}/catalog.json")
        return

    print(f"\nCreating release {tag}...")

    # Build release notes
    pack_count = len(sqlite_files)
    entry_counts = []
    for info_file in OUTPUT_DIR.glob("*_packs.json"):
        with open(info_file) as f:
            for p in json.load(f):
                entry_counts.append(p.get("entry_count", 0))
    total_entries = sum(entry_counts)

    notes = f"Knowledge packs for Trakke iOS.\n\n"
    notes += f"- {pack_count} packs\n"
    notes += f"- {total_entries:,} total entries\n"
    notes += f"- {total_size / 1024 / 1024:.1f} MB total\n\n"
    notes += "Themes: kulturminnerLokaliteter, kulturmiljoer, naturvernomrader, restriksjonsomraderNaturvern, friluftslivsomrader, arterNasjonal\n\n"
    notes += f"Catalog URL: `{get_base_url(tag)}/catalog.json`"

    # Create release
    create_cmd = [
        "gh", "release", "create", tag,
        "--repo", REPO,
        "--title", f"Knowledge Packs {tag}",
        "--notes", notes,
        "--prerelease",
    ]

    result = subprocess.run(create_cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Error creating release: {result.stderr}")
        sys.exit(1)
    print(f"Release created: {result.stdout.strip()}")

    # Upload assets
    for f in files_to_upload:
        print(f"  Uploading {f.name}...")
        upload_cmd = [
            "gh", "release", "upload", tag,
            str(f),
            "--repo", REPO,
            "--clobber",
        ]
        result = subprocess.run(upload_cmd, capture_output=True, text=True)
        if result.returncode != 0:
            print(f"  Error: {result.stderr}")
        else:
            print(f"  Done.")

    print(f"\nRelease URL: https://github.com/{REPO}/releases/tag/{tag}")
    print(f"Catalog URL: {get_base_url(tag)}/catalog.json")


if __name__ == "__main__":
    main()
