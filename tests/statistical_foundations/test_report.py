import json,subprocess,tempfile,shutil,sys
from pathlib import Path
root=Path(sys.argv[1] if len(sys.argv)>1 else 'output/statistical_foundations/verified_0906')
source=root/'runs/run_hair_1_dir';results={}
for label,edit in [('missing',lambda p:(p/'executive_summary.md').unlink()),('wrong_claim',lambda p:None),('wrong_hash',lambda p:None)]:
 with tempfile.TemporaryDirectory(prefix='threeway_report_') as td:
  d=Path(td)
  for f in ['evidence_results.json','analysis_config.json','executive_summary.md','quality_check.md','narrative_claims.json']:shutil.copy2(source/f,d/f)
  edit(d)
  c=json.loads((d/'narrative_claims.json').read_text())
  if label=='wrong_claim':c['claims'][0]['value']+=1
  if label=='wrong_hash':c['result_sha256']='bad'
  (d/'narrative_claims.json').write_text(json.dumps(c))
  s=subprocess.run(['Rscript','.agents/skills/vcd-bayesian-evidence-analysis/templates/three_way/render_report.R',str(d)],capture_output=True,text=True)
  assert s.returncode!=0 and not (d/'dashboard.html').exists(),label
  results[label]=True
for d in (root/'runs').glob('run_*'):
 if not (d/'dashboard.html').exists():continue
 s=(d/'dashboard.html').read_text()
 assert s.count('<svg ')==6 and '<html lang="ja">' in s and '保留' in s and '数値根拠' in s,d
 results[d.name]=True
(root/'report_test_results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2))
print(results)
