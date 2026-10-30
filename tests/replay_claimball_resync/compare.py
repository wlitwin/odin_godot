"""Replay one captured schedule against explicitly supplied prior receiver files."""
from pathlib import Path
import hashlib,json,os,re,subprocess,sys

root=Path(__file__).resolve().parents[2]
out,client,events,trace,current=map(lambda s:Path(s).resolve(),sys.argv[1:])
out.mkdir(parents=True,exist_ok=False);collection=out/'collection';collection.mkdir()
for p in root.iterdir():
    if p.name not in {'replay','.git'}: (collection/p.name).symlink_to(p,target_is_directory=p.is_dir())
(collection/'replay').mkdir()
for p in (root/'replay').iterdir():
    if p.name not in {'net','view'}:(collection/'replay'/p.name).symlink_to(p,target_is_directory=p.is_dir())
for package,filename,source in [('net','client.odin',client),('view','events.odin',events)]:
    dest=collection/'replay'/package;dest.mkdir()
    for p in (root/'replay'/package).iterdir():
        if p.name!=filename:(dest/p.name).symlink_to(p,target_is_directory=p.is_dir())
    (dest/filename).write_bytes(source.read_bytes())
with (out/'build.log').open('w') as log:
    subprocess.run([os.environ.get('ODIN','odin'),'build',str(root/'tests/replay_claimball_trace/replay'),f'-collection:godot={collection}',f'-out:{out/"replay-before"}'],stdout=log,stderr=subprocess.STDOUT,check=True)
results={}
for name,exe in [('before',out/'replay-before'),('after',current)]:
    r=subprocess.run([str(exe),str(trace)],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=60)
    (out/f'{name}.log').write_text(r.stdout)
    results[name]={'exit':r.returncode,'sha256':hashlib.sha256(exe.read_bytes()).hexdigest()}
assert results['before']['exit']==1 and 'TRACE_STATE_MISMATCH' in (out/'before.log').read_text()
assert results['after']['exit']==0 and 'CLAIMBALL_TRACE_REPLAY_OK' in (out/'after.log').read_text()
match=re.search(r'TRACE_STATE_MISMATCH frame=(\d+) expected=Frame\{(.*?)\} actual=Frame\{(.*?)\}',(out/'before.log').read_text());assert match
expected=dict(item.split(' = ',1) for item in match[2].split(', '))
actual=dict(item.split(' = ',1) for item in match[3].split(', '))
assert int(expected['changes'])>0 and actual['changes']=='0'
assert {k:v for k,v in expected.items() if k not in {'changes','changes_hash'}}=={k:v for k,v in actual.items() if k not in {'changes','changes_hash'}}
results['difference']={'frame':int(match[1]),'expected_changes':int(expected['changes']),'prior_changes':0,'all_other_frame_fields_equal':True}
results['trace_sha256']=hashlib.sha256(trace.read_bytes()).hexdigest()
results['prior_sources']={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in [client,events]}
(out/'result.json').write_text(json.dumps(results,indent=2)+'\n')
print('REPLAY_CLAIMBALL_RESYNC_BEFORE_AFTER_OK')
