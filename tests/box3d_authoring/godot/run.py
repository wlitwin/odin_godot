#!/usr/bin/env python3
"""One ordinary SDK build/import/headless authoring transaction, when Root grants it."""
from pathlib import Path
import argparse, hashlib, json, os, shutil, subprocess

ROOT=Path(__file__).resolve().parents[3]
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--out',type=Path,required=True);p.add_argument('--native-library',type=Path,required=True)
 p.add_argument('--godot',required=True);p.add_argument('--odin',required=True)
 a=p.parse_args();out=a.out.resolve();out.mkdir(parents=True,exist_ok=False);project=out/'project'
 shutil.copytree(Path(__file__).parent/'project',project)
 shutil.copytree(ROOT/'addons/box3d_authoring',project/'addons/box3d_authoring')
 folders=['addons/box3d_authoring','box3d/authoring','box3d/godot/authoring','tests/box3d_authoring/godot']
 source={str(f.relative_to(ROOT)):sha(f) for n in folders for f in sorted((ROOT/n).rglob('*')) if f.is_file() and '__pycache__' not in f.parts}
 env=os.environ.copy();env.update(ROOT=str(ROOT),ODIN_GODOT_ROOT=str(ROOT),ODIN=a.odin,GODOT=a.godot,BOX3D_NATIVE_LIBRARY=str(a.native_library.resolve()),SCRIPT_BUILD_FLAGS='-o:speed')
 native_before=sha(a.native_library);godot_before=sha(a.godot)
 steps=[];error=None
 commands=[['bash',str(ROOT/'build/build_scripts.sh'),str(project)],
           [a.godot,'--headless','--editor','--path',str(project),'--quit-after','120'],
           [a.godot,'--headless','--path',str(project),'--script','test_authoring.gd']]
 try:
  for name,argv in zip(['build','import','functional'],commands):
   if name!='build':
    ext='dylib' if os.uname().sysname=='Darwin' else 'so';env['ODIN_SCRIPTS_DLL']=str(project/'bin'/('libodinscripts.'+ext))
   with (out/(name+'.log')).open('w') as log:r=subprocess.run(argv,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=300)
   steps.append(dict(step=name,argv=argv,exit_code=r.returncode,log=str(out/(name+'.log'))))
   if r.returncode:raise RuntimeError(name+' failed')
  text=(out/'functional.log').read_text()
  if 'BOX3D_AUTHORING_OK' not in text or any(x in text for x in ['SCRIPT ERROR','ERROR:','instances were leaked','resources still in use','CLEANUP_FAIL']):raise RuntimeError('functional output/cleanup failed')
 except Exception as exc:error=repr(exc)
 after={name:sha(ROOT/name) for name in source};fence=after==source
 native_fence=sha(a.native_library)==native_before;godot_fence=sha(a.godot)==godot_before
 report=dict(result='PASS' if error is None and fence and native_fence and godot_fence else 'FAIL',error=error,steps=steps,source_fence_unchanged=fence,source=source,source_scope='selected authoring source roots, not exact compiler import tracing',native_library=str(a.native_library.resolve()),native_sha256=native_before,native_fence_unchanged=native_fence,godot_sha256=godot_before,godot_fence_unchanged=godot_fence,compiler_sha256=sha(a.odin),scope='actual SDK module/Resource/node save-reload/source-free Native construction; not Kit/Replay adapter or GateC acceptance')
 (out/'report.json').write_text(json.dumps(report,indent=2)+'\n');return 0 if report['result']=='PASS' else 1
if __name__=='__main__':raise SystemExit(main())
