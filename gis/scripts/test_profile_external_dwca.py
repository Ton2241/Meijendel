#!/usr/bin/env python3
"""Tests voor de reproduceerbare profilering van externe Darwin Core-bronnen."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
import zipfile
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("profile_external_dwca.py")
SPEC = importlib.util.spec_from_file_location("profile_external_dwca", MODULE_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
SPEC.loader.exec_module(MODULE)


class GeometryTests(unittest.TestCase):
    def test_point_in_polygon_and_boundary(self):
        polygon = [[0.0, 0.0], [10.0, 0.0], [10.0, 10.0], [0.0, 10.0], [0.0, 0.0]]
        self.assertTrue(MODULE.point_in_ring(5.0, 5.0, polygon))
        self.assertFalse(MODULE.point_in_ring(15.0, 5.0, polygon))
        self.assertTrue(MODULE.point_in_ring(0.0, 5.0, polygon))


class DwcaTests(unittest.TestCase):
    def test_reads_meta_mapping_instead_of_assuming_header_names(self):
        meta = """<archive xmlns=\"http://rs.tdwg.org/dwc/text/\">
          <core encoding=\"UTF-8\" fieldsTerminatedBy=\"\\t\" linesTerminatedBy=\"\\n\" ignoreHeaderLines=\"1\">
            <files><location>occurrence.txt</location></files><id index=\"0\"/>
            <field index=\"1\" term=\"http://rs.tdwg.org/dwc/terms/occurrenceID\"/>
            <field index=\"2\" term=\"http://rs.tdwg.org/dwc/terms/decimalLatitude\"/>
            <field index=\"3\" term=\"http://rs.tdwg.org/dwc/terms/decimalLongitude\"/>
            <field index=\"4\" term=\"http://rs.tdwg.org/dwc/terms/locality\"/>
          </core></archive>"""
        with tempfile.TemporaryDirectory() as tmp:
            archive = Path(tmp) / "test.zip"
            with zipfile.ZipFile(archive, "w") as handle:
                handle.writestr("meta.xml", meta)
                handle.writestr(
                    "occurrence.txt",
                    "internal\twrong1\twrong2\twrong3\twrong4\n1\tocc-1\t52.1\t4.3\tMeijendel\n",
                )
            rows = list(MODULE.iter_core_rows(archive))
        self.assertEqual(rows[0]["occurrenceID"], "occ-1")
        self.assertEqual(rows[0]["decimalLatitude"], "52.1")
        self.assertEqual(rows[0]["locality"], "Meijendel")

    def test_selects_extension_rows_by_core_id(self):
        meta = """<archive xmlns=\"http://rs.tdwg.org/dwc/text/\">
          <core encoding=\"UTF-8\" fieldsTerminatedBy=\"\\t\"><files><location>event.txt</location></files><id index=\"0\"/></core>
          <extension encoding=\"UTF-8\" fieldsTerminatedBy=\"\\t\"><files><location>occurrence.txt</location></files><coreid index=\"0\"/><field index=\"1\" term=\"http://rs.tdwg.org/dwc/terms/occurrenceID\"/></extension>
        </archive>"""
        with tempfile.TemporaryDirectory() as tmp:
            archive = Path(tmp) / "test.zip"
            with zipfile.ZipFile(archive, "w") as handle:
                handle.writestr("meta.xml", meta)
                handle.writestr("event.txt", "one\ntwo\n")
                handle.writestr("occurrence.txt", "one\tocc-1\ntwo\tocc-2\n")
            rows = MODULE.select_first_extension(archive, {"two"})
        self.assertEqual(rows, [{"_core_id": "two", "occurrenceID": "occ-2"}])

    def test_selects_named_extension_when_archive_has_multiple_extensions(self):
        meta = """<archive xmlns=\"http://rs.tdwg.org/dwc/text/\">
          <core fieldsTerminatedBy=\"\\t\"><files><location>event.txt</location></files><id index=\"0\"/></core>
          <extension fieldsTerminatedBy=\"\\t\"><files><location>reference.txt</location></files><coreid index=\"0\"/></extension>
          <extension fieldsTerminatedBy=\"\\t\"><files><location>occurrence.txt</location></files><coreid index=\"0\"/><field index=\"1\" term=\"http://rs.tdwg.org/dwc/terms/scientificName\"/></extension>
        </archive>"""
        with tempfile.TemporaryDirectory() as tmp:
            archive = Path(tmp) / "test.zip"
            with zipfile.ZipFile(archive, "w") as handle:
                handle.writestr("meta.xml", meta)
                handle.writestr("event.txt", "one\n")
                handle.writestr("reference.txt", "one\n")
                handle.writestr("occurrence.txt", "one\tPlantago lanceolata\n")
            rows = MODULE.select_named_section(archive, "occurrence.txt", {"one"})
        self.assertEqual(rows[0]["scientificName"], "Plantago lanceolata")

    def test_explicit_meijendel_locality_is_separate_from_coordinate_hit(self):
        self.assertTrue(MODULE.explicit_meijendel_locality("Meijendel, Bierlap"))
        self.assertTrue(MODULE.explicit_meijendel_locality("Kijfhoek"))
        self.assertFalse(MODULE.explicit_meijendel_locality("Wassenaar"))


if __name__ == "__main__":
    unittest.main()
