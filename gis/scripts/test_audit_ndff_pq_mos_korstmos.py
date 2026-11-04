import unittest

from audit_ndff_pq_mos_korstmos import classify, nullable_mysql_value


class ClassificationTests(unittest.TestCase):
    def test_strict_unique_match_precedes_other_candidates(self):
        self.assertEqual(classify(1, 1, 1, 1, 1), "sterk_strikt")

    def test_near_match_does_not_become_exact(self):
        self.assertEqual(classify(0, 1, 1, 1, 1), "nabij_kandidaat")

    def test_ambiguous_match_is_not_declared_independent(self):
        self.assertEqual(classify(0, 0, 1, 1, 1), "meervoudige_kandidaat")

    def test_no_match_is_not_independence(self):
        self.assertEqual(classify(0, 0, 0, 0, 0), "geen_datum_taxon_match")

    def test_mysql_null_is_empty_in_csv(self):
        self.assertEqual(nullable_mysql_value("NULL"), "")
        self.assertEqual(nullable_mysql_value(r"\N"), "")
        self.assertEqual(nullable_mysql_value("42"), "42")


if __name__ == "__main__":
    unittest.main()
