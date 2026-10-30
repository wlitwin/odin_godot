from pathlib import Path
import hashlib,json,os,re,subprocess,sys
root=Path(__file__).resolve().parents[2];build,upgrades,out=map(lambda x:Path(x).resolve(),sys.argv[1:4]);profile=sys.argv[4];out.mkdir(parents=True,exist_ok=False)
name='c8.checkpoint' if profile=='cave' else 'o2.checkpoint';rows=json.loads((upgrades/'result.json').read_text())['rows'];row=next(r for r in rows if r['source'].endswith('/'+name))
expected=re.search(r'hash=(-?\d+)',row['log'])[1];identity=out/'identity';identity.write_bytes(bytes([37])+bytes(15))
project=build/'project';ext='dylib' if sys.platform=='darwin' else 'so';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for n,h in json.loads((build/'framework.json').read_text()).items():assert sha(root/n)==h,n
env=os.environ|{'ODIN_GODOT_ROOT':str(root),'ODIN_SCRIPTS_DLL':str(project/('bin/libodinscripts.'+ext)),'REPLAY_CAVE_ROLE':'solo','REPLAY_CAVE_PROFILE':str(identity),'REPLAY_CAVE_PERSIST':'0','REPLAY_CAVE_RESUME':'1','REPLAY_CAVE_SAVE':str(upgrades/row['target']),'IMPACT_RESUME_HASH':expected}
with (out/'run.log').open('w') as log:result=subprocess.run([env['GODOT'],'--headless','--max-fps','60','--path',str(project),'--script',str(root/'tests/replay_cave_impact/resume.gd')],env=env,stdout=log,stderr=subprocess.STDOUT,timeout=25)
text=(out/'run.log').read_text();assert result.returncode==0 and 'REPLAY_CAVE_IMPACT_RESUME_OK' in text and not re.search(r'ERROR:|FAIL|instances were leaked',text),text
(out/'result.json').write_text(json.dumps({'pass':True,'profile':profile,'restored_tick':1,'expected_hash':expected,'epoch':2,'impact_and_loot':True,'binary_sha256':sha(project/('bin/libodinscripts.'+ext))},indent=2)+'\n')
print('REPLAY_CAVE_IMPACT_RESUME_OK',profile)
