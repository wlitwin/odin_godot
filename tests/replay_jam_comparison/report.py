from pathlib import Path
import argparse,csv,hashlib,json,math,os,statistics,sys
from provenance import validate
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"replay_network_faults"))
from proxy_report import verify as verify_proxy
parser=argparse.ArgumentParser();parser.add_argument('run',type=Path);parser.add_argument('--allow-partial',action='store_true');parser.add_argument('--implementation',choices=['kit','replay']);args=parser.parse_args()
implementations=[args.implementation] if args.implementation else ['kit','replay']
root=args.run;contract=json.loads((root/'contract.json').read_text());expected=json.loads(Path(__file__).with_name('contract.json').read_text());assert contract==expected
build=json.loads((root/'build-manifest.json').read_text())
assert build['flags']==['-debug','-o:speed'] and build['odin']
assert {name.split('/')[0] for name in build['binaries']}=={'kit','replay'}
assert (root/'source-sha256.txt').stat().st_size>0
for impl in ('kit','replay'):
 fixture=json.loads((root/impl/'endurance-fixture.json').read_text());assert fixture['data/guns/bolter.tres']['setting']=={'mag':8,'jam_per_mille':200}
 assert hashlib.sha256((root/impl/'project/data/guns/bolter.tres').read_bytes()).hexdigest()==fixture['data/guns/bolter.tres']['after_sha256']
policy_proof=json.loads((root/'replay/action-policy.json').read_text());assert policy_proof['policy']==contract['replay_action_timing']=='Receipt'
assert hashlib.sha256((root/'replay/project/shared/game/game.odin').read_bytes()).hexdigest()==policy_proof['after_sha256']
for name,digest in build['binaries'].items():assert hashlib.sha256((root/name).read_bytes()).hexdigest()==digest,('binary',name)
for line in (root/'source-sha256.txt').read_text().splitlines():
 digest,name=line.split('  ',1);assert hashlib.sha256((root/name).read_bytes()).hexdigest()==digest,('source',name)
framework=json.loads((root/'framework-source.json').read_text())
assert framework['sha256']
source_root=Path(os.environ.get('REPLAY_SOURCE_ROOT',framework['root']))
original_model=(source_root/'examples/replay_scrapyard/shared/game/game.odin').read_bytes()
assert hashlib.sha256(original_model).hexdigest()==policy_proof['before_sha256']
expected_model=original_model.replace(b'return {step_view = step_view, action = action,',b'return {action_timing = .Receipt, step_view = step_view, action = action,',1)
expected_model=expected_model.replace(b'action_schedule = dash_schedule(),',b'action_schedule = {},',1)
assert expected_model!=original_model and (root/'replay/project/shared/game/game.odin').read_bytes()==expected_model
for name,digest in framework['sha256'].items():assert hashlib.sha256((source_root/name).read_bytes()).hexdigest()==digest,('framework',name)
plan=json.loads((root/'run-plan.json').read_text());control=validate(root,framework,build,plan);assert control['enabled'];full=plan['repetitions']==3 and plan['conditions']==['delay','lossy'] and not plan.get('trace_actions',False) and len(implementations)==2;assert full or args.allow_partial
assert type(plan['repetitions'])==int and 1<=plan['repetitions']<=3
assert plan['conditions'] and len(set(plan['conditions']))==len(plan['conditions']) and all(c in contract['conditions'] for c in plan['conditions'])
from workload import validate_condition

runs=[]
for condition in plan['conditions']:runs.extend(validate_condition(root,contract,plan,implementations,control,condition,verify_proxy))
aggregates={}
for condition in plan['conditions']:
 for impl in implementations:
  for role in ('host','client'):
   rows=[r for r in runs if r['implementation']==impl and r['role']==role and r['condition']==condition]
   aggregates[condition+'/'+impl+'/'+role]={key:{'median':statistics.median(r[key] for r in rows),'min':min(r[key] for r in rows),'max':max(r[key] for r in rows)} for key in ['p50_us','p95_us','p99_us','application_bytes_per_second','rss_peak_kib','living_time_mean','kills','census_p50_us']}
value={'implementations':implementations,'correction_reuse':plan.get('correction_reuse',False),'owner_control':control,'contract':contract,'full_plan':full,'runs':runs,'aggregates':aggregates,'interpretation':'Moving swarm with reload, dash, scheduled DOT/healing and normal status reactions under delay and raw UDP loss. Different authority/presentation, actual shot and spawn timing remain visible. Callback elapsed time and application bytes are not CPU-only or transport overhead.'}
temporary=root/'summary.json.pending';temporary.write_text(json.dumps(value,indent=2)+'\n');temporary.replace(root/'summary.json');print('REPLAY_JAM_REPORT_OK full_plan='+str(full).lower()+' processes='+str(len(runs)))
