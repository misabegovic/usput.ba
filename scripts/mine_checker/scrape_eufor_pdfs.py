#!/usr/bin/env python3
"""
Download all EUFOR BiH Mine Contamination Map PDFs (MICC / BHMAC data).

Source page: https://euforbih.org/index.php/bih-minefield-maps
The sheet links (e.g. 2782-I) are <area href> tags in an HTML imagemap,
pointing to /images/infopoint/{sheet}/{sheet}-{I..IV}.pdf

Usage:
    pip install requests beautifulsoup4 lxml
    python scrape_eufor_pdfs.py [output_dir]

Downstream (per Henning-arround/BiH_mines pipeline):
    1. inkscape --export-type=svg on each PDF          (pdf_to_svg.sh)
    2. extract mine polygons from SVG vectors          (detect_elements.ipynb)
    3. simplify with mapshaper for web delivery

NOTE: These maps are periodic snapshots ("Created: 25 June 2025" as of this
writing), NOT the live BHMAC database. Record the page's creation date as
`data_as_of` in anything you build on top of this. Authoritative + daily-
updated data requires an agreement with BHMAC (033/253-800) / UNDP BiH.
"""
import random
import re
import sys
import time
from pathlib import Path

import requests
from bs4 import BeautifulSoup

BASE = "https://euforbih.org"
INDEX = f"{BASE}/index.php/bih-minefield-maps"
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36",
    "Referer": "https://www.google.com",
}
PDF_RE = re.compile(r"infopoint/.+\.pdf$", re.IGNORECASE)


def main(out_dir: Path) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    resp = requests.get(INDEX, headers=HEADERS, timeout=30)
    resp.raise_for_status()

    soup = BeautifulSoup(resp.text, "lxml")
    hrefs = sorted(
        {
            a["href"]
            for a in soup.find_all(["area", "a"], href=True)
            if PDF_RE.search(a["href"])
        }
    )
    if not hrefs:
        sys.exit("No PDF links found — page structure may have changed.")
    print(f"Found {len(hrefs)} map sheets.")

    # Try to capture the page's data date for provenance
    m = re.search(r"(Created|Kreirano):\s*([0-9]{1,2}\s+\w+\s+[0-9]{4})", resp.text)
    (out_dir / "DATA_AS_OF.txt").write_text(
        f"Source: {INDEX}\nPage date: {m.group(2) if m else 'unknown'}\n"
        f"Scraped: {time.strftime('%Y-%m-%d %H:%M:%S%z')}\n"
    )

    for i, href in enumerate(hrefs, 1):
        url = href if href.startswith("http") else f"{BASE}/{href.lstrip('/')}"
        name = url.rsplit("/", 1)[-1]
        dest = out_dir / name
        if dest.exists() and dest.stat().st_size > 0:
            print(f"[{i}/{len(hrefs)}] {name} — exists, skipping")
            continue
        r = requests.get(url, headers=HEADERS, timeout=60)
        if r.ok and r.headers.get("content-type", "").lower().startswith(
            ("application/pdf", "application/octet")
        ):
            dest.write_bytes(r.content)
            print(f"[{i}/{len(hrefs)}] {name} — {len(r.content)//1024} KB")
        else:
            print(f"[{i}/{len(hrefs)}] {name} — FAILED ({r.status_code})")
        time.sleep(random.uniform(1, 2))  # be polite

    print(f"\nDone. PDFs in {out_dir}/")


if __name__ == "__main__":
    main(Path(sys.argv[1] if len(sys.argv) > 1 else "data/pdf"))
