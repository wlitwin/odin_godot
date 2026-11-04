#!/usr/bin/env python3
"""Run the immutable independent-process functional matrix on one target."""
import argparse,hashlib,json,pathlib,subprocess,sys,time
ROOT=pathlib.Path(__file__).resolve().parents[2]
def sha(p):return hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--debug',required=True);ap.add_argument('--release',required=True);ap.add_argument('--out',required=True);ap.add_argument('--inspector',required=True);a=ap.parse_args()
 out=pathlib.Path(a.out).resolve();assert not out.exists() or not any(out.iterdir()),'immutable matrix output exists';out.mkdir(parents=True,exist_ok=True)
 builds={cfg:pathlib.Path(value).resolve() for cfg,value in [('Debug',a.debug),('Release',a.release)]};manifests={};cases=[]
 for cfg,path in builds.items():
  m=json.loads((path/'endpoint-manifest.json').read_text());assert m['configuration']==cfg
  for name,b in m['binaries'].items():assert sha(b['path'])==b['sha256']
  for p,digest in m['sources'].items():assert sha(ROOT/p)==digest,('frozen source changed',p)
  manifests[cfg]={'path':str(path/'endpoint-manifest.json'),'sha256':sha(path/'endpoint-manifest.json'),'native_archive_sha256':m['native_archive_sha256']}
 for cfg,path in builds.items():
  for framework in ('kit','replay'):
   episodes=[('corpus',1,None,None),('corpus',7,None,None),('lifetime',1,None,None),('malformed',1,None,None),('fault',1,None,None)]
   episodes += [('incompatible',1,mode,str(path/'replay-schema') if mode=='schema' and framework=='replay' else None) for mode in ('assets','rules','schema')]
   opposite=builds['Release' if cfg=='Debug' else 'Debug'];episodes.append(('incompatible',1,'build',str(opposite/framework)))
   for scenario,seed,mode,client in episodes:
    name=f'{cfg}-{framework}-{scenario}-{mode or seed}';dest=out/name
    cmd=[sys.executable,str(ROOT/'tests/box3d_network/run.py'),'--exe',str(path/framework),'--framework',framework,'--out',str(dest),'--scenario',scenario,'--seed',str(seed),'--ticks','300']
    if mode:cmd+=['--mode',mode]
    if client:cmd+=['--client-exe',client]
    started=time.monotonic()
    with (out/(name+'.log')).open('w') as log:result=subprocess.run(cmd,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
    item={'name':name,'command':cmd,'exit_code':result.returncode,'elapsed_seconds_observation':time.monotonic()-started,'result':str(dest/'result.json')}
    if result.returncode==0:
     summary=json.loads((dest/'result.json').read_text());assert summary['success'] and all(c==0 for c in summary['exit_codes']);item.update(compared_confirmed_frames=summary['compared_confirmed_frames'],features=summary['features'],result_sha256=sha(dest/'result.json'))
     if scenario=='fault':
      trace=dest/'role2-generation1/first.trace';inspect=[a.inspector,str(trace)]
      with (dest/'inspect.log').open('w') as output:subprocess.run(inspect,stdout=output,stderr=subprocess.STDOUT,check=True)
      assert 'BOX3D_TRACE_INSPECT_OK' in (dest/'inspect.log').read_text();item['trace_sha256']=sha(trace);item['inspector_command']=inspect
    cases.append(item);(out/'matrix-progress.json').write_text(json.dumps({'manifests':manifests,'cases':cases},indent=2)+'\n')
    if result.returncode:raise SystemExit(f'Failed {name}; preserved {dest}')
 for cfg,path in builds.items():
  for p,digest in json.loads((path/'endpoint-manifest.json').read_text())['sources'].items():assert sha(ROOT/p)==digest,('source changed during matrix',p)
 report={'schema_version':1,'status':'functional matrix passed','gate_b_whole_4ms':'UNMET; no performance acceptance claim','transport':'real local TCP framing; bounded test logical channels, not ENet/UDP deployment','manifests':manifests,'cases':cases,'total_cases':len(cases)}
 (out/'matrix-report.json').write_text(json.dumps(report,indent=2)+'\n');print(out/'matrix-report.json')
if __name__=='__main__':main()
