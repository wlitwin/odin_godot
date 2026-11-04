#!/usr/bin/env python3
"""Focused prospective eligibility controls; historical RED artifacts stay intact."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys

repo=Path(__file__).resolve().parents[5]
out=Path(sys.argv[1]).resolve();out.mkdir(parents=True,exist_ok=False)
native=Path('/tmp/odin-box3d-goal-t4jbbj4v/box3d-native-count-once-v1/cache/build/Release/libogb3.a')
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
assert sha(native)=='6a6a19edc5f9c4023229155a4822630f3ea58e6363fd91be7100a10b00ef898f'
def sources():
    roots=['kit','box3d','replay/schema','runtime','godot','gdext',
           'examples/box3d_common','examples/kit_box3d/scripts','tests/box3d_slices/kit/intents',
           'tests/box3d_soak/kit/input_admission/fresh_intent']
    return dict(sorted((str(p.relative_to(repo)),sha(p)) for root in roots
                       for p in (repo/root).rglob('*') if p.is_file()
                       and p.suffix in ('.odin','.py') and '__pycache__' not in p.parts))
before=sources();(out/'sources-before.json').write_text(json.dumps(before,sort_keys=True)+'\n')
command=['nix','develop',str(repo),'--command','odin','test',
         str(repo/'tests/box3d_soak/kit/input_admission/fresh_intent'),
         '-collection:godot='+str(repo),'-define:ODIN_TEST_THREADS=1',
         '-define:BOX3D_LIBRARY='+str(native),'-o:speed','-debug',
         '-extra-linker-flags:-lc++','-keep-executable','-out:'+str(out/'fresh-intent')]
# Match the ordinary SDK annotation declarations; no ignore-all attribute flag.
command += ['-custom-attribute:'+name for name in
            ['gd_method','gd_connect','gd_rpc','gd_command','gd_tick','gd_input',
             'gd_sample','gd_step','gd_event','gd_half','gd_message']]
with (out/'test.log').open('x') as log:
    completed=subprocess.run(command,cwd=out,stdout=log,stderr=subprocess.STDOUT)
after=sources();(out/'sources-after.json').write_text(json.dumps(after,sort_keys=True)+'\n')
observation=json.loads((out/'observation.json').read_text()) if (out/'observation.json').exists() else None
report=dict(schema=1,scope='fresh_eligibility_actual_imported_example_common4_static9c66_nilOwner_noSDK_noTiming',
            argv=command,exit_code=completed.returncode,source_fence_unchanged=before==after,
            source_manifest_sha256=sha(out/'sources-after.json'),
            native_archive=str(native),native_archive_sha256=sha(native),
            native_manifest_sha256=sha(native.with_name('build-manifest.json')),
            binary_sha256=sha(out/'fresh-intent') if (out/'fresh-intent').exists() else None,
            observation=observation,
            files={p.name:dict(bytes=p.stat().st_size,sha256=sha(p)) for p in out.glob('*.bin')},
            log_sha256=sha(out/'test.log'))
if observation:
    controls=['unknown41_within_original_window','before_pair_equal','after_pair_equal',
              'client_publication_unchanged','accepted_unchanged','no_new_packets','effects_unchanged',
              'first41_fullparts_equal','first41_fx_equal','published_identity_preserved','host_known_slot_bypassed']
    cleanup=['native_live','wrapper_live','provider_live','checkpoint_live','diagnostic_live','odin_live']
    report['all_recorded_preservation_controls']=all(observation[k] for k in controls)
    report['cleanup_zero']=all(observation[k]==0 for k in cleanup)
    report['proposed_criterion_failed']=not observation['proposed_criterion_pass']
    report['focused_groups']=3
    report['unchanged_legacy_functions_invoked_once']=[
        'prefetch_never_emits_early_and_abort_keeps_same_attempt',
        'two_unsampled_reset_links_keep_original_due',
        'published_sample_without_packet_is_not_retargeted',
        'no_tick_after_end_is_explicit_failure',
        'fresh_source_catalog_does_not_recreate_retired_scenario_inputs']
    report['other_getter_error_runtime_control']='not reachable with current attached-network public getter; explicit non-History_Missing error branch source-audited only'
(out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(dict(report=str(out/'report.json'),report_sha256=sha(out/'report.json'),
                     actual_exit=completed.returncode,observation_saved=observation is not None),indent=2))
sys.exit(completed.returncode)
