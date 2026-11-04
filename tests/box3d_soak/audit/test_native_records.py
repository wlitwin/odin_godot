"""Pure Native observation record controls; no Native/Godot/clock/process."""
import copy
import json
from pathlib import Path
import tempfile
import unittest

import analyze
import records as r
from test_analyze import meta, sample, end, H


def native_meta(functional=None):
    m=meta('functional_only' if functional else 'profile')
    paths={1:'box3d/native/api.c',**{i:'box3d/native/owned_snapshot.c' for i in range(2,7)},
           **{i:'box3d/native/recovery_codec.c' for i in range(7,13)}}
    for path in sorted(set(paths.values())):
        m['boundary']['source_refs'].append(dict(path=path,symbol='selected_native_sites',sha256=H))
    m['native_observer']=dict(abi_version=1,mode=functional or 'timed',block_bytes=49392,span_bytes=48,
        capacity=1024,stack_capacity=16,phase_mask=4095,clock_domain='godot_ticks_usec',native_static_bytes=48,
        binding_control_bytes=32,clock_binding_static_bytes=24,meter_context_bytes=219928,
        source_phase_map=[dict(phase=i,name=r.NATIVE_PHASE_NAMES[i],path=paths[i],symbol='actual_selected_site',sha256=H) for i in range(1,13)],
        native_status_names=copy.deepcopy(r.NATIVE_STATUS_NAMES),overhead='inside_whole')
    if not functional:m['exclusive_grant']='synthetic-only-not-a-real-grant'
    return m


def block(mode=2):
    spans=[dict(id=1,parent_id=0,root_ordinal=1,phase=2,native_status=0,start_us=1100,end_us=1700),
           dict(id=2,parent_id=1,root_ordinal=1,phase=3,native_status=-(2**31),start_us=1200,end_us=1500),
           dict(id=3,parent_id=0,root_ordinal=2,phase=1,native_status=0,start_us=1800,end_us=1900)]
    if mode==1:
        for span in spans:span['start_us']=span['end_us']=0
    return dict(abi_version=1,struct_bytes=49392,mode=mode,capacity=1024,count=3,stack_depth=0,error_flags=0,state=2,
        scope_token=2**64-1,domain_cookie=2**63+9,next_span_id=4,root_count=2,clock_reads=6 if mode==2 else 0,
        clock_errors=0,overflow_count=0,nesting_errors=0,last_clock_us=1900 if mode==2 else 0,phase_mask=4095,
        stack=[0]*16,spans=spans)


def derived(b):
    return [dict(name=r.NATIVE_PHASE_NAMES[x['phase']],duration_ns=(x['end_us']-x['start_us'])*1000,
        clock_domain='godot_ticks_usec',start_us=x['start_us'],end_us=x['end_us'],relation='native_nested_in_whole',
        native_span_id=x['id'],native_parent_id=x['parent_id'],native_root_ordinal=x['root_ordinal'],
        native_phase=x['phase'],native_status=x['native_status']) for x in b['spans']]


def native_sample(op,seq):
    s=sample(op,seq);s['native_observation']=block();s['phases']=derived(s['native_observation']);return s


def native_result(functional=None):
    value=end(0 if functional else 2)
    value['native_observation']=None if functional=='off' else block(1)
    value['native_clock_prewarm_calls']=0 if functional else 1
    return value


class NativeRecordControls(unittest.TestCase):
    def run_values(self,values):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);p=root/'input.jsonl';p.write_text(''.join(json.dumps(x)+'\n' for x in values))
            report=analyze.analyze(p,root/'out')
            raw=(root/'out/samples.jsonl').read_text() if (root/'out/samples.jsonl').exists() else ''
            return report,raw

    def test_valid_raw_derived_native_uint64_and_unavailable_status_roundtrip(self):
        report,raw=self.run_values([native_meta(),native_sample('normal',1),native_sample('repair8',2),native_result()])
        self.assertEqual(report['result'],'RECORDS_VALID');self.assertEqual(report['operation_findings_count'],0)
        saved=json.loads(raw.splitlines()[0]);self.assertEqual(saved['native_observation']['scope_token'],2**64-1)
        self.assertEqual(saved['native_observation']['domain_cookie'],2**63+9)
        self.assertEqual(saved['native_observation']['spans'][1]['native_status'],-(2**31))
        self.assertFalse(report['phase_sum_used_as_whole']);self.assertEqual(report['statistics']['normal']['max_ns'],3_000_000)

    def test_native_metadata_and_explicit_grant_are_exact_optin(self):
        changes=(lambda m:m.pop('exclusive_grant'),lambda m:m['native_observer'].update(block_bytes=49384),
                 lambda m:m['native_observer'].update(clock_binding_static_bytes=0),
                 lambda m:m['native_observer'].update(native_static_bytes=0),
                 lambda m:m['native_observer'].update(meter_context_bytes=0),
                 lambda m:m['native_observer'].update(phase_mask=32767),
                 lambda m:m['native_observer']['native_status_names'].update({'-2147483648':'OK'}),
                 lambda m:m['native_observer']['source_phase_map'][0].update(sha256='2'*64))
        for change in changes:
            m=native_meta();change(m)
            with self.subTest(change=change):
                with self.assertRaises(r.RecordError):r.validate_meta(m)

    def test_observation_flags_fail_without_rewriting_committed_game(self):
        for field,value in (('error_flags',1),('clock_errors',1),('overflow_count',1),('nesting_errors',1),
                            ('stack_depth',1),('state',1),('mode',1),('root_count',3),('next_span_id',5)):
            with self.subTest(field=field):
                a=native_sample('repair8',2);a['native_observation'][field]=value
                report,raw=self.run_values([native_meta(),native_sample('normal',1),a,native_result()])
                self.assertEqual(report['result'],'FAIL');self.assertEqual(report['samples_retained'],2)
                self.assertEqual(json.loads(raw.splitlines()[1])['outcome'],'committed')
                self.assertTrue(json.loads(raw.splitlines()[1])['proof']['full_state_equal'])

    def test_invalid_clock_failure_omits_only_native_derived_and_keeps_all_raw(self):
        s=native_sample('repair8',2);b=s['native_observation']
        b['error_flags']=4;b['clock_errors']=1;b['spans'][1].update(start_us=1200,end_us=0)
        s['phases']=[dict(name='existing_odin_duration_only',duration_ns=1000,clock_domain='native_ns',start_us=None,end_us=None,relation='nested')]
        report,raw=self.run_values([native_meta(),native_sample('normal',1),s,native_result()])
        self.assertEqual(report['result'],'FAIL');self.assertEqual(report['samples_retained'],2)
        saved=json.loads(raw.splitlines()[1]);self.assertEqual(saved['outcome'],'committed')
        self.assertEqual(saved['native_observation'],b);self.assertEqual(len(saved['phases']),1)
        self.assertEqual(saved['native_observation']['spans'][1]['end_us'],0)
        valid=native_sample('repair8',2);valid['phases']=[]
        report,_=self.run_values([native_meta(),native_sample('normal',1),valid,native_result()])
        self.assertEqual(report['result'],'FAIL');self.assertIn('one-for-one',report['error'])

    def test_raw_and_derived_cannot_be_aliased_renamed_or_silently_dropped(self):
        changes=(lambda s:s['phases'].pop(),lambda s:s['phases'].append(copy.deepcopy(s['phases'][0])),
                 lambda s:s['phases'][0].update(native_status=-(2**31)),
                 lambda s:s['phases'][1].update(native_parent_id=0),
                 lambda s:s['phases'][0].update(name='native.fake'),
                 lambda s:s['native_observation']['spans'][0].update(status_name='OK'),
                 lambda s:s['native_observation'].update(count=1025))
        for change in changes:
            s=native_sample('repair8',2);change(s)
            report,raw=self.run_values([native_meta(),native_sample('normal',1),s,native_result()])
            with self.subTest(change=change):
                self.assertEqual(report['result'],'FAIL');self.assertEqual(len(raw.splitlines()),2)

    def test_parent_root_clock_nesting_and_known_native_status_are_observed(self):
        changes=(lambda b:b['spans'][1].update(parent_id=2),lambda b:b['spans'][1].update(root_ordinal=2),
                 lambda b:b['spans'][1].update(end_us=1750),lambda b:b['spans'][2].update(start_us=1600),
                 lambda b:b['spans'][1].update(native_status=-1),lambda b:b.update(clock_reads=5),
                 lambda b:b.update(last_clock_us=1800),lambda b:b.update(stack=[1]+[0]*15))
        for change in changes:
            b=block();change(b);r.validate_native_block(b)
            with self.subTest(change=change):self.assertTrue(r.native_findings(b,2,(1000,4000)))

    def test_uint64_float_rounding_bool_and_signed_status_corruption_fail(self):
        changes=(lambda b:b.update(scope_token=float(2**64-1)),lambda b:b.update(domain_cookie=True),
                 lambda b:b.update(scope_token=2**64),lambda b:b['spans'][1].update(native_status=2**31),
                 lambda b:b['spans'][0].update(start_us=1100.0))
        for change in changes:
            b=block();change(b)
            with self.subTest(change=change):
                with self.assertRaises(r.RecordError):r.validate_native_block(b)

    def test_functional_off_structure_no_clock_sample_and_final160_untimed(self):
        for mode in ('off','structure_only'):
            m=native_meta(mode);result=native_result(mode)
            if mode=='structure_only':result['native_functional_scopes']=[block(1) for _ in range(20)]
            report,raw=self.run_values([m,result])
            self.assertEqual(report['result'],'FUNCTIONAL_PASS');self.assertEqual(raw,'')
            self.assertEqual(report['cpu_candidate_acceptance'],'NOT_MEASURED')
            bad=copy.deepcopy(result);bad['native_clock_prewarm_calls']=1
            report,_=self.run_values([m,bad]);self.assertEqual(report['result'],'FAIL')
        m=native_meta('structure_only');bad=native_result('structure_only');bad['native_observation']['clock_reads']=1
        report,_=self.run_values([m,bad]);self.assertEqual(report['result'],'FAIL')
        report,_=self.run_values([native_meta('structure_only'),native_sample('normal',1),native_result('structure_only')])
        self.assertEqual(report['result'],'FAIL')
        timed=native_result();timed['native_observation']=block(2)
        report,_=self.run_values([native_meta(),native_sample('normal',1),native_sample('repair8',2),timed])
        self.assertEqual(report['result'],'FAIL')


if __name__=='__main__':unittest.main()
