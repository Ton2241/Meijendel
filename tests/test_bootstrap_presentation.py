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
        self.assertEqual(sum(r['n_planned']==2000 for r in bundle['long']),32)
        self.assertEqual(sum(r['n_planned']==500 for r in bundle['long']),124)
        self.assertTrue(all(r['n_planned']==500 for key in ('periods','annual') for r in bundle[key]))
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


class AnnualRateContract(unittest.TestCase):
    def test_known_growth_and_decline(self):
        rows=[{'jaar':year,'value':100*1.03**(year-1990)} for year in range(1990,2026)]
        self.assertAlmostEqual(p.annual_rate(rows,1990,2025)['estimate_pct_per_year'],3,places=10)
        rows=[{'jaar':year,'value':100*.98**(year-1990)} for year in range(1990,2026)]
        self.assertAlmostEqual(p.annual_rate(rows,1990,2025)['estimate_pct_per_year'],-2,places=10)

    def test_no_shift_no_dropped_zero_or_gap(self):
        rows=[{'jaar':year,'value':100} for year in range(1990,2026)]
        self.assertIsNone(p.annual_rate(rows,1958,2025)['estimate_pct_per_year'])
        self.assertIsNone(p.annual_rate(rows[:4]+rows[5:],1990,2025)['estimate_pct_per_year'])
        rows[4]['value']=0
        self.assertEqual(p.annual_rate(rows,1990,2025)['reason'],'nulindex')
        self.assertIsNone(p.annual_rate(rows,1990,2025)['estimate_pct_per_year'])

    def test_complete_inventory(self):
        bundle=p.build_bundle(ROOT/'trim/bootstrap/species_2025_2000_20261103')
        self.assertEqual(len(bundle['annual_rates']),312)
        self.assertEqual({r['start_year'] for r in bundle['annual_rates']},{1958,1990})

class PeriodSourceContract(unittest.TestCase):
    def test_separate_assessment_is_used_and_bound_to_its_manifest(self):
        import tempfile,json,shutil
        archive=ROOT/'trim/bootstrap/species_2025_2000_20261103'
        with tempfile.TemporaryDirectory() as folder:
            target=Path(folder)
            for name in ('periods.csv','annual_indices.csv'):shutil.copyfile(archive/name,target/name)
            meta=dict(species=156,period='1958-2025',formal_intervals=False,first500_preserved_exact=True,
                      run_id='period-test',parent_context_sha256='context',identity={'source_hash':'source'})
            (target/'period_manifest.json').write_text(json.dumps(meta))
            b=p.build_bundle(archive,period_source=target)
            self.assertEqual(b['period_assessment']['run_id'],'period-test')
            self.assertEqual(b['period_assessment']['source_hash'],'source')
            self.assertEqual(b['period_assessment']['parent_context_sha256'],'context')
            meta['formal_intervals']=True;(target/'period_manifest.json').write_text(json.dumps(meta))
            with self.assertRaises(ValueError):p.build_bundle(archive,period_source=target)

class ConsumerContract(unittest.TestCase):
    def test_integral_consumer_inventory(self):
        import tempfile
        with tempfile.TemporaryDirectory() as folder:
            website=Path(folder);app=website/'website/vwg-m-linux-app/app'
            (app/'templates').mkdir(parents=True)
            (app/'bootstrap_presentation.py').write_text('# fixture')
            (app/'templates/species_detail.html').write_text('bootstrap-preview.asp?view=simple')
            roles=p.release_consumers(ROOT,website)
            self.assertEqual(set(roles),{'dashboard','shiny','website'})
            self.assertTrue(all(len(h)==64 for files in roles.values() for h in files.values()))

if __name__ == '__main__': unittest.main()
