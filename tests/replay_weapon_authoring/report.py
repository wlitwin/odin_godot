"""Verify data-only authoring, absence of the cold client's row, and all peer results."""
from pathlib import Path
import difflib,hashlib,itertools,json,re,sys

def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def report(root,partial=False):
 root=Path(root);contract=json.loads((root/'contract.json').read_text());plan=json.loads((root/'run-plan.json').read_text())
 assert contract==json.loads((Path(__file__).parent/'contract.json').read_text())
 full=plan['cases']==contract['cases'] and plan['conditions']==contract['conditions'] and plan['repetitions']==contract['repetitions']
 assert full or partial
 assert plan['receive_delay_ms']=={'local':0,'delayed':120} and plan['loss_permyriad']==plan['duplicate_permyriad']==0
 assert plan['cases'] and set(plan['cases'])<=set(contract['cases']) and len(set(plan['cases']))==len(plan['cases'])
 assert plan['conditions'] and set(plan['conditions'])<=set(contract['conditions']) and len(set(plan['conditions']))==len(plan['conditions'])
 assert type(plan['repetitions'])==int and 1<=plan['repetitions']<=contract['repetitions']
 build=json.loads((root/'build.json').read_text())
 for name,expected in build['binaries'].items():assert digest(root/name)==expected,('binary',name)
 feature_summary={}
 for impl,variant in itertools.product(('kit','replay'),('new','cold')):
  base=root/impl/variant;project=base/'project';before=json.loads((base/'before.json').read_text());source=json.loads((base/'source.json').read_text());feature=json.loads((base/'feature/changes.json').read_text());fixture=json.loads((base/'fixture-changes.json').read_text())
  expected={'data/guns/stapler.tres'}|({'shared/content/stock.odin'} if impl=='replay' else set()) if variant=='new' else set()
  assert set(feature['changes'])==expected and feature['implementation']==impl and feature['variant']==variant
  assert feature['handwritten_gameplay_files']==feature['handwritten_network_files']==0 and feature['authored_resource_files']==int(variant=='new')
  expected_after=dict(before)
  for name,row in feature['changes'].items():assert row['before']==before.get(name);expected_after[name]=row['after']
  for name,row in fixture.items():assert row['before']==expected_after[name];expected_after[name]=row['after']
  assert set(fixture)==({'data/mobs/hulk.tres','shared/content/stock.odin'} if impl=='replay' else {'data/mobs/hulk.tres'})
  assert set(source)==set(expected_after)|{'weapon_authoring.gd','scripts/weapon_authoring.odin'}
  for name,expected_hash in expected_after.items():assert source[name]==expected_hash,('unrecorded edit',impl,variant,name)
  for name,expected_hash in source.items():assert digest(project/name)==expected_hash,('source',impl,variant,name)
  if variant=='cold':
   assert not (project/'data/guns/stapler.tres').exists()
   if impl=='replay':assert 'c.guns[7]' not in (project/'shared/content/stock.odin').read_text()
  else:
   resource=base/'feature/stapler.tres';assert digest(resource)==digest(Path(__file__).parent/'stapler.tres')==digest(project/'data/guns/stapler.tres')
   row={'authored_files':1,'resource_physical_lines':len(resource.read_text().splitlines()),'resource_nonblank_lines':sum(bool(x.strip()) for x in resource.read_text().splitlines()),'handwritten_gameplay_files':0,'handwritten_network_files':0,'derived_added_lines':0,'derived_removed_lines':0}
   if impl=='replay':
    a=base/'feature/stock-before.odin';b=base/'feature/stock-after.odin';delta=''.join(difflib.unified_diff(a.read_text().splitlines(True),b.read_text().splitlines(True),fromfile='stock-before.odin',tofile='stock-after.odin'))
    assert digest(a)==before['shared/content/stock.odin'] and digest(b)==feature['changes']['shared/content/stock.odin']['after']
    assert delta==(base/'feature/generated.patch').read_text()
    row['derived_added_lines']=sum(x.startswith('+') and not x.startswith('+++') for x in delta.splitlines());row['derived_removed_lines']=sum(x.startswith('-') and not x.startswith('---') for x in delta.splitlines())
   feature_summary[impl]=row
 expected_paths=set();runs=[]
 for pair,condition,case,impl in itertools.product(range(1,plan['repetitions']+1),plan['conditions'],plan['cases'],('kit','replay')):
  folder=root/'runs'/str(pair)/condition/case/impl
  for seat,role in enumerate(('host','client'),1):
   path=folder/('success-'+role+'.json');expected_paths.add(path);v=json.loads(path.read_text())
   assert v['implementation']==impl and v['role']==role and v['case']==case and v['seat']==seat
   assert v['resource_present']==(role=='host' or case=='shared_resource')
   assert v['name']==v['label']=='stapler' and v['regions']==[[0,48,32,16]]*2
   assert v['definition']=={'damage':3,'cooldown':12,'mag':3,'reload':60,'jam':0,'speed':12,'ttl':30}
   assert v['swaps']==[{'before':i,'after':i+1} for i in range(7)]
   assert json.loads((folder/('declared-'+role+'.json')).read_text())=={'ready':True}
   assert json.loads((folder/('equipped-'+role+'.json')).read_text())=={'iron':[0,0]}
   assert v['first_hit']=={'enemy_hp':17,'damage':3,'spent':[1,0]}
   assert v['spent']==[7,7] and v['ammo']==[2,2] and v['damage']==20 and v['kills']==1 and v['reloads']>=2
   assert [x['held'] for x in v['inputs']]==([True,False,True,False] if role=='host' else [True,False])
   assert v['inputs'][-1]['local_spent']==7 and (role!='host' or v['inputs'][1]['local_spent']==1)
   rows=v['trace'];assert len(rows)>=20 and [x['ms'] for x in rows]==sorted(x['ms'] for x in rows)
   settled=[x for x in rows if x['phase']=='settled'];assert settled[-1]['ms']-settled[0]['ms']>=850
   assert all(x['spent']==[7,7] and x['ammo']==[2,2] and x['damage']==20 for x in settled)
   assert json.loads((folder/('quiesced-'+role+'.json')).read_text())=={'ready':True}
   log=(folder/(role+'.log')).read_text();assert 'REPLAY_WEAPON_AUTHORING_PEER_OK' in log and not re.search(r'WEAPON_AUTHORING_FAIL|SCRIPT ERROR|ERROR:|instances were leaked|resources still in use',log)
   if role=='client' and case=='host_only_resource':assert ('SY_DEFS guns=7' if impl=='kit' else 'RSY_CONTENT_LOADED guns=7') in log
  assert not list(folder.glob('failure-*.json'))
  runs.append({'pair':pair,'condition':condition,'case':case,'implementation':impl})
 assert set((root/'runs').glob('*/*/*/*/success-*.json'))==expected_paths
 value={'feature':contract['feature'],'full_plan':full,'feature_changes':feature_summary,'runs':runs,'peer_receipts':len(expected_paths),'interpretation':'Data-resource addition in an existing family. Generated stock output is separate. Not human authoring time, new-family work, save/migration coverage, or a performance comparison.'}
 temporary=root/'summary.json.pending';temporary.write_text(json.dumps(value,indent=2)+'\n');temporary.replace(root/'summary.json');return value
if __name__=='__main__':
 v=report(sys.argv[1],sys.argv[2:]==['--allow-partial']);print('REPLAY_WEAPON_AUTHORING_REPORT_OK full_plan='+str(v['full_plan']).lower()+' peer_receipts='+str(v['peer_receipts']))
