import os,subprocess,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
class ReleaseYearGuard(unittest.TestCase):
 def env(self):return {k:v for k,v in os.environ.items() if k not in ('MEIJENDEL_ANALYSIS_END_YEAR','MEIJENDEL_RELEASE_MANIFEST')}
 def test_no_export_or_remote_preflight_without_explicit_year(self):
  for name in ('deploy_meijendel_vps.sh','update_en_deploy_meijendel.sh'):
   result=subprocess.run(['bash',str(ROOT/'deploy'/name)],env=self.env(),capture_output=True,text=True)
   self.assertEqual(result.returncode,2);self.assertIn('MEIJENDEL_ANALYSIS_END_YEAR',result.stderr)
 def test_help_available_without_data_year(self):
  result=subprocess.run(['bash',str(ROOT/'deploy/deploy_meijendel_vps.sh'),'--help'],env=self.env(),capture_output=True,text=True)
  self.assertEqual(result.returncode,0);self.assertIn('Gebruik:',result.stdout)
if __name__=='__main__':unittest.main()
