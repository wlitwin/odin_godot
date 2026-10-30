from pathlib import Path
import os,subprocess,sys,json
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/"replay/testing/tools"))
from peers import Peer,free_port,run
work=Path(sys.argv[1]).resolve();project=work/'project';out=work/'checks';out.mkdir(exist_ok=False)
ext='dylib' if sys.platform=='darwin' else 'so'
env=os.environ|{'ODIN_SCRIPTS_DLL':str(project/f'bin/libodinscripts.{ext}'),'RSY_PERSIST':'0','RSY_SETTINGS_PATH':str(out/'settings.json')}
with (out/'preview.log').open('w') as log:subprocess.run([os.environ['GODOT'],'--headless','--max-fps','60','--path',str(project),'--script','storm_preview.gd'],env=env,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=20)
assert 'STORMCALLER_PREVIEW_OK' in (out/'preview.log').read_text()
with (out/'workbench.log').open('w') as log:subprocess.run([os.environ['GODOT'],'--headless','--max-fps','60','--path',str(project),'--script','storm_workbench.gd'],env=env,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=35)
assert 'STORMCALLER_WORKBENCH_OK' in (out/'workbench.log').read_text()
for name in ['preview.log','workbench.log']:
 assert not any(s in (out/name).read_text() for s in ['SCRIPT ERROR','ERROR:','_FAIL','instances were leaked','resources still in use']),name
port=free_port()
peers=[]
for role in ['host','client','observer']:
 e=env|{'RSY_ROLE':role,'RSY_NAME':role,'RSY_TOKEN':'storm-'+role,'RSY_PORT':str(port),'RSY_RUN':'0','RSY_REQUIRE_STOCK':'1','RSY_LATENCY':'120','RSY_SEED':'1337','RSY_RESULT_DIR':str(out),'RSY_ENCOUNTER':'stormcaller'}
 peers.append(Peer(role,[os.environ['GODOT'],'--headless','--max-fps','60','--path',str(project),'--script','storm_peers.gd'],e,('STORMCALLER_PEER_OK','REPLAY_SCRAPYARD_COMBAT_PEER_OK')))
result=run(peers,out,hash_pattern=r'RSY_COMBAT_HASH role=\w+ tick=(\d+) hash=(\d+)')
hashes=list(result['hashes'].values())
(out/'result.json').write_text(json.dumps({'pass':True,'roles':['host','client','observer'],'latency_ms':120,'hp':[8,10],'tick':hashes[0][0],'hash':hashes[0][1]},indent=2)+'\n')
print('STORMCALLER_PEERS_OK',hashes[0])
