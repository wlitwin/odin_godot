#!/usr/bin/env python3
"""Functional ONLY. No probe timers/SAMPLE; actual Core/SDK shared build."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[3]
OWN=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--stage',type=Path,required=True)
    parser.add_argument('--fixture',choices=('dense','common'),default='dense')
    parser.add_argument('--godot',default='/Applications/Godot.app/Contents/MacOS/Godot')
    parser.add_argument('--build',type=Path,help='explicit speed/debug compiled build artifact directory')
    parser.add_argument('--mode',choices=('functional_only','profile'),default='functional_only')
    parser.add_argument('--exclusive-grant',default='',help='Root grant label; required for profile, never self-authorizes a run')
    parser.add_argument('--observation',choices=('off','structure','timed'),default='off')
    args=parser.parse_args()
    if args.mode=='profile' and not args.exclusive_grant:parser.error('profile requires an explicit Root quiet-window grant')
    if args.mode=='profile' and args.observation=='structure':parser.error('structure-only observation must not emit timing SAMPLE records')
    if args.mode!='profile' and args.observation=='timed':parser.error('functional mode must not prewarm or read any profile clock')
    args.stage.mkdir(parents=True,exist_ok=False)
    project=args.stage/'project'
    source_project=args.build/'project' if args.build else OWN/'project'
    shutil.copytree(source_project,project,ignore=shutil.ignore_patterns('.godot','*.dSYM','*.r*.dylib','.odin_crash.log'))
    source_files={}
    for base in ('kit','box3d','core','runtime','godot','gdext','decl','tests/box3d_soak/kit','tests/box3d_soak/native_observe','tests/replay_physics_net/fixture','examples/box3d_common'):
        for p in (ROOT/base).rglob('*.odin'):
            if not (OWN/'project' in p.parents and '.gen.' in p.name):source_files[str(p.resolve())]=sha(p)
    binary_files={str(p.resolve()):sha(p) for p in (project/'bin').glob('*.dylib')}
    manifest_path=args.stage/'source-manifest.json'
    if args.build:
        shutil.copy2(args.build/'source-manifest.json',manifest_path)
        source_files={str((ROOT/Path(k)).resolve()):v for k,v in json.loads(manifest_path.read_text()).items()}
    else:manifest_path.write_text(json.dumps({str(Path(k).relative_to(ROOT)):v for k,v in source_files.items()},indent=2,sort_keys=True)+'\n')
    # Include the actual copied scriptgen output in the runtime fence as well.
    source_files.update({str(p.resolve()):sha(p) for p in (project/'scripts').glob('*.gen.odin')})
    source_manifest=sha(manifest_path)
    godot_executable=Path(args.godot).resolve()
    godot_version=subprocess.check_output([str(godot_executable),'--version'],text=True).strip()
    runtime=json.loads((project/'bin/box3d-runtime.json').read_text())
    domain=runtime.get('domain',{})
    dense=args.fixture=='dense'
    descriptor={'world_source':sha(ROOT/('tests/replay_physics_net/fixture/fixture.odin' if dense else 'examples/box3d_common/rules.odin')),
                'adapter':sha(OWN/'fixture/fixture.odin'),'seed':1,'target':160,
                'schedule':'host x alternates±10 eachtick,Spawn40/41 Remove95 Motor115' if dense else 'exactcommon.scripted_control/action for2seats;Spawn40 Remove56 Motor80 Sleep120 Wake136 Query160',
                'storage':'bounded4MiB/128plainpublicpackets+facts countedSDKMeter;sourceparticipants destroyedbeforefinalreceiver',
                'measurement_windows':{'kind':'fresh_same_suffix','base_tick':154,'head_tick':162,'repair_samples':19,'final_untimed_tick':162,'normal_samples':0},
                'source_input_preparation':'realunchangedauthoritytrajectorythrough162;publicResetbootstrap154;plainfull5Sourceoracle;FULLsourcecontextsfreedbeforecandidate;separatefresh154to162eachsample;ResetdecodeUNtimed'}
    descriptor['wire_revision']=2;descriptor['measurement_windows']={'kind':'fresh_same_suffix','base_tick':154,'head_tick':162,'repair_samples':19,'final_untimed_tick':162};descriptor['ordinary_ingress']='actualReliableACCEPTED162(155..162)+SIGNATURE162/noCHUNK';descriptor['native_recovery_read_in_operation']=False
    descriptor_hash=hashlib.sha256(json.dumps(descriptor,sort_keys=True,separators=(',',':')).encode()).hexdigest()
    refs=[]
    for path,symbol in [('tests/box3d_soak/kit/fixture/fixture.odin','apply_operation_typed'),('kit/session/session.odin','session_handle_packet'),('kit/sim/lane.odin','lane_frame'),('kit/sim/world_history.odin','world_protocol_apply_signature/world_operation'),('kit/sim/snapshot.odin','world_protocol_frame_signature/world_wire_parts'),('kit/physics/network.odin','network_attach codec.encode/input typed decode'),('box3d/native/api.c','ogb3_world_step_fixed'),('box3d/native/owned_snapshot.c','ogb3_snapshot_capture/fresh_finish/validate'),('tests/box3d_soak/kit/project/scripts/native_clock.odin','native_clock_prepare/native_clock_read'),('tests/box3d_soak/kit/project/scripts/probe.odin','kit_gate_b_apply'),('tests/box3d_soak/native_observe/observer.odin','begin/end/raw_owner_lifetime')]:
        refs.append({'path':path,'symbol':symbol,'sha256':sha(ROOT/path)})
    meta={'framework':'kit','fixture':{'id':'dense32_boxes_extra_sphere' if dense else 'common32_spheres_crates_extra_capsule','profile_hex':'504859534e455431' if dense else '534c494345503031','descriptor_sha256':descriptor_hash,'initial_dynamic':32,'reference_peak':{'bodies':35,'shapes':35,'contacts':141 if dense else 122,'joints':1}},
          'execution':{'core':'actual_godot_core','ownership':'sdk_meter','native_linkage':'shared_dso','transport':'offline_public_packets','native_images':None},
          'identity':{'os':'macos' if sys.platform=='darwin' else 'linux','arch':os.uname().machine,'configuration':'Odin speed+debug / Native Release' if args.build else 'NativeRelease_OdinDebug','godot':godot_version,'source_manifest_sha256':source_manifest,'core_binary_sha256':sha(project/'bin/libodin_godot.dylib'),'script_binary_sha256':sha(project/'bin/libodinscripts.dylib'),'native_binary_sha256':sha(project/'bin/libogb3.dylib'),'native_build_sha256':domain.get('build',''),'native_target_sha256':domain.get('target','')},
          'limits':{'normal_ns':4000000,'repair8_ns':4000000,'hz':60,'substeps':4,'history':128,'prediction':8,'ordinary_repair':8,'bodies':35,'shapes':35,'contacts':147,'joints':1,'tracked_bytes':67108864},
          'boundary':{'id':'core_public_ingress_v1','receiver_entry':'session_dispatch_then_lane_frame','clock_domain':'godot_ticks_usec','clock_resolution_ns':1000,'included_work':['public_dispatch','envelope_reassembly_inspect','typed_decode','accepted_input_replay','canonical_five_part_signature_verification','complete_paired_compare','publication_events','operation_cleanup','core_return'],'excluded_work':['network_wait','render','diagnostic_output','diagnostic_resource_read'],'source_refs':refs},
          'source_files':source_files,'binary_files':binary_files,'descriptor':descriptor}
    observer_compiled=bool(args.build and '-define:GATE_B_NATIVE_OBSERVATION=true' in json.loads((args.build/'compiled-build.json').read_text()).get('environment',{}).get('SCRIPT_BUILD_FLAGS',''))
    if args.observation!='off' or (args.mode=='functional_only' and observer_compiled):
        phase_names=['step.fixed','snapshot.capture','snapshot.serialize','snapshot.normalize','snapshot.finalize','snapshot.validate','admission.world','recovery.read','recovery.parse_validate','recovery.build','recovery.verify_reencode','recovery.write']
        phase_symbols=['ogb3_world_step_fixed','ogb3_snapshot_capture','ogb3_snapshot_capture:serialize','ogb3_snapshot_capture:normalize','ogb3_snapshot_capture:finalize','validate/fresh_finish','ogb3_recovery_world_admit','ogb3_recovery_read','ogb3_recovery_read:parse','build_native','ogb3_recovery_read:verify_reencode','ogb3_recovery_write']
        phase_map=[]
        for phase,(name,symbol) in enumerate(zip(phase_names,phase_symbols),1):
            path='box3d/native/api.c' if phase==1 else ('box3d/native/owned_snapshot.c' if phase<=6 else 'box3d/native/recovery_codec.c')
            phase_map.append({'phase':phase,'name':'native.'+name,'path':path,'symbol':symbol,'sha256':sha(ROOT/path)})
        meta['native_observer']={'abi_version':1,'mode':'structure_only' if args.observation=='structure' else args.observation,'block_bytes':49392,'span_bytes':48,'capacity':1024,'stack_capacity':16,'phase_mask':4095,'clock_domain':'godot_ticks_usec','native_static_bytes':48,'binding_control_bytes':32,'clock_binding_static_bytes':24,'meter_context_bytes':219928,'source_phase_map':phase_map,'overhead':'inside_whole','native_status_names':{'0':'OGB3_OK','1':'OGB3_INVALID_ARGUMENT','2':'OGB3_INVALID_HANDLE','3':'OGB3_OUT_OF_MEMORY','4':'OGB3_CAPACITY','5':'OGB3_UNSUPPORTED','6':'OGB3_INCOMPATIBLE','7':'OGB3_CORRUPT','-2147483648':'UNAVAILABLE'}}
    if args.mode=='profile':meta['exclusive_grant']=args.exclusive_grant
    (args.stage/'meta.json').write_text(json.dumps(meta,indent=2)+'\n')
    env=os.environ.copy();env.update(GATE_B_FIXTURE=args.fixture,GATE_B_META=str(args.stage/'meta.json'),GATE_B_RUN_ID='kit-'+args.mode+'-'+args.fixture,GATE_B_MODE=args.mode,GATE_B_OBSERVATION=args.observation)
    if args.mode=='profile':env['GATE_B_EXCLUSIVE_GRANT']=args.exclusive_grant
    with (args.stage/'prepare.log').open('w') as log:
        subprocess.run([sys.executable,str(ROOT/'build/box3d_profile.py'),'--prepare-import',str(project)],stdout=log,stderr=subprocess.STDOUT,check=True)
        subprocess.run([args.godot,'--headless','--path',str(project),'--import'],env=env,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=45)
    with (args.stage/'godot.log').open('w') as log:
        process=subprocess.run([args.godot,'--headless','--path',str(project),'--script',str(project/'functional.gd')],env=env,stdout=log,stderr=subprocess.STDOUT,timeout=60)
    text=(args.stage/'godot.log').read_text();records=[]
    for line in text.splitlines():
        if line.startswith('{'):
            try:records.append(json.loads(line))
            except json.JSONDecodeError:pass
    # Preserve original producer bytes separately. Native integer tokens are
    # emitted losslessly by the producer, never repaired/recast by this sealer.
    (args.stage/'raw-records.jsonl').write_text(''.join(line+'\n' for line in text.splitlines() if line.startswith('{')))
    result=next((x for x in records if x.get('event')=='GATE_B_RESULT'),None)
    shutdown=process.returncode==0 and not any(x in text for x in ('ERROR:','NOTEMPTY','NativeShutdownwarning','SCRIPT ERROR:','SIGSEGV','SIGABRT'))
    # Retain raw provider record with unknown shutdown; seal only independently
    # observed process/shutdown/fence facts into the controller record stream.
    if result:
        result['cleanup']['core_shutdown_clean']=shutdown
        result['source_fence_unchanged']=all(Path(p).exists() and sha(Path(p))==v for p,v in source_files.items())
        result['binary_fence_unchanged']=all(sha(Path(p))==v for p,v in binary_files.items())
    edge_values=[0,2**53-1,2**53,2**53+1,2**63-1,2**63,2**64-1]
    precision_applicable=result.get('producer_precision_applicable') if result else None
    composer_exact=bool(result and result.get('composer_precision_ok') is True and result.get('producer_uint64_edges')==edge_values and all(type(x) is int for x in result['producer_uint64_edges']))
    native_precision_exact=None
    precision_ok=False
    if precision_applicable is False:
        precision_ok=bool(composer_exact and result.get('producer_precision_ok') is None and result.get('producer_precision_control')=={} and result.get('native_observation') is None and result.get('native_observation_summary',{}).get('compiled') is False and args.observation=='off')
    elif precision_applicable is True:
        native_precision_exact=bool(result.get('producer_precision_ok') is True)
        if native_precision_exact:
            control=result['producer_precision_control'];block=control['native_raw'];span=block['spans'][0];phase=control['native_phases'][0]
            native_precision_exact=(type(block['scope_token']) is int and type(block['domain_cookie']) is int and block['scope_token']==block['domain_cookie']==2**64-1 and type(span['start_us']) is int and span['start_us']==2**53+1 and span['end_us']==2**53+2 and phase['start_us']==span['start_us'] and phase['end_us']==span['end_us'] and type(phase['duration_ns']) is int and phase['duration_ns']==1000)
        precision_ok=composer_exact and native_precision_exact
    (args.stage/'records.jsonl').write_text(''.join(json.dumps(r,sort_keys=True)+'\n' for r in records))
    if args.build:
        build=json.loads((args.build/'compiled-build.json').read_text());build['source_manifest_sha256']=source_manifest
        (args.stage/'compiled-build.json').write_text(json.dumps(build,indent=2)+'\n')
        runtime_record={'execution':records[0]['execution'],'identity':records[0]['identity'],'godot_observation':{'argv':[str(godot_executable),'--version'],'stdout':godot_version,'binary_sha256':sha(godot_executable)},'image_census_observed':records[0]['execution']['native_images']==1,'pid_evidence':'actual Node method enumerates loaded process images; raw stdout bound by hash','controller':'run_functional.py actual Godot process exit+log'}
        (args.stage/'runtime-observations.json').write_text(json.dumps(runtime_record,indent=2)+'\n')
        artifact={'source_manifest':str(manifest_path),'core_binary':str(project/'bin/libodin_godot.dylib'),'script_binary':str(project/'bin/libodinscripts.dylib'),'native_binary':str(project/'bin/libogb3.dylib'),'compiled_build_record':str(args.stage/'compiled-build.json'),'runtime_observations':str(args.stage/'runtime-observations.json')}
        (args.stage/'artifact-map.json').write_text(json.dumps(artifact,indent=2)+'\n')
    report={'result':'PASS' if result and result['correctness_ok'] and shutdown and result['source_fence_unchanged'] and result['binary_fence_unchanged'] and precision_ok else 'FAIL','scope':'functional_only NOT_MEASURED' if args.mode=='functional_only' else 'repair19_only NORMAL_MISSING/GateBnotaccepted','producer_precision_exact':native_precision_exact,'producer_precision_applicable':precision_applicable,'composer_precision_exact':composer_exact,'numeric_recast_or_normalization':False,'exclusive_grant':args.exclusive_grant,'exit':process.returncode,'raw_log_sha256':sha(args.stage/'godot.log'),'record_path':str(args.stage/'records.jsonl'),'record_sha256':sha(args.stage/'records.jsonl'),'functional_result':result}
    (args.stage/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({'result':report['result'],'report':str(args.stage/'report.json')}))
    return 0 if report['result']=='PASS' else 1

if __name__=='__main__':raise SystemExit(main())
