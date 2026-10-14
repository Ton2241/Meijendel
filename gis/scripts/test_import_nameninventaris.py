#!/usr/bin/env python3
"""Gedrags- en integriteitstests voor de Meijendel-nameninventaris."""

from __future__ import annotations

import csv
import importlib.util
import json
import shutil
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).parents[2]
IMPORTER = ROOT / "gis" / "scripts" / "import_nameninventaris.py"
SCHEMA = ROOT / "gis" / "database" / "nameninventaris_schema.sql"
DELIVERY = Path(
    "/Users/ton/Documents/Codex/2026-10-14/"
    "referenced-chatgpt-conversation-this-is-an/outputs/"
    "meijendel_nameninventaris_2026-10-14"
)


def load_importer():
    spec = importlib.util.spec_from_file_location("import_nameninventaris", IMPORTER)
    if spec is None or spec.loader is None:
        raise AssertionError(f"Importer niet laadbaar: {IMPORTER}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class DeliveryCopy:
    def __enter__(self) -> Path:
        self._tmp = tempfile.TemporaryDirectory()
        target = Path(self._tmp.name) / DELIVERY.name
        shutil.copytree(DELIVERY, target)
        self.path = target
        return target

    def __exit__(self, *_args) -> None:
        self._tmp.cleanup()


def csv_rows(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    with path.open(encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        return list(reader.fieldnames or []), list(reader)


def write_csv(path: Path, fields: list[str], rows: list[dict[str, str]]) -> None:
    with path.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


class NameninventarisContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.module = load_importer()

    def assert_invalid(self, delivery: Path, fragment: str) -> None:
        with self.assertRaisesRegex(ValueError, f"(?i:{fragment})"):
            self.module.build_import_plan(delivery, verify_checksums=False)

    def test_full_delivery_normalizes_expected_records(self) -> None:
        plan = self.module.build_import_plan(DELIVERY)
        self.assertEqual(
            plan.counts,
            {
                "bronnen": 8,
                "objecten": 182,
                "vermeldingen": 299,
                "geometrieen": 71,
                "ontbrekende_geometrie": 111,
                "top10nl_ids": 47,
                "osm_ids": 60,
            },
        )
        blankenburgh = plan.objects["OBJ-FB0E7E2F03"]
        voorlinden = plan.objects["OBJ-AC70DD4C7A"]
        self.assertEqual((blankenburgh.voorkeursnaam, blankenburgh.bronobjecttype),
                         ("Blankenburgh", "Buitenplaats"))
        self.assertEqual((voorlinden.voorkeursnaam, voorlinden.bronobjecttype),
                         ("Voorlinden", "Buitenplaats"))
        self.assertEqual(
            plan.objects["OBJ-3DB0CB7DAA"].source_ids,
            ("SRC-BEEKMAN-2021", "SRC-PDOK-TOP10NL-2026"),
        )
        periods = {mention.periode_letterlijk: mention for mention in plan.mentions.values()}
        self.assertEqual((periods["1957"].jaar_van, periods["1957"].jaar_tot,
                          periods["1957"].datumprecisie), (1957, 1957, "jaar"))
        self.assertEqual((periods["1909/1914"].jaar_van, periods["1909/1914"].jaar_tot,
                          periods["1909/1914"].datumprecisie), (1909, 1914, "jaarbereik"))
        self.assertEqual(self.module.parse_period("1980/1989"),
                         (1980, 1989, "decennium"))
        decennium_tot_bronjaar = next(
            item for item in plan.mentions.values()
            if item.periode_letterlijk == "1980/1989" and item.periode_einde_letterlijk == "2012"
        )
        self.assertEqual((decennium_tot_bronjaar.jaar_van, decennium_tot_bronjaar.jaar_tot,
                          decennium_tot_bronjaar.datumprecisie),
                         (1980, 2012, "decennium"))
        osm_ids = [link.bronobject_id for link in plan.geometry_source_objects
                   if link.bronobject_systeem == "OSM"]
        self.assertIn("420886239", osm_ids)
        self.assertEqual(len(osm_ids), 60)
        self.assertEqual(
            len({link.bronobject_id for link in plan.geometry_source_objects
                 if link.bronobject_systeem == "TOP10NL"}),
            47,
        )
        self.assertEqual(plan.objects["OBJ-AAFF6A6E85"].nauwkeurigheidsstatus,
                         "niet_opgegeven")

    def test_changed_delivery_file_is_rejected_by_checksum(self) -> None:
        with DeliveryCopy() as delivery:
            path = delivery / "meijendel_bronnen.csv"
            path.write_text(path.read_text(encoding="utf-8-sig") + "\n", encoding="utf-8-sig")
            with self.assertRaisesRegex(ValueError, "checksum"):
                self.module.build_import_plan(delivery)

    def test_missing_required_header_is_rejected(self) -> None:
        with DeliveryCopy() as delivery:
            path = delivery / "meijendel_namen_rdnew.csv"
            fields, rows = csv_rows(path)
            fields.remove("object_id")
            write_csv(path, fields, rows)
            self.assert_invalid(delivery, "kolom.*object_id")

    def test_duplicate_object_id_is_rejected(self) -> None:
        with DeliveryCopy() as delivery:
            path = delivery / "meijendel_namen_rdnew.csv"
            fields, rows = csv_rows(path)
            rows.append(dict(rows[0]))
            write_csv(path, fields, rows)
            self.assert_invalid(delivery, "dubbel.*object_id")

    def test_orphan_mention_is_rejected(self) -> None:
        with DeliveryCopy() as delivery:
            path = delivery / "meijendel_vermeldingen.csv"
            fields, rows = csv_rows(path)
            rows[0]["object_id"] = "OBJ-BESTAAT-NIET"
            write_csv(path, fields, rows)
            self.assert_invalid(delivery, "verweesde.*vermelding")

    def test_unknown_name_status_is_rejected(self) -> None:
        with DeliveryCopy() as delivery:
            path = delivery / "meijendel_namen_rdnew.csv"
            fields, rows = csv_rows(path)
            rows[0]["name_status"] = "mogelijk"
            write_csv(path, fields, rows)
            self.assert_invalid(delivery, "name_status")

    def test_invalid_period_is_rejected(self) -> None:
        with DeliveryCopy() as delivery:
            path = delivery / "meijendel_vermeldingen.csv"
            fields, rows = csv_rows(path)
            rows[0]["mention_start"] = "1909-1914?"
            write_csv(path, fields, rows)
            self.assert_invalid(delivery, "periode")

    def test_empty_geometry_is_rejected(self) -> None:
        with DeliveryCopy() as delivery:
            path = delivery / "meijendel_namen_epsg4326.geojson"
            document = json.loads(path.read_text(encoding="utf-8"))
            feature = next(item for item in document["features"] if item["geometry"])
            feature["geometry"] = {"type": "GeometryCollection", "geometries": []}
            path.write_text(json.dumps(document), encoding="utf-8")
            self.assert_invalid(delivery, "lege geometrie")

    def test_wrong_geojson_crs_is_rejected(self) -> None:
        with DeliveryCopy() as delivery:
            path = delivery / "meijendel_namen_epsg4326.geojson"
            document = json.loads(path.read_text(encoding="utf-8"))
            document["crs"]["properties"]["name"] = "EPSG:3857"
            path.write_text(json.dumps(document), encoding="utf-8")
            self.assert_invalid(delivery, "CRS84")

    def test_invalid_geometry_is_rejected(self) -> None:
        with DeliveryCopy() as delivery:
            path = delivery / "meijendel_namen_rdnew.csv"
            fields, rows = csv_rows(path)
            row = next(item for item in rows if item["wkt_rdnew"])
            row["wkt_rdnew"] = "POLYGON ((0 0, 2 2, 0 2, 2 0, 0 0))"
            write_csv(path, fields, rows)
            self.assert_invalid(delivery, "ongeldige geometrie")

    def test_nonexistent_osm_source_id_is_rejected(self) -> None:
        with DeliveryCopy() as delivery:
            path = delivery / "meijendel_vermeldingen.csv"
            fields, rows = csv_rows(path)
            row = next(item for item in rows if item["source_id"] == "SRC-OSM-2026-04-03")
            row["page_or_map"] = "999999999999999999"
            write_csv(path, fields, rows)
            self.assert_invalid(delivery, "OSM.*bronobject")


if __name__ == "__main__":
    unittest.main(verbosity=2)
