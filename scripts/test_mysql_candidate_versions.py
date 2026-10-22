#!/usr/bin/env python3
"""Run the actual validator against bounded runtime responses; no database or network."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

class RuntimeVersionTests(unittest.TestCase):
    def run_validator(self, source, target, expected, uid='1999'):
        with tempfile.TemporaryDirectory() as d:
            docker = Path(d) / 'docker'
            docker.write_text("#!/usr/bin/env python3\nimport os,sys\nargs=sys.argv[1:]\nif args[0]=='inspect': sys.exit(0)\ncontainer=args[1]\nif args[2:4]==['id','-u'] or args[2:4]==['id','-g']:\n print(os.environ['TARGET_UID'] if container=='target' else '1999');sys.exit(0)\nif 'SELECT VERSION()' in args:\n print(os.environ['SOURCE_VERSION'] if container=='source' else os.environ['TARGET_VERSION']);sys.exit(0)\nif any('mysqladmin ping' in a for a in args): sys.exit(0)\nprint('VERSIONS_ACCEPTED',file=sys.stderr);sys.exit(42)\n")
            docker.chmod(0o755)
            return subprocess.run(['bash', str(ROOT/'deploy/validate_mysql_uid_migration_vps_remote.sh'),
                                   'source','target','1999','1999',*expected],
                                  env={**os.environ,'PATH':d+os.pathsep+os.environ['PATH'],
                                       'SOURCE_VERSION':source,'TARGET_VERSION':target,'TARGET_UID':uid},
                                  text=True,capture_output=True)

    def test_explicit_upgrade_accepts_different_expected_versions(self):
        result=self.run_validator('9.7.1','9.7.4',['9.7.1','9.7.4'])
        self.assertIn('VERSIONS_ACCEPTED',result.stderr)

    def test_default_keeps_existing_971_contract(self):
        result=self.run_validator('9.7.1','9.7.1',[])
        self.assertIn('VERSIONS_ACCEPTED',result.stderr)
        result=self.run_validator('9.7.1','9.7.4',[])
        self.assertNotIn('VERSIONS_ACCEPTED',result.stderr)

    def test_wrong_source_or_target_blocks_before_database_inventory(self):
        for source,target in [('9.7.2','9.7.4'),('9.7.1','9.7.3')]:
            result=self.run_validator(source,target,['9.7.1','9.7.4'])
            self.assertNotIn('VERSIONS_ACCEPTED',result.stderr)
            self.assertNotEqual(result.returncode,0)

    def test_target_uid_remains_mandatory(self):
        result=self.run_validator('9.7.1','9.7.4',['9.7.1','9.7.4'],uid='999')
        self.assertNotIn('VERSIONS_ACCEPTED',result.stderr)
        self.assertIn('UID wijkt af',result.stderr)

if __name__=='__main__': unittest.main()
