#!/usr/bin/env python3
"""Exercise the candidate scan gate without network or Docker."""
from pathlib import Path
import subprocess
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]
HELPER=ROOT/'deploy/prepare_mysql_974_vps_remote.sh'
IMAGE='sha256:'+'a'*64
TAG='vwgm-mysql:candidate-974-'+'b'*12
SUMMARY='SAMENVATTING|kandidaat-'+('a'*12)+'|critical=0|high=0|fix_beschikbaar=0|zonder_fix=0'

class ScanGateTests(unittest.TestCase):
    def gate(self, output, status):
        with tempfile.TemporaryDirectory() as d:
            path=Path(d)/'scan';path.write_text(output+'\n')
            return subprocess.run(['bash','-c','source "$1"; check_candidate_scan "$2" "$3" "$4" "$5"',
                'test',str(HELPER),str(path),str(status),IMAGE,TAG],text=True,capture_output=True)
    def test_exact_clean_candidate_with_old_runtime_attention_is_accepted(self):
        r=self.gate(SUMMARY+'\nAANDACHT|container-image|meijendel-mysql|known finding\nAANDACHT|container-hygiene|onverwachte-imagetag='+TAG,1)
        self.assertEqual(r.returncode,0,r.stderr)
    def test_vulnerable_missing_or_wrong_candidate_blocks(self):
        for output in [SUMMARY.replace('high=0','high=1'),SUMMARY.replace('critical=0','critical=1'),'',SUMMARY.replace('a'*12,'c'*12)]:
            self.assertNotEqual(self.gate(output,1).returncode,0)
    def test_technical_failure_or_unexpected_hygiene_blocks(self):
        for output,status in [(SUMMARY,2),(SUMMARY+'\nURGENT|scanner|failure',1),(SUMMARY+'\nBLOKKADE|scanner|failure',1),(SUMMARY+'\nAANDACHT|container-hygiene|unexpected',1)]:
            self.assertNotEqual(self.gate(output,status).returncode,0)

if __name__=='__main__':unittest.main()
