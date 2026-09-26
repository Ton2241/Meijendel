#!/usr/bin/env python3
"""Contracttest voor de bronoverstijgende analysegeschiktheidslaag."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCHEMA = ROOT / "gis" / "database" / "analysegeschiktheid_schema.sql"


def main() -> int:
    sql = SCHEMA.read_text(encoding="utf-8")
    folded = " ".join(sql.casefold().split())

    for fragment in (
        "create table if not exists analyse_type",
        "create table if not exists analyse_datareeks",
        "create table if not exists analyse_datareeks_geschiktheid",
        "create table if not exists analyse_recorduitzondering",
        "view v_analyse_catalogus",
        "view v_analyse_selectieadvies",
    ):
        assert fragment in folded, fragment

    for analysecode in ("'V'", "'I'", "'TV'", "'TA'", "'TK'"):
        assert analysecode in sql, analysecode

    for quality_dimension in (
        "datareeks_naam",
        "deelreeks_naam",
        "ruimtelijke_status",
        "bezoekstructuur_status",
        "nulwaarneming_status",
        "methode_status",
        "validatie_status",
        "beveiligingsniveau",
        "kwaliteitsmelding",
    ):
        assert quality_dimension in sql, quality_dimension

    assert "unique key uq_analyse_datareeks_sleutel (datareeks_sleutel)" in folded
    assert "unique key uq_analyse_datareeks_geschiktheid" in folded
    assert "bronrecord_sleutel" in sql
    assert "foreign key (datareeks_id)" in folded

    # De compacte adviesview mag aantallen uit verschillende besluiten niet
    # optellen alsof het unieke waarnemingen zijn.
    compact_view = folded.split(
        "create or replace sql security invoker view v_analyse_selectieadvies as", 1
    )[1]
    assert "sum(recordaantal_bij_beoordeling)" not in compact_view

    # De laag classificeert bronrecords; zij kopieert geen waarnemingsinhoud.
    for forbidden in (
        "wetenschappelijke_naam",
        "nederlandse_naam",
        "latitude",
        "longitude",
        "geometrie_wkt",
        "aantal_min",
        "aantal_max",
    ):
        assert forbidden not in sql.casefold(), forbidden

    print("OK: analysegeschiktheid-schemacontract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
