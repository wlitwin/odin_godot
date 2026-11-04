"""Synthetic policy-layer controls only; no actual lifecycle or Native proof."""
import copy
import hashlib
import json
from pathlib import Path
import struct
import tempfile
import unittest

import recovery_policy as p

H = '1' * 64


def sig(tick):
    # A checksum-valid native-free diagnostics signature for synthetic controls;
    # never described as an observed Native frame or used in a live case.
    raw = b'OGB3SIG1' + struct.pack('<II', 1, 0)
    raw += struct.pack('<IIIIQ', 3, 1, 1, 1, 0x534c494345503031) + b'\x01' * (6 * 32)
    raw += struct.pack('<QQ', 1, tick)
    for _ in range(5): raw += struct.pack('<Q', 1) + hashlib.sha256(b'x').digest()
    return (raw + hashlib.sha256(raw).digest()).hex()


def fixture():
    policy = dict(p.VALUES, policy_id=p.POLICY_ID, limits=dict(p.LIMITS), causes=copy.deepcopy(p.CAUSES))
    plan = dict(framework='kit', case='recovery', seed=42, blackout_ms=300,
                end_tick=1200, future_ticks=240, out='/synthetic/fresh-policy-case')
    binding = dict(event=p.EVENT, schema=1, policy_id=p.POLICY_ID, run_id='fresh-policy-case',
        policy_ref=dict(path='/synthetic/policy.json', sha256=H), policy=copy.deepcopy(policy),
        source_manifest_sha256=H, build_record_sha256=H, plan=copy.deepcopy(plan))
    events = []; clock = 0.0
    def add(role, kind, row, at=None):
        nonlocal clock
        clock = clock + .001 if at is None else at
        events.append(dict(id=len(events), role=role, kind=kind, observed_at=clock, row=row))
        return events[-1]
    add('controller', p.EVENT, binding)
    for role in ('host','client'):
        add(role, 'READY', dict(framework='kit', role=role, epoch=1, baseline=0, world_wire_revision=2))
        add(role, 'GO', dict(framework='kit', role=role))
        add(role, 'LIMITS', dict(history=128,max_prediction=8,max_repair=8,
            process_limit_bytes=67108864,initial_cached_dynamic_bodies=32))
    issue = dict(epoch=1,seat=2,sequence=5,kind=3,submitted_tick=5,framework='kit')
    action = dict(epoch=1,seat=2,sequence=5,kind=3,tick=5,accepted=True,applied=True,framework='kit')
    add('client','ISSUED',issue);add('host','APPLIED',action);add('client','APPLIED',action)
    def fx(role,tick,key):
        row=dict(epoch=1,tick=tick,key=key,kind=0,lifetime=key,seat=0,serial=key,confirmed=True)
        add(role,'FX',row)
        return row
    hostfx=[fx('host',5,1)];clientfx=[fx('client',5,1)]
    for role in ('host','client'):add(role,'FRAME',dict(epoch=1,tick=10,confirmed=10))
    req=add('client','RECOVERY_REQUESTED',dict(epoch=1,head=15,confirmed=10,pre_confirmed=10,
        published_preserved=True,request_status=0,request_source='manual_ui',reason=0),10.0)
    hostfx.append(fx('host',20,2));add('host','FRAME',dict(epoch=1,tick=30,confirmed=30))
    rec=add('client','RECOVERED',dict(epoch=1,head=30,confirmed=30,baseline=30,
        previous_head=15,previous_confirmed=10,request_sequence=1,received_sequence=2,signature_hex=sig(30)),10.5)
    bits=struct.pack('>d',4/60).hex()
    add('client','STATUS',dict(stage='recovery_bootstrap',bootstrap_sequence=2,anchor_baseline=30,
        owned_once=True,progress_proven=True,receipt=2,returned_steps=4,before_head=33,after_head=37,
        before_confirmed=33,after_confirmed=33,matched_signature_tick=33,accepted_through=33,
        supplied_bits=bits,receipt_bits=bits))
    decisions=[]
    for tick in range(31,271):
        for seat in (1,2):
            row=dict(epoch=1,tick=tick,seat=seat,player=seat,**{'class':0},accepted=True,
                     status=0,origin=3 if seat==1 else 1,sequence=tick,x=1,z=0)
            for role in ('host','client'):
                add(role,'INPUT',dict(row,role=role))
                decisions.append(dict(role=role,id=json.dumps([1,tick,seat,0],separators=(',',':')),body=p.json_bytes(row)))
    for seat in (1,2):decisions.append(dict(role='host',id=f'[1,20,{seat},0]',body=b'gap'))
    for tick,key in ((60,3),(1200,4)):
        hostfx.append(fx('host',tick,key));clientfx.append(fx('client',tick,key))
        for role in ('host','client'):add(role,'FRAME',dict(epoch=1,tick=tick,confirmed=tick))
    for role in ('host','client'):
        add(role,'RESULT',dict(ok=True,tick=1200,errors=0,cleanup_errors=0,engine_live=0,wrapper_live=0,meter_live=0))
    add('host','TAIL',dict(from_role='client',matched=True,tick=1200))
    ledger=[]
    for role,values in (('host',hostfx),('client',clientfx)):
        for row in values:
            ledger.append(dict(role=role,id=f'[1,{row["tick"]},{row["key"]}]',state='settled',
                payload=p.json_bytes({k:row[k] for k in ('serial','lifetime','seat','kind')})))
    missing_findings=list(p.MISSING_FINDINGS)
    rolling=dict(result='FAIL',decision_missing=2,fx_missing=1,decision_changed=0,decision_extra=0,
        fx_changed=0,fx_extra=0,unmatched_required_frames=0,final_tail_missing=0,
        matched_comparisons=3,required_follower_exports=3,findings=missing_findings)
    pair=dict(confirmed_end=1200,action_timing='Scheduled',compared_confirmed_frames=3,
        actual_verdicts={k:[dict(synthetic_parent_result=True)] for k in ('Spawn','Remove','Motor','Sleep','Wake','Query')},
        intent_causality=[dict(role='client',issued=issue,published=action)])
    exits={}
    for role in ('host','client'):
        exits[role]=dict(natural=True,exit_code=0,reader_error=None,intake=dict(records_seen=1,
            records_published=1,records_consumed=1,pending_events=0,reader_eof=True,consumer_closed=True,
            writer_closed=True,final_flush_fsync_ok=True,integrity_error=None,
            identity=dict(identity=dict(source_manifest_sha256=H,compiled_build_sha256=H))))
    report=dict(plan=plan,build_record_sha256=H,source_fence_unchanged=True,driver_fence_unchanged=True,
        project_fence_unchanged=True,exits=exits,existing_pair_gates=[dict(role='client',generation=1,result=pair)],
        rolling=rolling,error=repr(p.EvidenceError(str(('unchanged rolling evidence failed',missing_findings)))),
        interventions=[dict(action='SIGSTOP',pid=2,requested_ms=300),dict(action='SIGCONT',pid=2,observed_host_head=30)])
    report[p.REPORT_KEY]=binding
    store=dict(decisions=decisions,fx=ledger,
        matches=[dict(role='client',epoch=1,tick=t) for t in (10,60,1200)],
        comparisons=[dict(epoch=1,tick=t,byte_comparison=True,parts=[dict(length=1,sha256=H)]*5) for t in (10,60,1200)])
    return policy,binding,report,events,store


class RecoveryPolicyControls(unittest.TestCase):
    def run_case(self, change=None):
        values=fixture()
        if change:change(*values)
        original=copy.deepcopy(values[2])
        result=p.evaluate(*values)
        self.assertEqual(values[2],original)
        return result

    def test_missing_only_inside_validated_gap_passes_separately_rawFAIL_retained(self):
        result=self.run_case()
        self.assertEqual(result['result'],'INTENTIONAL_RESET_LIFECYCLE_COVERAGE_PASS')
        self.assertEqual(result['raw_rolling']['result'],'FAIL')
        self.assertEqual(result['exact_missing_decisions'],['[1,20,1,0]','[1,20,2,0]'])
        self.assertEqual(result['exact_missing_FX'],['[1,20,2]'])

    def test_old_case_or_late_binding_never_gets_newPASS(self):
        values=fixture();values[2].pop(p.REPORT_KEY)
        self.assertEqual(p.evaluate(*values)['result'],'INCOMPLETE')
        values=fixture();values[3].insert(0,dict(id=-1,role='host',kind='BOOT',observed_at=0,row={}))
        self.assertNotEqual(p.evaluate(*values)['result'],'INTENTIONAL_RESET_LIFECYCLE_COVERAGE_PASS')

    def test_policy_version_build_source_and_actual_plan_are_bound(self):
        changes=(lambda p,b,r,e,s:p.update(version=2),lambda p,b,r,e,s:b.update(build_record_sha256='2'*64),
            lambda p,b,r,e,s:b.update(source_manifest_sha256='2'*64),lambda p,b,r,e,s:r['plan'].update(seed=17),
            lambda p,b,r,e,s:r.update(project_fence_unchanged=False))
        for change in changes:
            with self.subTest(change=change):self.assertNotEqual(self.run_case(change)['result'],'INTENTIONAL_RESET_LIFECYCLE_COVERAGE_PASS')

    def test_missing_outside_gap_and_exact_count_mismatch_fail(self):
        def count(p,b,r,e,s):r['rolling']['decision_missing']=1
        # Tick31 is outside; the guard must reconcile keys, not just counts.
        def actual_outside(p,b,r,e,s):s['decisions'].append(dict(role='host',id='[1,31,1,1]',body=b'x'));r['rolling']['decision_missing']+=1
        for change in (actual_outside,count):self.assertEqual(self.run_case(change)['result'],'FAIL')

    def test_unvalidated_request_signature_watermark_cause_and_time_fail(self):
        for field,value in (('published_preserved',False),('request_status',1),('reason',99)):
            def change(p,b,r,e,s,field=field,value=value):next(x['row'] for x in e if x['kind']=='RECOVERY_REQUESTED')[field]=value
            self.assertEqual(self.run_case(change)['result'],'FAIL')
        for change in (lambda p,b,r,e,s:next(x['row'] for x in e if x['kind']=='RECOVERED').update(signature_hex='00'),
                       lambda p,b,r,e,s:next(x['row'] for x in e if x['kind']=='RECOVERED').update(received_sequence=1),
                       lambda p,b,r,e,s:next(x for x in e if x['kind']=='RECOVERED').update(observed_at=16.0)):
            self.assertEqual(self.run_case(change)['result'],'FAIL')
        result=self.run_case(lambda p,b,r,e,s:next(x for x in e if x['kind']=='RECOVERED').update(observed_at=None))
        self.assertEqual(result['result'],'INCOMPLETE')

    def test_changed_extra_arbitrary_findings_cleanup_intake_are_hard(self):
        for change in (lambda p,b,r,e,s:r['rolling'].update(decision_changed=1),
                       lambda p,b,r,e,s:r['rolling']['findings'].append('unrelated corruption'),
                       lambda p,b,r,e,s:r['exits']['client']['intake'].update(pending_events=1),
                       lambda p,b,r,e,s:next(x['row'] for x in e if x['role']=='client' and x['kind']=='RESULT').update(meter_live=1),
                       lambda p,b,r,e,s:s['decisions'].append(dict(role='client',id='[1,20,2,1]',body=b'x'))):
            self.assertEqual(self.run_case(change)['result'],'FAIL')

    def test_duplicates_lost_settlement_and_pastFX_replay_fail_inside_gap(self):
        def duplicate(p,b,r,e,s):e.append(copy.deepcopy(next(x for x in e if x['kind']=='FX' and x['role']=='client')))
        def lost(p,b,r,e,s):s['fx'][:]=[x for x in s['fx'] if not (x['role']=='client' and x['id']=='[1,5,1]')]
        def past(p,b,r,e,s):
            x=copy.deepcopy(next(x for x in e if x['kind']=='FX' and x['row']['tick']==20));x['role']='client';x['id']=99999;e.append(x)
        for change in (duplicate,lost,past):self.assertEqual(self.run_case(change)['result'],'FAIL')

    def test_any_client_issued_unjoined_is_hard_even_inside_gap(self):
        def change(p,b,r,e,s):
            issue=copy.deepcopy(next(x for x in e if x['kind']=='ISSUED'));issue['row'].update(sequence=20,submitted_tick=20);e.append(issue)
        self.assertEqual(self.run_case(change)['result'],'FAIL')

    def test_future_controls_full5_FX_ACK_bootstrap_all_required(self):
        changes=(lambda p,b,r,e,s:e.remove(next(x for x in e if x['kind']=='INPUT' and x['role']=='client')),
            lambda p,b,r,e,s:s['comparisons'].pop(),
            lambda p,b,r,e,s:e.remove(next(x for x in e if x['kind']=='TAIL')),
            lambda p,b,r,e,s:next(x['row'] for x in e if x['kind']=='STATUS').update(owned_once=False),
            lambda p,b,r,e,s:next(x['row'] for x in e if x['kind']=='STATUS').update(bootstrap_sequence=3))
        for change in changes:self.assertNotEqual(self.run_case(change)['result'],'INTENTIONAL_RESET_LIFECYCLE_COVERAGE_PASS')

    def test_make_binding_checks_actual_file_hash_and_execution(self):
        policy,_,report,_,_=fixture()
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'policy.json';path.write_text(json.dumps(policy));digest=p.sha_file(path)
            binding=p.make_binding(path,digest,run_id='fresh-policy-case',source_sha256=H,build_sha256=H,plan=report['plan'])
            self.assertEqual(binding['policy'],policy)
            with self.assertRaises(p.PolicyError):p.load_policy(path,'2'*64)
            report['plan']['blackout_ms']=301
            with self.assertRaises(p.PolicyError):p.make_binding(path,digest,run_id='fresh-policy-case',source_sha256=H,build_sha256=H,plan=report['plan'])


if __name__=='__main__':unittest.main()
