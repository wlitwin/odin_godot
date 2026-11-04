#!/usr/bin/env python3
"""One focused PURE actual-producer suite; never actual control coverage."""
from pathlib import Path
import hashlib,json,subprocess,sys
repo=Path(__file__).resolve().parents[5]
out=Path(sys.argv[1]).resolve();out.mkdir(parents=True,exist_ok=False)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
native=Path('/tmp/odin-box3d-goal-t4jbbj4v/box3d-native-zero42-v1/off-cache/build/Release/libogb3.a')
assert sha(native)=='2be61c6e0344c3449ba97d5ef2078dfbd6fb4772167d00695b12ac44a141f432'
assert sha(repo/'examples/kit_box3d/scripts/runtime.odin')=='7ef5cdfebe4c341e0158252acbd2b2c048806e76c28238f8dcddd6f90739044a'
def sources():
    roots=['kit','box3d','replay/schema','runtime','godot','gdext','examples/box3d_common','examples/kit_box3d/scripts','tests/box3d_soak/kit/input_admission/confirmed_controls']
    return dict(sorted((str(p.relative_to(repo)),sha(p)) for root in roots for p in (repo/root).rglob('*') if p.is_file() and p.suffix in ('.odin','.py') and '__pycache__' not in p.parts))
before=sources();(out/'sources-before.json').write_text(json.dumps(before,sort_keys=True)+'\n')
argv=['nix','develop',str(repo),'--command','odin','test',str(repo/'tests/box3d_soak/kit/input_admission/confirmed_controls'),'-collection:godot='+str(repo),'-define:ODIN_TEST_THREADS=1','-define:BOX3D_LIBRARY='+str(native),'-o:speed','-debug','-extra-linker-flags:-lc++','-keep-executable','-out:'+str(out/'confirmed-controls')]
argv+=['-custom-attribute:'+n for n in ['gd_method','gd_connect','gd_rpc','gd_command','gd_tick','gd_input','gd_sample','gd_step','gd_event','gd_half','gd_message']]
with (out/'test.log').open('x') as log:run=subprocess.run(argv,cwd=out,stdout=log,stderr=subprocess.STDOUT)
after=sources();(out/'sources-after.json').write_text(json.dumps(after,sort_keys=True)+'\n')
validation=dict(ran=False,passed=False)
if run.returncode==0:
    try:
        rows=[]
        for line in (out/'test.log').read_text().splitlines():
            if line.startswith('{'):
                row=json.loads(line)
                if row.get('event')=='INPUT' or row.get('stage','').startswith('confirmed_control_'):rows.append(row)
        assert not [r for r in rows if r.get('event')=='INPUT']
        def no_float(v):
            assert type(v) is not float
            if isinstance(v,dict):
                for child in v.values():no_float(child)
            elif isinstance(v,list):
                for child in v:no_float(child)
        for r in rows:no_float(r)
        summaries={}
        for actor in range(701,708):
            actor_rows=[r for r in rows if r['session_generation']==actor]
            config=[r for r in actor_rows if r['stage']=='confirmed_control_config']
            unavailable=[r for r in actor_rows if r['stage']=='confirmed_control_unavailable']
            summary=[r for r in actor_rows if r['stage']=='confirmed_control_summary']
            assert len(config)==1 and len(summary)==1 and len(unavailable)<=8
            assert all(r['coverage_available'] is False for r in unavailable)
            assert summary[0]['domain_complete'] is False
            assert summary[0]['max_target']==65535 and summary[0]['max_input_rows']==131070
            summaries[actor]=summary[0]
        assert len(rows)==31
        a=summaries[701];assert a['expected']==20 and a['emitted']==0 and a['unavailable']==6 and a['duplicates_suppressed']==1 and a['through']==5
        a=summaries[702];assert a['expected']==200 and a['emitted']==0 and a['unavailable']==40 and a['unavailable_statuses']==8
        a=summaries[703];assert a['expected']==131070 and a['emitted']==131070 and a['capped']==2
        a=summaries[704];assert a['expected']==4 and a['emitted']==0 and a['unavailable']==4 and a['capped']==2
        for actor in [705,706,707]:assert summaries[actor]['emitted']==0 and summaries[actor]['unavailable']==2
        copies=json.loads((out/'copy-controls.json').read_text());assert len(copies)==12
        expected=[{'x':0,'z':0},{'x':-100,'z':100},{'x':-32768,'z':32767},{'x':32767,'z':-32768}]
        for i,item in enumerate(copies):
            assert item['valid'] is True and item['actual']==item['expected']==expected[i//3]
            assert item['origin']==i%3+1
            assert all(type(item['actual'][axis]) is int for axis in ['x','z'])
        layout=json.loads((out/'layout.json').read_text());assert layout['control_size']==4
        validation=dict(ran=True,passed=True,scope='PURE synthetic counters/world metadata; NO actual INPUT rows, accepted ledger or control-coverage proof',status_records=31,input_records=0,actors=7,copy_vectors=12,zero_negative_extreme_copy=True,malformed_filters=True,bounded_status=True,single_summary=True,cap_duplicate_gap_domain_truth=True,no_false_INPUT=True,layout=layout,synthetic_cap_note='actor703 emitted131070 is injected COUNTER metadata only; zero INPUT records were emitted')
    except Exception as e:validation=dict(ran=True,passed=False,error=repr(e))
(out/'producer-validation.json').write_text(json.dumps(validation,indent=2)+'\n')
report=dict(schema=1,scope='PURE focused actual Runtime evidence helpers; no initialized world/Lane/Native/SDK/Godot/admission/coverage/timing',argv=argv,actual_exit=run.returncode,groups=6,source_fence_unchanged=before==after,source_manifest_sha256=sha(out/'sources-after.json'),production_runtime_sha256=sha(repo/'examples/kit_box3d/scripts/runtime.odin'),native_link_only_archive=str(native),native_archive_sha256=sha(native),binary_sha256=sha(out/'confirmed-controls') if (out/'confirmed-controls').exists() else None,producer_validation=validation,log_sha256=sha(out/'test.log'),actual_constructor_meter_charge_verified=False)
(out/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(dict(actual_exit=run.returncode,validation_passed=validation['passed'],report=str(out/'report.json'),report_sha256=sha(out/'report.json')),indent=2))
sys.exit(run.returncode if run.returncode else (0 if validation['passed'] else 1))
