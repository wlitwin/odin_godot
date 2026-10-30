from pathlib import Path
import hashlib,json,os,re,shutil,subprocess,sys
root=Path(__file__).resolve().parents[2];out=Path(sys.argv[1]).resolve();run=out/'transitions';run.mkdir(exist_ok=False);ext='dylib' if sys.platform=='darwin' else 'so';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for name,digest in json.loads((out/'prepared.json').read_text()).items():assert sha(out/'project'/name)==digest,name
for name,digest in json.loads((out/'framework.json').read_text()).items():assert sha(root/name)==digest,name
shutil.copy2(root/'tests/replay_cave_floor/transition.gd',run/'driver.gd')
(run/'inputs.json').write_text(json.dumps({'driver':sha(run/'driver.gd'),'binaries':{p.name:sha(p) for p in (out/'project/bin').glob('*.'+ext)}},indent=2)+'\n')
for mode,source_name in [('descent','before-descent'),('restart','before-restart')]:
 source=root/'tests/replay_cave/fixtures/content4'/(source_name+'.replay');target=run/(mode+'.replay')
 converted=subprocess.run([str(out/'upgrade'),str(source),str(target)],capture_output=True,text=True,timeout=30);assert converted.returncode==0,converted.stderr
 (run/(mode+'-convert.log')).write_text(converted.stdout+converted.stderr)
 env=os.environ.copy();env.update(ODIN_SCRIPTS_DLL=str(out/('project/bin/libodinscripts.'+ext)),REPLAY_CAVE_ROLE='solo',REPLAY_CAVE_TOKEN='cave-floor-legacy',REPLAY_CAVE_RESUME='1',REPLAY_CAVE_SAVE=str(target),REPLAY_CAVE_PERSIST='0',CAVE_FLOOR_CASE=mode,CAVE_FLOOR_OUT=str(run))
 with (run/(mode+'.log')).open('w') as log:
  result=subprocess.run([env['GODOT'],'--headless','--max-fps','60','--path',str(out/'project'),'--script',str(run/'driver.gd')],env=env,stdout=log,stderr=subprocess.STDOUT,timeout=20)
 text=(run/(mode+'.log')).read_text();assert result.returncode==0 and 'CAVE_FLOOR_TRANSITION_OK' in text and not re.search(r'ERROR:|SCRIPT ERROR|FAIL|instances were leaked|resources still in use',text),text
 assert json.loads((run/(mode+'.json')).read_text())['pass'];print(text.strip())
print('REPLAY_CAVE_FLOOR_TRANSITIONS_OK')
