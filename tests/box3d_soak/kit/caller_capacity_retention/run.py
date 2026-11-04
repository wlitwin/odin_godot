#!/usr/bin/env python3
"""One selected pure baseline; never run before Root's explicit grant."""
from pathlib import Path
import hashlib,json,os,subprocess,sys

REPO=Path(__file__).resolve().parents[4]
assert (REPO/'flake.nix').is_file()
EXPECTED={
 'examples/kit_box3d/scripts/runtime.odin':'561190144488617e3f1d9676e5cc39b9b0ac0dc4e7b228f81fcbbe25f039b6fa',
 'examples/kit_box3d/scripts/intents.odin':'dc0c537b18594b73da01304b36e49f8ab039d9203657a720c970e7508f86b700',
 'examples/kit_box3d/scripts/kitslice.odin':'d3faad33fa48d7dd4d5a6843d5e406f3d1228fb322f7b759f6fd49fe7f1ac01a',
}
ROOTS=['box3d','kit','runtime','godot','gdext','examples/box3d_common','examples/kit_box3d/scripts','tests/box3d_soak/kit/caller_capacity_retention']
NATIVE=Path('/tmp/odin-box3d-goal-t4jbbj4v/box3d-native-zero42-v1/off-cache/build/Release/libogb3.a')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def sources():return dict(sorted((str(p.relative_to(REPO)),sha(p)) for root in ROOTS for p in (REPO/root).rglob('*') if p.is_file() and p.suffix in ('.odin','.py') and '__pycache__' not in p.parts))
def main():
 out=Path(sys.argv[1]).resolve();appgen_path=Path(sys.argv[2]).resolve();appgen=json.loads(appgen_path.read_text())
 assert appgen['actual_exit_code']==0 and appgen['source_fence_unchanged'] is True
 for key,value in EXPECTED.items():assert sha(REPO/key)==value and appgen['production_sources'][key]==value,key
 for key,value in appgen['generated_sources'].items():assert sha(REPO/key)==value,key
 assert sha(NATIVE)=='2be61c6e0344c3449ba97d5ef2078dfbd6fb4772167d00695b12ac44a141f432'
 out.mkdir(parents=True,exist_ok=False);before=sources()
 (out/'sources-before.json').write_text(json.dumps(before,sort_keys=True,indent=2)+'\n')
 (out/'appgen-record.json').write_bytes(appgen_path.read_bytes())
 argv=['nix','develop',str(REPO),'--command','odin','test',str(Path(__file__).resolve().parent),'-collection:godot='+str(REPO),'-define:ODIN_TEST_THREADS=1','-define:BOX3D_LIBRARY='+str(NATIVE),'-o:speed','-debug','-extra-linker-flags:-lc++','-keep-executable','-out:'+str(out/'current-capacity-pure')]
 argv+=['-custom-attribute:'+x for x in ['gd_method','gd_connect','gd_rpc','gd_command','gd_tick','gd_input','gd_sample','gd_step','gd_event','gd_half','gd_message']]
 (out/'command.json').write_text(json.dumps(argv,indent=2)+'\n')
 with (out/'test.log').open('x') as log:result=subprocess.run(argv,cwd=out,env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1'},stdout=log,stderr=subprocess.STDOUT)
 after=sources();(out/'sources-after.json').write_text(json.dumps(after,sort_keys=True,indent=2)+'\n')
 observation_path=out/'retention-observation.json';observation=json.loads(observation_path.read_text()) if observation_path.exists() else None
 log=(out/'test.log').read_text();errors=sum('[ERROR]' in x for x in log.splitlines())
 expected_RED=observation is not None and observation['setup_complete'] and not observation['combined_prospective_criterion'] and result.returncode==1 and errors==1 and 'EXPECTED prospective RED:' in log and 'Finished 1 test' in log
 report=dict(schema=1,scope='PURE actual helper offer/settle synthetic receipt; no Runtime/Lane/World/Native or historical-cause proof',actual_exit=result.returncode,source_fence_unchanged=before==after,source_manifest_sha256=sha(out/'sources-after.json'),log_sha256=sha(out/'test.log'),Appgen_sha256=sha(appgen_path),native_archive_sha256=sha(NATIVE),binary_sha256=sha(out/'current-capacity-pure') if (out/'current-capacity-pure').exists() else None,observation=observation,observation_sha256=sha(observation_path) if observation is not None else None,actual_ERROR_count=errors,expected_one_prospective_RED_reached=expected_RED,actual_Runtime_or_Native_or_cleanup_claim=False)
 (out/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(dict(actual_exit=result.returncode,report=str(out/'report.json'),report_sha256=sha(out/'report.json'),expected_one_RED=expected_RED),indent=2));return result.returncode
if __name__=='__main__':sys.exit(main())
