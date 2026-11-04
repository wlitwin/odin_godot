#!/usr/bin/env python3
"""Test-only compile transaction provenance; forwards compiler args unchanged."""
from pathlib import Path
import argparse,hashlib,json,os,shutil,subprocess,sys
repo=Path(__file__).resolve().parents[3];p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
project=repo/'tests/box3d_soak/replay'
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def sources():
 result={}
 for name in ['box3d','core','runtime','godot','gdext','replay','build','scriptgen','tests/box3d_soak/replay','tests/replay_physics_net/fixture','examples/box3d_common','examples/replay_box3d/shared/adapter']:
  for f in (repo/name).rglob('*'):
   if f.is_file() and not any(t in f.parts for t in ['bin','.godot','__pycache__']) and '.gen.odin' not in f.name and not f.name.endswith('.uid'):result[str(f.relative_to(repo))]=sha(f)
 return dict(sorted(result.items()))
before=sources();(out/'sources-before.json').write_text(json.dumps(before,sort_keys=True,separators=(',',':'))+'\n')
compiler=Path(shutil.which(os.environ.get('ODIN','odin'))).resolve();wrapper=out/'record-odin.py';calls=out/'compiler-calls.jsonl'
wrapper.write_text('#!/usr/bin/env python3\nimport os,subprocess,sys,json\nwith open(os.environ["GATE_B_COMPILER_CALLS"],"a") as f:f.write(json.dumps({"argv":sys.argv[1:]})+"\\n")\nr=subprocess.run([os.environ["GATE_B_REAL_ODIN"]]+sys.argv[1:]);sys.exit(r.returncode)\n');wrapper.chmod(0o755)
env=os.environ.copy();env.update(ODIN=str(wrapper),GATE_B_REAL_ODIN=str(compiler),GATE_B_COMPILER_CALLS=str(calls),SKIP_CORE='1',SCRIPT_BUILD_FLAGS='-o:speed');command=['bash','build/build_scripts.sh',str(project)]
core_command=['bash','-c','source "$ROOT/build/common.sh"; atomic_odin_dll "$ROOT/core" "$BOX3D_RUNTIME_DIR/libodin_godot.dylib" -o:speed -debug']
core_env=env.copy();core_env.update(ROOT=str(repo),BOX3D_RUNTIME_DIR=str(project/'bin'))
with (out/'build.log').open('w') as log:
 result=subprocess.run(command,cwd=repo,env=env,stdout=log,stderr=subprocess.STDOUT)
 if result.returncode==0:result=subprocess.run(core_command,cwd=repo,env=core_env,stdout=log,stderr=subprocess.STDOUT)

after=sources();(out/'sources-after.json').write_text(json.dumps(after,sort_keys=True,separators=(',',':'))+'\n')
changed=[n for n in set(before)|set(after) if before.get(n)!=after.get(n)]
binaries={name:sha(project/'bin'/name) for name in ['libodin_godot.dylib','libodinscripts.dylib','libogb3.dylib']} if result.returncode==0 else {}
binding={'command':command,'core_command':core_command,'exit_code':result.returncode,'source_fence_unchanged':not changed,'source_manifest_sha256':sha(out/'sources-after.json'),'source_before_sha256':sha(out/'sources-before.json'),'source_after_sha256':sha(out/'sources-after.json'),'source_changed':changed,'compiler':{'path':str(compiler),'sha256':sha(compiler),'version':subprocess.run([str(compiler),'version'],capture_output=True,text=True).stdout.strip()},'compiler_calls':str(calls),'compiler_calls_sha256':sha(calls),'environment_flags':{k:env.get(k,'') for k in ['SCRIPT_BUILD_FLAGS','SKIP_CORE','BOX3D_NATIVE_LIBRARY']},'binaries':binaries,'core_binary_sha256':binaries.get('libodin_godot.dylib'),'script_binary_sha256':binaries.get('libodinscripts.dylib'),'native_binary_sha256':binaries.get('libogb3.dylib'),'generated_sources':{str(f.relative_to(repo)):sha(f) for f in (project/'scripts').glob('*.gen.odin')},'configuration':'Odin speed+debug / Native Release'}
(project/'bin/gate-b-build-binding.json').write_text(json.dumps(binding,indent=2)+'\n');(out/'build-binding.json').write_text(json.dumps(binding,indent=2)+'\n');print(json.dumps({'returncode':result.returncode,'changed':changed,'binding':str(out/'build-binding.json'),'sha256':sha(out/'build-binding.json')},indent=2));sys.exit(0 if result.returncode==0 and not changed else 1)
