#!/usr/bin/env python3
"""One actual imported-credit-helper PURE run; no Runtime frame or live receipt."""
from pathlib import Path
import hashlib,json,subprocess,sys
repo=Path(__file__).resolve().parents[5];out=Path(sys.argv[1]).resolve();out.mkdir(parents=True,exist_ok=False)
native=Path('/tmp/odin-box3d-goal-t4jbbj4v/box3d-native-zero42-v1/off-cache/build/Release/libogb3.a')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(native)=='2be61c6e0344c3449ba97d5ef2078dfbd6fb4772167d00695b12ac44a141f432'
def sources():
    roots=['box3d','kit','replay/schema','runtime','godot','gdext','examples/box3d_common','examples/kit_box3d/scripts','tests/box3d_slices/kit/intents','tests/box3d_soak/kit/input_admission/caller_delta','tests/box3d_soak/kit/input_admission/caller_credit']
    return dict(sorted((str(p.relative_to(repo)),sha(p)) for root in roots for p in (repo/root).rglob('*') if p.is_file() and p.suffix in ('.odin','.py') and '__pycache__' not in p.parts))
assert sha(repo/'examples/kit_box3d/scripts/runtime.odin')=='8a23ffda9b2ff11a3a5bc38805eb42f35e299bac5f915e2bdbc831382ed70c70'
before=sources();(out/'sources-before.json').write_text(json.dumps(before,sort_keys=True)+'\n')
argv=['nix','develop',str(repo),'--command','odin','test',str(repo/'tests/box3d_soak/kit/input_admission/caller_credit'),'-collection:godot='+str(repo),'-define:ODIN_TEST_THREADS=1','-define:BOX3D_LIBRARY='+str(native),'-o:speed','-debug','-extra-linker-flags:-lc++','-keep-executable','-out:'+str(out/'caller-credit')]
argv+=['-custom-attribute:'+n for n in ['gd_method','gd_connect','gd_rpc','gd_command','gd_tick','gd_input','gd_sample','gd_step','gd_event','gd_half','gd_message']]
with (out/'test.log').open('x') as log:run=subprocess.run(argv,cwd=out,stdout=log,stderr=subprocess.STDOUT)
after=sources();(out/'sources-after.json').write_text(json.dumps(after,sort_keys=True)+'\n')
result=dict(schema=1,scope='PURE_actual_example_credit_helpers_synthetic_Boundary_metadata_only_no_live_Lane_Native_publication_Runtime_frame_Godot_or_timing',argv=argv,actual_exit=run.returncode,source_fence_unchanged=before==after,source_manifest_sha256=sha(out/'sources-after.json'),native_link_only_archive=str(native),native_archive_sha256=sha(native),binary_sha256=sha(out/'caller-credit') if (out/'caller-credit').exists() else None,differential=json.loads((out/'differential.json').read_text()) if (out/'differential.json').exists() else None,layout=json.loads((out/'layout.json').read_text()) if (out/'layout.json').exists() else None,log_sha256=sha(out/'test.log'),unchanged_legacy_controls=5,production_runtime_sha256=sha(repo/'examples/kit_box3d/scripts/runtime.odin'),expected_production_sha256='8a23ffda9b2ff11a3a5bc38805eb42f35e299bac5f915e2bdbc831382ed70c70',no_actual_runtime_allocation_proof=True)
(out/'report.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(dict(actual_exit=run.returncode,report=str(out/'report.json'),report_sha256=sha(out/'report.json')),indent=2));sys.exit(run.returncode)
