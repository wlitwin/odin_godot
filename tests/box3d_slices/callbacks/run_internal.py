#!/usr/bin/env python3
"""Compile the unchanged Core package plus a private test in owned scratch."""
import argparse,hashlib,json,pathlib,shutil,subprocess
p=argparse.ArgumentParser();p.add_argument('--out',required=True);p.add_argument('--odin',default='odin');p.add_argument('--native');a=p.parse_args()
repo=pathlib.Path(__file__).resolve().parents[3];out=pathlib.Path(a.out).resolve();out.mkdir(parents=True,exist_ok=False)
shutil.copytree(repo/'core',out/'core')
source=pathlib.Path(__file__).resolve().parent/'internal/callback_internal_test.odin';shutil.copy2(source,out/'core/callback_internal_test.odin')
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
fence={str(x.relative_to(repo)):sha(x) for x in sorted((repo/'core').rglob('*.odin'))}
command=[a.odin,'test',str(out/'core'),f'-collection:godot={repo}','-define:ODIN_TEST_THREADS=1',f'-out:{out}/core-tests']
if a.native:command.append('-define:MANAGED_TEST_NATIVE='+str(pathlib.Path(a.native).resolve()))
r=subprocess.run(command,cwd=repo,stdout=subprocess.PIPE,stderr=subprocess.STDOUT);(out/'test.log').write_bytes(r.stdout)
unchanged=all(sha(repo/x)==v for x,v in fence.items())
report=dict(result='PASS' if r.returncode==0 and unchanged else 'FAIL',command=command,exit_code=r.returncode,source_sha256=fence,test_sha256=sha(source),log_sha256=sha(out/'test.log'),scope='Direct actual Core finalizer/collect state controls; optional actual Native ledger charge/release; no production hook or Godot event claim',native_sha256=sha(pathlib.Path(a.native)) if a.native else None)
(out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
if report['result']!='PASS':raise SystemExit(1)
print(out/'report.json')
