#!/usr/bin/env python3
"""One coherent V2 public reset/FIRST46 plus owned metadata/legacy suite."""
from pathlib import Path
import hashlib,json,subprocess,sys
repo=Path(__file__).resolve().parents[5]
out=Path(sys.argv[1]).resolve();out.mkdir(parents=True,exist_ok=False)
native=Path('/tmp/odin-box3d-goal-t4jbbj4v/box3d-native-zero42-v1/off-cache/build/Release/libogb3.a')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(native)=='2be61c6e0344c3449ba97d5ef2078dfbd6fb4772167d00695b12ac44a141f432'
expected={
 'examples/kit_box3d/scripts/runtime.odin':'b9bdec9a9be4165b51259dc0cf6d8ac72214f7c2fe48c48840f0e32a7da3b5a5',
 'examples/kit_box3d/scripts/intents.odin':'932cfb1d9b2cd5acf8d975ed9f8b3618f958dae6cde2c8f8ed4d8b3b99e56408',
 'examples/kit_box3d/scripts/kitslice.odin':'4cf0acce1590a318cf858d2e587658489fd02bcb9231098e4b166ac32f4af851',
}
for path,digest in expected.items():assert sha(repo/path)==digest
def sources():
    roots=['kit','box3d','replay/schema','runtime','godot','gdext','examples/box3d_common',
           'examples/kit_box3d/scripts','tests/box3d_soak/kit/input_admission/fresh_intent',
           'tests/box3d_soak/kit/input_admission/known_skip_reset','tests/box3d_slices/kit/intents']
    return dict(sorted((str(p.relative_to(repo)),sha(p)) for root in roots for p in (repo/root).rglob('*')
                       if p.is_file() and p.suffix in ('.odin','.py') and '__pycache__' not in p.parts))
before=sources();(out/'sources-before.json').write_text(json.dumps(before,sort_keys=True)+'\n')
argv=['nix','develop',str(repo),'--command','odin','test',str(repo/'tests/box3d_soak/kit/input_admission/known_skip_reset'),
      '-collection:godot='+str(repo),'-define:ODIN_TEST_THREADS=1','-define:BOX3D_LIBRARY='+str(native),
      '-o:speed','-debug','-extra-linker-flags:-lc++','-keep-executable','-out:'+str(out/'known-skip-reset')]
argv+=['-custom-attribute:'+n for n in ['gd_method','gd_connect','gd_rpc','gd_command','gd_tick','gd_input','gd_sample','gd_step','gd_event','gd_half','gd_message']]
with (out/'test.log').open('x') as log:r=subprocess.run(argv,cwd=out,stdout=log,stderr=subprocess.STDOUT)
after=sources();(out/'sources-after.json').write_text(json.dumps(after,sort_keys=True)+'\n')
observation=json.loads((out/'observation.json').read_text()) if (out/'observation.json').exists() else None
report=dict(schema=1,scope='ONE_actual_app_generic4_static_OFFddff_nilOwner_public_Session_Lane_memory_NOT_SDK32_ENet_timing_or_oldcause',
            argv=argv,actual_exit=r.returncode,source_fence_unchanged=before==after,
            source_manifest_sha256=sha(out/'sources-after.json'),production=expected,
            native_archive=str(native),native_archive_sha256=sha(native),
            native_manifest_sha256=sha(native.with_name('build-manifest.json')) if native.with_name('build-manifest.json').exists() else None,
            expected_native_build='ddff3ce2612b66717785981ead3d5433992d84ab8cfd5e6e98ab4fc36e43da66',
            expected_native_target='fbf45171357f68a60c98378b29bee1e6be069545dfbff27cbd0b6a4214d5455a',
            binary_sha256=sha(out/'known-skip-reset') if (out/'known-skip-reset').exists() else None,
            observation=observation,log_sha256=sha(out/'test.log'),
            raw_capture_scope='ALL sends after reused fixture Welcome handshake; earlier handshake raw not archived here',
            raw_packet_cap=2048,raw_byte_cap=8*1024*1024,
            artifacts={p.name:dict(bytes=p.stat().st_size,sha256=sha(p)) for p in out.iterdir() if p.suffix in ('.bin','.sig')})
if observation:
    reached=observation['setup_complete']
    report['public_setup_complete']=reached
    report['original_public_RED_now_green']=reached and observation['proposed_criterion_pass']
    report['cleanup_observed']=observation['cleanup_observed']
    report['all_other_recorded_controls']=reached and all(observation[k] for k in ['full5_preserved_confirmed39','full5_after45','reset_signature_match','identity_preserved','packet_provenance_ok','cleanup_observed','first46_reached','first46_packet_observed','first46_full5','first46_fx_equal','first46_identity_pinned'])
    report['unreached_fields_rule']='Status/head/sequence/plan defaults are UNAVAILABLE unless their preceding reached flag/stage establishes the observation; no default zero is proof.'
    rows=[]
    for line in (out/'test.log').read_text().splitlines():
        if line.startswith('{'):
            try:row=json.loads(line)
            except json.JSONDecodeError:continue
            rows.append(row)
    actual_rebase=[row for row in rows if row.get('event')=='INTENT_REBASE' and row.get('session_generation')==0 and row.get('original_requested_tick')==40 and row.get('old_head')==40 and row.get('new_head')==45]
    report['public_actual_V2_record_count']=len(actual_rebase)
    report['public_V2_record_prestate_valid']=len(actual_rebase)==1 and actual_rebase[0].get('intent_contract_version')==2 and actual_rebase[0].get('player')==2 and actual_rebase[0].get('class')==1 and all(actual_rebase[0].get(k) is False for k in ['pre_attempted','pre_published','pre_transported']) and all(type(actual_rebase[0].get(k)) is int and actual_rebase[0][k]==0 for k in ['pre_attempt_tick','pre_attempt_head','pre_packet_head','pre_row_sequence','pre_recovery_serial'])
    report['groups']=10
    report['pure_metadata_groups']=4
    report['legacy_metadata_groups_once']=5
    report['memory_transport_catalog_flag_note']='Memory send is real; app Wire hook is absent, so transported flag is preserved false rather than fabricated. Actual serialized row46/authority admission/receipt/full5/FX prove this fixture path.'
(out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(dict(actual_exit=r.returncode,report=str(out/'report.json'),report_sha256=sha(out/'report.json'),observation_saved=observation is not None),indent=2))
sys.exit(r.returncode if r.returncode else (0 if report.get('all_other_recorded_controls') and report.get('public_V2_record_prestate_valid') and report.get('original_public_RED_now_green') else 1))
