"""Check this delivery snapshot; later intentional source changes need new evidence."""
from pathlib import Path
import hashlib,json,re,subprocess
root=Path(__file__).resolve().parents[2];out=root/'docs/replay/results/editor-first-2026-09-20'
data=json.loads((out/'manifest.json').read_text());sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for name,value in data['sources'].items():assert sha(root/name)==value,name
for name,value in data['receipts'].items():assert sha(out/name)==value,name
for name,value in data['preserved'].items():assert sha(root/name)==value,name
assert not subprocess.check_output(['git','status','--porcelain','--',*data['original_paths']],cwd=root,text=True).strip()
assert not subprocess.check_output(['git','status','--porcelain'],cwd=root.parent/'scrapyard',text=True).strip()
assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=root.parent/'scrapyard',text=True).strip()==data['scrapyard_head']
for name in ['docs/replay/editor-first-plan.md','docs/replay/editor-first-progress.md','replay/godot/editor-first.md','examples/replay_scrapyard/editor-first.md','docs/replay/results/editor-first-2026-09-20/README.md']:
 p=root/name
 for link in re.findall(r'\]\(([^)]+)\)',p.read_text()):
  if '://' in link or link.startswith('#'):continue
  assert (p.parent/link.split('#')[0]).exists(),(name,link)
for name in ['final/editor-checks/result.json','final/checks/result.json','final/revive/result.json']:
 assert json.loads((out/'receipts'/name).read_text())['pass']
assert 'REPLAY_EDITOR_WEB_OK' in (out/'receipts/web/driver.log').read_text()
assert 'REPLAY_SCRAPYARD_CRASH_OK' in (out/'receipts/migration-fixed.log').read_text()
assert len(json.loads((out/'receipts/timings/result.json').read_text())['rows'])==18
result={'pass':True,'sources':len(data['sources']),'receipts':len(data['receipts']),'preserved_model_kit':len(data['preserved']),'originals_preserved':True,'native_scenes':True,'browser_scenes':True,'combat_revive_crash':True}
(out/'audit.json').write_text(json.dumps(result,indent=2)+'\n')
print('REPLAY_EDITOR_AUDIT_OK',json.dumps(result))
