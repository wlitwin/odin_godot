"""Synthetic verifier records only; no Native, process, Lane, or runtime proof."""
import copy
from pathlib import Path
from types import SimpleNamespace
import sys
import unittest

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parents[1]/'box3d_slices/harness'))
sys.path.insert(0,str(HERE.parent/'audit'))
from evidence import EvidenceError, verify_kit_intent_catalog
from test_rolling import signature_for
import long_policy as lp


def ready(version=2):
    value=dict(epoch=1,seat=2,me=2,session_generation=1,target=300,
               intent_source='outside_sim_catalog_class1',action_timing='Scheduled')
    if version is not None:value['intent_contract_version']=version
    return value


def reset(baseline=45,old_head=40,old_serial=14,new_serial=17):
    return dict(event='RECOVERED',epoch=1,session_generation=1,previous_head=old_head,
                previous_confirmed=min(39,old_head),baseline=baseline,head=baseline,
                confirmed=baseline,request_sequence=old_serial,received_sequence=new_serial,
                signature_hex=signature_for((b'solver',b'game',b'side',b'obs',b'fx'),1,baseline).hex())


def rebase(original=40,old_due=40,baseline=45,old_head=40,old_serial=14,new_serial=17,
           pre_serial=0,version=2):
    value=dict(event='INTENT_REBASE',epoch=1,seat=2,session_generation=1,
        original_requested_tick=original,old_current_due=old_due,new_current_due=baseline+1,
        old_head=old_head,new_head=baseline,old_serial=old_serial,new_serial=new_serial,
        cause='validated_reset',committed=False)
    if version is not None:value['intent_contract_version']=version
    if version==2:
        value.update(pre_attempted=False,pre_published=False,pre_transported=False,
            pre_attempt_tick=0,pre_attempt_head=0,pre_packet_head=0,pre_row_sequence=0,
            pre_recovery_serial=pre_serial,player=2)
        value['class']=1
    return value


def attempt(original=40,due=46,sample=None):
    sample=due if sample is None else sample
    return dict(event='INTENT_ATTEMPT',epoch=1,seat=2,session_generation=1,
        original_requested_tick=original,requested_tick=due,sampled_tick=sample,
        sampled_head=sample-1,candidate_only=True)


def issued(original=40,due=46,sample=None,serial=17,rebased=True):
    value=attempt(original,due,sample)
    value.update(event='ISSUED',published=True,transport='existing_class1_input_stream',
        action_timing='Scheduled',submitted_tick=value['sampled_tick'],
        sequence=value['sampled_tick'],packet_head=value['sampled_tick'],
        rebased_before_sampling=rebased,recovery_serial=serial)
    value.pop('candidate_only')
    return value


def endpoint(events=None,version=2):
    if events is None:events=[reset(),rebase(),attempt(),issued()]
    ep=SimpleNamespace(framework='kit',role='client',ready=ready(version),
                       status_marks=[],issue_marks=[])
    for order,value in enumerate(events,1):
        (ep.issue_marks if value['event']=='ISSUED' else ep.status_marks).append((order,copy.deepcopy(value)))
    return ep


def multiple_pending(first=201,second=202):
    return endpoint([reset(200,40),rebase(baseline=200),
        rebase(original=160,old_due=160,baseline=200),
        attempt(due=201,sample=first),issued(due=201,sample=first),
        attempt(original=160,due=201,sample=second),issued(original=160,due=201,sample=second)])


class IntentContractControls(unittest.TestCase):
    def reject(self,ep):
        with self.assertRaises((EvidenceError,KeyError,ValueError,TypeError)):
            verify_kit_intent_catalog(ep)

    def test_v1_absent_and_explicit_keep_crossing_and_output(self):
        events=[reset(old_head=39),rebase(old_head=39,version=None),attempt(),issued()]
        absent=verify_kit_intent_catalog(endpoint(events,None))
        explicit=verify_kit_intent_catalog(endpoint(events,1))
        self.assertEqual(absent,explicit)
        self.assertEqual(absent[(1,2,46)]['original_requested_tick'],40)

    def test_v1_past_due_still_rejected(self):
        for version in (None,1):
            with self.subTest(version=version):
                self.reject(endpoint([reset(),rebase(version=None)],version))

    def test_v1_unpublished_candidate_legacy_behavior_unchanged(self):
        events=[attempt(due=40),reset(45,39),rebase(old_head=39,version=None),attempt(),issued()]
        self.assertIn((1,2,46),verify_kit_intent_catalog(endpoint(events,1)))

    def test_ready_and_rebase_versions_are_exact_typed_contracts(self):
        for bad in (0,3,True,False,2.0,'2',None):
            with self.subTest(bad=bad):
                ep=endpoint();ep.ready['intent_contract_version']=bad;self.reject(ep)
                ep=endpoint();ep.status_marks[1][1]['intent_contract_version']=bad;self.reject(ep)
        ep=endpoint();ep.status_marks[1][1].pop('intent_contract_version');self.reject(ep)
        ep=endpoint();ep.ready['intent_contract_version']=1;self.reject(ep)
        ep=endpoint();ep.ready.pop('intent_source');self.reject(ep)
        ep=endpoint();ep.ready['action_timing']='Receipt';self.reject(ep)

    def test_v2_equal_and_past_old_head_without_invented_lookup(self):
        for head in (39,40,44,50):
            with self.subTest(head=head):
                ep=endpoint([reset(old_head=head),rebase(old_head=head),attempt(),issued()])
                self.assertIn((1,2,46),verify_kit_intent_catalog(ep))
                self.assertNotIn('lookup',ep.status_marks[1][1])

    def test_multiple_pending_plans_share_one_real_reset_episode(self):
        result=verify_kit_intent_catalog(multiple_pending())
        self.assertEqual(set(result),{(1,2,201),(1,2,202)})
        self.assertEqual(result[(1,2,202)]['original_requested_tick'],160)

    def test_every_pre_flag_and_counter_is_required_false_or_zero(self):
        fields=('pre_attempted','pre_published','pre_transported','pre_attempt_tick',
                'pre_attempt_head','pre_packet_head','pre_row_sequence','pre_recovery_serial')
        for field in fields:
            with self.subTest(missing=field):
                ep=endpoint();ep.status_marks[1][1].pop(field);self.reject(ep)
            for bad in ((True,0,None) if field in fields[:3] else (1,True,0.0,'0')):
                with self.subTest(field=field,bad=bad):
                    ep=endpoint();ep.status_marks[1][1][field]=bad;self.reject(ep)

    def test_any_prior_attempt_or_publication_is_pinned(self):
        self.reject(endpoint([attempt(due=40),reset(),rebase()]))
        self.reject(endpoint([attempt(due=40),issued(due=40,serial=0,rebased=False),reset(),rebase()]))
        for field in ('pre_published','pre_transported'):
            ep=endpoint();ep.status_marks[1][1][field]=True;self.reject(ep)

    def test_actor_epoch_generation_player_class_are_bound(self):
        for field,bad in (('epoch',2),('seat',1),('session_generation',2),
                          ('player',3),('class',0),('class',True),('role','host'),('actor','host')):
            with self.subTest(field=field,bad=bad):
                ep=endpoint();ep.status_marks[1][1][field]=bad;self.reject(ep)
        for field,bad in (('epoch',2),('session_generation',2),('role','host'),('actor','host')):
            ep=endpoint();ep.status_marks[0][1][field]=bad;self.reject(ep)

    def test_reset_signature_publication_and_watermarks_are_required(self):
        for field,bad in (('head',44),('confirmed',44),('previous_head',41),
                          ('baseline',44),('request_sequence',13),('received_sequence',18)):
            with self.subTest(field=field):
                ep=endpoint();ep.status_marks[0][1][field]=bad;self.reject(ep)
        ep=endpoint();value=ep.status_marks[0][1]['signature_hex'];ep.status_marks[0][1]['signature_hex']=value[:-2]+'00';self.reject(ep)
        ep=endpoint();ep.status_marks[1][1]['new_serial']=14;self.reject(ep)
        ep=endpoint();ep.status_marks.pop(0);self.reject(ep)
        ep=endpoint([reset(),reset(),rebase(),attempt(),issued()]);self.reject(ep)
        ep=endpoint([rebase(),reset(),attempt(),issued()]);self.reject(ep)

    def test_ordinary_catchup_does_not_authorize_rebase(self):
        ep=endpoint();ep.status_marks[1][1]['cause']='ordinary_catchup';self.reject(ep)
        ep=endpoint();ep.status_marks[0][1]['event']='PUMP';self.reject(ep)

    def test_repeated_links_keep_current_due_original_and_plan_scope(self):
        ep=endpoint([reset(),rebase(),reset(50,46,18,20),
            rebase(old_due=46,baseline=50,old_head=46,old_serial=18,new_serial=20,pre_serial=17),
            attempt(due=51),issued(due=51,serial=20)])
        result=verify_kit_intent_catalog(ep)
        self.assertEqual(len(result[(1,2,51)]['links']),2)
        wrong=copy.deepcopy(ep);wrong.status_marks[3][1]['old_current_due']=40;self.reject(wrong)
        wrong=copy.deepcopy(ep);wrong.status_marks[3][1]['pre_recovery_serial']=0;self.reject(wrong)
        wrong=endpoint();wrong.status_marks[1][1]['original_requested_tick']=160;self.reject(wrong)
        self.reject(endpoint([reset(),rebase(),rebase()]))

    def test_target_overflow_and_still_future_due_reject(self):
        ep=endpoint();ep.ready['target']=45;self.reject(ep)
        ep=endpoint();ep.status_marks[1][1]['new_current_due']=47;self.reject(ep)
        ep=endpoint([reset(39,40),rebase(baseline=39)]);self.reject(ep)
        ep=endpoint([reset(2**64-1,40),rebase(baseline=2**64-1)]);ep.ready['target']=2**64-1;self.reject(ep)

    def test_sampling_and_packet_windows_remain_strict(self):
        ep=endpoint([reset(),rebase(),attempt(sample=54),issued(sample=54)])
        self.assertIn((1,2,54),verify_kit_intent_catalog(ep))
        for bad in (45,55):self.reject(endpoint([reset(),rebase(),attempt(sample=bad),issued(sample=bad)]))
        for field,bad in (('sampled_head',40),('submitted_tick',47),('sequence',47),('packet_head',54)):
            ep=endpoint();ep.issue_marks[0][1][field]=bad;self.reject(ep)

    def test_duplicate_and_reversed_fifo_cannot_use_other_original(self):
        self.reject(multiple_pending(201,201))
        self.reject(multiple_pending(202,201))
        ep=endpoint();ep.issue_marks.append((5,copy.deepcopy(ep.issue_marks[0][1])));self.reject(ep)


class ClosedLongBindingControls(unittest.TestCase):
    def test_legacy_absent_and_explicit1(self):
        self.assertEqual(lp._intent_contract_binding('kit',{},ready(None)),1)
        self.assertEqual(lp._intent_contract_binding('kit',{'kit_intent_contract':1},ready(1)),1)
        self.assertEqual(lp._intent_contract_binding('replay',{},{}),1)

    def test_v2_requires_actual_prelaunch_report_plan2_and_ready2(self):
        self.assertEqual(lp._intent_contract_binding('kit',{'kit_intent_contract':2},ready()),2)
        for plan,value in (({},ready()),({'kit_intent_contract':1},ready()),
                           ({'kit_intent_contract':2},ready(None))):
            with self.subTest(plan=plan):
                with self.assertRaises(lp.PolicyError):lp._intent_contract_binding('kit',plan,value)

    def test_unknown_types_replay2_and_wrong_catalog_timing_reject(self):
        for bad in (0,3,True,False,2.0,'2',None):
            with self.subTest(bad=bad):
                with self.assertRaises(lp.PolicyError):lp._intent_contract_binding('kit',{'kit_intent_contract':bad})
                value=ready();value['intent_contract_version']=bad
                with self.assertRaises(lp.PolicyError):lp._intent_contract_binding('kit',{'kit_intent_contract':2},value)
        with self.assertRaises(lp.PolicyError):lp._intent_contract_binding('replay',{'kit_intent_contract':2},ready())
        for field,bad in (('intent_source','other'),('action_timing','Receipt')):
            value=ready();value[field]=bad
            with self.assertRaises(lp.PolicyError):lp._intent_contract_binding('kit',{'kit_intent_contract':2},value)


if __name__=='__main__':unittest.main()
