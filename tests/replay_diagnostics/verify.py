from pathlib import Path
import hashlib,json,subprocess,sys

root=Path(__file__).resolve().parents[2];work=Path(sys.argv[1]);tool=work/'inspect_run'
source=work/'plain.replay'
spray=work/'spray.replay'
changed=work/'changed.replay'
def run(name,left,right,arguments=(),expected=0):
    hashes={p:hashlib.sha256(p.read_bytes()).hexdigest() for p in [left,right]}
    result=subprocess.run([str(tool),str(left),str(right),*arguments],text=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=20)
    (work/(name+'.stderr')).write_text(result.stderr)
    assert result.returncode==expected,(name,result.stdout,result.stderr)
    for p,digest in hashes.items():assert hashlib.sha256(p.read_bytes()).hexdigest()==digest
    if expected==2:
        assert not result.stdout,(name,'partial report');return
    value=json.loads(result.stdout);(work/(name+'.json')).write_text(json.dumps(value,indent=2)+'\n');return value
assert run('equal',source,source)['equal']
value=run('changed',source,changed,expected=1)
assert not value['equal'] and value['total']==4 and not value['truncated']
fields={r['path']:r for r in value['fields']}
assert fields['$.players[0].hp']['expected']=='8' and fields['$.players[0].hp']['actual']=='7'
assert fields['$.players[0].scrap']['actual']=='7'
assert '$.players[0].ability_cd[0].remaining' in fields
assert any(path.startswith('$.shots.generations[') for path in fields)
limited=run('limited',source,changed,['--limit','2'],1)
assert limited['total']==4 and len(limited['fields'])==2 and limited['truncated']
run('different-ticks',source,spray,expected=2)
assert run('cross-tick',source,spray,['--allow-different-ticks'],1)['total']>0
run('bad-limit',source,source,['--limit','0'],2)
bad=work/'corrupt.replay';data=bytearray(source.read_bytes());data[-1]^=1;bad.write_bytes(data)
run('corrupt',source,bad,expected=2)
old=root/'tests/replay_scrapyard/fixtures/protocol6/plain.replay';run('old-version',source,old,expected=2)
print('REPLAY_DIAGNOSTICS_OK')
