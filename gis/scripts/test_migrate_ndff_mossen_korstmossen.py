#!/usr/bin/env python3
"""Bescherm de DDL-grens van de NDFF-mos/korstmosverhuizing."""

import importlib.util
import unittest
from pathlib import Path


MODULE = Path(__file__).with_name("migrate_ndff_mossen_korstmossen.py")


def load_module():
    spec = importlib.util.spec_from_file_location("mos_migratie", MODULE)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class MigratieDDLTest(unittest.TestCase):
    def test_bronafnemers_lezen_de_fysieke_groepstabellen(self):
        scripts = MODULE.parent
        protocol = (scripts / "import_ndff_protocolkwaliteit.py").read_text()
        for function, table in (("korstmos_source_sql", "korstmossen_waarneming"),
                                ("mos_source_sql", "mossen_waarneming")):
            body = protocol.split(f"def {function}(", 1)[1].split("\ndef ", 1)[0]
            self.assertIn(f"FROM Meijendel.{table} o", body)
        audit = (scripts / "audit_blwg_korstmossen.py").read_text()
        importer = (scripts / "import_blwg_korstmossen_bron.py").read_text()
        self.assertIn("JOIN Meijendel.korstmossen_waarneming o", audit)
        self.assertIn("JOIN Meijendel.korstmossen_waarneming o", importer)
        spatial = (scripts / "import_meijendel_ruimtelijke_lagen.py").read_text()
        self.assertIn("FROM mossen_waarneming", spatial)
        self.assertIn("FROM korstmossen_waarneming", spatial)

    def test_bestaande_beveiligde_selectie_leest_alle_fysieke_bronnen(self):
        schema = (MODULE.parents[1] / "database" / "ndff_secure_schema.sql").read_text()
        canonical = schema.split("CREATE OR REPLACE VIEW v_ndff_canonieke_waarneming AS", 1)[1]
        canonical = canonical.split("CREATE OR REPLACE VIEW v_ndff_analyse_record AS", 1)[0]
        self.assertIn("Meijendel.ndff_open_waarneming_register", canonical)
        self.assertIn("Meijendel.mossen_waarneming", canonical)
        self.assertIn("Meijendel.korstmossen_waarneming", canonical)
        self.assertIn("r.opslag_tabel='mossen_waarneming'", canonical)
        self.assertIn("r.opslag_tabel='korstmossen_waarneming'", canonical)

    def test_nieuwe_schema_bevat_slechts_een_smal_register(self):
        module = load_module()
        sql = "\n".join(module.new_table_sql())
        self.assertIn("CREATE TABLE `Meijendel`.`ndff_open_waarneming_register`", sql)
        self.assertIn("UNIQUE KEY `uq_ndff_open_register_identity` (`identiteit_sha256`)", sql)
        self.assertNotIn("`raw_payload`", sql)
        self.assertNotIn("`openbare_geometrie`", sql)
        for group in ("mossen", "korstmossen"):
            self.assertIn(f"CREATE TABLE `Meijendel`.`{group}_waarneming` LIKE ", sql)
            self.assertIn(f"FOREIGN KEY (`waarneming_id`) REFERENCES `Meijendel`.`ndff_open_waarneming_register`", sql)
        self.assertNotIn("FOREIGN_KEY_CHECKS=0", sql)

    def test_voegt_eerst_nieuwe_fk_toe_en_verwijdert_dan_oude(self):
        module = load_module()
        rows = [
            ("mossen_recordselectie", "fk_mos_bron", "waarneming_id", "NO ACTION", "NO ACTION"),
            ("mossen_recordselectie", "fk_mos_canoniek", "canonieke_waarneming_id", "NO ACTION", "NO ACTION"),
        ]
        statements = module.fk_retarget_sql(rows)
        self.assertEqual(statements, [
            "ALTER TABLE `Meijendel`.`mossen_recordselectie` "
            "ADD CONSTRAINT `fk_mos_bron_mk` FOREIGN KEY (`waarneming_id`) "
            "REFERENCES `Meijendel`.`ndff_open_waarneming_register` (`waarneming_id`) "
            "ON UPDATE NO ACTION ON DELETE NO ACTION, "
            "ADD CONSTRAINT `fk_mos_canoniek_mk` FOREIGN KEY (`canonieke_waarneming_id`) "
            "REFERENCES `Meijendel`.`ndff_open_waarneming_register` (`waarneming_id`) "
            "ON UPDATE NO ACTION ON DELETE NO ACTION;",
            "ALTER TABLE `Meijendel`.`mossen_recordselectie` "
            "DROP FOREIGN KEY `fk_mos_bron`, DROP FOREIGN KEY `fk_mos_canoniek`;",
        ])

    def test_weigert_andere_fk_actie_en_identifier(self):
        module = load_module()
        for row in [
            ("mossen_recordselectie", "fk_mos_bron", "waarneming_id", "CASCADE", "NO ACTION"),
            ("mossen_recordselectie;DROP", "fk_mos_bron", "waarneming_id", "NO ACTION", "NO ACTION"),
        ]:
            with self.assertRaises(ValueError):
                module.fk_retarget_sql([row])

    def test_omschakeling_is_een_transactie_met_volledige_terugdraaiing(self):
        module = load_module()
        sql = module.swap_procedure_sql("Meijendel", original=810830,
                                        mosses=32353, lichens=28643)
        self.assertIn("START TRANSACTION;", sql)
        self.assertIn("DECLARE EXIT HANDLER FOR SQLEXCEPTION", sql)
        self.assertIn("ROLLBACK;", sql)
        self.assertIn("COMMIT;", sql)
        self.assertLess(sql.index("DELETE o FROM"), sql.index("COMMIT;"))
        self.assertLess(sql.index("NDFF-register mist bronregel"), sql.index("COMMIT;"))
        self.assertIn("cq_n<>749834", sql)

    def test_triggerinventaris_sluit_views_uit(self):
        source = MODULE.read_text()
        body = source.split("def _install_central_guards()", 1)[1].split("\ndef ", 1)[0]
        self.assertIn("TABLE_TYPE='BASE TABLE'", body)


if __name__ == "__main__":
    unittest.main()
