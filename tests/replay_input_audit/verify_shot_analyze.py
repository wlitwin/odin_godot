"""Reject broken impact evidence without changing captured source or receipts."""
from pathlib import Path
import json,re,shutil,sys,tempfile
from shot_analyze import analyze
source=Path(sys.argv[1]);checks=[]
for case in ('valid','missing_birth','duplicate_end','invalid_reason','hp_overflow','backward_tick','wrong_fired_total','wrong_damage_total','wrong_kill_total','buffer_overflow','missing_buffer','empty'):
 with tempfile.TemporaryDirectory(prefix='replay-impact-check-') as tmp:
  root=Path(tmp);shutil.copy2(source/'audit-manifest.json',root/'audit-manifest.json')
  folder=root/'pair-1/lossy';folder.mkdir(parents=True)
  log=(source/'pair-1/lossy/host.log').read_text().splitlines()
  data=json.loads((source/'pair-1/lossy/success-host.json').read_text())
  birth=next(i for i,line in enumerate(log) if line.startswith('INPUT_SHOT_BORN '));end=next(i for i,line in enumerate(log) if line.startswith('INPUT_SHOT_END '))
  if case=='missing_birth':log.pop(birth)
  if case=='duplicate_end':log.append(log[end])
  if case=='invalid_reason':log[end]=re.sub(r'reason=\d+','reason=9',log[end])
  if case=='hp_overflow':log[end]=re.sub(r'hp_before=\d+','hp_before=99',log[end])
  if case=='backward_tick':log[end]=re.sub(r'tick=\d+','tick=0',log[end])
  if case=='wrong_fired_total':data['final_guns'][0]['shots']+=1
  if case=='wrong_damage_total':data['final']['damage'][0]+=1
  if case=='wrong_kill_total':data['final']['kills'][0]+=1
  if case=='buffer_overflow':log=[line.replace('dropped=0','dropped=1') if line.startswith('INPUT_AUDIT_COUNT ') else line for line in log]
  if case=='missing_buffer':log=[line for line in log if not line.startswith('INPUT_AUDIT_COUNT ')]
  (folder/'host.log').write_text('\n'.join(log)+'\n')
  if case!='empty':(folder/'success-host.json').write_text(json.dumps(data))
  accepted=True
  try:analyze(root)
  except AssertionError:accepted=False
  assert accepted==(case=='valid'),case
  checks.append({'case':case,'accepted':accepted})
(source/'shot-validation.json').write_text(json.dumps({'cases':checks},indent=2)+'\n')
print('REPLAY_SHOT_VALIDATION_OK cases='+str(len(checks)))
