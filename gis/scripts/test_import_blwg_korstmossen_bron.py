"""Contract tests for the primary BLWG lichen source import."""

import unittest

from import_blwg_korstmossen_bron import (
    build_form_matrix, db_match_status, match_results, validate_source,
)


class BlwgSourceImportTest(unittest.TestCase):
    def test_group_match_uses_database_enum_value(self):
        self.assertEqual(db_match_status("group"), "groep")
        self.assertEqual(db_match_status("direct"), "direct")

    def test_parallel_forms_are_not_forced_onto_individual_ndff_ids(self):
        source = [
            {"row": 2, "key": (14, "2015-01-01", "Cladonia foliacea")},
            {"row": 3, "key": (14, "2015-01-01", "Cladonia foliacea")},
            {"row": 4, "key": (14, "2015-01-01", "Cetraria aculeata")},
        ]
        ndff = [
            {"id": 11, "key": source[0]["key"]},
            {"id": 12, "key": source[0]["key"]},
            {"id": 13, "key": source[2]["key"]},
        ]
        matched, links = match_results(source, ndff, "a" * 64, "public")
        self.assertEqual([m["direct_id"] for m in matched], [None, None, 13])
        self.assertEqual([m["match_status"] for m in matched], ["group", "group", "direct"])
        self.assertEqual(len(links), 3)
        self.assertEqual(matched[0]["group_hash"], matched[1]["group_hash"])
        self.assertNotEqual(matched[0]["group_hash"], matched[2]["group_hash"])

    def test_missing_ndff_record_aborts_before_import(self):
        source = [{"row": 2, "key": (14, "2000-01-01", "Cladonia foliacea")}]
        with self.assertRaisesRegex(ValueError, "NDFF multiset mismatch"):
            match_results(source, [], "a" * 64, "public")

    def test_form_and_observation_plot_date_must_agree(self):
        plots = {14: {"plot": 14}}
        forms = {1785: {"kopid": 1785, "plot": 14, "date": "2025-03-03"}}
        observations = [{"row": 2, "kopid": 1785, "plot": 14, "date": "2025-03-04"}]
        with self.assertRaisesRegex(ValueError, "form/date mismatch"):
            validate_source(plots, forms, observations)

    def test_only_confirmed_fixed_form_gets_a_true_zero(self):
        forms = {
            1: {"plot": 14, "kopid": 1},
            2: {"plot": 284, "kopid": 2},
        }
        observations = [
            {"row": 2, "kopid": 1, "name": "Cladonia foliacea", "quantity": 2},
            {"row": 3, "kopid": 2, "name": "Cladonia foliacea", "quantity": 5},
        ]
        matrix = build_form_matrix(forms, observations,
                                   ("Cladonia foliacea", "Cetraria aculeata"))
        self.assertEqual([(r["kopid"], r["name"], r["status"], r["quantity"])
                          for r in matrix], [
            (1, "Cetraria aculeata", "echte_nul", 0),
            (1, "Cladonia foliacea", "waargenomen", 2),
            (2, "Cladonia foliacea", "waargenomen", 5),
        ])


if __name__ == "__main__":
    unittest.main()
