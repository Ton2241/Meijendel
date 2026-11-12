#!/usr/bin/env python3
"""Contracttest voor de vijf gereconstrueerde kervenkernvlakken."""

from __future__ import annotations

import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCHEMA = ROOT / "gis/database/maatregelen_schema.sql"
MIGRATION = ROOT / "Ruimtelijke data/19_registreer_kerven_kernvlakken_20261112.sql"
CENTRAL_QUERY = ROOT / "gis/scripts/import_external_ecology_sources.py"


class KervenKernvlakkenContract(unittest.TestCase):
    def test_schema_bewaart_afzonderlijke_geometrieobjecten(self) -> None:
        sql = SCHEMA.read_text(encoding="utf-8")
        self.assertRegex(
            sql,
            r"object_code\s+VARCHAR\(32\).*NOT NULL DEFAULT 'geheel'",
        )
        self.assertIn(
            "UNIQUE KEY uq_maatregel_geometrie "
            "(uitvoering_id, geometrie_type, geometrie_jaar, object_code)",
            sql,
        )

    def test_migratie_registreert_precies_mey1_tot_mey5(self) -> None:
        sql = MIGRATION.read_text(encoding="utf-8")
        codes = re.findall(r"'MEY([1-5])'", sql)
        self.assertEqual(sorted(set(codes)), ["1", "2", "3", "4", "5"])
        self.assertEqual(len(codes), 5)
        self.assertEqual(sql.count("ST_GeomFromText('MULTIPOLYGON"), 5)
        self.assertIn("'TG03_uitvoeringsgebied'", sql)
        self.assertIn("2015", sql)
        self.assertIn("gereconstrueerd kernvlak 30 x 30 m", sql)

    def test_migratie_bewaakt_bestaande_uitvoeringsfeiten(self) -> None:
        sql = MIGRATION.read_text(encoding="utf-8")
        for value in (
            "zeereep_vijf_kerven_2014_2015",
            "2013-12-01",
            "2015-03-31",
            "10.9434",
            "Meijendel k 15",
            "Meijendel k 16",
            "Meijendel k 17a",
        ):
            self.assertIn(value, sql)

    def test_migratie_herkent_meerkolomsindex_als_een_index(self) -> None:
        sql = MIGRATION.read_text(encoding="utf-8")
        self.assertIn("@uq_bestaand>0", sql)

    def test_nieuwe_unieke_index_bestaat_voordat_de_oude_wordt_verwijderd(self) -> None:
        sql = MIGRATION.read_text(encoding="utf-8")
        add = sql.index("ADD UNIQUE KEY uq_maatregel_geometrie_object")
        drop = sql.index("DROP INDEX uq_maatregel_geometrie")
        self.assertLess(add, drop)

    def test_centrale_routecontrole_kent_object_code(self) -> None:
        source = CENTRAL_QUERY.read_text(encoding="utf-8")
        match = re.search(
            r"'maatregel_geometrie': frozenset\(\[([^\]]+)\]\)", source
        )
        self.assertIsNotNone(match)
        self.assertIn("'object_code'", match.group(1))


if __name__ == "__main__":
    unittest.main()
