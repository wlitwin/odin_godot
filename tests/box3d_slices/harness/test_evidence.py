"""Auditor negative controls only. These never assert an actual network PASS."""
from pathlib import Path
import importlib.util
import hashlib
import struct
import tempfile
import unittest

from evidence import EndpointEvidence, EvidenceError, load_frame, signature, strict_json, verify_kit_intent_catalog, verify_spawn_conflict

GOLDEN = Path(__file__).resolve().parents[2] / 'box3d_protocol/golden.py'
spec = importlib.util.spec_from_file_location('existing_protocol_golden', GOLDEN)
golden = importlib.util.module_from_spec(spec)
spec.loader.exec_module(golden)

class AuditorControls(unittest.TestCase):
    def test_independent_signature_spec_and_rejections(self):
        valid=golden.vectors()['signature.bin']
        self.assertEqual(signature(valid)[:2],(7,42))
        for invalid in (valid[:-1],valid+b'x',bytes([valid[0]^1])+valid[1:],valid[:448]+bytes(32)):
            with self.assertRaises(EvidenceError):signature(invalid)
        with self.assertRaises(EvidenceError):signature(valid,7,43)

    def test_full_parts_required_and_confined(self):
        parts=[b'full solver with pending end',b'rng counters mappings',b'side fields',b'completed sensor events',b'occurrences with stable keys']
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);prefix=root/'frame-7-42'
            Path(str(prefix)+'.sig').write_bytes(golden.signature(parts))
            for i,part in enumerate(parts):Path(str(prefix)+f'.part{i}').write_bytes(part)
            record=dict(epoch=7,tick=42,confirmed=42,basePath='frame-7-42')
            self.assertEqual(load_frame(root,record).parts(),parts)
            Path(str(prefix)+'.part3').write_bytes(b'incorrect completed observations')
            with self.assertRaises(EvidenceError):load_frame(root,record)
            with self.assertRaises(EvidenceError):load_frame(root,dict(record,confirmed=41))
            with self.assertRaises(EvidenceError):load_frame(root,dict(record,basePath='../escape'))

    def test_no_exit_or_missing_owner_evidence_cannot_pass(self):
        endpoint=EndpointEvidence('kit','host',Path('/unused'))
        with self.assertRaises(EvidenceError):endpoint.teardown(0)
        endpoint.result=dict(engine_live=0,wrapper_live=0,meter_live=0)
        with self.assertRaises(EvidenceError):endpoint.teardown(0)
        endpoint.result['owners_live']=0
        with self.assertRaises(EvidenceError):endpoint.teardown(1)
        endpoint.result['owners_live']=1
        with self.assertRaises(EvidenceError):endpoint.teardown(0)
        endpoint.result['owners_live']=0
        self.assertEqual(endpoint.teardown(0),dict(engine=0,wrapper=0,meter=0,owners=0))

    def test_ambiguous_observations_rejected(self):
        for text in ('{"applied":true,"applied":false}','{"value":NaN}'):
            with self.assertRaises(EvidenceError):strict_json(text)

    def test_spawn_predicate_respects_declared_action_timing(self):
        local=dict(seat=1,tick=40,sequence=1,kind='Spawn',accepted=True,applied=False,reason='Predicate')
        remote=dict(seat=2,tick=38,sequence=1,kind='Spawn',accepted=True,applied=True,reason='None')
        self.assertEqual(verify_spawn_conflict([local,remote],'Receipt')['winner']['seat'],2)
        with self.assertRaises(EvidenceError):verify_spawn_conflict([local,remote],'Scheduled')
        scheduled=[dict(local,applied=True,reason='None'),dict(remote,tick=40,applied=False,reason='Predicate')]
        self.assertEqual(verify_spawn_conflict(scheduled,'Scheduled')['rejected']['seat'],2)
        for invalid in ([dict(local,applied=True),remote],
                        [local,dict(remote,applied=False)],
                        [local,dict(remote,tick=41)],
                        [dict(local,reason='Stale'),remote],
                        [local,dict(remote,tick=40)],
                        [local,remote,dict(seat=1,tick=39,sequence=2,kind='Remove',accepted=True,applied=True)]):
            with self.assertRaises(EvidenceError):verify_spawn_conflict(invalid,'Receipt')

    def test_interim_exit_cannot_substitute_for_terminal_result(self):
        endpoint=EndpointEvidence('replay','client',Path('/unused'))
        endpoint.receive('SESSION_EXIT',dict(ok=True,engine_live=0,wrapper_live=0,meter_live=0,owners_live=0))
        with self.assertRaises(EvidenceError):endpoint.teardown(0)
        self.assertEqual(endpoint.teardown(0,interim=True)['owners'],0)
        with self.assertRaises(EvidenceError):endpoint.receive('RESULT',{})
        with self.assertRaises(EvidenceError):endpoint.receive('SESSION_EXIT',{})
        with self.assertRaises(EvidenceError):EndpointEvidence('kit','host',Path('/unused')).receive('SESSION_EXIT',{})

    def catalog(self):
        endpoint=EndpointEvidence('kit','client',Path('/unused'))
        endpoint.receive('READY',dict(epoch=7,baseline=0,action_timing='Scheduled',intent_source='outside_sim_catalog_class1'))
        return endpoint

    def reset_link(self,endpoint,old_head,new_head,old_due,old_serial,new_serial):
        sig=bytearray(golden.vectors()['signature.bin'])
        struct.pack_into('<QQ',sig,232,7,new_head)
        sig[448:]=hashlib.sha256(sig[:448]).digest()
        endpoint.receive('RECOVERED',dict(epoch=7,previous_head=old_head,baseline=new_head,
                         head=new_head,confirmed=new_head,request_sequence=old_serial,
                         received_sequence=new_serial,signature_hex=bytes(sig).hex()))
        endpoint.receive('INTENT_REBASE',dict(epoch=7,seat=2,original_requested_tick=40,
                         old_current_due=old_due,new_current_due=new_head+1,
                         old_head=old_head,new_head=new_head,old_serial=old_serial,new_serial=new_serial,
                         cause='validated_reset',committed=False))

    def issue(self,endpoint,**changes):
        value=dict(epoch=7,seat=2,kind='Spawn',original_requested_tick=40,requested_tick=61,
                   sampled_head=60,sampled_tick=61,submitted_tick=61,sequence=61,packet_head=61,
                   published=True,transport='existing_class1_input_stream',action_timing='Scheduled',
                   rebased_before_sampling=True,recovery_serial=9)
        value.update(changes)
        endpoint.receive('ISSUED',value)

    def prepared_chain(self):
        endpoint=self.catalog()
        self.reset_link(endpoint,15,42,40,3,6)
        self.reset_link(endpoint,42,60,43,6,9)
        endpoint.receive('INTENT_ATTEMPT',dict(epoch=7,seat=2,original_requested_tick=40,
                         requested_tick=61,sampled_head=60,sampled_tick=61,candidate_only=True))
        return endpoint

    def test_repeated_reset_uses_current_due_and_keeps_original(self):
        endpoint=self.prepared_chain()
        self.issue(endpoint)
        result=verify_kit_intent_catalog(endpoint)
        self.assertEqual(result[(7,2,61)]['original_requested_tick'],40)
        self.assertEqual([x['old_current_due'] for x in result[(7,2,61)]['links']],[40,43])

    def test_invalid_reset_chain_or_postpublication_retarget_rejected(self):
        endpoint=self.prepared_chain()
        second=next(record for _,record in endpoint.status_marks
                    if record['event']=='INTENT_REBASE' and record['new_serial']==9)
        second['old_current_due']=40
        with self.assertRaises(EvidenceError):verify_kit_intent_catalog(endpoint)
        endpoint=self.prepared_chain()
        endpoint.status_marks=[(at,record) for at,record in endpoint.status_marks
                               if not (record['event']=='RECOVERED' and record['received_sequence']==9)]
        with self.assertRaises(EvidenceError):verify_kit_intent_catalog(endpoint)
        endpoint=self.prepared_chain()
        self.issue(endpoint)
        self.reset_link(endpoint,60,75,61,9,12)
        with self.assertRaises(EvidenceError):verify_kit_intent_catalog(endpoint)

    def test_candidate_and_packet_proof_are_required(self):
        for changes in (dict(published=False),dict(sequence=62),dict(packet_head=69),
                        dict(recovery_serial=6),dict(transport='aux_game_command')):
            endpoint=self.prepared_chain()
            self.issue(endpoint,**changes)
            with self.assertRaises(EvidenceError):verify_kit_intent_catalog(endpoint)
        endpoint=self.prepared_chain()
        endpoint.status_marks=[(at,record) for at,record in endpoint.status_marks if record['event']!='INTENT_ATTEMPT']
        self.issue(endpoint)
        with self.assertRaises(EvidenceError):verify_kit_intent_catalog(endpoint)
        endpoint=self.catalog()
        endpoint.receive('INTENT_UNEXERCISED',dict(reason='fresh_tick_after_end'))
        self.assertTrue(endpoint.errors)
        with self.assertRaises(EvidenceError):verify_kit_intent_catalog(endpoint)

if __name__=='__main__':unittest.main()
