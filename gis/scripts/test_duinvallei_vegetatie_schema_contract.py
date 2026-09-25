#!/usr/bin/env python3
"""Contracttest voor de openbare duinvalleivegetatietabellen."""

from pathlib import Path


SCHEMA = Path(__file__).parents[1] / "database" / "duinvallei_vegetatie_schema.sql"


def main() -> int:
    sql = SCHEMA.read_text(encoding="utf-8")
    folded = " ".join(sql.casefold().split())
    assert "use meijendel" in folded
    assert "pq_vegetatie" not in folded
    for table in (
        "duinvallei_import_batch",
        "duinvallei_plot",
        "duinvallei_opname",
        "duinvallei_taxon",
        "duinvallei_bedekkingscode",
        "duinvallei_bedekking",
        "duinvallei_bodemparameter",
        "duinvallei_bodemmeting",
    ):
        assert f"create table if not exists {table}" in folded, table
    for view in (
        "v_duinvallei_analyse_opname",
        "v_duinvallei_analyse_bedekking",
    ):
        assert f"create or replace view {view}" in folded, view
    assert "uitgesloten_bronanomalie" in folded
    assert "bronbestand_sha256" in folded
    assert "foreign key (bedekkingscode) references duinvallei_bedekkingscode" in folded
    assert "where o.analyse_status = 'toegelaten'" in folded
    assert "meijendel_soort_id" not in folded
    assert "taxon_koppeling_status" not in folded
    assert "references soorten" not in folded
    print("OK: duinvalleivegetatie-schemacontract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
