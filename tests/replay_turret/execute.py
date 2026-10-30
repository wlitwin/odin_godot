from pathlib import Path
import json,os,subprocess,sys
root=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(root/'replay/testing/tools'))
from peers import Peer,free_port,run
work=Path(sys.argv[1]).resolve();project=work/'project';out=work/'turret-peers';out.mkdir(exist_ok=False)
ext='dylib' if sys.platform=='darwin' else 'so'
env=os.environ|{'ODIN_SCRIPTS_DLL':str(project/f'bin/libodinscripts.{ext}'),'RSY_DEV':'1','RSY_PERSIST':'0','RSY_RUN':'0','RSY_ENCOUNTER':'turret','RSY_PORT':str(free_port()),'RSY_LATENCY':'120','RSY_RESULT_DIR':str(out),'RSY_SETTINGS_PATH':str(out/'settings.json')}
with (out/'workbench.log').open('w') as log:
 subprocess.run([os.environ['GODOT'],'--headless','--max-fps','60','--path',str(project),'--script','turret_workbench_test.gd'],env=env,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=30)
receipt=(out/'workbench.log').read_text()
assert 'REPLAY_TURRET_WORKBENCH_OK' in receipt,receipt
assert not any(x in receipt for x in ['SCRIPT ERROR','ERROR:','_FAIL','instances were leaked','resources still in use']),receipt
peers=[]
for role in ['host','client','observer']:
 peers.append(Peer(role,[os.environ['GODOT'],'--headless','--max-fps','60','--path',str(project),'--script','turret_peers.gd'],env|{'RSY_ROLE':role,'RSY_TOKEN':'turret-'+role},('REPLAY_TURRET_PEER_OK','REPLAY_SCRAPYARD_COMBAT_PEER_OK')))
result=run(peers,out,timeout=75,hash_pattern=r'RSY_COMBAT_HASH role=\w+ tick=(\d+) hash=(\d+)')
(out/'result.json').write_text(json.dumps({'pass':True,'roles':list(result['hashes']),'hashes':result['hashes'],'latency_ms':120},indent=2)+'\n')
print('REPLAY_TURRET_PEERS_OK')
