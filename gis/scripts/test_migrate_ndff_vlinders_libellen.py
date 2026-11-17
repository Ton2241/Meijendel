"""Contractcontroles voor de NDFF-verhuizing en aannemelijke routekoppelingen."""

import unittest

from migrate_ndff_vlinders_libellen import (
    classify_libel_family,
    classify_vlinder_family,
    partition_for_group,
)


class MigrationContractTest(unittest.TestCase):
    def test_each_requested_group_has_one_physical_destination(self):
        for group in ("Dagvlinders", "Nachtvlinders", "Microvlinders"):
            self.assertEqual(partition_for_group(group), "vlinders_waarneming")
        self.assertEqual(partition_for_group("Libellen"), "libellen_waarneming")
        self.assertIsNone(partition_for_group("Vliesvleugeligen"))

    def test_voorlinden_is_a_route_without_tove_year(self):
        self.assertEqual(
            classify_vlinder_family(7, 2013, "Zwartsprietdikkopje"),
            (None, "voorlinden_aannemelijk"),
        )

    def test_vallei_eikenpage_is_separate_object(self):
        self.assertEqual(
            classify_vlinder_family(3, 2017, "Eikenpage"),
            (5169, "tove_routejaar_aannemelijk"),
        )
        self.assertEqual(
            classify_vlinder_family(3, 2017, "Icarusblauwtje"),
            (4588, "tove_routejaar_aannemelijk"),
        )
        self.assertEqual(
            classify_vlinder_family(3, 2018, "Eikenpage"),
            (None, "geen_tove_object"),
        )
        self.assertEqual(
            classify_vlinder_family(4, 2013, "Bruin zandoogje"),
            (638, "tove_routejaar_aannemelijk"),
        )

    def test_hertenkamp_poel_pair_is_not_forced(self):
        self.assertEqual(classify_libel_family(2), (None, "twee_poelen_onbeslist"))
        self.assertEqual(classify_libel_family(1), (8, "tove_locatiejaar_aannemelijk"))


if __name__ == "__main__":
    unittest.main()
