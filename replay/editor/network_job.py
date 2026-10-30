from pathlib import Path
import json,signal,sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'testing/tools'))
from peers import Peer,run
# Turn termination into normal unwinding so run() cleans all peer process groups.
def terminate(*_):raise KeyboardInterrupt()
signal.signal(signal.SIGTERM,terminate)
spec,out=map(Path,sys.argv[1:])
peers=[Peer(**value) for value in json.loads(spec.read_text())]
result=run(peers,out,timeout=70,hash_pattern=r'REPLAY_AUTHORING_HASH tick=(\d+) hash=(\d+)')
(out/'result.json').write_text(json.dumps({'ok':True,'hashes':result['hashes']},indent=2)+'\n')
print('REPLAY_AUTHORING_NETWORK_OK')
