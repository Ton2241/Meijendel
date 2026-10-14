#!/usr/bin/env python3
"""Gedrags- en integriteitstests voor de Meijendel-nameninventaris."""

from __future__ import annotations

import csv
import importlib.util
import json
import os
import re
import shutil
import subprocess
import tempfile
import unittest
import uuid
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

    def test_import_sql_is_transactional_ordered_and_portable(self) -> None:
        plan = self.module.build_import_plan(DELIVERY)
        sql = self.module.build_import_sql(plan, "Meijendel_test")
        self.assertIn("START TRANSACTION", sql)
        self.assertIn("COMMIT", sql)
        self.assertLess(sql.index("INSERT INTO nameninventaris_import"),
                        sql.index("INSERT INTO nameninventaris_bron"))
        self.assertLess(sql.index("INSERT INTO nameninventaris_bron"),
                        sql.index("INSERT INTO nameninventaris_object"))
        self.assertLess(sql.index("INSERT INTO nameninventaris_object"),
                        sql.index("INSERT INTO nameninventaris_vermelding"))
        self.assertLess(sql.index("INSERT INTO nameninventaris_geometrie"),
                        sql.index("INSERT INTO nameninventaris_geometrie_bronobject"))
        self.assertNotIn("/Volumes/T7", sql)
        self.assertNotIn(str(DELIVERY.parent), sql)
        self.assertIn("zotero:NZWRNSSI", sql)
        self.assertIn("project:Recreatie/OSM/osm_highways_lijnen.geojson", sql)

    def test_validation_failure_happens_before_mysql_write(self) -> None:
        calls: list[tuple] = []

        def record_mysql(*args, **kwargs):
            calls.append((args, kwargs))
            return ""

        with DeliveryCopy() as delivery:
            path = delivery / "meijendel_namen_rdnew.csv"
            fields, rows = csv_rows(path)
            rows[0]["name_status"] = "mogelijk"
            write_csv(path, fields, rows)
            with self.assertRaisesRegex(ValueError, "name_status"):
                self.module.apply_delivery(
                    delivery,
                    database="Meijendel_namen_test_no_write",
                    verify_checksums=False,
                    mysql_runner=record_mysql,
                )
        self.assertEqual(calls, [])

    def test_central_database_contract_accepts_nameninventaris_without_taxon_route(self) -> None:
        import import_external_ecology_sources as external

        additions = {
            "nameninventaris_import": {
                "import_id", "versiesleutel", "leveringsdatum", "bronreferentie",
                "archief_sha256", "regelversie", "verwacht_bronnen", "verwacht_objecten",
                "verwacht_vermeldingen", "verwacht_geometrieen", "verwacht_lacunes",
                "geimporteerd_op",
            },
            "nameninventaris_bron": {
                "import_id", "source_id", "titel", "auteur_beheerder", "bronjaar",
                "brontype", "bronverwijzing", "zotero_item_key", "raadpleegdatum",
                "ruimtelijke_grondslag", "rechten", "kwaliteitsbeoordeling",
            },
            "nameninventaris_object": {
                "object_id", "import_id", "voorkeursnaam", "aangeleverde_naam",
                "objectklasse", "bronobjecttype", "bewijsstatus", "nauwkeurigheid_m",
                "nauwkeurigheidsstatus", "aangemaakt_op",
            },
            "nameninventaris_vermelding": {
                "mention_id", "import_id", "object_id", "source_id", "bronnaam",
                "periode_letterlijk", "periode_einde_letterlijk", "jaar_van", "jaar_tot",
                "datumprecisie", "pagina_kaart_bronobject", "deelgebied", "bewijsnotitie",
            },
            "nameninventaris_geometrie": {
                "geometrie_id", "import_id", "object_id", "source_id", "geometrieversie",
                "peildatum", "bronobjecttype", "wkt_sha256", "nauwkeurigheid_m",
                "nauwkeurigheidsstatus", "ruimtelijke_selectiegrondslag",
                "geometrieopmerking", "geometry", "aangemaakt_op",
            },
            "nameninventaris_geometrie_bronobject": {
                "geometrie_id", "bronobject_systeem", "bronobject_id",
            },
            "nameninventaris_beoordeling": {
                "beoordeling_id", "import_id", "object_id", "regelversie",
                "beoordelingsstatus", "ontbreekt", "gevolg", "kleinste_volgende_bron",
                "actueel", "beoordeeld_op",
            },
        }
        actual = {name: set(columns) for name, columns in external.CENTRAL_QUERY_SCHEMA.items()}
        actual.update(additions)
        external.central_query_schema_contract(actual)


@unittest.skipUnless(os.environ.get("MEIJENDEL_MYSQL_INTEGRATION") == "1",
                     "zet MEIJENDEL_MYSQL_INTEGRATION=1 voor de MySQL-schemaproef")
class NameninventarisSchemaIntegration(unittest.TestCase):
    mysql = "/usr/local/mysql/bin/mysql"

    def setUp(self) -> None:
        self.module = load_importer()
        self.database = "Meijendel_namen_test_" + uuid.uuid4().hex[:10]
        self.run_mysql(f"CREATE DATABASE `{self.database}` CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci")

    def tearDown(self) -> None:
        if getattr(self, "database", "").startswith("Meijendel_namen_test_"):
            self.run_mysql(f"DROP DATABASE `{self.database}`")

    @classmethod
    def run_mysql(cls, sql: str, *, database: str | None = None) -> str:
        command = [cls.mysql, "--login-path=meijendel_root", "--protocol=TCP",
                   "--batch", "--raw", "--skip-column-names"]
        if database:
            command.append(database)
        result = subprocess.run(command, input=sql, text=True, capture_output=True, check=False)
        if result.returncode:
            raise AssertionError(result.stderr or result.stdout)
        return result.stdout.strip()

    def test_schema_creates_seven_restrictive_tables(self) -> None:
        schema = SCHEMA.read_text(encoding="utf-8")
        schema = re.sub(r"\bUSE\s+Meijendel\s*;", f"USE `{self.database}`;", schema,
                        count=1, flags=re.IGNORECASE)
        self.run_mysql(schema)
        expected = {
            "nameninventaris_import",
            "nameninventaris_bron",
            "nameninventaris_object",
            "nameninventaris_vermelding",
            "nameninventaris_geometrie",
            "nameninventaris_geometrie_bronobject",
            "nameninventaris_beoordeling",
        }
        actual = set(self.run_mysql("SHOW TABLES", database=self.database).splitlines())
        self.assertEqual(actual, expected)
        for table in expected:
            status = self.run_mysql(
                "SELECT ENGINE,TABLE_COLLATION FROM information_schema.TABLES "
                f"WHERE TABLE_SCHEMA='{self.database}' AND TABLE_NAME='{table}'"
            )
            self.assertEqual(status, "InnoDB\tutf8mb4_0900_ai_ci")
        geometry_ddl = self.run_mysql(
            "SHOW CREATE TABLE nameninventaris_geometrie", database=self.database
        )
        geometry_metadata = self.run_mysql(
            "SELECT SRS_ID,GEOMETRY_TYPE_NAME FROM information_schema.ST_GEOMETRY_COLUMNS "
            f"WHERE TABLE_SCHEMA='{self.database}' AND TABLE_NAME='nameninventaris_geometrie' "
            "AND COLUMN_NAME='geometry'"
        )
        self.assertEqual(geometry_metadata, "28992\tgeometry")
        self.assertIn("`geometry` geometry NOT NULL", geometry_ddl)
        self.assertIn("SPATIAL KEY", geometry_ddl)
        object_ddl = self.run_mysql(
            "SHOW CREATE TABLE nameninventaris_object", database=self.database
        )
        for status in ("actueel_bronbewijs", "historisch_bronbewijs",
                       "actueel_en_historisch_bronbewijs"):
            self.assertIn(status, object_ddl)
        mention_ddl = self.run_mysql(
            "SHOW CREATE TABLE nameninventaris_vermelding", database=self.database
        )
        self.assertIn("datumprecisie", mention_ddl)
        assessment_ddl = self.run_mysql(
            "SHOW CREATE TABLE nameninventaris_beoordeling", database=self.database
        )
        self.assertIn("regelversie", assessment_ddl)
        foreign_keys = int(self.run_mysql(
            "SELECT COUNT(*) FROM information_schema.REFERENTIAL_CONSTRAINTS "
            f"WHERE CONSTRAINT_SCHEMA='{self.database}'"
        ))
        self.assertGreaterEqual(foreign_keys, 8)

    def test_import_is_idempotent_and_auditable(self) -> None:
        first = self.module.apply_delivery(
            DELIVERY,
            database=self.database,
            mysql_client=Path(self.mysql),
        )
        before = self.module.database_fingerprint(
            database=self.database,
            mysql_client=Path(self.mysql),
        )
        second = self.module.apply_delivery(
            DELIVERY,
            database=self.database,
            mysql_client=Path(self.mysql),
        )
        after = self.module.database_fingerprint(
            database=self.database,
            mysql_client=Path(self.mysql),
        )
        self.assertEqual(first, "imported")
        self.assertEqual(second, "already_present")
        self.assertEqual(after, before)
        audit = self.module.audit_database(
            database=self.database,
            mysql_client=Path(self.mysql),
        )
        self.assertEqual(audit["counts"], {
            "nameninventaris_import": 1,
            "nameninventaris_bron": 8,
            "nameninventaris_object": 182,
            "nameninventaris_vermelding": 299,
            "nameninventaris_geometrie": 71,
            "nameninventaris_geometrie_bronobject": 107,
            "nameninventaris_beoordeling": 111,
        })
        self.assertEqual(audit["invalid_geometry"], 0)
        self.assertEqual(audit["orphan_rows"], 0)
        self.assertEqual(audit["top10nl_ids"], 47)
        self.assertEqual(audit["osm_ids"], 60)
        self.assertEqual(audit["missing_named_geometry"], ["Bunkerpad", "Klippad"])

    def test_existing_version_with_changed_content_is_rejected(self) -> None:
        self.module.apply_delivery(
            DELIVERY,
            database=self.database,
            mysql_client=Path(self.mysql),
        )
        with DeliveryCopy() as delivery:
            path = delivery / "meijendel_bronnen.csv"
            fields, rows = csv_rows(path)
            rows[0]["title"] += " gewijzigd"
            write_csv(path, fields, rows)
            with self.assertRaisesRegex(ValueError, "afwijkende inhoudshash"):
                self.module.apply_delivery(
                    delivery,
                    database=self.database,
                    mysql_client=Path(self.mysql),
                    verify_checksums=False,
                )


if __name__ == "__main__":
    unittest.main(verbosity=2)
