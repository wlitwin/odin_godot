"""Resume the current ordinary-profile fixtures without historical converters."""
from pathlib import Path
import hashlib,json,os,re,subprocess,sys,shutil
root=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(root/'tests/replay_cave'))
from current_fixtures import CASES,stage
out=Path(sys.argv[1]).resolve();run=out/(sys.argv[2] if len(sys.argv)>2 else 'saved-fixtures');run.mkdir(exist_ok=False)
ext='dylib' if sys.platform=='darwin' else 'so'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
shutil.copy2(root/'tests/replay_cave_director/resume.gd',run/'resume.gd');results=[]
for index,row in enumerate(r for r in CASES.values() if r['profile']=='cave' and r['group']!='impact'):
 target=run/(row['id']+'.replay');stage(row['id'],target)
 env=os.environ.copy();env.update(ODIN_SCRIPTS_DLL=str(out/('project/bin/libodinscripts.'+ext)),REPLAY_CAVE_ROLE='solo',REPLAY_CAVE_TOKEN=row['token_label'],REPLAY_CAVE_RESUME='1',REPLAY_CAVE_SAVE=str(target),REPLAY_CAVE_PERSIST='0')
 with (run/(row['id']+'-resume.log')).open('w') as log:
  result=subprocess.run([env['GODOT'],'--headless','--max-fps','60','--path',str(out/'project'),'--script',str(run/'resume.gd')],env=env,stdout=log,stderr=subprocess.STDOUT,timeout=20)
 text=(run/(row['id']+'-resume.log')).read_text()
 assert result.returncode==0 and 'CAVE_DIRECTOR_RESUME_OK' in text and not re.search(r'ERROR:|SCRIPT ERROR|FAIL|instances were leaked|resources still in use',text),text
 assert sha(root/row['path'])==row['sha256'] and sha(target)==row['sha256']
 results.append({'id':row['id'],'sha256':row['sha256'],'tick':row['tick'],'frame_hash':row['frame_hash'],'resume':True})
 print('CURRENT_CAVE_FIXTURE_RESUMED',row['id'],flush=True)
assert len(results)==15
(run/'result.json').write_text(json.dumps(results,indent=2)+'\n')
print('REPLAY_CAVE_CURRENT_FIXTURES_OK',len(results))
