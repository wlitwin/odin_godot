"""Synthetic class0 evidence only; no Native, Lane, Godot, clock or process."""
import copy
import json
import sqlite3
from types import SimpleNamespace
import unittest

import long_policy as lp

PLAYERS=[11,22]


def control(tick=1,seat=1,**changes):
    row=dict(epoch=1,tick=tick,seat=seat,player=PLAYERS[seat-1],
             x=0,z=0,origin=2,sequence=0,accepted=True,status=0)
    row['class']=0;row.update(changes)
    return row


def key_for(row):return [row['epoch'],row['tick'],row['seat'],row['class']]


def store():
    db=sqlite3.connect(':memory:');db.row_factory=sqlite3.Row
    db.executescript('''CREATE TABLE decisions(role TEXT,id TEXT,body BLOB);
        CREATE TABLE fx(role TEXT,id TEXT,settled BLOB);
        CREATE TABLE events(id INTEGER,role TEXT,kind TEXT,body TEXT);''')
    return db


def put(db,role,row,key=None,encoded_key=None):
    key=key_for(row) if key is None else key
    db.execute('INSERT INTO decisions VALUES(?,?,?)',
        (role,encoded_key if encoded_key is not None else json.dumps(key,separators=(',',':')),
         json.dumps(row,separators=(',',':')).encode()))


def fill(db,target=2,missing=None):
    missing=missing or set()
    for role in ('host','client'):
        for tick in range(1,target+1):
            for seat in (1,2):
                if (role,tick,seat) not in missing:put(db,role,control(tick,seat))


def proof_audit(db,framework='kit',target=2,decision_missing=0,gaps=None):
    a=lp._Audit.__new__(lp._Audit)
    a.plan=dict(framework=framework,epoch=1,target_tick=target);a.admission=0
    a.store=a.events=db;a.gaps=gaps or [];a.summary={};a.report=dict(error=None)
    a.bundle=SimpleNamespace(store=SimpleNamespace(sha256='1'*64))
    a.roles={role:SimpleNamespace(ready=dict(row=dict(baseline=0,players=PLAYERS)))
             for role in ('host','client')}
    a.raw=dict(result='FAIL' if decision_missing else 'PASS',
        findings=[lp.DECISION_MISSING] if decision_missing else [],
        fx_missing=0,decision_missing=decision_missing,fx_changed=0,fx_extra=0,
        decision_changed=0,decision_extra=0,unmatched_required_frames=0,final_tail_missing=0)
    return a


class ConfirmedControlFields(unittest.TestCase):
    def reject(self,key,row,players=PLAYERS):
        with self.assertRaises(lp.PolicyError):lp._kit_control_fields(key,row,1,players)

    def test_zero_signed_extremes_origins_and_full_u64_sequence(self):
        for origin in (1,2,3):
            for x,z in ((0,0),(-32768,32767),(32767,-32768)):
                for seq in (0,2**64-1):
                    row=control(origin=origin,x=x,z=z,sequence=seq)
                    self.assertEqual(lp._kit_control_fields(key_for(row),row,1,PLAYERS),(1,1))

    def test_every_flat_field_is_required(self):
        for field in control():
            with self.subTest(field=field):
                row=control();row.pop(field);self.reject([1,1,1,0],row)

    def test_null_nonobject_and_explicit_unavailable_reject(self):
        for row in (None,False,0,[],[0],'unavailable'):
            self.reject([1,1,1,0],row)
        for field,value in (('available',False),('available',None),('unavailable',True)):
            self.reject([1,1,1,0],control(**{field:value}))

    def test_signed_fields_reject_float_bool_null_and_out_of_range(self):
        for field in ('x','z'):
            for value in (-32769,32768,0.0,True,False,None,'0'):
                with self.subTest(field=field,value=value):
                    self.reject([1,1,1,0],control(**{field:value}))

    def test_nonaccepted_non_ok_and_unknown_origin_reject(self):
        for field,values in (('accepted',(False,1,0,None)),
                             ('status',(4,0.0,False,None)),
                             ('origin',(0,4,-1,2.0,True,None))):
            for value in values:self.reject([1,1,1,0],control(**{field:value}))

    def test_sequence_requires_typed_u64(self):
        for value in (-1,2**64,0.0,True,None,'143'):
            self.reject([1,1,1,0],control(sequence=value))

    def test_player_and_ready_mapping_are_actual_and_typed(self):
        for value in (0,22,11.0,True,None):self.reject([1,1,1,0],control(player=value))
        for mapping in (None,[],[11],[11,11],[11,True],[11,{}],[11,22,33]):
            self.reject([1,1,1,0],control(),mapping)
        row=control(seat=2);self.assertEqual(lp._kit_control_fields(key_for(row),row,1,PLAYERS),(1,2))

    def test_key_shape_types_epoch_seat_class_and_body_must_match(self):
        for key in (None,{},[1,1,1],[1,1,1,0,0],[True,1,1,0],
                    [1,1.0,1,0],[1,1,False,0],[1,1,1,False],
                    [2,1,1,0],[1,1,3,0],[1,1,1,1]):
            self.reject(key,control())
        for field,value in (('epoch',2),('tick',2),('seat',2),('class',1),
                             ('epoch',True),('tick',1.0),('seat',True),('class',False)):
            self.reject([1,1,1,0],control(**{field:value}))


class ConfirmedControlCoverage(unittest.TestCase):
    def setUp(self):self.db=store();self.addCleanup(self.db.close)
    def coverage(self,admission=0,target=2,mapping=None):
        return lp._kit_control_coverage(self.db,1,admission,target,
            mapping if mapping is not None else dict(host=PLAYERS,client=PLAYERS))

    def test_counts_only_unique_post_admission_host_rows_and_keeps_zero(self):
        fill(self.db,target=3)
        for role in ('host','client'):
            for seat in (1,2):put(self.db,role,control(0,seat))
        self.assertEqual(self.coverage(admission=1,target=3),dict(host=4,client=4))

    def test_duplicate_logical_key_cannot_count_via_whitespace_alias(self):
        fill(self.db);row=control();put(self.db,'host',row,encoded_key='[1, 1, 1, 0]')
        with self.assertRaises(lp.PolicyError):self.coverage()

    def test_class1_actions_cannot_be_substituted_for_controls(self):
        action=dict(epoch=1,tick=1,seat=1,kind=3,accepted=True,applied=True,sequence=1)
        put(self.db,'host',action,key=[1,1,1,1])
        self.assertEqual(self.coverage(),dict(host=0,client=0))
        malformed=control();malformed['class']=1;put(self.db,'host',malformed,key=[1,1,1,1])
        with self.assertRaises(lp.PolicyError):self.coverage()

    def test_malformed_client_body_rejects_even_with_complete_host(self):
        fill(self.db)
        self.db.execute('UPDATE decisions SET body=? WHERE role=? AND id=?',
            (json.dumps(control(x=None)).encode(),'client','[1,1,1,0]'))
        with self.assertRaises(lp.PolicyError):self.coverage()

    def test_finite_target_and_outside_target_rows_reject(self):
        for target in (0,65536,2.0,True):
            with self.assertRaises(lp.PolicyError):self.coverage(target=target)
        put(self.db,'host',control(3))
        with self.assertRaises(lp.PolicyError):self.coverage(target=2)

    def test_absent_and_missing_host_coverage_remain_unavailable(self):
        a=proof_audit(self.db)
        with self.assertRaisesRegex(lp.Unavailable,'authority per-tick control coverage unavailable'):
            a.missing_and_global()
        fill(self.db,missing={('host',2,2),('client',2,2)})
        with self.assertRaisesRegex(lp.Unavailable,'authority per-tick control coverage unavailable'):
            proof_audit(self.db).missing_and_global()

    def test_complete_actual_body_coverage_passes_without_an_overall_claim(self):
        fill(self.db);a=proof_audit(self.db);a.missing_and_global()
        self.assertEqual(a.summary['authority_controls'],dict(required=4,actual=4))
        self.assertTrue(a.summary['raw_missing_guard']['not_an_overall_pass'])

    def test_qualified_client_missing_gap_keeps_original_classification(self):
        fill(self.db,missing={('client',1,1),('client',1,2)})
        gap=dict(id=20,start_exclusive=0,end_inclusive=1,previously_confirmed=0)
        a=proof_audit(self.db,decision_missing=2,gaps=[gap]);a.missing_and_global()
        self.assertEqual(a.summary['authority_controls'],dict(required=4,actual=4))
        rows=a.summary['exact_missing_classification']['classified_decisions']
        self.assertEqual(len(rows),2)
        self.assertTrue(all(x['disposition']=='UNOBSERVED_PAST' for x in rows))
        self.assertEqual(a.raw['result'],'FAIL')

    def test_outside_gap_missing_client_controls_still_fail(self):
        fill(self.db,missing={('client',1,1),('client',1,2)})
        with self.assertRaises(lp.PolicyError):
            proof_audit(self.db,decision_missing=2).missing_and_global()

    def test_replay_legacy_representation_and_count_loop_unchanged(self):
        for role in ('host','client'):
            for tick in (1,2):
                for seat in (1,2):
                    put(self.db,role,dict(epoch=1,tick=tick,seat=seat),key=[1,tick,seat,0])
        a=proof_audit(self.db,framework='replay');a.missing_and_global()
        self.assertEqual(a.summary['authority_controls'],dict(required=4,actual=4))


if __name__=='__main__':unittest.main()
