#!/usr/bin/env python3
"""One CASE_A plain compile/test. Any setup failure stops without workaround."""
from pathlib import Path
import hashlib,json,subprocess,sys
repo=Path(__file__).resolve().parents[4];out=Path(sys.argv[1]).resolve();out.mkdir(parents=True,exist_ok=False)
native=Path('/tmp/odin-box3d-goal-t4jbbj4v/box3d-native-zero42-v1/off-cache/build/Release/libogb3.a')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(native)=='2be61c6e0344c3449ba97d5ef2078dfbd6fb4772167d00695b12ac44a141f432'
def sources():
    roots=['box3d','replay','tests/replay_physics_net/fixture','tests/box3d_soak/replay/action_retire','tests/box3d_soak/replay/action_scope_case_a']
    return dict(sorted((str(p.relative_to(repo)),sha(p)) for root in roots for p in (repo/root).rglob('*') if p.is_file() and p.suffix in ('.odin','.py') and '__pycache__' not in p.parts))
before=sources();(out/'sources-before.json').write_text(json.dumps(before,sort_keys=True)+'\n')
argv=['nix','develop',str(repo),'--command','odin','test',str(repo/'tests/box3d_soak/replay/action_scope_case_a'),'-collection:godot='+str(repo),'-define:ODIN_TEST_THREADS=1','-define:BOX3D_LIBRARY='+str(native),'-o:speed','-debug','-extra-linker-flags:-lc++','-keep-executable','-out:'+str(out/'case-a')]
with (out/'test.log').open('x') as log:run=subprocess.run(argv,cwd=out,stdout=log,stderr=subprocess.STDOUT)
after=sources();(out/'sources-after.json').write_text(json.dumps(after,sort_keys=True)+'\n')
case=json.loads((out/'case-report.json').read_text()) if (out/'case-report.json').exists() else None
result=dict(schema=1,scope='CASE_A_generic4_staticOFFddff_nilOwner_publicLinkMemory_controlledReliablehold_reorder_NOTENet_NOTSDK32',argv=argv,actual_exit=run.returncode,source_fence_unchanged=before==after,source_manifest_sha256=sha(out/'sources-after.json'),native_archive=str(native),native_archive_sha256=sha(native),native_manifest_sha256=sha(native.with_name('build-manifest.json')),binary_sha256=sha(out/'case-a') if (out/'case-a').exists() else None,case=case,raw_packets={p.name:dict(bytes=p.stat().st_size,sha256=sha(p)) for p in out.glob('raw-*.bin')},log_sha256=sha(out/'test.log'),no_fallback_retry=True)
(out/'report.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(dict(actual_exit=run.returncode,report=str(out/'report.json'),report_sha256=sha(out/'report.json'),case_stage=case.get('stage') if case else None,ok=bool(case and case.get('ok') and run.returncode==0 and before==after)),indent=2))
sys.exit(run.returncode)
