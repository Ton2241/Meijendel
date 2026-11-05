"""Synthetic storage boundary checks; never starts databases or network jobs."""
import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
import subprocess
from types import SimpleNamespace
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]

def module(relative):
    spec = importlib.util.spec_from_file_location(Path(relative).stem, ROOT / relative)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value

class TrialStorageGuards(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir=os.environ['TMPDIR'])
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.forbidden = ROOT / 'outputs' / ('forbidden-' + self.root.name)
        self.recipe = dict(mode='local_rehearsal', analysis_root=str(ROOT), website_root=str(ROOT),
                           bootstrap_root=str(self.root / 'missing'), year_from=1958, year_to=2025)

    def test_native_checks_storage_before_config_read(self):
        native = module('scripts/rehearse_integral_release.py')
        with self.assertRaisesRegex(ValueError, 'T7'):
            native.NativeHooks(self.forbidden, ROOT)

    def test_trial_package_checks_storage_before_source_read(self):
        core = module('deploy/integral_release.py')
        with self.assertRaisesRegex(ValueError, 'T7'):
            core.build_package(self.recipe, self.forbidden)
        self.assertFalse(self.forbidden.exists())

    def test_gateway_prepare_checks_before_mkdir(self):
        client = module('deploy/integral_gateway_client.py')
        recipe = self.root / 'recipe.json'
        recipe.write_text(json.dumps(self.recipe))
        with patch.object(client, 'check_checkout', return_value='a' * 40), \
             patch.object(Path, 'mkdir', side_effect=AssertionError('mkdir before T7 guard')):
            with self.assertRaisesRegex(ValueError, 'T7'):
                client.prepare(recipe, None, self.forbidden, ROOT)

    def test_gateway_resume_checks_before_checkout_or_network(self):
        client = module('deploy/integral_gateway_client.py')
        prepared = self.root / 'prepared.json'
        prepared.write_text(json.dumps(dict(intent='isolated_trial', recipe=self.recipe, project_root=str(ROOT))))
        # This copy is a small fixture, but the output boundary must still reject a local resume root.
        with patch.object(Path, 'read_text', return_value=prepared.read_text()), \
             patch.object(client, 'check_checkout', side_effect=AssertionError('checkout before T7 guard')):
            with self.assertRaisesRegex(ValueError, 'T7'):
                client.execute(self.forbidden / 'prepared.json', 'preflight')

    def test_presentation_checks_before_source_read(self):
        builder = module('scripts/build_trim_bootstrap_presentation.py')
        args = ['builder', '--source', str(self.root / 'missing'), '--output', str(self.forbidden),
                '--parent-manifest', str(self.root / 'missing.json'), '--selection', str(self.root / 'selection.json')]
        with patch.object(sys, 'argv', args), self.assertRaisesRegex(ValueError, 'T7'):
            builder.main()

    def test_period_report_checks_before_mkdir(self):
        builder = module('scripts/build_trim_period_2000_report.py')
        args = ['builder', '--run', str(self.root / 'missing'), '--output', str(self.forbidden)]
        with patch.object(sys, 'argv', args), \
             patch.object(Path, 'mkdir', side_effect=AssertionError('mkdir before T7 guard')):
            with self.assertRaisesRegex(ValueError, 'T7'):
                builder.main()

    def test_legacy_native_cleanup_can_stop_but_cannot_restart_or_mutate(self):
        native = module('scripts/rehearse_integral_release.py')
        config = dict(pg_bin='/unused', postgres_database='vwg_release_fixture')
        with patch.object(native, 'read_json', return_value=config):
            hook = native.NativeHooks(self.forbidden, ROOT, allow_legacy_cleanup=True)
        with patch.object(hook, 'pgsql', side_effect=AssertionError('database before storage gate')):
            for action in ('start', 'apply', 'restore'):
                with self.subTest(action=action), self.assertRaisesRegex(ValueError, 'T7'):
                    getattr(hook, action)(self.root / 'missing')
        args = ['test', 'stop', '--root', str(self.forbidden)]
        with patch.object(sys, 'argv', args), patch.object(native, 'read_json', return_value=config), \
             patch.object(native.NativeHooks, 'stop') as stop:
            native.main()
            stop.assert_called_once()

    def test_native_accepts_t7_root_until_config_read(self):
        native = module('scripts/rehearse_integral_release.py')
        with self.assertRaises(FileNotFoundError):
            native.NativeHooks(self.root / 'native', ROOT)

    def test_native_rejects_child_symlink_before_config(self):
        native = module('scripts/rehearse_integral_release.py')
        (self.root / 'runtime').symlink_to(ROOT, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, 'T7'):
            native.NativeHooks(self.root, ROOT)

    def test_native_rejects_internal_postgres_before_apply_or_restore(self):
        native = module('scripts/rehearse_integral_release.py')
        hook = native.NativeHooks.__new__(native.NativeHooks)
        hook.root = self.root
        for action in ('apply', 'restore', 'start'):
            with self.subTest(action=action), patch.object(hook, 'pgsql', return_value='/usr/local/var/postgresql'), \
                 self.assertRaisesRegex(ValueError, 'T7'):
                getattr(hook, action)(self.root / 'missing')

    def test_native_rejects_external_postgres_tablespace(self):
        native = module('scripts/rehearse_integral_release.py')
        hook = native.NativeHooks.__new__(native.NativeHooks)
        hook.root = self.root
        with patch.object(hook, 'pgsql', side_effect=[str(self.root), str(ROOT)]), \
             self.assertRaisesRegex(ValueError, 'T7'):
            hook.guard_postgres()

    def test_recovery_exercise_checks_postgres_before_fault_injection(self):
        native = module('scripts/rehearse_integral_release.py')
        hook = native.NativeHooks.__new__(native.NativeHooks)
        hook.root = self.root
        candidate = self.root / 'candidate'
        old = self.root / 'old'
        def read(path):
            if path.name == 'activation-proof.json':
                return dict(attempted='candidate', phase='active')
            if path.name == 'last_backup.json':
                return dict(package=str(old))
            return dict(year_to=2025, source_hash='frozen', release_id=path.parent.name)
        args = ['test', 'exercise-recovery', '--root', str(self.root), '--candidate', str(candidate)]
        with patch.object(sys, 'argv', args), patch.object(native, 'NativeHooks', return_value=hook), \
             patch.object(native, 'read_json', side_effect=read), \
             patch.object(native.release, 'current', return_value=candidate), \
             patch.object(native.release, 'activate', side_effect=lambda root, package, hooks: hooks.apply(package)), \
             patch.object(hook, 'sql', side_effect=AssertionError('SQL mutation before PostgreSQL gate')), \
             patch.object(hook, 'pgsql', return_value='/usr/local/var/postgresql'), \
             self.assertRaisesRegex(ValueError, 'T7'):
            native.main()

    def test_period_report_checks_writable_assessment_source(self):
        builder = module('scripts/build_trim_period_2000_report.py')
        args = ['builder', '--run', str(ROOT / 'outputs' / 'internal-trial'), '--output', str(self.root / 'report')]
        with patch.object(sys, 'argv', args), self.assertRaisesRegex(ValueError, 'T7'):
            builder.main()

    def test_package_production_keeps_non_t7_staging(self):
        core = module('deploy/integral_release.py')
        # The absent source is reached only after production bypasses the local trial gate.
        with self.assertRaises(FileNotFoundError):
            core.build_package(self.recipe | dict(mode='production'), self.forbidden)

class DatabaseTrialGuards(unittest.TestCase):
    def mysql(self, args, **kwargs):
        sql = kwargs.get('input', '')
        if 'CREATE DATABASE' in sql or 'CREATE SCHEMA' in sql:
            raise AssertionError('database creation before T7 guard')
        return SimpleNamespace(returncode=0, stdout='/usr/local/mysql/data' if '@@datadir' in sql else '0', stderr='')

    def test_contract_database_creators_reject_imac_datadir(self):
        for name in ('test_maatregelen_schema_contract.py', 'test_maatregelen_seed_contract.py',
                     'test_maatregelen_migratie_contract.py', 'test_maatregel_registraties_migratie_contract.py'):
            with self.subTest(script=name), patch.object(subprocess, 'run', side_effect=self.mysql):
                script = module('gis/scripts/' + name)
                with self.assertRaisesRegex(ValueError, 'T7'):
                    script.main()

    def test_pq_release_database_creators_reject_imac_datadir(self):
        script = module('gis/scripts/test_import_external_ecology_sources.py')
        for entry in ('check_pq_release_retirement', 'check_pq_release_schema'):
            with self.subTest(entry=entry), patch.object(subprocess, 'run', side_effect=self.mysql):
                with self.assertRaisesRegex(ValueError, 'T7'):
                    getattr(script, entry)()

    def test_restore_source_copy_checks_datadir_before_backup_or_database(self):
        script = module('gis/scripts/import_external_ecology_sources.py')
        db = script.CentralQueryDatabase('Meijendel_bronnen_proef_20261105', writable=True)
        with patch.object(subprocess, 'run', side_effect=self.mysql), self.assertRaisesRegex(ValueError, 'T7'):
            script.restore_source_copy(db, Path('/missing-backup.gz'))

    def test_central_trial_migration_checks_datadir_before_backup_read(self):
        script = module('gis/scripts/import_external_ecology_sources.py')
        args = SimpleNamespace(centrale_bewijs_dir=Path('/missing-proof'), database='Meijendel_taxa_query_proef_20261105',
                               login_path='unused', mysql_client='unused', host='127.0.0.1', port=3306, apply=True)
        with patch.object(subprocess, 'run', side_effect=self.mysql), self.assertRaisesRegex(ValueError, 'T7'):
            script.execute_central_query_migration(args)

    def test_gis_rehearsals_reject_imac_datadir(self):
        with patch.object(sys, 'path', [str(ROOT / 'gis/scripts'), *sys.path]):
            for name in ('rehearse_ndff_mos_korstmos_restore.py', 'rehearse_ndff_mossen_korstmossen_partition.py'):
                script = module('gis/scripts/' + name)
                with self.subTest(script=name), patch.object(sys, 'argv', ['test', '--apply']), \
                     patch.object(subprocess, 'run', side_effect=self.mysql):
                    if hasattr(script, 'preflight'):
                        with patch.object(script, 'preflight'), self.assertRaisesRegex(ValueError, 'T7'):
                            script.main()
                    else:
                        with self.assertRaisesRegex(ValueError, 'T7'):
                            script.main()

class ShinyShellStorageGuards(unittest.TestCase):
    def setUp(self):
        import shutil
        self.temp = tempfile.TemporaryDirectory(dir=os.environ['TMPDIR'])
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.scripts = self.root / 'scripts'
        self.scripts.mkdir()
        for name in ('build_shiny_image_local.sh', 'generate_shiny_sbom.sh'):
            shutil.copy2(ROOT / 'scripts' / name, self.scripts / name)
        (self.scripts / 'test_shiny_reproducibility.sh').write_text('#!/bin/bash\nexit 0\n')
        (self.scripts / 'test_shiny_reproducibility.sh').chmod(0o700)
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        for name, source in dict(uname='echo Darwin',
                                 docker='echo DOCKER_REACHED >&2; exit 71',
                                 mktemp='echo MKTEMP_REACHED >&2; exit 72').items():
            path = self.bin / name
            path.write_text('#!/bin/bash\n' + source + '\n')
            path.chmod(0o700)
        self.env = os.environ | dict(PATH=str(self.bin) + ':' + os.environ['PATH'], TMPDIR=str(self.root))

    def shell(self, name, *args, temp=None):
        env = self.env | (dict(TMPDIR=str(temp)) if temp is not None else {})
        return subprocess.run(['bash', str(self.scripts / name), *map(str, args)], env=env,
                              text=True, capture_output=True)

    def test_local_image_build_blocks_unproven_docker_desktop_storage(self):
        result = self.shell('build_shiny_image_local.sh')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('T7', result.stderr)
        self.assertIn('Docker Desktop', result.stderr)
        self.assertNotIn('DOCKER_REACHED', result.stderr)
        self.assertNotIn('MKTEMP_REACHED', result.stderr)

    def test_sbom_rejects_internal_temporary_storage_before_docker(self):
        result = self.shell('generate_shiny_sbom.sh', 'test-image', self.root / 'bom.json', temp=ROOT)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('T7', result.stderr)
        self.assertNotIn('DOCKER_REACHED', result.stderr)
        self.assertNotIn('MKTEMP_REACHED', result.stderr)

    def test_linux_sbom_retains_remote_temporary_storage_procedure(self):
        (self.bin / 'uname').write_text('#!/bin/bash\necho Linux\n')
        result = self.shell('generate_shiny_sbom.sh', 'test-image', self.root / 'bom.json', temp=ROOT)
        self.assertIn('DOCKER_REACHED', result.stderr)
        self.assertNotIn('T7-uitvoer geweigerd', result.stderr)

    def test_sbom_accepts_t7_temporary_storage_before_docker(self):
        result = self.shell('generate_shiny_sbom.sh', 'test-image', self.root / 'bom.json')
        self.assertIn('DOCKER_REACHED', result.stderr)
        self.assertNotIn('MKTEMP_REACHED', result.stderr)

if __name__ == '__main__':
    unittest.main()
