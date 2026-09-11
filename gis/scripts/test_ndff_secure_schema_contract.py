#!/usr/bin/env python3
"""Contracttest voor het lokale beveiligde NDFF-schema."""

from pathlib import Path


SCHEMA = Path(__file__).parents[1] / "database" / "ndff_secure_schema.sql"


def view_body(sql: str, name: str) -> str:
    marker = f"CREATE OR REPLACE VIEW {name} AS"
    start = sql.index(marker) + len(marker)
    end = sql.find(";", start)
    return sql[start:end].casefold()


def main() -> int:
    sql = SCHEMA.read_text(encoding="utf-8")
    folded = sql.casefold()
    for column in (
        "toewijzingskwaliteit",
        "protocol_auditklasse",
        "verspreidingscontext_status",
        "trend_status",
        "analyse_poort_versie",
        "is_pq_bronrecord",
        "ndff_bronrol",
        "primaire_pq_bron",
    ):
        assert column in folded, f"statuskolom ontbreekt: {column}"

    views = (
        "v_ndff_lokale_overzicht",
        "v_ndff_lokale_plot_jaar_taxon",
        "v_ndff_lokale_protocolstatus",
    )
    forbidden = (
        "exacte_geometrie",
        "centrum_x",
        "centrum_y",
        "ndff_identity",
        "open_identity",
        "raw_payload",
        "periode_start",
        "periode_stop",
    )
    for view in views:
        body = view_body(sql, view)
        assert "count(" in body, f"{view} bevat geen aggregatie"
        for field in forbidden:
            assert field not in body, f"{view} lekt gevoelig veld {field}"

    plot_view = view_body(sql, "v_ndff_lokale_plot_jaar_taxon")
    assert "single_volledig_binnen" in plot_view
    assert "kandidaat_verspreidingscontext" in plot_view
    assert "('onafhankelijk','niet_van_toepassing')" in plot_view.replace(" ", "")
    assert "is_pq_bronrecord = 0" in plot_view
    assert "positieve_waarnemingen" in plot_view
    assert "nulwaarneming" not in plot_view
    assert "trendklaar" not in plot_view

    canonical = view_body(sql, "v_ndff_canonieke_waarneming")
    for required in (
        "canonieke_identiteit_sha256",
        "secure_vervangt_open",
        "alleen_openbaar",
        "alleen_beveiligd",
        "union all",
        "exacte_geometrie",
        "openbare_geometrie",
        "open_identity_sha256",
    ):
        assert required in canonical, f"canonieke view mist {required}"
    assert "raw_payload" not in canonical
    assert "ndff_identity" not in canonical
    print("OK: NDFF secure schemacontract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
