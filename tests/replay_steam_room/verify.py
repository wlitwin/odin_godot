from pathlib import Path
import json,re,sys
build=Path(sys.argv[1]).resolve();run=build/(sys.argv[2] if len(sys.argv)>2 else 'migrations');results=[]
for case in sorted(run.glob('*-*')):
 if not case.is_dir():continue
 mode=case.name.split('-')[0];rows={}
 for member in ([1,2,3] if mode=='planned' else [2,3]):
  text=(case/f'member-{member}.log').read_text()
  assert 'CAVE_CARRIER_MIGRATION_OK' in text,text[-3000:]
  assert f'STEAM_ROOM_FACTORY member={member} count=2' in text,(case.name,member,'fresh peer')
  hosts=re.findall(r'STEAM_ROOM_HOST member=(\d+) virtual_port=(\d+)',text)
  clients=re.findall(r'STEAM_ROOM_CLIENT member=(\d+) target=(\d+) virtual_port=(\d+)',text)
  if member==2:assert hosts and hosts[-1]==('2','0'),(case.name,member,hosts)
  else:assert clients and clients[-1]==(str(member),'76561198000000002','0'),(case.name,member,clients)
  if member!=1:assert clients[0]==(str(member),'76561198000000001','0')
  data=json.loads((case/f'member-{member}.json').read_text());assert data['pass']
  rows[str(member)]={'host_calls':hosts,'client_calls':clients,'recovery':data}
 results.append({'case':case.name,'pass':True,'members':rows})
assert len(results)==4
(run/'steam-contract.json').write_text(json.dumps({'pass':True,'transport':'Steam API contract over local ENet, not Valve networking','cases':results},indent=2)+'\n')
print('REPLAY_STEAM_ROOM_CONTRACT_OK',len(results))
