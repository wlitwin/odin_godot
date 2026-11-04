#!/usr/bin/env python3
"""Production exported cases. Default is an inspectable plan with ZERO jobs."""
from pathlib import Path
import argparse,hashlib,importlib.util,json,os,platform,signal,subprocess,sys
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[3]
from plan import build_plan,CASES,TARGETS
import overlay

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def save(p,value):
 with Path(p).open('x') as f:json.dump(value,f,indent=2);f.write('\n');f.flush();os.fsync(f.fileno())
def inputs(plan,toolchain):
 hashes={}
 for key in ['godot','odin','native_library']:
  p=Path(plan['inputs'][key]);
  if not p.is_file() or (key!='native_library' and not os.access(p,os.X_OK)):raise ValueError('actual input unavailable: '+key)
  hashes[key]=sha(p)
 if hashes['native_library']!=plan['inputs']['native_sha256']:raise ValueError('actual Native SHA differs')
 if plan['target']=='macos-arm64':
  if platform.system()!='Darwin' or platform.machine().lower() not in ['arm64','aarch64']:raise ValueError('native MacARM64 host required')
 else:
  if platform.system()!='Linux':raise ValueError('run Linux case inside declared target userspace')
  spec=importlib.util.spec_from_file_location('existing_desktop_preflight',ROOT/'tests/box3d_desktop/run.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
  module.validate_linux_preflight(json.loads(Path(toolchain).read_text()),plan['execution_mode'],hashes)
  hashes['toolchain_report']=sha(toolchain)
 return hashes

def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--target',choices=TARGETS,required=True);p.add_argument('--framework',choices=['kit','replay'],required=True);p.add_argument('--case',choices=CASES,default='long')
 for name in ['godot','odin','native-library','native-sha256','out']:p.add_argument('--'+name,required=True)
 p.add_argument('--port',type=int,required=True);p.add_argument('--ticks',type=int);p.add_argument('--timeout',type=float);p.add_argument('--pause-at',type=int,default=240)
 p.add_argument('--execution-mode',choices=['native','translated-linux-x86_64']);p.add_argument('--toolchain-report');p.add_argument('--export-timeout',type=float,default=7200);p.add_argument('--execute',action='store_true')
 a=p.parse_args();config=vars(a)
 config['overlay_sha256']=overlay.describe(Path(__file__).with_name('pause_overlay'))['sha256']
 plan=build_plan(config,ROOT,sys.executable);output=Path(a.out).resolve()
 if output==ROOT or ROOT in output.parents:raise ValueError('actual output resolves into source repository')
 output.mkdir(parents=True,exist_ok=False)
 helpers=list(Path(__file__).parent.glob('*.py'))+list(Path(__file__).with_name('pause_overlay').iterdir())+[ROOT/'tests/box3d_gate_c/macos/export.py',ROOT/'tests/box3d_gate_c/linux/pipeline.py',ROOT/'tests/box3d_gate_c/run_exported.py',ROOT/'tests/box3d_samples/run.py']
 helper_before={str(p):sha(p) for p in helpers if p.is_file()};plan['helper_sources']=helper_before;save(output/'plan.json',plan)
 if not a.execute:print(json.dumps({'result':'STAGED_ONLY','plan':str(output/'plan.json'),'jobs_started':0}));return 0
 report={'schema':1,'result':'FAIL','plan':str(output/'plan.json'),'steps':[],'scope':plan['scope']};error=None
 try:
  report['actual_inputs']=inputs(plan,a.toolchain_report)
  env=os.environ.copy();env.update(ODIN=a.odin,GODOT=a.godot)
  for step in plan['steps']:
   log=output/(step['name']+'.log')
   with log.open('xb') as f:
    process=subprocess.Popen(step['argv'],cwd=ROOT,env=env,stdout=f,stderr=subprocess.STDOUT,start_new_session=True)
    try:code=process.wait(timeout=a.export_timeout if step['name']=='ordinary_export' else plan['timeout_seconds']+60)
    except subprocess.TimeoutExpired:
     try:os.killpg(process.pid,signal.SIGKILL)
     except ProcessLookupError:pass
     process.wait(timeout=10);raise RuntimeError('owned step timeout '+step['name'])
    f.flush();os.fsync(f.fileno())
   record={'name':step['name'],'argv':step['argv'],'actual_pid':process.pid,'actual_exit':code,'log':str(log),'log_sha256':sha(log)};report['steps'].append(record)
   if code!=0:raise RuntimeError('actual '+step['name']+' failed; preserve result')
   data=json.loads(Path(step['record']).read_text())
   if data.get('result')!='PASS':raise RuntimeError('actual bound result failed '+step['name'])
   record.update(report=step['record'],report_sha256=sha(step['record']))
  report['result']='PASS'
 except Exception as exc:error=repr(exc);report['error']=error
 report['helper_fence_unchanged']=all(sha(p)==v for p,v in helper_before.items())
 if not report['helper_fence_unchanged']:report['result']='FAIL'
 save(output/'report.json',report);print(json.dumps({'result':report['result'],'report':str(output/'report.json'),'error':error}));return 0 if report['result']=='PASS' else 1
if __name__=='__main__':raise SystemExit(main())
