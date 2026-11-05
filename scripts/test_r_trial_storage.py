#!/usr/bin/env python3
"""All local exploratory R CLIs must reject non-T7 output before reading fixtures."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
THREE = '''run_trim_2025_validation run_trim_2025_2000 run_trim_period_recovery assess_trim_500_validation audit_trim_500_index_gaps audit_trim_bridge_long_windows audit_trim_bridge_sensitivity audit_trim_bridge_zero_totals audit_trim_main_index_zeros build_trim_species_pilot_2025 compare_trim_index_summaries compare_trim_zero_count_models trim_random_plot_trial summarise_trim_species_pilot_2025 trim_endpoint_bootstrap'''.split()


class RTrialTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir=os.environ['TMPDIR'], prefix='r-storage-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.alias = Path('/tmp/t7-audit-' + self.root.name)
        self.alias.symlink_to(self.root, target_is_directory=True)
        self.addCleanup(self.alias.unlink)
        self.env = dict(os.environ, TMPDIR=str(self.alias))

    def test_cli_rejects_local_output_before_model_or_input_work(self):
        bad = str(REPO / 'README.md')  # Existing file: old code cannot create a product here.
        specs = [(n, [str(REPO), str(self.root), bad]) for n in THREE]
        specs += [(n, [str(REPO), str(self.root), str(self.root), bad]) for n in
                  ['assess_trim_2025_2000', 'assess_trim_period_2000', 'assess_trim_period_uncertainty']]
        specs += [('render_trim_random_trial', [str(self.root), str(self.root), bad]),
                  ('audit_trim_bootstrap_clusters', [str(self.root), bad]),
                  ('summarise_trim_bootstrap_pilot', [bad, '1', str(self.root / 'none.rds')]),
                  ('build_trim_bootstrap_bundle', ['--sql', str(self.root), '--bundle', bad, '--end-year', '2025', '--planned-replicates', '1', '--run-id', 'fixture']),
                  ('run_trim_bootstrap_batch', ['--bundle', str(self.root), '--output', bad, '--replicate-from', '1', '--replicate-to', '1'])]
        for name, args in specs:
            with self.subTest(script=name):
                result = subprocess.run(['Rscript', str(REPO/'R'/(name+'.R')), *args], env=self.env,
                                        text=True, capture_output=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('T7-uitvoer geweigerd:', result.stderr)

    def test_fixture_writer_rejects_local_output_before_processing_bundle(self):
        code = 'source(commandArgs(TRUE)[1]);write_trim_uncertainty_outputs(list(),list(),commandArgs(TRUE)[2],mode="fixture")'
        result = subprocess.run(['Rscript','-e',code,str(REPO/'R/write_trim_uncertainty_outputs.R'),str(REPO/'README.md')],env=self.env,text=True,capture_output=True)
        self.assertNotEqual(result.returncode,0)
        self.assertIn('T7-uitvoer geweigerd:',result.stderr)

    def test_shared_r_gate_allows_new_t7_output_and_rejects_child_symlinks(self):
        source = REPO / 'R/trial_storage.R'
        code = 'source(commandArgs(TRUE)[1]);root<-commandArgs(TRUE)[2];stopifnot(trial_output(file.path(root,"new"))==file.path(root,"new"));file.symlink(path.expand("~/Documents"),file.path(root,"cache"));x<-try(trial_output(root),silent=TRUE);stopifnot(inherits(x,"try-error"),grepl("T7-uitvoer geweigerd:",as.character(x)))'
        result = subprocess.run(['Rscript','-e',code,str(source),str(self.root)], env=self.env, text=True,capture_output=True)
        self.assertEqual(result.returncode,0,result.stderr)


if __name__ == '__main__':
    unittest.main()
