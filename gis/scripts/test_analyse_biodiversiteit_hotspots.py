#!/usr/bin/env python3
"""Gerichte regressietests voor de biodiversiteit-hotspotanalyse."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import tempfile


SCRIPT = Path(__file__).with_name("analyse_biodiversiteit_hotspots.py")


def load_module():
    spec = importlib.util.spec_from_file_location("hotspots", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_periodisering_sluit_oude_startdata_en_2026_uit():
    module = load_module()
    assert module.assign_period(1949) is None
    assert module.assign_period(1950) == "1950-1969"
    assert module.assign_period(1969) == "1950-1969"
    assert module.assign_period(1970) == "1970-1989"
    assert module.assign_period(2005) == "2005-2014"
    assert module.assign_period(2025) == "2015-2025"
    assert module.assign_period(2026) is None


def test_percentielrang_behandelt_gelijke_waarden_gelijk():
    module = load_module()
    ranks = module.percentile_ranks({"A": 10.0, "B": 20.0, "C": 20.0, "D": 40.0})
    assert ranks == {"A": 0.0, "B": 0.5, "C": 0.5, "D": 1.0}


def test_meerbronnenklasse_vergt_twee_geldige_hoge_lagen():
    module = load_module()
    assert module.classify_multisource_signal(
        bird_rank=0.90,
        bird_years=8,
        pq_rank=0.80,
        pq_years=3,
        ndff_rank=0.20,
        ndff_records=100,
        ndff_years=5,
    ) == "meerdere_bronnen_hoog"
    assert module.classify_multisource_signal(
        bird_rank=0.90,
        bird_years=8,
        pq_rank=0.20,
        pq_years=2,
        ndff_rank=0.90,
        ndff_records=3,
        ndff_years=1,
    ) == "een_bron_hoog"
    assert module.classify_multisource_signal(
        bird_rank=None,
        bird_years=0,
        pq_rank=None,
        pq_years=0,
        ndff_rank=0.90,
        ndff_records=100,
        ndff_years=5,
    ) == "onvoldoende_meerbronnendekking"


def test_lage_ndff_registratie_wordt_nooit_soortenarm_genoemd():
    module = load_module()
    label = module.classify_multisource_signal(
        bird_rank=0.20,
        bird_years=8,
        pq_rank=0.20,
        pq_years=3,
        ndff_rank=0.05,
        ndff_records=50,
        ndff_years=4,
    )
    assert label == "geen_meerbronnen_hotspotsignaal"
    assert "soortenarm" not in label


def test_rapportdataset_bevat_geen_beveiligde_detailvelden():
    module = load_module()
    safe = module.safe_report_row(
        {
            "plot_id": 3511,
            "plotnaam": "Kavel 1",
            "periode": "2015-2025",
            "ndff_taxa": 12,
            "ndff_records": 44,
            "ndff_identity": "verboden",
            "exacte_geometrie": "verboden",
            "wetenschappelijke_naam": "verboden",
        }
    )
    assert safe == {
        "plot_id": 3511,
        "plotnaam": "Kavel 1",
        "periode": "2015-2025",
        "ndff_taxa": 12,
        "ndff_records": 44,
    }


def test_uitvoerpad_moet_in_beveiligde_t7_zone_staan():
    module = load_module()
    module.assert_secure_output_path(
        Path("/Volumes/T7 Data/Home_Ton/Meijendel data/NDFF/secure/ticket_58679/derived/hotspots")
    )
    with tempfile.TemporaryDirectory() as temporary_directory:
        try:
            module.assert_secure_output_path(Path(temporary_directory))
        except ValueError as exc:
            assert "beveiligde NDFF-afleidingsmap" in str(exc)
        else:
            raise AssertionError("Een onveilig uitvoerpad werd ten onrechte geaccepteerd")


def test_data_app_snapshot_bevat_alleen_geaggregeerde_queries():
    module = load_module()
    result = {
        "created_utc": "2026-09-10T12:00:00+00:00",
        "period_summary": [{"periode": "2015-2025", "multi_high": 6}],
        "plot_period": [{"plot_id": 3511, "plotnaam": "Kavel 1", "periode": "2015-2025"}],
        "change": [{"plot_id": 3511, "plotnaam": "Kavel 1", "bird_richness_delta": 1.2}],
    }
    snapshot = module.build_reviewed_snapshot(result)
    assert snapshot["surface"] == "report"
    assert snapshot["buildStatus"] == "creating"
    assert set(snapshot["queries"]) == {"period_summary", "plot_period", "change"}
    encoded = str(snapshot)
    assert "exacte_geometrie" not in encoded
    assert "ndff_identity" not in encoded


if __name__ == "__main__":
    test_periodisering_sluit_oude_startdata_en_2026_uit()
    test_percentielrang_behandelt_gelijke_waarden_gelijk()
    test_meerbronnenklasse_vergt_twee_geldige_hoge_lagen()
    test_lage_ndff_registratie_wordt_nooit_soortenarm_genoemd()
    test_rapportdataset_bevat_geen_beveiligde_detailvelden()
    test_uitvoerpad_moet_in_beveiligde_t7_zone_staan()
    test_data_app_snapshot_bevat_alleen_geaggregeerde_queries()
    print("OK: biodiversiteit-hotspotanalyse")
