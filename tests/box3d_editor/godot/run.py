#!/usr/bin/env python3
"""One ordinary SDK/editor/runtime transaction, scheduled by Root only."""
from pathlib import Path
import argparse,hashlib,json,os,shutil,subprocess
ROOT=Path(__file__).resolve().parents[3]
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
 p=argparse.ArgumentParser(description=__doc__)
 for name in ['out','native-library','kit-frame-json','replay-frame-json']:p.add_argument('--'+name,type=Path,required=True)
 p.add_argument('--godot',required=True);p.add_argument('--odin',required=True)
 a=p.parse_args();out=a.out.resolve();out.mkdir(parents=True,exist_ok=False);project=out/'project'
 shutil.copytree(Path(__file__).parent/'project',project)
 shutil.copytree(ROOT/'addons/box3d_authoring',project/'addons/box3d_authoring')
 # Existing Core supports this standard modules directory only. No load bypass.
 shutil.copytree(ROOT/'addons/box3d_authoring/tool_module',project/'modules/box3d_authoring_tools')
 (project/'data').mkdir();frames={}
 for role,source in [('kit',a.kit_frame_json),('replay',a.replay_frame_json)]:
  target=project/'data'/(role+'-frame.json');shutil.copyfile(source,target)
  frames[role]=dict(source=str(source.resolve()),sha256=sha(source),copied_sha256=sha(target));assert frames[role]['sha256']==frames[role]['copied_sha256']
 folders=['addons/box3d_authoring','box3d/authoring','box3d/godot/authoring','box3d/debugdraw','box3d/godot/debugdraw','tests/box3d_editor/godot']
 source={str(f.relative_to(ROOT)):sha(f) for n in folders for f in sorted((ROOT/n).rglob('*')) if f.is_file() and '__pycache__' not in f.parts}
 env=os.environ.copy();env.update(ROOT=str(ROOT),ODIN_GODOT_ROOT=str(ROOT),ODIN=a.odin,GODOT=a.godot,BOX3D_NATIVE_LIBRARY=str(a.native_library.resolve()),SCRIPT_BUILD_FLAGS='-o:speed')
 native_before=sha(a.native_library);godot_before=sha(a.godot);steps=[];error=None
 commands=[('build',['bash',str(ROOT/'build/build_scripts.sh'),str(project)]),('import',[a.godot,'--headless','--editor','--path',str(project),'--quit-after','120']),('editor',[a.godot,'--headless','--editor','--path',str(project),'--quit-after','900']),('functional',[a.godot,'--headless','--path',str(project),'--script','test_runtime.gd'])]
 try:
  for name,argv in commands:
   run_env=env.copy()
   if name!='build':
    ext='dylib' if os.uname().sysname=='Darwin' else 'so';run_env['ODIN_SCRIPTS_DLL']=str(project/'bin'/('libodinscripts.'+ext))
   if name=='editor':run_env['BOX3D_EDITOR_CHECK']='1'
   with (out/(name+'.log')).open('w') as log:r=subprocess.run(argv,cwd=ROOT,env=run_env,stdout=log,stderr=subprocess.STDOUT,timeout=300)
   steps.append(dict(step=name,argv=argv,exit_code=r.returncode,log=str(out/(name+'.log'))))
   text=(out/(name+'.log')).read_text()
   if r.returncode or (name!='build' and any(x in text for x in ['SCRIPT ERROR','ERROR:','instances were leaked','resources still in use','CLEANUP_FAIL'])):raise RuntimeError(name+' failed/strictlog')
   if name=='editor' and 'BOX3D_EDITOR_CHECK_OK' not in text:raise RuntimeError('editor actual checks unavailable')
   if name=='functional' and 'BOX3D_EDITOR_RUNTIME_OK' not in text:raise RuntimeError('runtime actual checks unavailable')
 except Exception as exc:error=repr(exc)
 after={name:sha(ROOT/name) for name in source};source_ok=source==after;native_ok=sha(a.native_library)==native_before;godot_ok=sha(a.godot)==godot_before
 for role,record in frames.items():record['source_unchanged']=sha(record['source'])==record['sha256']
 report=dict(result='PASS' if error is None and source_ok and native_ok and godot_ok and all(v['source_unchanged'] for v in frames.values()) else 'FAIL',error=error,steps=steps,source_fence_unchanged=source_ok,source=source,source_scope='selected editor/debug/authoring source roots, not exact compiler import trace',native_library=str(a.native_library.resolve()),native_sha256=native_before,native_fence_unchanged=native_ok,godot_sha256=godot_before,godot_fence_unchanged=godot_ok,compiler_sha256=sha(a.odin),actual_framework_frames=frames,scope='real SDK/editor plugins/ArrayMesh/shared owning artifacts +actual detached Kit/Replay frame renderer; no manual pixel/GateC/whole-goal claim')
 (out/'report.json').write_text(json.dumps(report,indent=2)+'\n');return 0 if report['result']=='PASS' else 1
if __name__=='__main__':raise SystemExit(main())
