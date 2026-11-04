#!/usr/bin/env python3
"""Functional-only actual Core/SDK offline CPU-fixture preparation; no timing job."""
from pathlib import Path
import argparse,hashlib,json,os,shutil,subprocess,sys
from allocation_activity import difference as allocation_difference
repo=Path(__file__).resolve().parents[3]
p=argparse.ArgumentParser();p.add_argument('--project',type=Path,default=repo/'tests/box3d_soak/replay');p.add_argument('--output',type=Path,required=True);p.add_argument('--fixture',choices=['dense','common'],required=True);p.add_argument('--timing-mode',choices=['functional_only','profile'],default='functional_only');p.add_argument('--exclusive-grant',default='');p.add_argument('--prepare-only',action='store_true');p.add_argument('--runtime-from',type=Path);p.add_argument('--phase-hooks',choices=['off','existing_callbacks'],default='off');p.add_argument('--operation',choices=['repair8','client_prediction_send','authority_step_requested_canonical'],default='repair8');a=p.parse_args()
if a.timing_mode=='profile' and not a.prepare_only and not a.exclusive_grant:p.error('Root exclusive grant required before profiling')
if a.operation!='repair8' and (a.fixture!='dense' or a.phase_hooks!='off'):p.error('Normal streams require the declared dense fixture and hooks OFF')
work=a.output.resolve();work.mkdir(parents=True,exist_ok=False);project=work/'project';shutil.copytree(a.project,project,ignore=shutil.ignore_patterns('.godot','*.dSYM','*.r*.dylib','__pycache__'))
# Existing imported metadata avoids editor import/autobuild. Main script URI loads
# directly; only extension list is required and already emitted by build helper.
(project/'.godot').mkdir(exist_ok=True);(project/'.godot/extension_list.cfg').write_text('res://odin_godot.gdextension\n')
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
paths=[]
for name in ['box3d','core','runtime','godot','gdext','replay','build','scriptgen','tests/box3d_soak/replay','tests/replay_physics_net/fixture','examples/box3d_common','examples/replay_box3d/shared/adapter']:
 for f in (repo/name).rglob('*'):
  if f.is_file() and not any(x in f.parts for x in ['bin','.godot','__pycache__']) and '.gen.odin' not in f.name and not f.name.endswith('.uid'):paths.append(f)
manifest={str(f.relative_to(repo)):sha(f) for f in sorted(set(paths))};mp=work/'source-manifest.json';mp.write_text(json.dumps(manifest,sort_keys=True,separators=(',',':'))+'\n')
bin=project/'bin';native=json.loads((bin/'box3d-runtime.json').read_text());build=json.loads((bin/'gate-b-build-binding.json').read_text());dense=a.fixture=='dense';fixture_id='dense32_boxes_extra_sphere' if dense else 'common32_spheres_crates_extra_capsule'
descriptor={'fixture':fixture_id,'seed':1,'geometry_sources':{name:manifest[name] for name in ['tests/box3d_soak/replay/scripts/models.odin','tests/box3d_soak/replay/scripts/runtime.odin','tests/replay_physics_net/fixture/fixture.odin','examples/box3d_common/rules.odin']},'dense_schedule':'Spawn40/41 Remove95 Motor115 target160','common_schedule':'local seat1 scriptedControl+scriptedAction; remoteheld0; target160','wire_scope':'unacked capture-only source; explicit retained160 request; notnormalplayableegress'}
meta={'event':'GATE_B_META','schema':1,'run_id':work.name,'framework':'replay','timing_mode':a.timing_mode,'fixture':{'id':fixture_id,'profile_hex':'504859534e455431' if dense else '534c494345503031','descriptor_sha256':hashlib.sha256(json.dumps(descriptor,sort_keys=True,separators=(',',':')).encode()).hexdigest(),'initial_dynamic':32,'reference_peak':{'bodies':35,'shapes':35,'contacts':141 if dense else 122,'joints':1}},'execution':{'core':'actual_godot_core','ownership':'sdk_meter','native_linkage':'shared_dso','transport':'offline_public_packets','native_images':None},'identity':{'os':None,'arch':None,'configuration':build['configuration'],'godot':None,'source_manifest_sha256':sha(mp),'core_binary_sha256':sha(bin/'libodin_godot.dylib'),'script_binary_sha256':sha(bin/'libodinscripts.dylib'),'native_binary_sha256':sha(bin/'libogb3.dylib'),'native_build_sha256':native['domain']['build'],'native_target_sha256':native['domain']['target']},'limits':{'normal_ns':4000000,'repair8_ns':4000000,'hz':60,'substeps':4,'history':128,'prediction':8,'ordinary_repair':8,'bodies':35,'shapes':35,'contacts':147,'joints':1,'tracked_bytes':67108864},'boundary':{'id':'core_public_ingress_v1','receiver_entry':'link_pump_then_client_pump','clock_domain':'godot_ticks_usec','clock_resolution_ns':1000,'included_work':['public_dispatch','envelope_reassembly_inspect','canonical_native_read_build_verify_reencode','typed_decode','accepted_input_replay','complete_paired_compare','publication_events','operation_cleanup','core_return'],'excluded_work':['network_wait','render','diagnostic_output','diagnostic_resource_read'],'source_refs':[{'path':name,'symbol':symbol,'sha256':manifest[name]} for name,symbol in [('tests/box3d_soak/replay/scripts/probe.odin','replay_gate_b_probe_probe_repair'),('replay/recovery/link.odin','link_pump'),('replay/net/client.odin','client_pump'),('tests/box3d_soak/replay/scripts/phases.odin','phase_sample'),('replay/net/complete_wire.odin','complete_decode_image'),('box3d/native/recovery_codec.c','ogb3_recovery_read_info'),('replay/correction.odin','revise_inputs_checked')]]},'sample_plan':{'normal':0,'repair8':19 if a.timing_mode=='profile' else 0},'phase_hooks':a.phase_hooks,'phase_hook_counters':{'scope':'per_sample; no clocks in functional_only','recorder_capacity':64,'overflow_policy':'operation_error; no truncated evidence','clock':'Godot Time.get_ticks_usec','actual_reads_field':'phase_observation.clock_reads','actual_callback_field':'phase_observation.net_callbacks','actual_overflow_field':'phase_observation.overflow','extra_reads':'entry, Link begin/end, Client begin/end, journal begin/end, inner return; net+codec existing public timing callbacks','native':'duration_only/null_origins/nested_in_Physics_Decode','overhead':'included in whole_ns; never subtracted'}}
if a.operation!='repair8':
 descriptor['normal_kind']=a.operation
 descriptor['wire_scope']='capture-only authority corpus; actual client Link Input send' if a.operation=='client_prediction_send' else 'real Sent Link/Memory tee; public canonical request-egress composite, NOT live cadence'
 descriptor['normal_inputs']='actual accepted prefix through152 then existing unknown hold/local seat2neutral' if a.operation=='client_prediction_send' else 'unchanged local seat1dense schedule and remoteheld0; real Hello incarnation'
 descriptor['normal_scope']='independent public runner references, sequential H128; source/current/default budgets unchanged'
 descriptor['normal_transport_time']='public Client/Link/Server times; target160*1000/60ms; no clock field setters'
 meta['fixture']['descriptor_sha256']=hashlib.sha256(json.dumps(descriptor,sort_keys=True,separators=(',',':')).encode()).hexdigest()
 meta['normal_kind']=a.operation;meta['step_observation']='committed_tick_require_step'
 meta['sample_plan']={'normal':19 if a.timing_mode=='profile' else 0,'repair8':0}
 meta['boundary']['receiver_entry']='link_pump_then_client_step' if a.operation=='client_prediction_send' else 'server_step_then_requested_snapshot_pump'
 meta['boundary']['included_work']=['public_dispatch','normal_step_capture_admission','required_serialization','publication_events','operation_cleanup','core_return']
 refs=[('tests/box3d_soak/replay/scripts/normal.odin','normal_client' if a.operation=='client_prediction_send' else 'normal_authority'),('replay/recovery/link.odin','link_pump'),('replay/timeline.odin','advance')]
 if a.operation=='client_prediction_send':refs += [('replay/net/client.odin','client_pump'),('replay/net/client.odin','client_step')]
 else:refs += [('replay/net/server.odin','server_step'),('replay/net/server.odin','server_pump'),('replay/net/physics_packets.odin','server_physics_prepare'),('replay/net/complete_wire.odin','complete_encode')]
 meta['boundary']['source_refs']=[{'path':name,'symbol':symbol,'sha256':manifest[name]} for name,symbol in refs]
 meta['normal_serialization']='actual typed Input packet send' if a.operation=='client_prediction_send' else 'explicit public requested canonical Snapshot egress composite; not live cadence'
 meta['normal_actual_steps']='null/unavailable; positive successful public step+observed Timeline.external.require_step and committed head delta1'
if build['source_manifest_sha256']!=sha(mp):raise SystemExit('Current source map differs from compiled build record')
(work/'descriptor.json').write_text(json.dumps(descriptor,indent=2)+'\n');mf=work/'meta.json';mf.write_text(json.dumps(meta)+'\n')
(work/'compiled-build.json').write_text(json.dumps(build,indent=2)+'\n')
artifact_map={'source_manifest':str(mp),'core_binary':str(bin/'libodin_godot.dylib'),'script_binary':str(bin/'libodinscripts.dylib'),'native_binary':str(bin/'libogb3.dylib'),'compiled_build_record':str(work/'compiled-build.json'),'runtime_observations':str(work/'runtime-observations.json')}
if a.runtime_from:
 observed=json.loads(a.runtime_from.read_text())
 for key in ['core_binary_sha256','script_binary_sha256','native_binary_sha256','native_build_sha256','native_target_sha256','configuration']:
  if observed['identity'].get(key)!=meta['identity'][key]:raise SystemExit('Prior observed artifact differs: '+key)
 meta['execution']=observed['execution'];meta['identity'].update({key:observed['identity'][key] for key in ['os','arch','godot']})
 (work/'runtime-observations.json').write_text(json.dumps(observed,indent=2)+'\n')
 mf.write_text(json.dumps(meta)+'\n')
(work/'artifact-map.json').write_text(json.dumps(artifact_map,indent=2)+'\n')
if a.prepare_only:
 print(json.dumps({'prepared_only':True,'meta':str(mf),'meta_sha256':sha(mf),'source_manifest_sha256':sha(mp),'timing_jobs_started':0},indent=2));sys.exit(0)
env=os.environ.copy();env.update(ODIN_SCRIPTS_DLL=str(bin/'libodinscripts.dylib'),GATE_B_FIXTURE=a.fixture,GATE_B_OPERATION=a.operation,GATE_B_TIMING_MODE=a.timing_mode,GATE_B_PHASE_HOOKS=a.phase_hooks,GATE_B_PROFILE_APPROVED='1' if a.exclusive_grant else '0',GATE_B_RUN_ID=work.name,GATE_B_META_FILE=str(mf),GATE_B_ACTUAL_META_FILE=str(work/'actual-meta.json'),GATE_B_RUNTIME_FILE=str(work/'runtime-observations.json'),GATE_B_RESULT_FILE=str(work/'producer-result.json'))
command=[env['GODOT'],'--headless','--max-fps','60','--path',str(project),'--script',str(project/'driver.gd')]
with (work/'godot.log').open('w') as log:
 try:completed=subprocess.run(command,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=120);code=completed.returncode
 except subprocess.TimeoutExpired:code=None
if (work/'actual-meta.json').exists():meta=json.loads((work/'actual-meta.json').read_text())
proofs=json.loads((work/'producer-result.json').read_text()) if (work/'producer-result.json').exists() else []
text=(work/'godot.log').read_text();errors=[line for line in text.splitlines() if 'ERROR' in line or 'SHUTDOWN' in line]
for proof in proofs:
 try:proof['allocation_activity']=allocation_difference(proof['allocation_before'],proof['allocation_after'])
 except (KeyError,ValueError,TypeError) as error:errors.append('allocation observation: '+str(error))
source_ok=all(sha(repo/name)==value for name,value in manifest.items());binary_ok=all(sha(bin/name)==meta['identity'][key] for name,key in [('libodin_godot.dylib','core_binary_sha256'),('libodinscripts.dylib','script_binary_sha256'),('libogb3.dylib','native_binary_sha256')])
samples=[]
for line in text.splitlines():
 if line.startswith('{'):
  try:item=json.loads(line)
  except json.JSONDecodeError:continue
  if item.get('event')=='GATE_B_SAMPLE':samples.append(item)
correct=bool(proofs) and all(v.get('correctness_ok') and v.get('prepare_status')==0 and v.get('repair_status')==0 and v.get('verify_status')==0 and v.get('cleanup_status')==0 for v in proofs)
cleanup=proofs[-1]['cleanup'] if proofs else {'native_live_bytes':None,'snapshot_live_bytes':None,'host_application_live_bytes':None,'all_explicit_drops_ok':False,'ownership_evidence':'missing'}
cleanup['all_explicit_drops_ok']=bool(proofs) and all(v.get('cleanup',{}).get('all_explicit_drops_ok',False) for v in proofs)
cleanup['core_shutdown_clean']=code==0 and not errors
result={'event':'GATE_B_RESULT','schema':1,'run_id':work.name,'sample_count':len(samples),'functional_operations':sum(v.get('prepare_status')==0 for v in proofs),'correctness_ok':correct and code==0,'source_fence_unchanged':source_ok,'binary_fence_unchanged':binary_ok,'cleanup':cleanup,'timing_status':'NOT_MEASURED' if a.timing_mode=='functional_only' else ('REPAIR_ONLY_NORMAL_COVERAGE_INCOMPLETE' if a.operation=='repair8' else 'NORMAL_ONLY_REPAIR_COVERAGE_INCOMPLETE'),'exit':code,'errors':errors,'operation_proofs':proofs}
(work/'compiled-build.json').write_text(json.dumps(build,indent=2)+'\n')
artifact_map={'source_manifest':str(mp),'core_binary':str(bin/'libodin_godot.dylib'),'script_binary':str(bin/'libodinscripts.dylib'),'native_binary':str(bin/'libogb3.dylib'),'compiled_build_record':str(work/'compiled-build.json'),'runtime_observations':str(work/'runtime-observations.json')}
(work/'artifact-map.json').write_text(json.dumps(artifact_map,indent=2)+'\n')
records=work/'records.jsonl';records.write_text('\n'.join(json.dumps(v) for v in [meta]+samples+[result])+'\n');(work/'report.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2));sys.exit(0 if result['correctness_ok'] and source_ok and binary_ok and not errors else 1)
