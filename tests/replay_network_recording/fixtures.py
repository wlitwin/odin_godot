from pathlib import Path
import gzip,hashlib,json,sys
root=Path(__file__).resolve().parents[2]
out=Path(sys.argv[1]).resolve();out.mkdir(parents=True,exist_ok=True)
fixtures=root/'tests/replay_network_recording/fixtures/current'
manifest=json.loads((fixtures/'manifest.json').read_text())
assert set(manifest)=={'host.rplrec.gz','client.rplrec.gz','browser.rplrec.gz'}
for index,name in enumerate(('host.rplrec.gz','client.rplrec.gz','browser.rplrec.gz')):
 data=gzip.decompress((fixtures/name).read_bytes())
 assert len(data)==manifest[name]['bytes'] and hashlib.sha256(data).hexdigest()==manifest[name]['sha256']
 (out/f'{index}.rplrec').write_bytes(data)
print('REPLAY_RECORDING_CURRENT_FIXTURES_READY')
