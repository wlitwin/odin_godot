"""Require real native channel options and traffic for negotiated/fallback paths."""
import json,sys
from pathlib import Path
root=Path(sys.argv[1]);expected=sys.argv[2] if len(sys.argv)>2 else 'separate';assert expected in ['separate','legacy']
files=sorted([*root.glob('control-*-before.json'),*root.glob('control-*-recovered.json')]);assert len(files)>=4;rows=[]
for p in files:
 peers=json.loads(p.read_text());assert peers
 for peer in peers:
  channels={c['id']:c for c in peer['channels']}
  for i in [0,1]:assert channels[i]['state']=='open' and channels[i]['sent']>0 and channels[i]['received']>0
  assert channels[0]['ordered'] and channels[0]['maxRetransmits'] is None
  assert not channels[1]['ordered'] and channels[1]['maxRetransmits']==0
  control=channels.get(2)
  if expected=='separate':
   assert control and control['label']=='replay-control-v1' and not control['ordered'] and control['maxRetransmits'] is None and control['maxPacketLifeTime'] is None and control['state']=='open' and control['sent']>0 and control['received']>0
  elif control:assert control['sent']==control['received']==0
  rows.append({'file':p.name,'channels':list(channels.values())})
(root/'control-validation.json').write_text(json.dumps({'pass':True,'expected':expected,'observations':rows},indent=2)+'\n');print('REPLAY_CONTROL_CHANNEL_OK',expected,len(rows))
