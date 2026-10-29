import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

import numpy as np
import pandas as pd
import rasterio
from rasterio.transform import from_origin


SCRIPT = Path(__file__).with_name("pq_representativiteit.py")


def load_module():
    spec = importlib.util.spec_from_file_location("pq_representativiteit", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class PqRepresentativiteitTest(unittest.TestCase):
    def setUp(self):
        self.module = load_module()

    def test_selecteert_dichtstbijzijnde_opname_binnen_vijf_jaar(self):
        opnamen = pd.DataFrame(
            {
                "opname_id": [1, 2, 3, 4],
                "pq_nummer": [10, 10, 20, 30],
                "jaar": [1999, 2003, 1995, 2022],
                "plot_id": [100, 100, 100, 200],
                "x_rd": [1, 2, 3, 4],
                "y_rd": [5, 6, 7, 8],
            }
        )
        selected = self.module.select_snapshot_opnamen(opnamen, 2001, max_afstand=5)
        self.assertEqual(selected["pq_nummer"].tolist(), [10])
        self.assertEqual(selected["opname_id"].tolist(), [2])
        self.assertEqual(selected["afstand_kaartjaar"].tolist(), [2])

    def test_berekent_oppervlaktegewichten_en_onbedekte_klassen(self):
        oppervlak = pd.DataFrame(
            {
                "plot_id": [100, 100, 100],
                "jaar": [2001, 2001, 2001],
                "klasse": ["open", "struweel", "bos"],
                "aandeel": [0.50, 0.30, 0.20],
            }
        )
        punten = pd.DataFrame(
            {
                "plot_id": [100, 100, 100, 100],
                "kaartjaar": [2001, 2001, 2001, 2001],
                "pq_nummer": [1, 2, 3, 4],
                "klasse": ["open", "open", "struweel", pd.NA],
                "raster_status": [
                    "gekoppeld",
                    "gekoppeld",
                    "gekoppeld",
                    "geen_bruikbare_rasterklasse",
                ],
            }
        )
        klassen, gewogen_punten, plots = self.module.build_representation_weights(
            oppervlak, punten
        )

        open_row = klassen[klassen["klasse"] == "open"].iloc[0]
        bos_row = klassen[klassen["klasse"] == "bos"].iloc[0]
        self.assertAlmostEqual(open_row["pq_aandeel"], 2 / 3)
        self.assertAlmostEqual(open_row["representatie_ratio"], (2 / 3) / 0.50)
        self.assertEqual(bos_row["n_pq"], 0)
        self.assertTrue(pd.isna(bos_row["representatie_ratio"]))
        self.assertAlmostEqual(
            plots.iloc[0]["oppervlakteaandeel_bemonsterde_klassen"], 0.80
        )
        self.assertAlmostEqual(gewogen_punten["gewicht"].sum(), 1.0)
        self.assertAlmostEqual(
            gewogen_punten.loc[gewogen_punten["klasse"] == "open", "gewicht"].iloc[0],
            0.3125,
        )
        self.assertAlmostEqual(
            gewogen_punten.loc[gewogen_punten["klasse"] == "struweel", "gewicht"].iloc[0],
            0.375,
        )
        self.assertEqual(len(gewogen_punten), 4)
        onbruikbaar = gewogen_punten[gewogen_punten["pq_nummer"] == 4].iloc[0]
        self.assertEqual(onbruikbaar["raster_status"], "geen_bruikbare_rasterklasse")
        self.assertTrue(pd.isna(onbruikbaar["gewicht"]))

    def test_bemonstert_landbedekkingsklasse_op_rd_coordinaat(self):
        selected = pd.DataFrame(
            {
                "opname_id": [1, 2],
                "pq_nummer": [10, 20],
                "jaar": [2001, 2001],
                "plot_id": [100, 100],
                "x_rd": [100_002.5, 100_007.5],
                "y_rd": [449_997.5, 449_997.5],
                "afstand_kaartjaar": [0, 0],
                "kaartjaar": [2001, 2001],
            }
        )
        with tempfile.TemporaryDirectory() as directory:
            raster = Path(directory) / "test.tif"
            with rasterio.open(
                raster,
                "w",
                driver="GTiff",
                width=2,
                height=1,
                count=1,
                dtype="int16",
                nodata=-9999,
                crs="EPSG:28992",
                transform=from_origin(100_000, 450_000, 5, 5),
            ) as destination:
                destination.write(np.array([[2, -9999]], dtype=np.int16), 1)
            result = self.module.sample_landcover(selected, raster, 2001)
        self.assertEqual(result.iloc[0]["rastercode"], 2)
        self.assertEqual(result.iloc[0]["klasse"], "struik")
        self.assertEqual(result.iloc[0]["raster_status"], "gekoppeld")
        self.assertTrue(pd.isna(result.iloc[1]["rastercode"]))
        self.assertTrue(pd.isna(result.iloc[1]["klasse"]))
        self.assertEqual(result.iloc[1]["raster_status"], "geen_bruikbare_rasterklasse")

    def test_leest_genormaliseerde_landbedekking_met_correcte_plot_id(self):
        wide = pd.DataFrame(
            {
                "plot_id": [999995, 3513],
                "kavel_nummer": ["M17", "M17a"],
                "jaar": [2001, 2001],
                "struik_aandeel": [0.2, 0.2],
                "bos_aandeel": [0.1, 0.1],
                "boomgroep_aandeel": [0.1, 0.1],
                "laag_aandeel": [0.3, 0.3],
                "riet_aandeel": [0.1, 0.1],
                "zand_aandeel": [0.1, 0.1],
                "water_aandeel": [0.1, 0.1],
            }
        )
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "landbedekking.csv"
            wide.to_csv(source, index=False)
            result = self.module.read_area_metrics(source)
        self.assertEqual(len(result), 14)
        self.assertEqual(result["plot_id"].unique().tolist(), [999995, 3513])
        self.assertAlmostEqual(result["aandeel"].sum(), 2.0)

        wide.loc[wide["plot_id"] == 3513, "kavel_nummer"] = "M17"
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "landbedekking_fout.csv"
            wide.to_csv(source, index=False)
            with self.assertRaisesRegex(ValueError, "M17/M17a-normalisatie"):
                self.module.read_area_metrics(source)

    def test_vat_oppervlakte_en_pq_verdeling_per_deelgebied_samen(self):
        classes = pd.DataFrame(
            {
                "plot_id": [1, 1, 2, 2],
                "kaartjaar": [2001] * 4,
                "klasse": ["open", "bos", "open", "bos"],
                "klasse_ha": [5.0, 5.0, 2.0, 18.0],
                "plot_oppervlakte_ha": [10.0, 10.0, 20.0, 20.0],
                "n_pq": [1, 1, 1, 3],
            }
        )
        zones = pd.DataFrame(
            {
                "plot_id": [1, 2],
                "gebied_code": ["buiten", "binnen"],
                "gebied_naam": ["Buitenduin", "Binnenduin"],
            }
        )
        result = self.module.summarize_representation(classes, zones)
        overall_open = result[
            (result["niveau"] == "geheel") & (result["klasse"] == "open")
        ].iloc[0]
        outside_open = result[
            (result["gebied_code"] == "buiten") & (result["klasse"] == "open")
        ].iloc[0]
        self.assertAlmostEqual(overall_open["oppervlakte_aandeel"], 7 / 30)
        self.assertAlmostEqual(overall_open["pq_aandeel"], 2 / 6)
        self.assertEqual(overall_open["plots"], 2)
        self.assertEqual(overall_open["plots_met_pq"], 2)
        self.assertAlmostEqual(outside_open["oppervlakte_aandeel"], 0.5)
        self.assertAlmostEqual(outside_open["pq_aandeel"], 0.5)
        self.assertEqual(outside_open["plots"], 1)

    def test_gepubliceerde_resultaten_behouden_vastgestelde_invarianten(self):
        results = SCRIPT.parent.parent / "resultaten"
        points = pd.read_csv(results / "pq_representativiteit_laatste_punten.csv")
        plots = pd.read_csv(results / "pq_representativiteit_laatste_plots.csv")
        manifest = json.loads(
            (results / "pq_representativiteit_laatste_manifest.json").read_text(
                encoding="utf-8"
            )
        )

        counts = points.groupby("kaartjaar")["raster_status"].agg(
            totaal="size",
            bruikbaar=lambda values: int((values == "gekoppeld").sum()),
            onbruikbaar=lambda values: int((values != "gekoppeld").sum()),
        )
        self.assertEqual(counts.loc[2001].to_dict(), {"totaal": 84, "bruikbaar": 82, "onbruikbaar": 2})
        self.assertEqual(counts.loc[2022].to_dict(), {"totaal": 102, "bruikbaar": 100, "onbruikbaar": 2})
        eligible = plots[
            (plots["n_pq"] >= 3)
            & (plots["oppervlakteaandeel_bemonsterde_klassen"] >= 0.70)
        ]
        self.assertEqual(eligible.groupby("kaartjaar").size().to_dict(), {2001: 8, 2022: 9})
        self.assertEqual(manifest["pq_punten_geselecteerd"], {"2001": 84, "2022": 102})
        for name, expected in manifest["uitvoerbestanden_sha256"].items():
            self.assertEqual(self.module.sha256_file(results / name), expected)


if __name__ == "__main__":
    unittest.main()
