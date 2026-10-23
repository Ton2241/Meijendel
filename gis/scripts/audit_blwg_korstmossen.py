"""Compare BLWG source forms with NDFF 02.202 without exposing sensitive sites.

Usage: python audit_blwg_korstmossen.py source.xlsx
The live MySQL connection uses the existing local `meijendel_root` login path.
"""

from __future__ import annotations

import argparse
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path
import subprocess

from openpyxl import load_workbook


ALIASES = {
    "Bacidia caligans": "Bacidina caligans",
    "Leptogium gelatinosum": "Scytinium gelatinosum",
    "Leptogium pulvinatum": "Scytinium pulvinatum",
}


def query(sql: str) -> list[list[str]]:
    proc = subprocess.run(
        ["/usr/local/mysql/bin/mysql", "--no-defaults", "--login-path=meijendel_root",
         "--batch", "--skip-column-names", "-e", sql],
        check=True, capture_output=True, text=True,
    )
    return [line.split("\t") for line in proc.stdout.splitlines()]


def rows(sheet):
    it = sheet.values
    next(it)
    return list(it)


def main(path: Path) -> None:
    workbook = load_workbook(path, read_only=True, data_only=True)
    plots = {int(r[0]): r for r in rows(workbook["Plotgegevens"])}
    forms = {int(r[5]): r for r in rows(workbook["Bezoekgegevens"])}
    source = rows(workbook["Waarnemingen"])
    locations = query("SELECT meetlocatie_id,centrum_x_rd,centrum_y_rd "
                      "FROM Meijendel.korstmossen_meetlocatie "
                      "WHERE reconstructieversie='ndff-korstmos-v2'")
    by_plot = {}
    for plot_id, plot in plots.items():
        x, y = float(plot[4]), float(plot[5])
        ordered = sorted(
            ((float(l[1])-x)**2 + (float(l[2])-y)**2, int(l[0]))
            for l in locations
        )
        if ordered[0][0] > 10000 or (len(ordered) > 1 and ordered[0][0] == ordered[1][0]):
            raise ValueError(f"BLWG plot {plot_id}: no unique NDFF site within 100 m")
        by_plot[plot_id] = ordered[0][1]
    if len(set(by_plot.values())) != len(by_plot):
        raise ValueError("Several BLWG plots map to the same NDFF site")

    source_keys = Counter()
    source_ids = defaultdict(list)
    sensitive = Counter()
    sensitive_plot_year = Counter()
    for plot_id, date, name, quantity, note, kopid in source:
        form = forms[int(kopid)]
        if int(form[0]) != int(plot_id) or form[1].date() != date.date():
            raise ValueError(f"Form {kopid} does not match its observation")
        canonical = ALIASES.get(name, name)
        if canonical == "Usnea articulata":
            sensitive[date.year] += 1
            sensitive_plot_year[(int(plot_id), date.year)] += 1
            continue
        key = (by_plot[int(plot_id)], date.date().isoformat(), canonical)
        source_keys[key] += 1
        source_ids[key].append(int(kopid))

    public = query("SELECT s.meetlocatie_id,DATE(o.periode_start),"
                   "o.wetenschappelijke_naam,o.waarneming_id "
                   "FROM Meijendel.korstmossen_recordselectie s "
                   "JOIN Meijendel.ndff_open_waarneming o "
                   "ON o.waarneming_id=s.waarneming_id "
                   "WHERE s.reconstructieversie='ndff-korstmos-v2'")
    ndff_keys = Counter((int(r[0]), r[1], r[2]) for r in public)
    missing = source_keys - ndff_keys
    extra = ndff_keys - source_keys
    ndff_sensitive = query("SELECT jaar,COUNT(*) FROM Meijendel.ndff_open_waarneming "
                           "WHERE protocol LIKE '02.202%' AND vervaagd=1 "
                           "GROUP BY jaar ORDER BY jaar")
    blurred_by_year = Counter({int(y): int(n) for y, n in ndff_sensitive})
    secure = query("SELECT jaar,bron_centrum_x_rd,bron_centrum_y_rd "
                   "FROM Meijendel_ndff_secure.ndff_waarneming_register "
                   "WHERE protocol LIKE '02.202%'")
    secure_plot_year = Counter()
    secure_unplaced = 0
    for year, x, y in secure:
        candidates = sorted(((float(plot[4])-float(x))**2 + (float(plot[5])-float(y))**2,
                             plot_id) for plot_id, plot in plots.items())
        if candidates[0][0] > 10000:
            secure_unplaced += 1
        else:
            secure_plot_year[(candidates[0][1], int(year))] += 1
    ambiguous = sum(n for n in source_keys.values() if n > 1)
    fixed_forms = [f for f in forms.values() if int(f[0]) in (14, 15, 16, 17)]
    oneoff_forms = [f for f in forms.values() if int(f[0]) not in (14, 15, 16, 17)]
    print(f"source_rows={len(source)} source_forms={len(forms)} source_plots={len(plots)}")
    print(f"public_source_rows={sum(source_keys.values())} ndff_public_rows={len(public)}")
    print(f"public_multiset_missing={sum(missing.values())} public_multiset_extra={sum(extra.values())}")
    print(f"duplicate_key_rows_observer_identity_not_recoverable={ambiguous}")
    print(f"sensitive_source={sum(sensitive.values())} sensitive_ndff={sum(blurred_by_year.values())}")
    print(f"sensitive_count_by_year_equal={sensitive == blurred_by_year}")
    print(f"sensitive_plot_year_count_equal={sensitive_plot_year == secure_plot_year} "
          f"secure_unplaced={secure_unplaced}")
    print(f"fixed_forms={len(fixed_forms)} oneoff_forms={len(oneoff_forms)}")
    if missing:
        print("missing_keys", sorted(missing.items()))
    if extra:
        print("extra_keys", sorted(extra.items()))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    main(parser.parse_args().source)
