"""Verify the frozen bridge delivery evidence against the current workspace."""
from pathlib import Path
import hashlib,json,re,subprocess
root=Path(__file__).resolve().parents[2]
evidence=root/'docs/replay/results/godot-bridge-2026-09-20'
manifest=json.loads((evidence/'manifest.json').read_text())
sha=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
for name,digest in manifest['sources'].items():assert sha(root/name)==digest,name
for name,digest in manifest['receipts'].items():assert sha(evidence/name)==digest,name
baseline=json.loads((root/'docs/replay/results/framework-release-2026-09-20/manifest.json').read_text())['preservation']
for name,digest in baseline['kit'].items():assert sha(root/name)==digest,name
assert not subprocess.check_output(['git','status','--porcelain','--',*baseline['original_game_paths']],cwd=root,text=True).strip()
assert not subprocess.check_output(['git','status','--porcelain'],cwd=root.parent/'scrapyard',text=True).strip()
assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=root.parent/'scrapyard',text=True).strip()==baseline['scrapyard_head']
receipts=evidence/'receipts'
assert 'REPLAY_BRIDGE_OK' in (receipts/'final-gates.log').read_text()
assert 'REPLAY_SCRUBBER_NETWORK_OK' in (receipts/'hello-final.log').read_text()
counts=[]
for name in ['replay','replay_view','replay_definitions','replay_owned']:
 text=(receipts/f'final-gates/{name}.log').read_text();counts.append(int(re.search(r'Finished (\d+) tests',text)[1]))
assert counts==[33,30,2,11],counts
for name,count in [('node-timings',84),('sparse-timings',126),('core-public',270)]:
 data=json.loads((receipts/name/'result.json').read_text());assert len(data['rows'])==count
for doc in ['docs/replay/godot-bridge-plan.md','docs/replay/godot-bridge-progress.md','docs/replay/godot-bridge-performance.md','docs/replay/results/godot-bridge-2026-09-20/README.md','replay/godot/view-pools.md','replay/godot/controls.md','replay/godot/effect-routes.md','replay/godot/body-bindings.md']:
 p=root/doc
 for link in re.findall(r'\]\(([^)]+)\)',p.read_text()):
  if '://' in link or link.startswith('#'):continue
  path=link.split('#')[0];assert (p.parent/path).exists(),(doc,link)
result={'pass':True,'sources':len(manifest['sources']),'receipts':len(manifest['receipts']),'unit_tests':sum(counts),'kit_files_preserved':len(baseline['kit']),'originals_preserved':True}
(evidence/'audit.json').write_text(json.dumps(result,indent=2)+'\n')
print('REPLAY_BRIDGE_AUDIT_OK',json.dumps(result))
