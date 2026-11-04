"""Synthetic storage invariants, not a physics, network or profiling run."""
import hashlib,json,os,sqlite3,struct,sys,tempfile,unittest,zlib
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'shared'))
from rolling import *
from evidence import Frame

SOURCE='1'*64


def signature_for(parts,epoch,tick,identity=1):
    h=bytearray(480);struct.pack_into('<8sII',h,0,b'OGB3SIG1',1,0)
    struct.pack_into('<IIIIQ',h,16,3,1,1,1,0x534c494345503031)
    for offset in range(40,232,32):h[offset:offset+32]=bytes([identity])*32
    struct.pack_into('<QQ',h,232,epoch,tick)
    for i,part in enumerate(parts):struct.pack_into('<Q',h,248+40*i,len(part));h[256+40*i:288+40*i]=hashlib.sha256(part).digest()
    h[448:]=hashlib.sha256(h[:448]).digest();return bytes(h)


class Controls(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.root=Path(self.tmp.name);self.addCleanup(self.tmp.cleanup);self.frames=0
    def store(self,baseline=0,**kwargs):
        path=self.root/('store'+str(len(list(self.root.glob('store*')))))
        cfg=dict(directory=path,authority_role='host',follower_roles=('client',),allowed_sources={'host':(SOURCE,),'client':(SOURCE,)},disk_budget_bytes=64*1024*1024)
        cfg.update(kwargs);store=RollingStore(RollingConfig(**cfg));self.addCleanup(store.close)
        for role,pid in [('host',1),('client',2)]:store.register_process(ProcessScope(role,role+'-g1',pid,SOURCE,1,baseline))
        return store
    def frame(self,tick,parts=None,epoch=1,identity=1):
        parts=parts or [b'solver'+str(tick).encode(),b'game',b'side',b'observations',b'occurrences']
        self.frames+=1;paths=[]
        for i,part in enumerate(parts):
            p=self.root/f'frame{self.frames}.part{i}';p.write_bytes(part);paths.append(p)
        return Frame(epoch,tick,signature_for(parts,epoch,tick,identity),tuple(paths),{})
    def pair(self,store,tick=1,epoch=1):
        a=store.register_frame('host','host-g1',self.frame(tick,epoch=epoch)).frames[0]
        b=store.register_frame('client','client-g1',self.frame(tick,epoch=epoch)).frames[0]
        sealed=store.compare_and_seal(b);self.assertEqual(sealed.state,'matched')
        return a,b
    def exits(self,store,tick=1,epoch=1):
        c=dict(ok=True,native_live_bytes=0,snapshot_live_bytes=0,host_application_live_bytes=0,all_explicit_drops_ok=True,core_shutdown_clean=True)
        for role in ['host','client']:store.register_exit(role,role+'-g1',exit_code=0,last_epoch=epoch,last_confirmed=tick,cleanup=c)
    def fx(self,**kw):
        result=dict(epoch=1,tick=1,source=1,key=9,phase='commit',confirmed=True,payload=dict(serial=1,lifetime=3,kind='hit'))
        result.update(kw);return result

    def test_old_harness_frame_exact_compare_seal_retire_and_chain(self):
        s=self.store();a,b=self.pair(s)
        s.retire(a);s.retire(b);self.exits(s)
        result=s.finalize();self.assertEqual(result['result'],'PASS');self.assertEqual(result['retained_canonical_frames'],1)
        paths=s.export_receipts(s.root/'export');previous='0'*64;count=0
        for item in paths:
            for line in zlib.decompress(Path(item['path']).read_bytes()).splitlines():
                row=json.loads(line);self.assertEqual(row['prev'],previous)
                previous=hashlib.sha256(bytes.fromhex(previous)+row['kind'].encode()+b'\0'+json.dumps(row['body'],sort_keys=True,separators=(',',':')).encode()).hexdigest()
                self.assertEqual(previous,row['hash']);count+=1
        self.assertEqual(count,result['receipt_count']);self.assertEqual(previous,result['receipt_chain_head'])

    def test_altered_part_with_valid_rehashed_signature_preserves_first_full_mismatch(self):
        s=self.store();s.register_frame('host','host-g1',self.frame(1))
        altered=self.frame(1,parts=[b'solver1',b'CHANGED',b'side',b'observations',b'occurrences'])
        ctx=dict(from_tick=1,to_tick=1,depth=0,source=1,sequence=0,sequence_available=False,accepted_inputs=b'accepted',predicted_inputs=b'predicted',provenance={'point':'read-only'})
        b=s.register_frame('client','client-g1',altered,context=ctx).frames[0]
        with self.assertRaises(EvidenceDivergence):s.compare_and_seal(b)
        saved=s.first_mismatch();self.assertEqual(saved['expected']['parts'][1],b'game');self.assertEqual(saved['actual']['parts'][1],b'CHANGED')
        self.assertEqual(saved['context']['accepted_inputs'],b'accepted');self.assertEqual(saved['context']['depth'],0)
        self.assertEqual(len(saved['expected']['parts']),5);self.assertEqual(len(saved['actual']['parts']),5)
        self.assertEqual(s.db.execute('SELECT count(*) FROM matches').fetchone()[0],0)

    def test_invalid_part_source_and_identity_cannot_seal(self):
        s=self.store();frame=self.frame(1);frame.paths[1].write_bytes(b'bad')
        with self.assertRaises(EvidenceError):s.register_frame('host','host-g1',frame)
        with self.assertRaises(EvidenceError):s.register_process(ProcessScope('client','bad-source',3,'2'*64,1,0))
        s.register_frame('host','host-g1',self.frame(1))
        with self.assertRaises(EvidenceError):s.register_frame('client','client-g1',self.frame(1,identity=2))
        self.assertEqual(s.db.execute('SELECT count(*) FROM matches').fetchone()[0],0)

    def test_unmatched_retirement_hot_bound_and_finalize_fail(self):
        s=self.store(max_hot_frames=1);a=s.register_frame('host','host-g1',self.frame(1)).frames[0]
        with self.assertRaises(EvidenceHold):s.retire(a)
        with self.assertRaises(EvidenceHold):s.register_frame('host','host-g1',self.frame(2))
        self.exits(s);result=s.finalize();self.assertEqual(result['result'],'FAIL');self.assertGreater(result['unmatched_required_frames'],0)

    def test_receipts_only_cannot_hash_compare_new_late_scope(self):
        s=self.store(raw_policy='receipts_only');a,b=self.pair(s);s.retire(a);s.retire(b)
        s.register_process(ProcessScope('client','client-g2',3,SOURCE,1,0))
        late=s.register_frame('client','client-g2',self.frame(1)).frames[0]
        with self.assertRaises(EvidenceHold):s.compare_and_seal(late)
        self.assertEqual(s.finalize()['retained_canonical_frames'],0)

    def test_global_fx_duplicate_survives_h128_retirement_and_rejoin(self):
        s=self.store(max_hot_frames=2);s.record_fx('client','client-g1',self.fx())
        for tick in range(1,131):
            a,b=self.pair(s,tick);s.retire(a);s.retire(b)
        s.register_process(ProcessScope('client','client-g2',3,SOURCE,1,130))
        with self.assertRaises(EvidenceDivergence):s.record_fx('client','client-g2',self.fx())
        self.assertIn('fx_lifecycle',s.first_mismatch()['kind'])

    def test_epoch_identity_separate_but_settled_cancel_keeps_permanent_id(self):
        s=self.store()
        s.record_fx('client','client-g1',self.fx(phase='begin',confirmed=False))
        s.record_fx('client','client-g1',self.fx(phase='confirm'))
        s.record_recovery('client','client-g1',dict(kind='epoch_reset',old_epoch=1,epoch=2,baseline=0,observed=True,basis='framework_epoch_reset'))
        s.record_fx('client','client-g1',self.fx(phase='cancel'))
        s.record_fx('client','client-g1',self.fx(epoch=2)) # numerical ID reuse in NEW epoch is valid
        with self.assertRaises(EvidenceDivergence):s.record_fx('client','client-g1',self.fx(phase='confirm'))
        self.assertEqual(s.db.execute('SELECT count(*) FROM fx WHERE settled IS NOT NULL').fetchone()[0],2)

    def test_settled_cancel_without_marker_or_changed_payload_fails(self):
        for tamper in (False,True):
            s=self.store();s.record_fx('client','client-g1',self.fx())
            if tamper:s.record_recovery('client','client-g1',dict(kind='epoch_reset',old_epoch=1,epoch=2,baseline=0,observed=True,basis='framework_epoch_reset'))
            value=self.fx(phase='cancel')
            if tamper:value['payload']['kind']='tampered'
            with self.assertRaises(EvidenceDivergence):s.record_fx('client','client-g1',value)

    def test_missing_fx_decision_or_cleanup_cannot_finalize_pass(self):
        s=self.store();self.pair(s);self.exits(s)
        s.record_fx('host','host-g1',self.fx())
        s.record_decision('host','host-g1',dict(epoch=1,tick=1,seat=1,kind='Spawn',sequence=1,applied=True,accepted=True))
        result=s.finalize();self.assertEqual(result['result'],'FAIL');self.assertEqual(result['fx_missing'],1);self.assertEqual(result['decision_missing'],1)

    def test_cancelled_speculation_can_rebegin_but_settlement_stays_unique(self):
        s=self.store();s.record_fx('client','client-g1',self.fx(phase='begin',confirmed=False))
        s.record_fx('client','client-g1',self.fx(phase='cancel',confirmed=False))
        s.record_fx('client','client-g1',self.fx(phase='begin',confirmed=False))
        s.record_fx('client','client-g1',self.fx(phase='confirm'))
        with self.assertRaises(EvidenceDivergence):s.record_fx('client','client-g1',self.fx(phase='confirm'))

    def test_receipt_tamper_detected_and_failed_exit_cannot_be_replaced(self):
        s=self.store();self.pair(s);self.exits(s)
        s.db.execute("UPDATE receipts SET body=? WHERE id=1",(b'{}',));s.db.commit()
        self.assertEqual(s.finalize()['result'],'FAIL')
        with self.assertRaises(EvidenceError):s.register_exit('client','client-g1',exit_code=1,last_epoch=1,last_confirmed=1,cleanup={})

    def test_decision_kind_mutation_intent_or_missing_fx_payload_rejected(self):
        s=self.store();row=dict(epoch=1,tick=1,seat=1,kind='Spawn',sequence=1,applied=True,accepted=True)
        s.record_decision('host','host-g1',row)
        changed=dict(row,kind='Remove')
        with self.assertRaises(EvidenceDivergence):s.record_decision('host','host-g1',changed)
        s2=self.store()
        with self.assertRaises(EvidenceError):s2.record_decision('host','host-g1',dict(row,event='ISSUED'))
        with self.assertRaises(EvidenceError):s2.record_fx('host','host-g1',dict(epoch=1,tick=1,key=8,phase='commit',confirmed=True))

    def test_optin_reference_policy_archives_unpaired_raw_and_compares_all_followers(self):
        s=self.store(frame_policy='all_follower_exports_required',max_hot_frames=1)
        references=[]
        for tick in (1,2):
            ref=s.register_frame('host','host-g1',self.frame(tick)).frames[0]
            archived=s.retire(ref);self.assertEqual(archived.state,'reference_archived');references.append(ref)
        follower=s.register_frame('client','client-g1',self.frame(2)).frames[0]
        with self.assertRaises(EvidenceHold):s.register_frame('client','client-g1',self.frame(3))
        self.assertEqual(s.compare_and_seal(follower).state,'matched');s.retire(follower);self.exits(s,tick=2)
        result=s.finalize();self.assertEqual(result['result'],'PASS')
        self.assertEqual(result['authority_export_count'],2);self.assertEqual(result['unmatched_authority_references'],1)
        self.assertEqual(result['required_follower_exports'],1);self.assertEqual(result['required_follower_matches'],1)
        self.assertEqual(result['retained_canonical_frames'],2);self.assertEqual(result['authority_archived_reference_count'],2)
        receipt=json.loads(s.db.execute("SELECT body FROM receipts WHERE kind='authority_reference_archived' LIMIT 1").fetchone()[0])
        self.assertFalse(receipt['byte_comparison'])

    def test_reference_optin_never_excuses_missing_follower_or_final_tail(self):
        s=self.store(frame_policy='all_follower_exports_required')
        a,b=self.pair(s);s.retire(a);s.retire(b)
        extra=s.register_frame('host','host-g1',self.frame(2)).frames[0];s.retire(extra)
        self.exits(s,tick=2)
        result=s.finalize();self.assertEqual(result['result'],'FAIL');self.assertGreater(result['final_tail_missing'],0)
        with self.assertRaises(EvidenceError):self.store(frame_policy='all_follower_exports_required',raw_policy='receipts_only')

    def test_post_admission_decision_optin_retains_baseline_but_never_waives_later_missing(self):
        row=lambda tick,seat:dict(epoch=1,tick=tick,seat=seat,x=0,z=0,origin='Held',generation=1,serial=1)
        strict=self.store(baseline=1);self.pair(strict);self.exits(strict)
        for seat in (1,2):strict.record_decision('host','host-g1',row(1,seat))
        self.assertEqual(strict.finalize()['decision_missing'],2)
        s=self.store(baseline=1,decision_coverage='after_admission_baseline');self.pair(s)
        for seat in (1,2):s.record_decision('host','host-g1',row(1,seat))
        self.exits(s);result=s.finalize();self.assertEqual(result['result'],'PASS')
        self.assertEqual(result['decision_outside_admission_count'],2);self.assertEqual(s.db.execute('SELECT count(*) FROM decisions').fetchone()[0],2)
        later=self.store(baseline=1,decision_coverage='after_admission_baseline');self.pair(later,2);self.exits(later,tick=2)
        later.record_decision('host','host-g1',row(2,1))
        self.assertEqual(later.finalize()['decision_missing'],1)

    def test_disk_exhaustion_rolls_back_without_receipt_publication(self):
        s=self.store(disk_budget_bytes=1024*1024,mismatch_reserve_bytes=16*1024,max_frame_bytes=4096,max_part_bytes=4096,max_context_bytes=1024)
        exhausted=False
        for index in range(100):
            before=s.db.execute('SELECT count(*) FROM receipts').fetchone()[0]
            try:s.record_fx('host','host-g1',self.fx(key=100+index,payload={'bytes':os.urandom(4096).hex()}))
            except EvidenceBudget:
                self.assertEqual(s.db.execute('SELECT count(*) FROM receipts').fetchone()[0],before);exhausted=True;break
        self.assertTrue(exhausted)
        self.assertLessEqual(sum(p.stat().st_size for p in s.root.iterdir() if p.is_file()),s.config.disk_budget_bytes)


if __name__=='__main__':unittest.main()
