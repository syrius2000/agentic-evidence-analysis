"""独立な比較・CLI失敗伝播・保存結果の再現性。実行結果を削除しない。"""
import json, math, subprocess, sys
from pathlib import Path
root=Path(sys.argv[1] if len(sys.argv)>1 else 'output/statistical_foundations/verified_0906')
load=lambda p:json.loads(p.read_text())
manifest=load(root/'case_manifest.json'); results={}
def check(name,ok):
    assert ok,name
    results[name]=True
    print('PASS:',name,flush=True)
def close(a,b): return abs(a-b)<=1e-8+1e-6*abs(b)
def readrun(id):return load(root/'runs'/f'run_{id[:16]}'/'evidence_results.json')
for id in manifest['configs']:
    r=readrun(id)
    check(id+' 計算・独立参照・MC',r['status']=='COMPUTED' and r['checks']['passed'] and r['posterior']['calibration']['passed'])
    check(id+' 全9モデル',len(r['models'])==9 and all(c['passed'] for c in r['checks']['per_model']))
for prefix in ['tit','hair']:
    a,b=readrun(prefix+'_1_dir'),readrun(prefix+'_100_dir')
    for baseline in ['M1','M7','M8']:
        ac,bc=a['cells'][baseline]['cells'],b['cells'][baseline]['cells']
        check(prefix+baseline+' 倍率不変',all(all(close(x[k],y[k]) for k in ['oe_ratio','log_oe_ratio','signed_deviance_per_sqrt_n','delta_g2_per_n','leverage']) for x,y in zip(ac,bc)))
        check(prefix+baseline+' 局所尤度の倍率感度',all(close(x['local_delta_g2']*100,y['local_delta_g2']) for x,y in zip(ac,bc)))
    check(prefix+' 生の条件付き割合不変',all(close(x['raw_proportion'],y['raw_proportion']) for x,y in zip(a['posterior']['conditional']['probabilities'],b['posterior']['conditional']['probabilities'])))
    check(prefix+' BFはN感度あり',not close(a['posterior']['exact_bf']['log_bf_sat_over_ind'],b['posterior']['exact_bf']['log_bf_sat_over_ind']))
for mult in [1,100]:
    a,b=readrun(f'tit_{mult}_exp'),readrun(f'tit_{mult}_dir')
    check(f'Titanic {mult} 目的変数で構造不変',a['models']==b['models'] and a['cells']==b['cells'])
# 故意に閉形式参照だけを壊すCLI。独立チェックの不合格が終了1まで伝播する。
fixture=root/'intentional_mismatch_runner.R'
fixture.write_text('''source(".agents/skills/vcd-bayesian-evidence-analysis/templates/three_way/analysis.R")
source("tests/statistical_foundations/reference_values.R")
source("tests/statistical_foundations/check_results.R")
bad_checker <- function(df,fit) {
 r<-extract_reference_values(df,c("A","B","C"),"n")
 r$models$M1$closed_form_fitted[1]<-r$models$M1$closed_form_fitted[1]+1
 check_results(df,fit,r)
}
cli_main(bad_checker)
''')
base=load(Path(manifest['configs']['tit_1_dir']))
def execute(id,runner='tests/statistical_foundations/run_validation.R'):
    c=dict(base,run_id=id)
    p=root/(id+'_config.json');assert not p.exists(),'テスト成果は保持。別の受入ディレクトリを使用'
    p.write_text(json.dumps(c,ensure_ascii=False,indent=2))
    s=subprocess.run(['Rscript',str(runner),'--config',str(p)],capture_output=True,text=True)
    (root/(id+'.log')).write_text(s.stdout+s.stderr)
    return s
s=execute('intentional_fail',fixture)
check('故意不一致の終了1',s.returncode==1 and readrun('intentional_fail')['status']=='CHECK_FAILED')
s=execute('reproduce')
check('再現実行終了0',s.returncode==0)
a,b=readrun('tit_1_dir'),readrun('reproduce')
for section in ['models','comparisons','cells','posterior','checks']:
    check('保存JSON再現 '+section,a[section]==b[section])
p=root/'reproduce_config.json'
s=subprocess.run(['Rscript','tests/statistical_foundations/run_validation.R','--config',str(p)],capture_output=True,text=True)
check('既存runの上書き拒否',s.returncode==1 and '実行先が存在' in s.stderr)
check('全再実行後も元CSV保持',load(root/'case_manifest.json')['source_sha256']==__import__('hashlib').sha256(Path('examples/titanic.csv').read_bytes()).hexdigest())
(root/'acceptance_test_results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2))
