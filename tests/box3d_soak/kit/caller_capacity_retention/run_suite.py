#!/usr/bin/env python3
"""Eight PURE groups; execute only after Root's explicit coherent-run grant."""
from pathlib import Path
import hashlib,json,os,re,subprocess,sys

REPO=Path(__file__).resolve().parents[4]
assert (REPO/'flake.nix').is_file()
EXPECTED={
 'examples/kit_box3d/scripts/runtime.odin':'41879adff7934b78eb0cba779b42c0667805762209e2ddcfd47d4bcfade83ecc',
 'examples/kit_box3d/scripts/intents.odin':'dc0c537b18594b73da01304b36e49f8ab039d9203657a720c970e7508f86b700',
 'examples/kit_box3d/scripts/kitslice.odin':'d3faad33fa48d7dd4d5a6843d5e406f3d1228fb322f7b759f6fd49fe7f1ac01a',
}
ROOTS=['box3d','kit','runtime','godot','gdext','examples/box3d_common','examples/kit_box3d/scripts','tests/box3d_soak/kit/caller_capacity_retention']
NATIVE=Path('/tmp/odin-box3d-goal-t4jbbj4v/box3d-native-zero42-v1/off-cache/build/Release/libogb3.a')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def sources():return dict(sorted((str(p.relative_to(REPO)),sha(p)) for root in ROOTS for p in (REPO/root).rglob('*') if p.is_file() and p.suffix in ('.odin','.py') and '__pycache__' not in p.parts))
def main():
 out=Path(sys.argv[1]).resolve();appgen_path=Path(sys.argv[2]).resolve();appgen=json.loads(appgen_path.read_text())
 assert sha(appgen_path)=='f401d9c720be8cfa296da00a6f9d61426118507446a66e3640b97f77e5a63144'
 assert appgen['actual_exit_code']==0 and appgen['source_fence_unchanged'] is True
 for key,value in EXPECTED.items():assert sha(REPO/key)==value and appgen['production_sources'][key]==value,key
 for key,value in appgen['generated_sources'].items():assert sha(REPO/key)==value,key
 assert sha(NATIVE)=='2be61c6e0344c3449ba97d5ef2078dfbd6fb4772167d00695b12ac44a141f432'
 package=Path(__file__).resolve().parent
 assert sha(package/'retention_test.odin')=='b84dba040def87fa92382bd69c9bfc036e55d86b99aaac9ce101c5880762af4c'
 names=[name for p in sorted(package.glob('*.odin')) for name in re.findall(r'@\(test\)\s*(\w+)\s*::\s*proc',p.read_text())];assert len(names)==8
 out.mkdir(parents=True,exist_ok=False);before=sources();(out/'sources-before.json').write_text(json.dumps(before,sort_keys=True,indent=2)+'\n');(out/'appgen-record.json').write_bytes(appgen_path.read_bytes())
 argv=['nix','develop',str(REPO),'--command','odin','test',str(package),'-collection:godot='+str(REPO),'-define:ODIN_TEST_THREADS=1','-define:BOX3D_LIBRARY='+str(NATIVE),'-o:speed','-debug','-extra-linker-flags:-lc++','-keep-executable','-out:'+str(out/'current-capacity-pure')]
 argv+=['-custom-attribute:'+x for x in ['gd_method','gd_connect','gd_rpc','gd_command','gd_tick','gd_input','gd_sample','gd_step','gd_event','gd_half','gd_message']]
 (out/'command.json').write_text(json.dumps(argv,indent=2)+'\n')
 with (out/'test.log').open('x') as log:result=subprocess.run(argv,cwd=out,env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1'},stdout=log,stderr=subprocess.STDOUT)
 after=sources();(out/'sources-after.json').write_text(json.dumps(after,sort_keys=True,indent=2)+'\n');log=(out/'test.log').read_text()
 observation=json.loads((out/'retention-observation.json').read_text()) if (out/'retention-observation.json').exists() else None
 validation=None;validation_error=None
 if result.returncode==0:
  try:
   assert 'Finished 8 tests' in log and 'All tests were successful.' in log and '[ERROR]' not in log
   assert observation is not None and observation['setup_complete'] and observation['combined_prospective_criterion']
   assert all(observation[k] for k in ['offered_valid','settled_valid','conservation_valid','exact_offered_debit'])
   properties=json.loads((out/'retention-properties.json').read_text());ulp=json.loads((out/'retention-ulp.json').read_text())
   assert properties['cases']==320 and ulp['once_pending']==ulp['twice_pending'] and ulp['once_excluded']==ulp['twice_excluded']
   assert all(type(v) is int for k,v in ulp.items() if k!='scope')
   validation=dict(scope='PURE synthetic helper evidence only',result='PASS',groups=8,property_cases=320,baseline_green=True,ULP_repeat_bit_exact=True)
  except Exception as error:validation_error=repr(error)
 if validation is not None:(out/'saved-json-validation.json').write_text(json.dumps(validation,indent=2)+'\n')
 report=dict(schema=1,scope='actual imported helpers with synthetic receipt/Boundary and caller_store POD; NO Runtime create/frame/destroy/Lane/World/Native ownership',actual_exit=result.returncode,groups=names,source_fence_unchanged=before==after,source_manifest_sha256=sha(out/'sources-after.json'),log_sha256=sha(out/'test.log'),Appgen_sha256=sha(appgen_path),binary_sha256=sha(out/'current-capacity-pure') if (out/'current-capacity-pure').exists() else None,baseline_observation=observation,saved_JSON=validation,saved_JSON_error=validation_error,actual_Runtime_Native_or_cleanup_claim=False)
 (out/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(dict(actual_exit=result.returncode,report=str(out/'report.json'),report_sha256=sha(out/'report.json'),saved_JSON_error=validation_error),indent=2))
 return result.returncode if result.returncode else (0 if before==after and validation is not None else 1)
if __name__=='__main__':sys.exit(main())
