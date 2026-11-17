#!/usr/bin/env python3
"""Controleer de primaire jaarlevering tegen de reeds geolokaliseerde selectie."""

from __future__ import annotations

import importlib.util
from pathlib import Path
from types import SimpleNamespace


SCRIPT = Path(__file__).with_name("import_vlinderstichting_tellingen.py")
SOURCE = Path("/Volumes/T7 Data/Home_Ton/Meijendel data/Vlinderstichting")


def load_module():
    spec = importlib.util.spec_from_file_location("vlinderstichting_tellingen", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> None:
    module = load_module()
    day = {
        393: "Parnassiapad Meijendel", 635: "Kijfhoekhoogte (Meijendel)",
        638: "Hertenkamp (Meijendel)", 640: "Helmduinen (Meijendel)",
        929: "Scheepje - Meijendel", 1149: "Violenwater Meijendel",
        4439: "Bierlap, groot dikkopje", 4410: "De Klip",
        4588: "Vallei Meijendel", 4615: "Sprang A. Meijendel",
        5169: "Vallei Meijendel Eikenpage",
    }
    libel = {
        1: "De Hertenkamp, bospoel", 2: "De Hertenkamp, poel",
        3: "De Hertenkamp, plas", 4: "De Klip, poel",
        5: "De Klip, kranswierpoel", 6: "De Klip, plas",
        7: "Meijendel - Helmduinen", 8: "Meijendel - Kikkerberg",
        9: "Meijendel - Parnassiapad", 10: "De Klip, Poel nieuw",
        11: "Meijendel Kikkervallei",
    }
    rows = module.build_rows(SOURCE, day, libel)
    assert len(rows.day_years) == 195
    assert len(rows.day_species_years) == 7409
    assert len(rows.libel_years) == 69
    assert sum(r["bezoekaantal"] for r in rows.day_years) == 3020
    assert sum(r["bezoekaantal"] for r in rows.libel_years) == 628
    assert sum(r["jaarcijfer"] == 0 for r in rows.day_species_years) == 2710
    assert sum(r["jaar"] == 2026 for r in rows.day_species_years) == 148
    assert len(rows.code_names) == 56
    assert len(set(rows.code_names.values())) == 35
    assert all(r["jaarstatus"] == "voorlopig" for r in rows.day_years if r["jaar"] == 2026)
    assert all(r["jaarstatus"] == "voorlopig" for r in rows.libel_years if r["jaar"] == 2026)
    assert all(r["ruw_totaal"] >= 0 for r in rows.day_years)
    assert all("ruw_totaal" not in r for r in rows.libel_years)
    assert not any(r["bron_code"] == 230 for r in rows.day_years)
    assert all((r["bron_code"], r["jaar"]) in
               {(y["bron_code"], y["jaar"]) for y in rows.day_years}
               for r in rows.day_species_years)

    less = module.build_rows(SOURCE, {393: day[393]}, {1: libel[1]})
    assert {r["bron_code"] for r in less.day_species_years} == {393}
    assert {r["telobject_id"] for r in less.libel_years} == {1}
    # SQL houdt de oorspronkelijke code als sleuteldeel, ook bij dezelfde naam.
    targets = {code: {'taxon_id': 1000 + int(code), 'wetenschappelijke_naam': name}
               for code, name in rows.code_names.items() if code != '66'}
    sql = module.import_sql(rows, day, libel,
                            SimpleNamespace(targets=targets,
                                            new_taxon={'weergavenaam': 'Grote weerschijnvlinder'}))
    assert 'CREATE TEMPORARY TABLE tove_soortjaar_plan' in sql
    assert "'kandidaat','onbekend'" in sql
    assert 'COALESCE(p.taxon_id,@tove_apatura_id)' in sql
    # MySQL mag dezelfde TEMP-tabel niet in hoofdselect en subquery heropenen.
    assert 'SELECT COUNT(*)=55 FROM tove_code_plan p JOIN taxa t' in sql
    assert 'SELECT COUNT(*) FROM tove_code_plan WHERE taxon_id IS NOT NULL' not in sql
    assert 'FROM tove_soortjaar_plan s JOIN taxa_bronkoppeling b' in sql
    assert 'INSERT INTO libellen_routejaar (telobject_id,jaar,bezoekaantal,jaarstatus,levering_id)' in sql
    assert 'INSERT INTO libellen_routejaar (telobject_id,jaar,bezoekaantal,ruw_totaal' not in sql
    assert "COUNT(*)=7409 FROM vlinders_dag_routejaar_soortcode" in sql
    assert "SUM(jaarcijfer=0)=2710" in sql
    assert sql.rstrip().endswith("SELECT 'tove-import',COUNT(*) FROM vlinders_dag_routejaar_soortcode;")
    print("OK: alleen geolokaliseerde Tove-telobjecten, bronnullen en 2026-status behouden")


if __name__ == "__main__":
    main()
