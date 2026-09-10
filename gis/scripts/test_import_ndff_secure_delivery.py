#!/usr/bin/env python3
"""Gerichte test voor de beveiligde NDFF-importvoorbereiding."""

from __future__ import annotations

import csv
import importlib.util
import json
import tempfile
from pathlib import Path

from osgeo import ogr, osr


SCRIPT = Path(__file__).with_name("import_ndff_secure_delivery.py")


def load_module():
    spec = importlib.util.spec_from_file_location("ndff_import", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def write_csv(path: Path, rows: list[dict[str, object]]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def write_gpkg(path: Path) -> None:
    driver = ogr.GetDriverByName("GPKG")
    dataset = driver.CreateDataSource(str(path))
    srs = osr.SpatialReference()
    srs.ImportFromEPSG(28992)
    layer = dataset.CreateLayer("ndff_mwl_z58679_Meijendel", srs, ogr.wkbPolygon)
    for name, field_type in (
        ("obs_uri", ogr.OFTString), ("soort_ned", ogr.OFTString),
        ("soort_wet", ogr.OFTString), ("srtgroepen", ogr.OFTString),
        ("datm_start", ogr.OFTString), ("datm_stop", ogr.OFTString),
        ("protocol", ogr.OFTString), ("dataeigenr", ogr.OFTString),
        ("kwliteit", ogr.OFTString), ("loc_type", ogr.OFTString),
        ("vervaagd", ogr.OFTString), ("area_m2", ogr.OFTReal),
        ("centrumx", ogr.OFTInteger), ("centrumy", ogr.OFTInteger),
        ("orig_aant", ogr.OFTString), ("telondrwrp", ogr.OFTString),
        ("telmethode", ogr.OFTString),
    ):
        layer.CreateField(ogr.FieldDefn(name, field_type))
    specs = (
        (1, "Taxon alpha", "Losse waarnemingen", "waarneming.nl"),
        (2, "Taxon beta", "12.007 Vegetatieopnamen", "provincie/zuid-holland"),
        (3, "Taxon gamma", "Losse waarnemingen", "waarneming.nl"),
        (4, "Taxon delta", "12.007 Vegetatieopnamen", "provincie/zuid-holland"),
    )
    for fid, taxon, protocol, owner in specs:
        feature = ogr.Feature(layer.GetLayerDefn())
        feature.SetFID(fid)
        values = {
            "obs_uri": f"https://example.test/{fid}", "soort_ned": f"Soort {fid}",
            "soort_wet": taxon, "srtgroepen": "Vaatplanten",
            "datm_start": "2020/05/01", "datm_stop": "2020/05/01",
            "protocol": protocol, "dataeigenr": owner, "kwliteit": "betrouwbaar",
            "loc_type": "punt", "vervaagd": "onvervaagd", "area_m2": 1.0,
            "centrumx": 80000 + fid, "centrumy": 460000 + fid,
            "orig_aant": "1", "telondrwrp": "levend exemplaar", "telmethode": "exact aantal",
        }
        for key, value in values.items():
            feature.SetField(key, value)
        ring = ogr.Geometry(ogr.wkbLinearRing)
        x, y = 80000 + fid, 460000 + fid
        for dx, dy in ((0, 0), (1, 0), (1, 1), (0, 1), (0, 0)):
            ring.AddPoint_2D(x + dx, y + dy)
        polygon = ogr.Geometry(ogr.wkbPolygon)
        polygon.AddGeometry(ring)
        feature.SetGeometry(polygon)
        layer.CreateFeature(feature)
    dataset = None


def main() -> int:
    module = load_module()
    assert module.mysql_connection_args("meijendel_root", "127.0.0.1", 3306) == [
        "--login-path=meijendel_root",
        "--protocol=tcp",
        "--host=127.0.0.1",
        "--port=3306",
        "--binary-mode",
    ]
    with tempfile.TemporaryDirectory(prefix="ndff-import-test-") as tmp:
        root = Path(tmp)
        gpkg = root / "secure.gpkg"
        write_gpkg(gpkg)
        gate = root / "gate.csv"
        spatial = root / "spatial.csv"
        pq = root / "pq.csv"
        plots = root / "plots.csv"
        write_csv(gate, [
            {"secure_fid": 1, "open_identity": "a" * 64, "groep": "Vaatplanten", "soort_wet": "Taxon alpha", "protocol": "Losse waarnemingen", "ruimtelijke_klasse": "single", "toewijzingskwaliteit": "single_volledig_binnen", "pq_status": "niet_van_toepassing", "protocol_auditklasse": "Alleen verspreidingscontext", "verspreidingscontext_status": "kandidaat_verspreidingscontext", "trend_status": "brondata_opvragen", "beslisregel_versie": "v1"},
            {"secure_fid": 2, "open_identity": "b" * 64, "groep": "Vaatplanten", "soort_wet": "Taxon beta", "protocol": "12.007 Vegetatieopnamen", "ruimtelijke_klasse": "single", "toewijzingskwaliteit": "single_volledig_binnen", "pq_status": "exact", "protocol_auditklasse": "PQ-overlap eerst uitsluiten", "verspreidingscontext_status": "uitgesloten_pq", "trend_status": "niet_trendklaar", "beslisregel_versie": "v1"},
            {"secure_fid": 3, "open_identity": "c" * 64, "groep": "Vaatplanten", "soort_wet": "Taxon gamma", "protocol": "Losse waarnemingen", "ruimtelijke_klasse": "outside", "toewijzingskwaliteit": "outside", "pq_status": "niet_van_toepassing", "protocol_auditklasse": "Alleen verspreidingscontext", "verspreidingscontext_status": "uitgesloten_ruimtelijk", "trend_status": "niet_trendklaar", "beslisregel_versie": "v1"},
            {"secure_fid": 4, "open_identity": "d" * 64, "groep": "Vaatplanten", "soort_wet": "Taxon delta", "protocol": "12.007 Vegetatieopnamen", "ruimtelijke_klasse": "single", "toewijzingskwaliteit": "single_volledig_binnen", "pq_status": "onafhankelijk", "protocol_auditklasse": "PQ-overlap eerst uitsluiten", "verspreidingscontext_status": "kandidaat_verspreidingscontext", "trend_status": "brondata_opvragen", "beslisregel_versie": "v1"},
        ])
        write_csv(spatial, [
            {"secure_fid": 1, "plot_match_count": 1, "toewijzingskwaliteit": "single_volledig_binnen"},
            {"secure_fid": 2, "plot_match_count": 1, "toewijzingskwaliteit": "single_volledig_binnen"},
            {"secure_fid": 3, "plot_match_count": 0, "toewijzingskwaliteit": "outside"},
            {"secure_fid": 4, "plot_match_count": 1, "toewijzingskwaliteit": "single_volledig_binnen"},
        ])
        write_csv(pq, [
            {"secure_fid": 1, "pq_status": "niet_van_toepassing", "pq_match_count": 0, "pq_opname_ids": "", "beslisregel_versie": "v1", "toelichting": "geen PQ"},
            {"secure_fid": 2, "pq_status": "exact", "pq_match_count": 1, "pq_opname_ids": "99", "beslisregel_versie": "v1", "toelichting": "provinciale PQ is primair"},
            {"secure_fid": 3, "pq_status": "niet_van_toepassing", "pq_match_count": 0, "pq_opname_ids": "", "beslisregel_versie": "v1", "toelichting": "geen PQ"},
            {"secure_fid": 4, "pq_status": "onafhankelijk", "pq_match_count": 0, "pq_opname_ids": "", "beslisregel_versie": "v1", "toelichting": "PQ-protocol blijft secundair"},
        ])
        write_csv(plots, [
            {"secure_fid": 1, "plot_id": "A", "match_volgnummer": 1, "overlap_oppervlak_m2": 1, "overlap_aandeel": 1, "centroid_binnen": 1, "ruimtelijke_klasse": "single", "koppelregel_versie": "v1"},
            {"secure_fid": 2, "plot_id": "A", "match_volgnummer": 1, "overlap_oppervlak_m2": 1, "overlap_aandeel": 1, "centroid_binnen": 1, "ruimtelijke_klasse": "single", "koppelregel_versie": "v1"},
            {"secure_fid": 4, "plot_id": "A", "match_volgnummer": 1, "overlap_oppervlak_m2": 1, "overlap_aandeel": 1, "centroid_binnen": 1, "ruimtelijke_klasse": "single", "koppelregel_versie": "v1"},
        ])
        model = module.prepare_import_model(gpkg, gate, spatial, pq, plots)
        assert model["counts"]["records"] == 4
        assert model["counts"]["taxa"] == 4
        assert model["counts"]["distribution_candidates"] == 1
        assert model["counts"]["trend_candidates"] == 1
        assert model["counts"]["pq_exact"] == 1
        by_fid = {row["secure_fid"]: row for row in model["records"]}
        assert by_fid[1]["inname_status"] == "toegelaten"
        assert by_fid[1]["trend_status"] == "trendkandidaat_wacht_op_brondata"
        assert by_fid[2]["inname_status"] == "uitgesloten"
        assert by_fid[2]["pq_is_primaire_bron"] is False
        assert by_fid[3]["inname_status"] == "uitgesloten"
        assert by_fid[4]["inname_status"] == "uitgesloten"
        assert by_fid[4]["inname_reason"] == "ndff_pq_secundaire_bron"
        assert by_fid[4]["pq_is_primaire_bron"] is False
        manifest = module.safe_manifest(model, gpkg)
        assert manifest["source_hierarchy"] == (
            "Provincie Zuid-Holland is de primaire en gezaghebbende PQ-bron; "
            "NDFF-PQ is uitsluitend een secundaire controlebron."
        )
        encoded = json.dumps(manifest)
        for forbidden in ("obs_uri", "centrumx", "centrumy", "geometry_wkb_hex", "Taxon alpha"):
            assert forbidden not in encoded
    print("OK: beveiligde NDFF-importvoorbereiding")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
