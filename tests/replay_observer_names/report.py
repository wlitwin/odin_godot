from pathlib import Path
import hashlib,json,sys
root=Path(sys.argv[1]).resolve();repo=Path(__file__).resolve().parents[2]
for name,h in json.loads((root/'source.json').read_text()).items():assert hashlib.sha256((root/'project'/name).read_bytes()).hexdigest()==h,name
for name,h in json.loads((root/'framework.json').read_text()).items():assert hashlib.sha256((repo/name).read_bytes()).hexdigest()==h,name
d=json.loads((root/'browser/result.json').read_text());rows=d['final'];assert len(rows)==3
mode=d.get('mode','planned');assert mode in ('planned','crash')
if mode=='crash':
 assert d['returned_host'] and d['returned_observer']
 for role in ['member-1-returned','member-3-returned']:assert 'REPLAY_SCRAPYARD_READY' in (root/f'browser/{role}.log').read_text()
 for row in rows:assert row['history'].count('Rhea (observer): fresh observer')==1
assert all(x['ready']==1 and x['epoch']==2 and x['players']==2 and x['pending']==0 for x in rows)
assert [x['seat'] for x in rows]==[1,2,0] and sum(x['authority'] for x in rows)==1 and rows[1]['authority']==1
assert d['promoted']['restored_exact']==1 and rows[2]['named_observer']==1
if 'status' in rows[2]:assert 'Observing' in rows[2]['status'] and not any(x in rows[2]['status'] for x in ['Shift','mouse fire','hold F'])
for row in rows:
 for line in ['host: before observer','Watcher Ω (observer): watching safely','host (observer): still an observer','host (observer): after migration']:assert row['history'].count(line)==1,(row['seat'],line)
assert 'REPLAY_OBSERVER_NAMES_OK' in (root/'driver.log').read_text()
assert 'WEB_AUTHORITY_SERVER_OK epoch=2' in (root/'server.log').read_text()
for role in ['host','client','observer']:assert 'REPLAY_SCRAPYARD_COMBAT_PEER_OK' in (root/f'native/{role}.log').read_text()
(root/'summary.json').write_text(json.dumps({'mode':mode,'returned_host':d.get('returned_host',False),'returned_observer':d.get('returned_observer',False),'observer_seat':0,'players':2,'epoch':2,'names_preserved':True,'exact_restore':True,'source_verified':True},indent=2)+'\n');print('OBSERVER_NAMES_REPORT_OK')
