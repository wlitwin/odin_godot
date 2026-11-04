#!/usr/bin/env python3
"""One public4 baseline; run only after Root selects this frozen checkpoint."""
from pathlib import Path
import hashlib,json,subprocess,sys
repo=Path(__file__).resolve().parents[4]
assert (repo/'flake.nix').is_file()
assert (repo/'replay/net/input_timing.odin').is_file()
assert (repo/'replay/net/physics_pending.odin').is_file()
out=Path(sys.argv[1]).resolve();out.mkdir(parents=True,exist_ok=False)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
native=Path('/tmp/odin-box3d-goal-t4jbbj4v/box3d-native-zero42-v1/off-cache/build/Release/libogb3.a')
assert sha(native)=='2be61c6e0344c3449ba97d5ef2078dfbd6fb4772167d00695b12ac44a141f432'
def sources():
    roots=['box3d','replay','runtime','godot','gdext','tests/replay_physics_net/fixture',
           'tests/box3d_soak/replay/action_retire','tests/box3d_soak/replay/input_fidelity']
    return dict(sorted((str(p.relative_to(repo)),sha(p)) for root in roots for p in (repo/root).rglob('*')
                       if p.is_file() and p.suffix in ('.odin','.py') and '__pycache__' not in p.parts))
before=sources();assert before and 'replay/net/input_timing.odin' in before and 'replay/net/physics_pending.odin' in before
(out/'sources-before.json').write_text(json.dumps(before,sort_keys=True)+'\n')
argv=['nix','develop',str(repo),'--command','odin','test',str(repo/'tests/box3d_soak/replay/input_fidelity'),
      '-collection:godot='+str(repo),'-define:ODIN_TEST_THREADS=1','-define:BOX3D_LIBRARY='+str(native),
      '-o:speed','-debug','-extra-linker-flags:-lc++','-keep-executable','-out:'+str(out/'input-fidelity')]
with (out/'test.log').open('x') as log:run=subprocess.run(argv,cwd=out,stdout=log,stderr=subprocess.STDOUT)
after=sources();(out/'sources-after.json').write_text(json.dumps(after,sort_keys=True)+'\n')
o=json.loads((out/'observation.json').read_text()) if (out/'observation.json').exists() else None
report=dict(schema=1,scope='ONE_public_generic4_completePhysics_ServerClient_Memory_staticOFFddff_nilOwner',argv=argv,
            actual_exit=run.returncode,source_fence_unchanged=before==after,source_manifest_sha256=sha(out/'sources-after.json'),
            native_archive=str(native),native_archive_sha256=sha(native),
            binary_sha256=sha(out/'input-fidelity') if (out/'input-fidelity').exists() else None,
            observation=o,log_sha256=sha(out/'test.log'),
            transport_trace_sha256=sha(out/'actual-memory-trace.json') if (out/'actual-memory-trace.json').exists() else None,
            packet_hash_source='real public Memory Trace payload_hash, not fabricated ACK or private complete parser',
            managed_owner_mode='nilOwner standalone; no Core/SDK owner activation or managed cleanup claim')
if o:
    controls=['control_admitted','control_executed','header_current_scope','complete_applied','full5_equal','cleanup_observed']
    report['all_other_recorded_controls']=o['setup_complete'] and all(o[k] for k in controls)
    report['expected_baseline_RED_reached']=o['setup_complete'] and not o['feedback_active']
    report['actual_ERROR_count']=sum('[ERROR]' in line for line in (out/'test.log').read_text().splitlines())
(out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(dict(actual_exit=run.returncode,report=str(out/'report.json'),report_sha256=sha(out/'report.json'),observation_saved=o is not None),indent=2))
sys.exit(run.returncode)
