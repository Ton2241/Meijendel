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

    analysis = view_body(sql, "v_ndff_analyse_record")
    for required in (
        "protocol_sleutel",
        "doelrelatie_record",
        "protocol_kandidaattypen",
        "ruimtelijk_toelaatbaar",
        "pq_status",
        "snl_overlap_status",
        "record_selectiestatus",
        "gegevensgeschiktheid",
        "kwaliteitsmelding",
        "ndff_open_pq_koppeling",
        "ndff_snl_waarneming_context",
        "ndff_analysebesluit",
    ):
        assert required in analysis, f"analyseview mist {required}"
    for forbidden_field in (
        "analyse_geometrie",
        "exacte_geometrie",
        "openbare_geometrie",
        "periode_start",
        "periode_stop",
        "raw_payload",
        "ndff_identity",
    ):
        assert forbidden_field not in analysis, f"analyseview lekt {forbidden_field}"

    verspreiding = view_body(sql, "v_ndff_verspreiding_plot_jaar_taxon")
    for required in (
        "v_ndff_analyse_record",
        "record_selectiestatus = 'voorlopig_bruikbaar'",
        "find_in_set('v',protocol_kandidaattypen)",
        "aanwezig",
        "bronrecords_ter_controle",
        "protocol_sleutels",
        "kwaliteitsmelding",
        "group by",
    ):
        assert required.replace(" ", "") in verspreiding.replace(" ", ""), (
            f"verspreidingsview mist {required}"
        )

    trend = view_body(sql, "v_ndff_trendkandidaat_plot_jaar_taxon")
    for required in (
        "v_ndff_analyse_record",
        "record_selectiestatus = 'voorlopig_bruikbaar'",
        "kandidaat_i",
        "kandidaat_tv",
        "kandidaat_ta",
        "kandidaat_tk",
        "gegevensgeschiktheid",
        "bronrecords_ter_controle",
        "kwaliteitsmelding",
        "group by",
    ):
        assert required in trend, f"trendkandidaatview mist {required}"
    assert "find_in_set('i',protocol_kandidaattypen)" in trend.replace(" ", "")
    for safe_view in (verspreiding, trend):
        for forbidden_field in (
            "canonieke_identiteit_sha256",
            "open_waarneming_id",
            "secure_waarneming_id",
            "exacte_geometrie",
            "analyse_geometrie",
            "periode_start",
            "periode_stop",
            "raw_payload",
            "ndff_identity",
        ):
            assert forbidden_field not in safe_view, (
                f"veilige analyseview lekt {forbidden_field}"
            )
    print("OK: NDFF secure schemacontract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
