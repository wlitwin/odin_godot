#!/usr/bin/env python3
"""Stage one ordinary authored sample in a NEW output; build only on explicit --build."""
from pathlib import Path
import argparse,hashlib,json,os,shutil,subprocess,sys
ROOT=Path(__file__).resolve().parents[2]
SHARED=Path(__file__).resolve().parent

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def files(folder):
 return [p for p in sorted(folder.rglob('*')) if p.is_file() and not any(x in p.parts for x in ['bin','.godot','__pycache__']) and not p.name.endswith(('.gen.odin','.uid')) and '.dSYM' not in str(p)]
def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--framework',choices=['kit','replay'],required=True);p.add_argument('--out',type=Path,required=True)
 p.add_argument('--native-library',type=Path,required=True);p.add_argument('--native-sha256')
 p.add_argument('--odin',default=os.environ.get('ODIN','odin'));p.add_argument('--godot',default=os.environ.get('GODOT',''))
 p.add_argument('--build',action='store_true');a=p.parse_args()
 source=ROOT/('examples/'+a.framework+'_box3d_authoring');out=a.out.resolve();out.mkdir(parents=True,exist_ok=False);project=out/'project'
 native=a.native_library.resolve();native_before=sha(native)
 if a.native_sha256 and native_before!=a.native_sha256:raise SystemExit('explicit Native SHA mismatch before build')
 content={str(p.relative_to(SHARED/'content')):sha(p) for p in files(SHARED/'content')}
 if {str(p.relative_to(source/'content')):sha(p) for p in files(source/'content')}!=content:raise SystemExit('example content differs from authoritative shared authored content')
 folders=[SHARED,source,ROOT/'addons/box3d_authoring',ROOT/'box3d/authoring',ROOT/'box3d/godot/authoring']
 before={str(p.relative_to(ROOT)):sha(p) for folder in folders for p in files(folder)}
 shutil.copytree(source,project,ignore=shutil.ignore_patterns('bin','.godot','__pycache__','*.dSYM'))
 addon=project/'addons/box3d_authoring';shutil.copytree(ROOT/'addons/box3d_authoring',addon)
 shutil.copytree(SHARED/'content',project/'content',dirs_exist_ok=True)
 (project/'shared').mkdir(exist_ok=True)
 for name in ['view.gd','visuals.tscn']:shutil.copyfile(SHARED/name,project/'shared'/name)
 # Optional editor tooling uses the one standard module location, never Core bypass.
 shutil.copytree(addon/'tool_module',project/'modules/box3d_authoring_tools')
 copied={str(p.relative_to(project/'content')):sha(p) for p in files(project/'content')}
 if copied!=content:raise SystemExit('actual copied content differs')
 command=['bash',str(ROOT/'build/build_scripts.sh'),str(project)]
 env=os.environ.copy();env.update(ROOT=str(ROOT),ODIN_GODOT_ROOT=str(ROOT),ODIN=a.odin,BOX3D_NATIVE_LIBRARY=str(native),SCRIPT_BUILD_FLAGS='-o:speed')
 if a.godot:env['GODOT']=a.godot
 code=None;error=None
 if a.build:
  try:
   with (out/'build.log').open('w') as log:code=subprocess.run(command,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=600).returncode
   if code:raise RuntimeError('ordinary sample SDK build failed')
  except Exception as exc:error=repr(exc)
 after={name:sha(ROOT/name) for name in before};source_ok=after==before;native_ok=sha(native)==native_before
 result='STAGED_ONLY' if not a.build else ('PASS' if code==0 and error is None and source_ok and native_ok else 'FAIL')
 if not source_ok or not native_ok:result='FAIL'
 binaries={str(p.relative_to(project)):sha(p) for p in (project/'bin').glob('*') if p.is_file()} if (project/'bin').exists() else {}
 report=dict(result=result,error=error,framework=a.framework,project=str(project),build_requested=a.build,actual_build_exit=code,build_argv=command,build_environment={k:env[k] for k in ['ROOT','ODIN_GODOT_ROOT','ODIN','BOX3D_NATIVE_LIBRARY','SCRIPT_BUILD_FLAGS']},source_before=before,source_fence_unchanged=source_ok,source_scope='selected authored sample/addon/shared extraction source roots; not exact compiler import trace',content_files_sha256=content,copied_content_byteexact=copied==content,shared_visual_sha256={n:sha(project/'shared'/n) for n in ['view.gd','visuals.tscn']},native_library=str(native),native_sha256=native_before,native_fence_unchanged=native_ok,actual_binaries_sha256=binaries,runtime_jobs_started=0,Native_builds_started=0,scope='ordinary source-free preparation/build only; Root owns actual import/runtime/network acceptance')
 (out/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(dict(result=result,project=str(project),report=str(out/'report.json'))));return 1 if result=='FAIL' else 0
if __name__=='__main__':raise SystemExit(main())
