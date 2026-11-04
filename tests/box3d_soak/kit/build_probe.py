#!/usr/bin/env python3
"""Test-only explicit baseline wrapper; never changes production build scripts."""
import argparse,hashlib,json,os,shutil,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
OWN=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def manifest():
    result={}
    for base in ('box3d','kit','core','runtime','godot','gdext','decl','tests/box3d_soak/kit','tests/box3d_soak/native_observe','tests/replay_physics_net/fixture','examples/box3d_common'):
        folder=ROOT/base
        if not folder.exists():continue
        for p in folder.rglob('*'):
            # Production generated bindings are real compiler inputs. The copied
            # project's generated files are recorded after scriptgen below.
            copied_generated=OWN/'project' in p.parents and '.gen.' in p.name
            if p.is_file() and p.suffix in ('.odin','.h','.c','.py','.sh','.gd') and not copied_generated and not any(x in p.parts for x in ('bin','.godot','__pycache__')):
                result[str(p.relative_to(ROOT))]=sha(p)
    return result
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--stage',type=Path,required=True);parser.add_argument('--native',type=Path,required=True)
    parser.add_argument('--native-observation',action='store_true',help='test-only opt-in ABI binding; requires opted-in Native')
    args=parser.parse_args();args.stage.mkdir(parents=True,exist_ok=False);project=args.stage/'project'
    shutil.copytree(OWN/'project',project,ignore=shutil.ignore_patterns('bin','.godot','*.dSYM'))
    before=manifest();mp=args.stage/'source-manifest.json';mp.write_text(json.dumps(before,indent=2,sort_keys=True)+'\n')
    env=os.environ.copy();env.update(BOX3D_NATIVE_LIBRARY=str(args.native.resolve()),SKIP_CORE='1',SCRIPT_BUILD_FLAGS='-o:speed')
    if args.native_observation:env['SCRIPT_BUILD_FLAGS']+=' -define:GATE_B_NATIVE_OBSERVATION=true'
    commands=[['bash',str(ROOT/'build/build_scripts.sh'),str(project)]]
    # ROOT must be explicit before sourcing common.sh; preserve its normal flags.
    commands.append(['bash','-c','set -euo pipefail\nROOT="$1"\nsource "$ROOT/build/common.sh"\nBOX3D_RUNTIME_DIR="$2/bin"\natomic_odin_dll "$ROOT/core" "$2/bin/libodin_godot.dylib" -o:speed -debug\npython3 "$ROOT/build/box3d_profile.py" --prepare-import "$2"','gate-b-core',str(ROOT),str(project)])
    steps=[];exit_code=0
    for i,cmd in enumerate(commands):
        log=args.stage/f'build-{i}.log'
        with log.open('w') as out:p=subprocess.run(cmd,cwd=ROOT,env=env,stdout=out,stderr=subprocess.STDOUT)
        steps.append({'argv':cmd,'exit_code':p.returncode,'log':str(log),'sha256':sha(log)})
        if p.returncode:exit_code=p.returncode;break
    after=manifest();(args.stage/'source-manifest-after.json').write_text(json.dumps(after,indent=2,sort_keys=True)+'\n')
    generated={str(p.resolve()):sha(p) for p in (project/'scripts').glob('*.gen.odin')} if exit_code==0 else {}
    # Absolute generated paths identify the exact copied inputs, rather than an
    # unrelated generated file left in the repository authoring project.
    compiled_sources=before|generated
    mp.write_text(json.dumps(compiled_sources,indent=2,sort_keys=True)+'\n')
    record={'exit_code':exit_code,'source_fence_unchanged':before==after,'source_manifest_sha256':sha(mp),
            'configuration':'Odin speed+debug / Native Release','environment':{k:env[k] for k in ('BOX3D_NATIVE_LIBRARY','SKIP_CORE','SCRIPT_BUILD_FLAGS')},
            'steps':steps,'generated_source_files':generated,
            'production_generated_source_count':sum('.gen.' in Path(k).name for k in before),
            'source_changes':{k:[before.get(k),after.get(k)] for k in before.keys()|after.keys() if before.get(k)!=after.get(k)}}
    if exit_code==0:
        record.update({key:sha(project/'bin'/name) for key,name in [('core_binary_sha256','libodin_godot.dylib'),('script_binary_sha256','libodinscripts.dylib'),('native_binary_sha256','libogb3.dylib')]})
        record['native_runtime']=json.loads((project/'bin/box3d-runtime.json').read_text())
    (args.stage/'compiled-build.json').write_text(json.dumps(record,indent=2,sort_keys=True)+'\n')
    print(json.dumps({'exit':exit_code,'source_unchanged':before==after,'project':str(project)}))
    return exit_code or (0 if before==after else 1)
if __name__=='__main__':raise SystemExit(main())
