from pathlib import Path
import hashlib,json,os,re,subprocess,sys,shutil
root=Path(__file__).resolve().parents[2];out=Path(sys.argv[1]).resolve();run=out/(sys.argv[2] if len(sys.argv)>2 else 'upgrades');run.mkdir(exist_ok=False);ext='dylib' if sys.platform=='darwin' else 'so'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
inputs=[('content1/cave.replay','cave-definition-legacy'),('content2/cave.replay','cave-lobby-legacy')]+[(f'content3/{name}.replay','cave-director-legacy') for name in ('waiting','pending','spawning','rest')]+[(f'content4/{name}.replay','cave-floor-legacy') for name in ('before-descent','after-descent','before-restart')]+[(f'content5/{name}.replay','cave-relic-legacy') for name in ('resting','carried','restart')]+[(f'content6/{name}.replay','cave-carrier-legacy') for name in ('dead','disconnected')]+[('content7/old-host-carrier.replay','cave-adoption-legacy')]
shutil.copy2(root/'tests/replay_cave_director/resume.gd',run/'resume.gd');results=[]
for index,(relative,token) in enumerate(inputs):
 source=root/'tests/replay_cave/fixtures'/relative;before=sha(source);target=run/(str(index)+'.replay')
 converted=subprocess.run([str(out/'upgrade'),str(source),str(target)],capture_output=True,text=True,timeout=30)
 (run/(str(index)+'-convert.log')).write_text(converted.stdout+converted.stderr);assert converted.returncode==0,converted.stderr
 match=re.search(r'tick=(\d+) hash=(-?\d+)',converted.stdout);assert match
 (run/(str(index)+'.replay.json')).write_text(json.dumps({'tick':match[1],'hash':match[2]}))
 env=os.environ.copy();env.update(ODIN_SCRIPTS_DLL=str(out/('project/bin/libodinscripts.'+ext)),REPLAY_CAVE_ROLE='solo',REPLAY_CAVE_TOKEN=token,REPLAY_CAVE_RESUME='1',REPLAY_CAVE_SAVE=str(target),REPLAY_CAVE_PERSIST='0')
 with (run/(str(index)+'-resume.log')).open('w') as log:
  result=subprocess.run([env['GODOT'],'--headless','--max-fps','60','--path',str(out/'project'),'--script',str(run/'resume.gd')],env=env,stdout=log,stderr=subprocess.STDOUT,timeout=20)
 text=(run/(str(index)+'-resume.log')).read_text();assert result.returncode==0 and 'CAVE_DIRECTOR_RESUME_OK' in text and not re.search(r'ERROR:|SCRIPT ERROR|FAIL|instances were leaked|resources still in use',text),text
 output_hash=sha(target)
 refused=subprocess.run([str(out/'upgrade'),str(source),str(target)],capture_output=True,text=True,timeout=30);assert refused.returncode==1 and sha(target)==output_hash
 assert sha(source)==before
 results.append({'source':relative,'source_sha256':before,'converted_sha256':output_hash,'tick':int(match[1]),'resume':True,'existing_destination_preserved':True})
(run/'result.json').write_text(json.dumps(results,indent=2)+'\n');print('REPLAY_CAVE_DIRECTOR_UPGRADES_OK',len(results))
