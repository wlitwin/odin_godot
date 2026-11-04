#!/usr/bin/env python3
"""CLIENT_A functional wrapper: one explicit standard Core/scripts build."""
import argparse,hashlib,json,os,runpy,shutil,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[4]
OWN=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()

def main():
 p=argparse.ArgumentParser();p.add_argument('--stage',type=Path,required=True);p.add_argument('--native',type=Path,required=True);a=p.parse_args()
 a.stage.mkdir(parents=True,exist_ok=False);project=a.stage/'project';shutil.copytree(OWN/'project',project,ignore=shutil.ignore_patterns('bin','.godot','*.dSYM'))
 manifest=runpy.run_path(str(OWN.parent/'build_probe.py'))['manifest']
 before=manifest();mp=a.stage/'source-manifest.json';mp.write_text(json.dumps(before,indent=2,sort_keys=True)+'\n')
 env=os.environ.copy();env.update(BOX3D_NATIVE_LIBRARY=str(a.native.resolve()),SKIP_CORE='1',SCRIPT_BUILD_FLAGS='-o:speed')
 commands=[['bash',str(ROOT/'build/build_scripts.sh'),str(project)],['bash','-c','set -euo pipefail\nROOT="$1"\nsource "$ROOT/build/common.sh"\nBOX3D_RUNTIME_DIR="$2/bin"\natomic_odin_dll "$ROOT/core" "$2/bin/libodin_godot.dylib" -o:speed -debug\npython3 "$ROOT/build/box3d_profile.py" --prepare-import "$2"','normal-core',str(ROOT),str(project)]]
 steps=[];code=0
 for i,cmd in enumerate(commands):
  log=a.stage/f'build-{i}.log'
  with log.open('w') as out:result=subprocess.run(cmd,cwd=ROOT,env=env,stdout=out,stderr=subprocess.STDOUT)
  steps.append({'argv':cmd,'exit_code':result.returncode,'log':str(log),'sha256':sha(log)})
  if result.returncode:code=result.returncode;break
 after=manifest();(a.stage/'source-manifest-after.json').write_text(json.dumps(after,indent=2,sort_keys=True)+'\n')
 generated={str(x.resolve()):sha(x) for x in (project/'scripts').glob('*.gen.odin')} if code==0 else {}
 mp.write_text(json.dumps(before|generated,indent=2,sort_keys=True)+'\n')
 record={'exit_code':code,'source_fence_unchanged':before==after,'source_manifest_sha256':sha(mp),'configuration':'Odin Core+scripts speed+debug / Native Release','environment':{k:env[k] for k in ('BOX3D_NATIVE_LIBRARY','SKIP_CORE','SCRIPT_BUILD_FLAGS')},'steps':steps,'generated_source_files':generated,'source_changes':{k:[before.get(k),after.get(k)] for k in before.keys()|after.keys() if before.get(k)!=after.get(k)}}
 if code==0:
  for key,name in [('core_binary_sha256','libodin_godot.dylib'),('script_binary_sha256','libodinscripts.dylib'),('native_binary_sha256','libogb3.dylib')]:record[key]=sha(project/'bin'/name)
  record['native_runtime']=json.loads((project/'bin/box3d-runtime.json').read_text())
 (a.stage/'compiled-build.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps({'exit':code,'source_unchanged':before==after,'project':str(project)}));return code or (0 if before==after else 1)
if __name__=='__main__':raise SystemExit(main())
