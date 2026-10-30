"""Drive loaded-recording UI against an already prepared native Hello build."""
from pathlib import Path
import json,hashlib,os,shutil,subprocess,sys,re
root=Path(__file__).resolve().parents[2];native=Path(sys.argv[1]).resolve();files=Path(sys.argv[2]).resolve();out=Path(sys.argv[3]).resolve();out.mkdir(exist_ok=False)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
ext='dylib' if sys.platform=='darwin' else 'so' if sys.platform.startswith('linux') else 'dll'
for name,digest in json.loads((native/'framework.json').read_text()).items():assert sha(root/name)==digest,name
for name,digest in json.loads((native/'prepared.json').read_text()).items():assert sha(native/'project'/name)==digest,name
driver=out/'driver.gd';shutil.copy2(root/'tests/replay_recording/playback.gd',driver)
(out/'inputs.json').write_text(json.dumps({'driver':sha(driver),'files':{p.name:sha(p) for p in files.glob('*.rplrec')},'binaries':{p.name:sha(p) for p in (native/'project/bin').glob('*.'+ext)}},indent=2)+'\n')
for mode in ('headless','rendered'):
 result=out/mode;result.mkdir();env=os.environ.copy();env.update(PLAYBACK_RESULT_DIR=str(result),PLAYBACK_FILES=str(files),ODIN_SCRIPTS_DLL=str(native/('project/bin/libodinscripts.'+ext)))
 if mode=='rendered':env['PLAYBACK_CAPTURE']=str(result/'mismatch.png')
 with (result/'game.log').open('w') as log:
  process=subprocess.Popen([env['GODOT']]+(['--headless'] if mode=='headless' else [])+['--fixed-fps','60','--path',str(native/'project'),'--script',str(driver)],env=env,stdout=log,stderr=subprocess.STDOUT)
  try:code=process.wait(timeout=60)
  finally:
   if process.poll() is None:
    process.terminate()
    try:process.wait(timeout=5)
    except subprocess.TimeoutExpired:process.kill();process.wait()
 text=(result/'game.log').read_text();assert code==0 and not re.search(r'SCRIPT ERROR|ERROR:|FAIL|instances were leaked|resources still in use',text),(mode,code,text[-3000:])
 assert json.loads((result/'result.json').read_text())['pass']
 print(mode,'REPLAY_PLAYBACK_OK',flush=True)
