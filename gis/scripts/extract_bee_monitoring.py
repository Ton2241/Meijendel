#!/usr/bin/env python3
"""Extraheer de 162 gestandaardiseerde EIS-bijenbezoeken uit het rapport 2023."""

from __future__ import annotations

import argparse
import csv
import re
import subprocess
from datetime import date
from pathlib import Path


MONTHS = {"april": 4, "mei": 5, "juni": 6, "juli": 7}
YEARS = (2019, 2021, 2023)


def area_for_plot(plot_code: str) -> str:
    number = int(plot_code[1:])
    if number <= 4:
        return "Vallei Meijendel"
    if number <= 8:
        return "De Loopert"
    if number <= 13:
        return "Buitenduinen"
    return "Binnenduinen"


def parse_date_list(value: str, year: int) -> list[str]:
    result = []
    for part in value.split(","):
        match = re.fullmatch(r"\s*(\d{1,2})\s+(april|mei|juni|juli)\s*", part, re.IGNORECASE)
        if not match:
            raise ValueError(f"Onleesbare bezoekdatum voor {year}: {part!r}")
        result.append(date(year, MONTHS[match.group(2).lower()], int(match.group(1))).isoformat())
    if len(result) != 3:
        raise ValueError(f"Verwacht drie bezoeken in {year}, ontving {value!r}")
    return result


def parse_visits(text: str) -> list[tuple[str, str, str, int, int]]:
    visits = []
    for raw_line in text.splitlines():
        match = re.search(r"(M\d{2})\s{2,}(.+?)\s{2,}(.+?)\s{2,}(.+?)\s*$", raw_line)
        if not match:
            continue
        plot_code = match.group(1)
        for year, value in zip(YEARS, match.groups()[1:]):
            for sequence, visit_date in enumerate(parse_date_list(value, year), start=1):
                visits.append((plot_code, area_for_plot(plot_code), visit_date, sequence, 45))
    visits.sort(key=lambda row: (row[0], row[2]))
    return visits


def pdf_text(pdf: Path) -> str:
    result = subprocess.run(
        ["pdftotext", "-layout", "-f", "6", "-l", "6", str(pdf), "-"],
        check=True, capture_output=True, text=True,
    )
    return result.stdout


def write_csv(path: Path, visits) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(("proefvlak_code", "deelgebied", "bezoekdatum", "ronde", "duur_minuten"))
        writer.writerows(visits)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pdf", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    visits = parse_visits(pdf_text(args.pdf))
    if len(visits) != 162 or len({row[0] for row in visits}) != 18:
        raise ValueError(f"Bronprofiel wijkt af: {len(visits)} bezoeken op {len({row[0] for row in visits})} proefvlakken")
    write_csv(args.output, visits)
    print(f"OK: {len(visits)} bezoeken op 18 proefvlakken")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
