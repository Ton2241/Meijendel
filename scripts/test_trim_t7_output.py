#!/usr/bin/env python3
"""Exercise entry points without fitting models; TMPDIR must be on mounted T7."""
import os
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

REPO = Path(__file__).resolve().parents[1]
BASE = Path('/Volumes/T7 Data/Home_Ton/Proefomgevingen')
spec = importlib.util.spec_from_file_location('trim_guard', REPO / 'scripts/check_trim_t7_output.py')
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)


class EntryPoints(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='guard-fixture-', dir=os.environ['TMPDIR'])
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        # R refuses spaces in TMPDIR; this small local reference still writes on T7.
        self.r_tmp = Path('/tmp') / ('trim-t7-' + self.root.name)
        self.r_tmp.symlink_to(self.root, target_is_directory=True)
        self.addCleanup(self.r_tmp.unlink)
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        stub = self.bin / 'Rscript'
        stub.write_text('#!/bin/sh\nprintf "%s\\n" "$@" >> "$CALLED"\n')
        stub.chmod(0o755)
        self.called = self.root / 'called'
        self.env = dict(os.environ, PATH=str(self.bin) + ':' + os.environ['PATH'], CALLED=str(self.called))
        self.sql = self.root / 'input.sql'
        self.sql.touch()
        self.run_root = self.root / 'run'
        bundle = self.run_root / 'input_bundle'
        bundle.mkdir(parents=True)
        (bundle / 'context.rds').touch()
        (bundle / 'identity.rds').touch()

    def worker(self, output, *extra, backend='local'):
        return self.invoke('scripts/run_trim_bootstrap_worker.sh', '--backend', backend,
                           '--input-dir', str(REPO), '--output-dir', str(output), *extra)

    def invoke(self, script, *args):
        return subprocess.run(['bash', str(REPO / script), *args], env=self.env, text=True, capture_output=True)

    def test_unknown_backend_does_not_create_output(self):
        output = self.root / 'unknown'
        result = self.worker(output, backend='unknown')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(output.exists())

    def test_worker_rejects_local_output_before_mkdir_or_r(self):
        output = REPO / 'outputs' / ('forbidden-' + self.root.name)
        # Never ask the old script to create an actual local product: it only creates an empty dir.
        self.addCleanup(lambda: output.rmdir() if output.is_dir() else None)
        result = self.worker(output, '--', '--output', str(output / 'batch.rds'))
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(output.exists())
        self.assertFalse(self.called.exists())

    def test_worker_rejects_forwarded_output_outside_approved_directory(self):
        output = self.root / 'worker'
        result = self.worker(output, '--', '--output', str(self.root / 'elsewhere.rds'))
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(output.exists())
        self.assertFalse(self.called.exists())

    def test_worker_rejects_missing_or_duplicate_forwarded_output(self):
        for args in [[], ['--output', str(self.root / 'a'), '--output', str(self.root / 'b')]]:
            with self.subTest(args=args):
                result = self.worker(self.root / 'worker', '--', *args)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(self.called.exists())

    def test_worker_allows_t7_output(self):
        output = self.root / 'worker with spaces'
        result = self.worker(output, '--', '--output', str(output / 'batch.rds'))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(output.is_dir())
        self.assertIn(str(output / 'batch.rds'), self.called.read_text())

    def test_local_runner_rejects_output_outside_t7_before_r(self):
        result = self.invoke('scripts/run_trim_bootstrap_local.sh', '--replicates', '1',
                             '--batch-size', '1', '--run-root', str(REPO / 'outputs' / 'forbidden'), '--sql', str(self.sql))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('T7-uitvoer geweigerd:', result.stderr)
        self.assertFalse(self.called.exists())

    def test_local_runner_allows_t7_and_keeps_batch_ranges(self):
        result = self.invoke('scripts/run_trim_bootstrap_local.sh', '--replicates', '3',
                             '--batch-size', '2', '--run-root', str(self.run_root), '--sql', str(self.sql))
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.called.read_text()
        self.assertIn('batch-000001-000002.rds', calls)
        self.assertIn('batch-000003-000003.rds', calls)

    def test_local_runner_rejects_escaping_batches_symlink(self):
        (self.run_root / 'batches').symlink_to(REPO / 'outputs', target_is_directory=True)
        result = self.invoke('scripts/run_trim_bootstrap_local.sh', '--replicates', '1',
                             '--batch-size', '1', '--run-root', str(self.run_root), '--sql', str(self.sql))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('T7-uitvoer geweigerd:', result.stderr)
        self.assertFalse(self.called.exists())

    def test_worker_rejects_symlinked_checkpoints_and_manifests(self):
        output = self.root / 'worker'
        output.mkdir()
        for suffix in ['.partial', '.manifest.rds']:
            with self.subTest(suffix=suffix):
                link = output / ('batch.rds' + suffix)
                link.symlink_to(REPO / 'README.md')
                try:
                    result = self.worker(output, '--', '--output', str(output / 'batch.rds'))
                    self.assertNotEqual(result.returncode, 0)
                    self.assertFalse(self.called.exists())
                finally:
                    link.unlink()

    def test_period_runner_rejects_escaping_root_files_and_batches(self):
        for name in ['identity.rds', 'config.rds', 'selected_periods.csv', 'reproduction.rds', 'batches']:
            with self.subTest(name=name):
                output = self.root / name.replace('.', '-')
                output.mkdir()
                link = output / name
                link.symlink_to(REPO / ('outputs' if name == 'batches' else 'README.md'))
                result = subprocess.run(['Rscript', str(REPO / 'R/run_trim_period_2000.R'), str(REPO),
                                         str(self.root), str(self.root), str(output)],
                                        env=dict(os.environ, TMPDIR=str(self.r_tmp)), text=True, capture_output=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('T7-uitvoer geweigerd:', result.stderr)

    def test_guard_rejects_missing_mount_even_when_directory_exists(self):
        with patch.object(guard.os.path, 'ismount', return_value=False):
            with self.assertRaisesRegex(ValueError, 'gemount'):
                guard.checked_output(str(self.root / 'new'))

    def test_plain_directory_cannot_impersonate_volume(self):
        fake = self.root / 'fake-volume'
        fake.mkdir()
        with patch.object(guard, 'T7', fake), patch.object(guard, 'TRIALS', fake / 'trials'):
            with self.assertRaisesRegex(ValueError, 'gemount'):
                guard.checked_output(str(fake / 'trials/task/output'))

    def test_guard_rejects_relative_root_sibling_traversal_and_symlink_escape(self):
        escape = self.root / 'escape'
        escape.symlink_to(REPO, target_is_directory=True)
        paths = ['relative/run', str(BASE), str(BASE / '../outside/output'),
                 str(BASE) + '-other/output', str(escape / 'outputs/new')]
        for value in paths:
            with self.subTest(value=value), self.assertRaises(ValueError):
                guard.checked_output(value)

    def test_guard_allows_physical_t7_descendant_with_spaces(self):
        value = self.root / 'new directory' / 'output'
        self.assertEqual(guard.checked_output(str(value)), value)
        self.assertFalse(value.exists())  # The guard only reads.

    def test_docker_validates_output_and_backend_before_any_mkdir(self):
        output = self.root / 'docker-output'
        for value in ['/tmp/batch.rds', '/work/output/../escaped.rds', '/work/output']:
            with self.subTest(value=value):
                result = self.worker(output, '--', '--output', value, backend='docker')
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(output.exists())
        result = self.worker(output, '--image-id', 'not-pinned', '--memory-limit', '1g',
                             '--remote-root', str(self.root), '--', '--output', '/work/output/batch.rds', backend='docker')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(output.exists())

    def test_docker_valid_path_retains_readonly_and_output_mounts(self):
        output = self.root / 'docker-output'
        docker = self.bin / 'docker'
        docker.write_text('#!/bin/sh\nprintf "%s\\n" "$@" > "$CALLED"\n')
        docker.chmod(0o755)
        result = self.worker(output, '--image-id', 'sha256:' + 'a' * 64, '--memory-limit', '1g',
                             '--remote-root', str(self.root), '--', '--output', '/work/output/batch.rds', backend='docker')
        self.assertEqual(result.returncode, 0, result.stderr)
        args = self.called.read_text().splitlines()
        self.assertIn('--read-only', args)
        self.assertIn('type=bind,src=' + str(REPO) + ',dst=/work/input,readonly', args)
        self.assertIn('type=bind,src=' + str(output) + ',dst=/work/output', args)
        self.assertFalse((self.root / 'bootstrap.lock').exists())

    def test_r_hashes_and_merge_accept_actual_t7_paths_with_spaces(self):
        fixture = self.root / 'hash with spaces.rds'
        fixture.write_bytes(b'abc')
        code = r"""
args<-commandArgs(TRUE);repo<-args[1];path<-args[2]
e<-new.env(parent=globalenv())
for(n in c('build_trim_bootstrap_bundle.R','run_trim_bootstrap_batch.R','merge_trim_bootstrap_batches.R'))sys.source(file.path(repo,'R',n),envir=e)
expected<-'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'
stopifnot(e$bundle_sha256_file(path)==expected,e$batch_sha256_file(path)==expected)
saveRDS(list(results=list(list(replicate_id=1L))),path)
saveRDS(list(identity=list(run_id='synthetic'),replicate_ids=1L,output_sha256=e$batch_sha256_file(path)),paste0(path,'.manifest.rds'))
stopifnot(identical(e$merge_trim_bootstrap_batches(path,1L)$replicate_ids,1L))
"""
        result = subprocess.run(['Rscript', '-e', code, str(REPO), str(fixture)],
                                env=dict(os.environ, TMPDIR=str(self.r_tmp)), text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_period_runner_rejects_local_root_before_loading_input(self):
        result = subprocess.run(['Rscript', str(REPO / 'R/run_trim_period_2000.R'), str(REPO),
                                 str(self.root), str(self.root), str(REPO / 'outputs' / 'forbidden')],
                                env=dict(os.environ, TMPDIR=str(self.r_tmp)), text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('T7-uitvoer geweigerd:', result.stderr)


if __name__ == '__main__':
    if not os.path.ismount('/Volumes/T7 Data') or not Path(os.environ.get('TMPDIR', '/')).resolve().is_relative_to(BASE):
        raise SystemExit('Tests vereisen gemounte T7 en TMPDIR onder Proefomgevingen.')
    unittest.main()
