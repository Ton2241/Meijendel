import unittest

from gis.scripts.rehearse_ndff_mos_korstmos_restore import child_filter, ident


class RestoreRehearsalSqlTest(unittest.TestCase):
    def test_child_filter_covers_both_foreign_keys(self):
        condition = child_filter("c", ("waarneming_id", "canonieke_waarneming_id"))
        self.assertIn("i.waarneming_id=c.waarneming_id", condition)
        self.assertIn("i.waarneming_id=c.canonieke_waarneming_id", condition)
        self.assertIn(" OR ", condition)

    def test_identifier_rejects_sql_injection(self):
        self.assertEqual(ident("ndff_open_waarneming"), "ndff_open_waarneming")
        with self.assertRaises(ValueError):
            ident("ndff_open_waarneming;DROP SCHEMA Meijendel")


if __name__ == "__main__":
    unittest.main()
