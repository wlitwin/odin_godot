"""Synthetic parser/analyzer controls only: no probe, timer, Native or Godot run."""
import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import analyze
import records as r

H = '1' * 64


def meta(mode='profile'):
    return dict(event='GATE_B_META',schema=1,run_id='synthetic-validator-control',framework='replay',timing_mode=mode,
        fixture=dict(id='common32_spheres_crates_extra_capsule',profile_hex='534c494345503031',descriptor_sha256=H,initial_dynamic=32,
                     reference_peak=dict(bodies=35,shapes=35,contacts=122,joints=1)),
        execution=dict(core='actual_godot_core',ownership='sdk_meter',native_linkage='shared_dso',transport='offline_public_packets',native_images=1),
        identity=dict(os='test',arch='test',configuration='test',godot='test',**{key:H for key in ('source_manifest_sha256','core_binary_sha256','script_binary_sha256','native_binary_sha256','native_build_sha256','native_target_sha256')}),
        limits=copy.deepcopy(r.LIMITS),boundary=dict(id='core_public_ingress_v1',receiver_entry='session_frame',clock_domain='godot_ticks_usec',clock_resolution_ns=1000,
            included_work=sorted(r.NORMAL_WORK|r.REPAIR_WORK),excluded_work=['diagnostic_output'],source_refs=[dict(path='probe.odin',symbol='operation',sha256=H)]),
        sample_plan=dict(normal=1 if mode=='profile' else 0,repair8=1 if mode=='profile' else 0))


def sample(op, seq, ns=3_000_000):
    repair=op=='repair8'
    return dict(event='GATE_B_SAMPLE',schema=1,run_id='synthetic-validator-control',seq=seq,operation=op,epoch=1,
        base_tick=152 if repair else 159,head_before=160 if repair else 159,head_after=160,
        confirmed_before=152 if repair else 159,confirmed_after=160,requested_depth=8 if repair else 0,
        actual_steps_before=20,actual_steps_after=28 if repair else 21,outcome='committed',
        outer_start_us=1000,outer_end_us=1000+ns//1000,whole_ns=ns,included_work=sorted(r.REPAIR_WORK if repair else r.NORMAL_WORK),
        proof=dict(full_state_equal=True,publication_atomic=True,quota_ok=True,expected_complete_sha256=H,actual_complete_sha256=H),
        counts=dict(bodies=34,shapes=34,contacts=120,joints=1),
        ledger=dict(live_bytes=20_000_000,reserved_bytes=2_000_000,admitted_bytes=22_000_000,limit_bytes=r.TRACKED_BYTES,committed_peak_bytes=25_000_000,storage_bytes=10276),phases=[])


def end(count=2):
    return dict(event='GATE_B_RESULT',schema=1,run_id='synthetic-validator-control',sample_count=count,functional_operations=2,
        correctness_ok=True,source_fence_unchanged=True,binary_fence_unchanged=True,
        cleanup=dict(native_live_bytes=0,snapshot_live_bytes=0,host_application_live_bytes=0,all_explicit_drops_ok=True,core_shutdown_clean=True,
                     ownership_evidence='synthetic fixture only'))


def normal_meta(kind, mode='profile'):
    value = meta(mode)
    value.update(normal_kind=kind, step_observation=r.NORMAL_STEP_OBSERVATION)
    value['boundary'].update(receiver_entry=r.NORMAL_ENTRIES[kind], included_work=sorted(r.NORMAL_WORK))
    value['sample_plan'] = dict(normal=19 if mode == 'profile' else 0, repair8=0)
    return value


def normal_sample(kind, seq=1):
    value = sample('normal', seq)
    value.update(normal_kind=kind, step_observation=r.NORMAL_STEP_OBSERVATION,
                 actual_steps_before=None, actual_steps_after=None)
    if kind == 'client_prediction_send':
        value.update(confirmed_before=152, confirmed_after=152)
    value['proof'].update(successful_public_step=True, external_require_step=True,
                          committed_tick_before=159, committed_tick_after=160)
    return value


class Controls(unittest.TestCase):
    def run_records(self, values):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);path=root/'input.jsonl'
            path.write_text(''.join(json.dumps(value)+'\n' for value in values))
            report=analyze.analyze(path,root/'out')
            raw=(root/'out/samples.jsonl').read_text() if (root/'out/samples.jsonl').exists() else ''
            return report,raw

    def test_core_only_cannot_replace_whole(self):
        repair=sample('repair8',2,5_000_000)
        repair['phases']=[dict(name='core',duration_ns=3_000_000,clock_domain='native_ns',start_us=None,end_us=None,relation='nested_in_whole')]
        report,raw=self.run_records([meta(),sample('normal',1),repair,end()])
        self.assertEqual(report['observed_whole_ceiling_result'],'FAIL')
        self.assertEqual(report['cpu_candidate_acceptance'],'INCOMPLETE') # Real provenance absent.
        self.assertEqual(report['statistics']['repair8']['max_ns'],5_000_000)
        self.assertIn('5000000',raw)

    def test_outlier_retained_and_fails_max_ceiling(self):
        m=meta();m['sample_plan']['normal']=2
        values=[sample('normal',1),sample('normal',2,9_000_000),sample('repair8',3)]
        report,raw=self.run_records([m,*values,end(3)])
        self.assertEqual(report['statistics']['normal']['raw_ns'],[3_000_000,9_000_000])
        self.assertEqual(report['statistics']['normal']['over_ceiling_count'],1)
        self.assertEqual(report['outliers_discarded'],0)

    def test_nested_phases_not_summed(self):
        s=sample('repair8',2)
        s['phases']=[dict(name=name,duration_ns=2_500_000,clock_domain='native_ns',start_us=None,end_us=None,relation='nested_in_decode') for name in ('decode','native')]
        report,_=self.run_records([meta(),sample('normal',1),s,end()])
        self.assertEqual(report['operation_findings_count'],0)
        self.assertEqual(report['statistics']['repair8']['max_ns'],3_000_000)
        self.assertFalse(report['phase_sum_used_as_whole'])
        self.assertEqual(report['cpu_candidate_acceptance'],'INCOMPLETE') # No real artifact proof.

    def test_cross_clock_absolute_interval_rejected(self):
        s=sample('repair8',2)
        s['phases']=[dict(name='native',duration_ns=1000,clock_domain='native_ns',start_us=1001,end_us=1002,relation='nested')]
        report,raw=self.run_records([meta(),sample('normal',1),s,end()])
        self.assertIn('cross-clock',report['error']);self.assertIn('native_ns',raw)

    def test_functional_has_no_fake_zero_measurement(self):
        report,_=self.run_records([meta('functional_only'),end(0)])
        self.assertEqual(report['cpu_candidate_acceptance'],'NOT_MEASURED')
        self.assertEqual(report['result'],'FUNCTIONAL_PASS')
        report,_=self.run_records([meta('functional_only'),sample('normal',1,0),end(1)])
        self.assertEqual(report['result'],'FAIL')

    def test_exact_tick_transitions_and_zero_short_noop_fail_retained(self):
        mutations=[lambda s:s.update(head_after=168,confirmed_after=168),
                   lambda s:s.update(confirmed_before=151),lambda s:s.update(confirmed_after=159),
                   lambda s:s.update(actual_steps_after=20),lambda s:s.update(actual_steps_after=27),
                   lambda s:s.update(whole_ns=0,outer_end_us=1000),lambda s:s.update(confirmed_before=161),
                   lambda s:s.update(confirmed_before=151,base_tick=151)]
        for change in mutations:
            with self.subTest(change=change):
                s=sample('repair8',2);change(s)
                report,raw=self.run_records([meta(),sample('normal',1),s,end()])
                self.assertEqual(report['cpu_candidate_acceptance'],'FAIL')
                self.assertEqual(report['samples_retained'],2);self.assertEqual(len(raw.splitlines()),2)
        s=sample('normal',1);s['head_after']=161
        report,_=self.run_records([meta(),s,sample('repair8',2),end()])
        self.assertGreater(report['operation_findings_count'],0)

    def test_profile_and_source_modes_do_not_mix(self):
        m=meta();m['fixture']['profile_hex']='504859534e455431'
        report,_=self.run_records([m,end(0)]);self.assertIn('identity mismatch',report['error'])
        m=meta();m['execution']['core']='registry_fake_core'
        report,_=self.run_records([m,sample('normal',1),sample('repair8',2),end()])
        self.assertEqual(report['cpu_candidate_acceptance'],'DIAGNOSTIC_ONLY')

    def test_repair_only_plan_does_not_fabricate_normal_boundary(self):
        m=meta();m['sample_plan']={'normal':0,'repair8':1};m['boundary']['included_work']=sorted(r.REPAIR_WORK)
        self.assertEqual(r.boundary_findings(m),[])
        report,_=self.run_records([m,sample('repair8',1),end(1)])
        self.assertEqual(report['cpu_candidate_acceptance'],'INCOMPLETE')
        self.assertEqual(report['statistics']['normal']['count'],0)
        m['sample_plan']['normal']=1
        self.assertTrue(any('normal_step_capture_admission' in value for value in r.boundary_findings(m)))

    def test_actual_artifact_map_required_and_runtime_census_not_label_only(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);probe=root/'probe.odin';probe.write_text('test fixture source only')
            files={name:root/name for name in ('core','script','native')}
            for name,path in files.items():path.write_text('synthetic '+name+' bytes, not an executable')
            manifest=root/'sources.json';manifest.write_text(json.dumps({'probe.odin':analyze.sha_file(probe)}))
            m=meta();ident=m['identity'];ident['source_manifest_sha256']=analyze.sha_file(manifest)
            m['boundary']['source_refs'][0]['sha256']=analyze.sha_file(probe)
            for name,path in files.items():ident[name+'_binary_sha256']=analyze.sha_file(path)
            mapping=dict(source_manifest=str(manifest),**{name+'_binary':str(path) for name,path in files.items()})
            path=root/'map.json';path.write_text(json.dumps(mapping))
            self.assertFalse(analyze.check_provenance(m,path,root)['verified'])
            build=root/'build.json';build.write_text(json.dumps(dict(exit_code=0,source_fence_unchanged=True,**{k:ident[k] for k in ('source_manifest_sha256','core_binary_sha256','script_binary_sha256','native_binary_sha256')})))
            observed=root/'observed.json';observed.write_text(json.dumps(dict(execution=m['execution'],identity=ident,image_census_observed=False)))
            mapping.update(compiled_build_record=str(build),runtime_observations=str(observed));path.write_text(json.dumps(mapping))
            with self.assertRaises(r.RecordError):analyze.check_provenance(m,path,root)
            observed.write_text(json.dumps(dict(execution=m['execution'],identity=ident,image_census_observed=True)))
            self.assertTrue(analyze.check_provenance(m,path,root)['verified']) # Structural unit only, NOT runtime attestation.
            files['script'].write_text('changed source binary')
            with self.assertRaises(r.RecordError):analyze.check_provenance(m,path,root)

    def test_missing_work_quota_or_cleanup_cannot_pass(self):
        s=sample('repair8',2);s['included_work'].remove('envelope_reassembly_inspect');s['proof']['quota_ok']=False
        report,_=self.run_records([meta(),sample('normal',1),s,end()]);self.assertEqual(report['cpu_candidate_acceptance'],'FAIL')
        finish=end();finish['cleanup']['snapshot_live_bytes']=1
        report,_=self.run_records([meta(),sample('normal',1),sample('repair8',2),finish]);self.assertEqual(report['cpu_candidate_acceptance'],'FAIL')

    def test_normal_kinds_are_separate_complete19_streams_but_missing_repair(self):
        for kind in r.NORMAL_ENTRIES:
            with self.subTest(kind=kind):
                m=normal_meta(kind)
                self.assertEqual(r.boundary_findings(r.validate_meta(m)),[])
                finish=end(19);finish['functional_operations']=19
                # Structural control only: this mock is NOT runtime attestation.
                with patch.object(analyze,'check_provenance',return_value=dict(verified=True)):
                    report,raw=self.run_records([m,*[normal_sample(kind,i) for i in range(1,20)],finish])
                self.assertEqual(report['result'],'RECORDS_VALID')
                self.assertEqual(report['counts'],dict(normal=19,repair8=0))
                self.assertEqual(report['meta']['normal_kind'],kind)
                self.assertEqual(report['cpu_candidate_acceptance'],'INCOMPLETE')
                self.assertEqual(len(raw.splitlines()),19)
                self.assertIsNone(json.loads(raw.splitlines()[0])['actual_steps_after'])

    def test_normal_metadata_rejects_cross_kind_entry_and_repair_pooling(self):
        changes=(lambda m:m.pop('normal_kind'),
                 lambda m:m.pop('step_observation'),
                 lambda m:m.update(normal_kind='undeclared'),
                 lambda m:m['boundary'].update(receiver_entry=r.NORMAL_ENTRIES['authority_step_requested_canonical']),
                 lambda m:m.update(sample_plan=dict(normal=18,repair8=0)),
                 lambda m:m.update(sample_plan=dict(normal=19,repair8=1)),
                 lambda m:m.update(sample_plan=dict(normal=0,repair8=19)))
        for change in changes:
            m=normal_meta('client_prediction_send');change(m)
            with self.subTest(meta=m):
                with self.assertRaises(r.RecordError):r.validate_meta(m)
        m=normal_meta('client_prediction_send')
        for change in (lambda s:s.update(normal_kind='authority_step_requested_canonical'),
                       lambda s:s.update(operation='repair8'),
                       lambda s:s.pop('normal_kind'),
                       lambda s:s.update(step_observation='replayed_ticks')):
            s=normal_sample('client_prediction_send');change(s)
            with self.subTest(sample=s):
                with self.assertRaises(r.RecordError):r.validate_sample(m,s,1)
        with self.assertRaises(r.RecordError):r.validate_sample(meta(),normal_sample('client_prediction_send'),1)

    def test_normal_tick_proof_cannot_fabricate_step_counters(self):
        m=normal_meta('client_prediction_send')
        for name in ('actual_steps_before','actual_steps_after'):
            s=normal_sample('client_prediction_send');s[name]=159
            with self.subTest(name=name):
                with self.assertRaises(r.RecordError):r.validate_sample(m,s,1)
        s=sample('repair8',2);s.update(actual_steps_before=None,actual_steps_after=None)
        with self.assertRaises(r.RecordError):r.validate_sample(meta(),s,2)

    def test_normal_failed_require_step_or_publication_proofs_retained(self):
        changes=(lambda s:s['proof'].update(successful_public_step=False),
                 lambda s:s['proof'].update(external_require_step=False),
                 lambda s:s['proof'].update(committed_tick_after=159),
                 lambda s:s['proof'].update(committed_tick_before=158),
                 lambda s:s.update(base_tick=158),
                 lambda s:s.update(confirmed_after=153),
                 lambda s:s.update(outcome='error'))
        for change in changes:
            with self.subTest(change=change):
                values=[normal_sample('client_prediction_send',i) for i in range(1,20)]
                change(values[0])
                finish=end(19);finish['functional_operations']=19
                report,raw=self.run_records([normal_meta('client_prediction_send'),*values,finish])
                self.assertEqual(report['result'],'FAIL')
                self.assertEqual(report['operation_findings_count'],1)
                self.assertEqual(report['samples_retained'],19)
                self.assertEqual(len(raw.splitlines()),19)
        s=normal_sample('authority_step_requested_canonical');s['confirmed_after']=159
        r.validate_sample(normal_meta('authority_step_requested_canonical'),s,1)
        self.assertTrue(any('authority' in x for x in r.sample_findings(s)))

    def test_normal_required_serialization_and_all_outliers_stay_hard(self):
        m=normal_meta('client_prediction_send')
        m['boundary']['included_work'].remove('required_serialization')
        self.assertTrue(any('required_serialization' in x for x in r.boundary_findings(m)))
        m=normal_meta('authority_step_requested_canonical')
        values=[normal_sample(m['normal_kind'],i) for i in range(1,20)]
        values[0].update(whole_ns=9_000_000,outer_end_us=10_000)
        values[1]['included_work'].remove('required_serialization')
        finish=end(19);finish['functional_operations']=19
        report,raw=self.run_records([m,*values,finish])
        self.assertEqual(report['samples_retained'],19)
        self.assertEqual(report['statistics']['normal']['max_ns'],9_000_000)
        self.assertEqual(report['statistics']['normal']['over_ceiling_count'],1)
        self.assertEqual(report['operation_findings_count'],1)
        self.assertEqual(report['outliers_discarded'],0)
        self.assertEqual(len(raw.splitlines()),19)

    def test_normal_functional_mode_has_no_samples_or_fake_counter(self):
        for kind in r.NORMAL_ENTRIES:
            m=normal_meta(kind,'functional_only')
            self.assertEqual(r.boundary_findings(r.validate_meta(m)),[])
            report,raw=self.run_records([m,end(0)])
            self.assertEqual(report['result'],'FUNCTIONAL_PASS')
            self.assertEqual(report['cpu_candidate_acceptance'],'NOT_MEASURED')
            self.assertEqual(raw,'')
            report,_=self.run_records([m,normal_sample(kind),end(1)])
            self.assertEqual(report['result'],'FAIL')
            m['boundary']['included_work']=sorted(r.REPAIR_WORK)
            self.assertTrue(any('functional normal' in x for x in r.boundary_findings(m)))


if __name__=='__main__':unittest.main()
