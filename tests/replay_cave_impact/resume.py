from pathlib import Path
import hashlib,json,os,re,subprocess,sys
root=Path(__file__).resolve().parents[2];build,out=map(lambda x:Path(x).resolve(),sys.argv[1:3]);profile=sys.argv[3];out.mkdir(parents=True,exist_ok=False)
sys.path.insert(0,str(root/'tests/replay_cave'))
from current_fixtures import stage
target=out/'saved.checkpoint';row=stage('impact_server' if profile=='cave' else 'impact_owner',target)
expected=row['frame_hash'];identity=out/'identity';identity.write_bytes(bytes([row['identity_first_byte']])+bytes(15))
project=build/'project';ext='dylib' if sys.platform=='darwin' else 'so';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for n,h in json.loads((build/'framework.json').read_text()).items():assert sha(root/n)==h,n
env=os.environ|{'ODIN_GODOT_ROOT':str(root),'ODIN_SCRIPTS_DLL':str(project/('bin/libodinscripts.'+ext)),'REPLAY_CAVE_ROLE':'solo','REPLAY_CAVE_PROFILE':str(identity),'REPLAY_CAVE_PERSIST':'0','REPLAY_CAVE_RESUME':'1','REPLAY_CAVE_SAVE':str(target),'IMPACT_RESUME_HASH':expected}
with (out/'run.log').open('w') as log:result=subprocess.run([env['GODOT'],'--headless','--max-fps','60','--path',str(project),'--script',str(root/'tests/replay_cave_impact/resume.gd')],env=env,stdout=log,stderr=subprocess.STDOUT,timeout=25)
text=(out/'run.log').read_text();assert result.returncode==0 and 'REPLAY_CAVE_IMPACT_RESUME_OK' in text and not re.search(r'ERROR:|FAIL|instances were leaked',text),text
(out/'result.json').write_text(json.dumps({'pass':True,'profile':profile,'restored_tick':1,'expected_hash':expected,'epoch':2,'impact_and_loot':True,'binary_sha256':sha(project/('bin/libodinscripts.'+ext))},indent=2)+'\n')
print('REPLAY_CAVE_IMPACT_RESUME_OK',profile)
