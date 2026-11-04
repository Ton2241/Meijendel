import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('presentation', ROOT/'scripts/build_trim_bootstrap_presentation.py')
p = importlib.util.module_from_spec(spec)
spec.loader.exec_module(p)

class PresentationContract(unittest.TestCase):
    def test_archive_complete(self):
        bundle = p.build_bundle(ROOT/'trim/bootstrap/species_2025_2000_20261103')
        self.assertEqual([len(bundle[k]) for k in ('long','periods','annual')], [156,312,10608])
        self.assertEqual(bundle['publication_status'], 'diagnostisch')
        self.assertTrue(all(r['ci95_low'] is None and r['ci95_high'] is None for key in ('long','periods','annual') for r in bundle[key]))

    def test_bands_fail_closed(self):
        row = dict(baseline_index=0, n_valid=500, n_planned=500, complete_non_degenerate=True,
                   is_reference=False, diagnostic_low=0, diagnostic_high=5)
        self.assertEqual(p.diagnostic_band(row), (0,5))
        for change in (dict(is_reference=True),dict(n_valid=499),dict(complete_non_degenerate=False),dict(diagnostic_high=None),dict(diagnostic_low=-1)):
            self.assertIsNone(p.diagnostic_band(row | change))
        self.assertIsNone(p.diagnostic_band(row | dict(baseline_index=None)))
        self.assertEqual(p.number('0'), 0)
        self.assertIsNone(p.number(''))
        self.assertIsNone(p.number('NaN'))

    def test_corrupt_archive_rejected(self):
        bundle = p.build_bundle(ROOT/'trim/bootstrap/species_2025_2000_20261103')
        bundle['annual'].pop()
        with self.assertRaises(ValueError): p.validate_bundle(bundle)

if __name__ == '__main__': unittest.main()
