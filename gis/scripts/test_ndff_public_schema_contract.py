#!/usr/bin/env python3
"""Contracttest voor openbare FFV- en GBIF-brontabellen in Meijendel."""

from pathlib import Path


SCHEMA = Path(__file__).parents[1] / "database" / "ndff_public_schema.sql"


def main() -> int:
    sql = SCHEMA.read_text(encoding="utf-8")
    folded = " ".join(sql.casefold().split())
    assert "use meijendel" in folded
    assert "use meijendel_ndff_secure" not in folded

    required_tables = (
        "ndff_open_import_batch",
        "ndff_soorten",
        "ndff_open_waarneming",
        "ndff_open_leveringsverrijking",
        "ndff_open_soortgroep_koppeling",
        "ndff_sovon_plotversie",
        "ndff_sovon_plot",
        "vangblik_import_batch",
        "vangblik_locatieversie",
        "vangblik_event",
        "vangblik_soorten",
        "vangblik_vangst",
        "vangblik_event_plot",
    )
    for table in required_tables:
        assert f"create table if not exists {table}" in folded, table

    assert "analyse_status enum('bronregistratie_niet_toegelaten'" in folded
    assert "geen_harde_nul" in folded
    assert "is_verplaatst_blok_7_18" in folded
    assert "is_vergelijkingsblik_1959" in folded
    assert "heeft_predatie_of_zoogdierrisico" in folded
    assert "is_verweesd" in folded
    assert "referentieel_geldig" in folded
    assert "cc by-nc 4.0" in folded
    assert "foreign key (plot_id) references plots (plot_id)" in folded
    for field in (
        "leveringsregel_id",
        "obs_uri",
        "obs_uri_sha256",
        "dataeigenaar_uri",
        "kwaliteitsstatus_raw",
        "aantal_min",
        "aantal_max",
        "eenheid_raw",
        "locatie_type_raw",
        "zoid_raw",
        "sessionid_raw",
        "datumdekking_raw",
        "oppervlaktedekking_raw",
        "leveringsgeometrie_gelijk_aan_openbaar",
        "leveringsperiode_gelijk_aan_openbaar",
        "bronrecord_sha256",
    ):
        assert field in folded, field
    for forbidden in (
        "exacte_geometrie geometry",
        "bron_centrum_x_rd",
        "bron_centrum_y_rd",
        "centrumx",
        "centrumy",
    ):
        assert forbidden not in folded, f"openbare verrijking bevat gevoelig veld {forbidden}"
    assert "unique key uq_ndff_open_verrijking_obs_uri (obs_uri_sha256)" in folded
    assert "unique key uq_ndff_open_verrijking_obs_uri (obs_uri)" not in folded

    for group_table in (
        "ndff_amfibieen",
        "ndff_kevers",
        "ndff_vaatplanten",
        "ndff_zoogdieren_overig",
    ):
        assert f"create table if not exists {group_table}" in folded, group_table

    print("OK: openbaar NDFF/GBIF-schemacontract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
