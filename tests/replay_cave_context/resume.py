from pathlib import Path
import hashlib,json,os,re,shutil,subprocess,sys
root=Path(__file__).resolve().parents[2];prepared,upgrades,out=map(lambda p:Path(p).resolve(),sys.argv[1:]);out.mkdir(parents=True,exist_ok=False)
project=prepared/'project';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for n,h in json.loads((prepared/'prepared.json').read_text()).items():assert sha(project/n)==h,n
identity=out/'identity';identity.write_bytes(bytes([19])+bytes(15))
expected=re.search(r'hash=(-?\d+)',(upgrades/'converted.log').read_text())[1]
driver=out/'driver.gd';shutil.copy2(root/'tests/replay_cave_context/resume.gd',driver)
ext='dylib' if sys.platform=='darwin' else 'so'
env=os.environ.copy();env.update(ODIN_GODOT_ROOT=str(root),ODIN_SCRIPTS_DLL=str(project/('bin/libodinscripts.'+ext)),REPLAY_CAVE_ROLE='solo',REPLAY_CAVE_PROFILE=str(identity),REPLAY_CAVE_PERSIST='0',REPLAY_CAVE_RESUME='1',REPLAY_CAVE_SAVE=str(upgrades/'converted.checkpoint'),OWNER_UPGRADE_HASH=expected)
with (out/'run.log').open('w') as log:
    result=subprocess.run([env['GODOT'],'--headless','--path',str(project),'--script',str(driver)],env=env,stdout=log,stderr=subprocess.STDOUT,timeout=25)
text=(out/'run.log').read_text()
assert result.returncode==0 and 'REPLAY_CAVE_OWNER_UPGRADE_RESUME_OK' in text and not re.search(r'ERROR:|FAIL|instances were leaked',text),text
(out/'result.json').write_text(json.dumps({'pass':True,'expected_frame_hash':expected,'tick':1,'epoch':2,'deferred_commands_settled':2,'continued_loot':True,'driver_sha256':sha(driver),'binary_sha256':sha(project/('bin/libodinscripts.'+ext))},indent=2)+'\n')
print('REPLAY_CAVE_OWNER_UPGRADE_FRESH_PROCESS_OK')
