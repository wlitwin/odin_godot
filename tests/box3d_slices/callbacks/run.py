#!/usr/bin/env python3
"""Actual Godot/Core managed callbacks; authored project copied per immutable run."""
import argparse,hashlib,json,os,pathlib,shutil,subprocess
p=argparse.ArgumentParser();p.add_argument('--out',required=True);p.add_argument('--native',required=True);p.add_argument('--godot',required=True);p.add_argument('--odin',default='odin');p.add_argument('--configuration',choices=['Debug','Release'],default='Debug');a=p.parse_args()
repo=pathlib.Path(__file__).resolve().parents[3];out=pathlib.Path(a.out).resolve();out.mkdir(parents=True,exist_ok=False);project=out/'project'
source=pathlib.Path(__file__).resolve().parent/'project'
shutil.copytree(source,project,ignore=shutil.ignore_patterns('bin','.godot','*.gen.odin','*.uid'))
env=os.environ.copy();env.update(ODIN_GODOT_ROOT=str(repo),ROOT=str(repo),BOX3D_NATIVE_LIBRARY=str(pathlib.Path(a.native).resolve()),ODIN=a.odin,ODIN_SCRIPTS_DLL=str(project/'bin'/('libodinscripts.dylib' if os.uname().sysname=='Darwin' else 'libodinscripts.so')))
# Existing helper deliberately defaults Core to debug. SCRIPT_BUILD_FLAGS and
# an explicit common.sh Core rebuild select Release optimization.
if a.configuration=='Release':
 env['SCRIPT_BUILD_FLAGS']='-o:speed'
records=[]
def sha(p):return hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()
paths=[*repo.glob('core/managed_callable*.odin'),*repo.glob('runtime/managed_callable*.odin'),repo/'core/scripts_native.odin',repo/'core/language.odin',repo/'core/main.odin',repo/'box3d/godot/host/registry.odin']
paths += [x for x in source.rglob('*') if x.is_file() and not any(z in x.parts for z in ('bin','.godot')) and not x.name.endswith(('.gen.odin','.uid'))]
fence={str(x.relative_to(repo)):sha(x) for x in sorted(paths)}
def run(name,argv,timeout=300):
 result=subprocess.run(argv,cwd=repo,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=timeout)
 log=out/(name+'.log');log.write_bytes(result.stdout);records.append(dict(name=name,argv=argv,exit_code=result.returncode,log=str(log),sha256=sha(log)))
 if result.returncode:raise RuntimeError(f'{name} failed: {log}')
 return result.stdout.decode(errors='replace')
report=dict(result='FAIL',scope='Actual official Godot custom Callable/Core boundary, not ENet or throughput certification',configuration=a.configuration,source_sha256=fence,native_sha256=sha(a.native),commands=records)
try:
 run('build',['bash',str(repo/'build/build_scripts.sh'),str(project)])
 if a.configuration=='Release':
  leaf='libodin_godot.dylib' if os.uname().sysname=='Darwin' else 'libodin_godot.so'
  run('core-release',['bash','-c','source "$1/build/common.sh"; BOX3D_RUNTIME_DIR="$2/bin"; atomic_odin_dll "$1/core" "$2/bin/$3" -o:speed -debug','managed-core',str(repo),str(project),leaf])
 # Freeze executables before reload overwrites the producer's published path.
 binaries={str(x.relative_to(project)):sha(x) for x in (project/'bin').iterdir() if x.is_file() and x.suffix in ('.so','.dylib')}
 report['initial_binaries']=binaries
 run('prepared-import',[a.godot,'--headless','--path',str(project),'--import'])
 log=run('callbacks',[a.godot,'--headless','--path',str(project),'--script','res://test_callbacks.gd','--','--reload'])
 for required in ['MANAGED_CALLBACKS_OK','CALLBACK_REENTRANT_BUSY_PRESERVED','CALLBACK_DROP_DECLINED','ODIN_RELOAD_GENERATION_LOADER_RELEASED','value=51']:
  assert required in log,required
 for forbidden in ['MANAGED_CALLBACK_FAIL','SCRIPT ERROR','SHUTDOWN_NOT_EMPTY','SHUTDOWN_LIVE','PANIC','USER ERROR']:
  assert forbidden not in log,forbidden
 start=log.index('MANAGED_CALLBACK_CLOSE_BEGIN');released=log.index('ODIN_RELOAD_GENERATION_LOADER_RELEASED');end=log.index('MANAGED_CALLBACK_CLOSE_RETURNED')
 assert start<log.index('CALLBACK_DESTRUCTOR_RETURN',start)<released<end
 assert all(sha(repo/path)==digest for path,digest in fence.items()),'source changed during run'
 report.update(result='PASS',post_reload_binaries={str(x.relative_to(project)):sha(x) for x in (project/'bin').iterdir() if x.is_file() and x.suffix in ('.so','.dylib')})
finally:
 (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
print(str(out/'report.json'))
