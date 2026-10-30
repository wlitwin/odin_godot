from pathlib import Path
import hashlib,json,sys
root=Path(sys.argv[1]).resolve();repo=Path(__file__).resolve().parents[2]
for name,h in json.loads((root/'source-sha256.json').read_text()).items():assert hashlib.sha256((root/'project'/name).read_bytes()).hexdigest()==h,name
for name,h in json.loads((root/'framework-source.json').read_text()).items():assert hashlib.sha256((repo/name).read_bytes()).hexdigest()==h,name
traces=json.loads((root/'browser/render-traces.json').read_text());assert len(traces)==3 and all(t['binds']>0 and t['conflicts']==0 and not t['records'] for t in traces)
for member in (1,2,3):
 text=(root/f'browser/member-{member}.log').read_text();assert 'REPLAY_MESH2_WEB_OWNERSHIP_OK' in text and 'WebGL: INVALID_' not in text and 'SCRIPT ERROR' not in text
assert 'REPLAY_SCRAPYARD_BROWSER_UI_OK' in (root/'driver.log').read_text()
assert 'WEB_AUTHORITY_SERVER_OK epoch=1' in (root/'server.log').read_text()
hashes=json.loads((root/'browser/hashes.json').read_text());assert len(hashes['common'])>=10 and len(hashes['hashes'])==3
assert all(all(h[k]==hashes['hashes'][0][k] for h in hashes['hashes']) for k in hashes['common'])
summary={'peers':3,'bind_calls':[t['binds'] for t in traces],'conflicts':[t['conflicts'] for t in traces],'common_worlds':len(hashes['common']),'source_verified':True}
(root/'render-summary.json').write_text(json.dumps(summary,indent=2)+'\n');print('REPLAY_RENDER_AUDIT_OK')
