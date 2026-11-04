"""Pure synthetic LONG policy controls. No process, Native, Godot or timer."""
import copy
import hashlib
import json
from pathlib import Path
import sqlite3
import sys
import tempfile
import unittest
import struct
import zlib

import long_policy as lp
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'audit'))
from test_rolling import signature_for

H='1'*64


def plan(framework='replay'):
    return lp.make_plan('synthetic-only',framework,36600,dict(host=H,client=H),
                        6144*1024*1024,512*1024*1024,128*1024*1024,execution=execution(),
                        replay_rule_oracle=dict(path='/synthetic-only/oracle.json',sha256=H) if framework=='replay' else None)


def execution():
    return dict(seed=17,required_ticks=36000,minimum_wall_seconds=600.0,timeout_seconds=900.0,
                latency_ms=0,jitter_ms=0,loss_percent=0,duplicate_percent=0,reorder=False,
                lifecycle='primary_pair_only_separate_cases_required')


def cli(p):
    e=p['execution']
    return dict(framework=p['framework'],end_tick=p['target_tick'],bodies=32,seed=e['seed'],
                ticks=e['required_ticks'],minimum_wall_seconds=e['minimum_wall_seconds'],timeout=e['timeout_seconds'],
                latency=e['latency_ms'],jitter=e['jitter_ms'],loss=e['loss_percent'],
                store_mib=p['disk']['rolling_bytes']//1024**2,event_mib=p['disk']['event_bytes']//1024**2,
                log_mib=p['disk']['log_bytes_each']//1024**2)


def raw_missing():
    return dict(result='FAIL',findings=[lp.FX_MISSING,lp.DECISION_MISSING],
        fx_missing=1,decision_missing=1,fx_changed=0,fx_extra=0,
        decision_changed=0,decision_extra=0,unmatched_required_frames=0,final_tail_missing=0)


def classification():
    fx=[1,105,[1,7]];decision=[1,106,2,0]
    row=lambda key:dict(key=key,disposition='UNOBSERVED_PAST',gap_ids=[20],
                        previously_settled=False,authority_body_sha256=H)
    return dict(raw_missing_fx=[fx],classified_fx=[row(fx)],
                raw_missing_decisions=[decision],classified_decisions=[row(decision)])


def audit_cycles():
    """Synthetic semantic inputs, NOT an actual run/provenance attestation."""
    a=lp._Audit(plan(),None);a.admission=1;a.gaps=[];a.matched={36600}
    a.store=sqlite3.connect(':memory:')
    a.store.execute('CREATE TABLE fx(role TEXT,id TEXT,settled BLOB,epoch TEXT)')
    a.store.execute('INSERT INTO fx VALUES(?,?,?,?)',('client','[1,1000,[1,1]]',b'{}',lp._hex(1)))
    counters=dict(host=0,client=0)
    for name,r in a.roles.items():
        r.ready=dict(row=dict(epoch=1,baseline=1,action_timing='Receipt',contract=5,game_rules=H,game_schema=H,serial=1))
    for cycle in range(152):
        due=40+240*cycle;a.matched.update((due-1,due+239))
        for name,kinds,seat,generation,serial in (
            ('host',('Spawn','Remove','Motor','Sleep','Wake'),1,0,0),
            ('client',('Spawn','Query'),2,1,1)):
            for kind in kinds:
                counters[name]+=1;seq=counters[name];tick=240*cycle+lp.PHASES[kind]
                issued=dict(epoch=1,seat=seat,kind=kind,sequence=seq,requested_tick=tick,
                    original_requested_tick=tick,sampled_head=tick-1,sampled_tick=tick,submitted_tick=tick,
                    rebased_before_sampling=False,recovery_serial=0,action_timing='Receipt',generation=generation,serial=serial)
                applied=not(name=='client' and kind=='Spawn')
                decision=dict(epoch=1,seat=seat,kind=kind,sequence=seq,tick=tick+(name=='client'),
                    accepted=True,applied=applied,reason='None' if applied else 'Predicate',
                    action_timing='Receipt',generation=generation,serial=serial)
                a.roles[name].issues.append(dict(id=tick*10+seat,row=issued))
                a.roles['host'].actions.append(dict(id=tick*10+seat+3,row=decision))
    return a


def audit_gaps(count=1):
    a=lp._Audit(plan(),None)
    for r in a.roles.values():r.ready=dict(row=dict(epoch=1,baseline=1,serial=1))
    last=1
    for index in range(count):
        start=100+index*200;end=start+8;event_id=20+index*30
        a.roles['client'].frames.extend((dict(id=event_id-1,tick=start,head=start,confirmed=start,observed_at=float(index*3)),
            dict(id=event_id+1,tick=end,head=end,confirmed=end,observed_at=float(index*3+2))))
        a.matched=getattr(a,'matched',set())|{end}
        a.roles['client'].marks.append(dict(id=event_id,kind='RECOVERY',observed_at=float(index*3+1),
            row=dict(epoch=1,cause='canonical_welcome',old_serial=index+1,new_serial=index+2,
                old_baseline=last,new_baseline=end,old_head=start,new_head=end,view_reset=index+1,resyncs=index+1,snapshot_catchups=0)))
        last=end
    return a


def spawn_pair(ticks=(40,41),winner_seat=1,policy='Scheduled'):
    """Synthetic immutable authority order for one original-due pair."""
    joins=[];events=[]
    for index,seat in enumerate((winner_seat,3-winner_seat)):
        tick=ticks[index]
        issued=dict(epoch=1,seat=seat,kind='Spawn',sequence=1,
                    requested_tick=40,original_requested_tick=40,
                    sampled_head=tick-1,sampled_tick=tick,submitted_tick=tick,
                    action_timing=policy)
        row=dict(epoch=1,seat=seat,kind='Spawn',sequence=1,tick=tick,
                 accepted=True,applied=index==0,reason='None' if index==0 else 'Predicate',
                 action_timing=policy)
        joins.append(dict(issued=issued,authority=row))
        events.append(dict(id=10+20*index,row=row))
    return joins,events


def oracle_fixture(root):
    """Synthetic file-binding fixture, NOT an actual Native/codec execution."""
    manifest={lp.SEED_SOURCES[0]:H,lp.SEED_SOURCES[1]:'2'*64,
              'replay/physics/network_codec.odin':'3'*64,'box3d/diagnostics/descriptor.odin':'4'*64}
    dump=lambda name,value:(root/name).write_bytes((json.dumps(value,sort_keys=True)+'\n').encode())
    dump('sources-before.json',manifest);dump('sources-after.json',manifest)
    binary=root/'oracle-unit-binary';binary.write_bytes(b'unit-only-not-executable')
    compiler=root/'compiler-unit';compiler.write_bytes(b'unit-only-not-compiler')
    native=root/'native-unit.a';native.write_bytes(b'unit-only-not-native')
    native_manifest=root/'native-manifest.json';native_manifest.write_bytes(b'{}')
    binding=dict(build_exit=0,run_exit=0,source_fence_unchanged=True,
        sources_before_sha256=lp._sha(root/'sources-before.json'),sources_after_sha256=lp._sha(root/'sources-after.json'),
        native_archive=str(native),native_archive_sha256=lp._sha(native),native_manifest=str(native_manifest),
        native_manifest_sha256=lp._sha(native_manifest),binary_sha256=lp._sha(binary),argv=['build','unit','-out:'+str(binary)])
    dump('build-binding.json',binding)
    app=bytes.fromhex(lp.expected_replay_rules(manifest,32,17));schema=b'unit-public-schema';values=b'unit-public-config-values'
    descriptor=lp._descriptor(b'odin-godot.replay.physics-rules.v1',(('application',app),('provider_schema',schema),('provider_values',values)))
    bound=hashlib.sha256(descriptor).digest()
    sig=signature_for((b'solver',b'game',b'',b'obs',b'events'),1,10)
    catalog=dict(solver_format=struct.unpack_from('<I',sig,16)[0],recovery_format=struct.unpack_from('<I',sig,20)[0],
        profile=struct.unpack_from('<Q',sig,32)[0],build_target=sig[40:72].hex(),assets=sig[72:104].hex(),solver_schema=sig[104:136].hex())
    status={k:0 for k in ('catalog_create','identity_status','codec_init','config_encode','codec_destroy','catalog_destroy','engine_status','wrapper_status')}
    cleanup={k:0 for k in ('engine_live','wrapper_live','provider_live','odin_live')}
    public=dict(ok=True,files_written=True,initial=32,seed=17,application_rules=list(app),bound_game_rules=list(bound),
        provider_canonical_bytes=len(schema),provider_value_bytes=len(values),native_build=list(bytes.fromhex(H)),
        native_target=list(bytes.fromhex('2'*64)),catalog_identity={k:list(bytes.fromhex(v)) if isinstance(v,str) else v for k,v in catalog.items()},**status,**cleanup)
    dump('report.json',dict(public=public))
    blobs={'application_rules.bin':app,'provider_config.canonical.bin':schema,'provider_config.values.bin':values,
           'bound_game_rules.bin':bound,'network_bound_rules.descriptor.bin':descriptor}
    for name,data in blobs.items():(root/name).write_bytes(data)
    data=dict(schema=1,ok=True,initial=32,seed=17,application_rules=app.hex(),actual_codec_game_rules=bound.hex(),python_descriptor=bound.hex(),
        bytes={k:dict(length=len(v),sha256=hashlib.sha256(v).hexdigest()) for k,v in blobs.items()},catalog_identity=catalog,
        native_build=H,native_target='2'*64,native_archive=str(native),native_archive_sha256=lp._sha(native),public_statuses=status,cleanup=cleanup,
        build=dict(exit=0,run_exit=0,source_fence_unchanged=True,binding_sha256=lp._sha(root/'build-binding.json'),
            source_manifest_sha256=lp._sha(root/'sources-before.json'),compiler_path=str(compiler),compiler_sha256=lp._sha(compiler),binary_sha256=lp._sha(binary)),
        report_sha256=lp._sha(root/'report.json'))
    dump('oracle.json',data);p=plan();p['replay_rule_oracle']=dict(path=str(root/'oracle.json'),sha256=lp._sha(root/'oracle.json'))
    return p,manifest,sig,data


class PureControls(unittest.TestCase):
    def test_plan_is_fixed_and_hash_binds_every_threshold(self):
        p=plan();self.assertEqual(lp.validate_plan(p),p)
        original=lp.plan_digest(p)
        for key in lp.FIXED:
            bad=copy.deepcopy(p);bad['fixed'][key]+=1
            with self.assertRaises(lp.PolicyError):lp.validate_plan(bad)
        bad=copy.deepcopy(p);bad['fixed']['min_seconds']=600.0
        with self.assertRaises(lp.PolicyError):lp.validate_plan(bad)
        p['run_id']='another';self.assertNotEqual(lp.plan_digest(p),original)

    def test_raw_guard_permits_only_exact_missing_keys_and_findings(self):
        self.assertEqual(lp.guard_raw_strict(raw_missing(),classification())['status'],'ALLOW_MISSING_ONLY_CLASSIFICATION')
        mutations=(lambda r,c:r['findings'].append('first divergence full5parts'),
                   lambda r,c:r.update(fx_changed=1),lambda r,c:r.update(decision_extra=1),
                   lambda r,c:r.update(final_tail_missing=1),lambda r,c:r.update(unmatched_required_frames=1),
                   lambda r,c:c['classified_fx'].append(copy.deepcopy(c['classified_fx'][0])),
                   lambda r,c:c['classified_decisions'][0].update(key=[1,107,2,0]),
                   lambda r,c:c['classified_fx'][0].update(previously_settled=True),
                   lambda r,c:c['classified_fx'][0].update(gap_ids=[]),
                   lambda r,c:c['classified_fx'][0].update(disposition='MATCHED'),
                   lambda r,c:r.update(fx_missing=2),lambda r,c:r.update(result='PASS'),
                   lambda r,c:r.update(findings=[{'not':'a string'}]))
        for mutate in mutations:
            r,c=raw_missing(),classification();mutate(r,c)
            with self.subTest(mutate=mutate):self.assertEqual(lp.guard_raw_strict(r,c)['status'],'FAIL')

    def test_historical_report_cannot_receive_new_pass(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);refs=[]
            for name,data in (('report',b'{"result":"PASS"}'),('events',b'old'),('store',b'old')):
                p=root/name;p.write_bytes(data);refs.append(lp.Artifact(p,hashlib.sha256(data).hexdigest()))
            result=lp.classify(plan(),lp.EvidenceBundle(*refs))
            self.assertEqual(result['result'],'INCOMPLETE')
            self.assertIn('historical',result['unavailable'][0])

    def test_wrong_immutable_artifact_fails_before_policy_application(self):
        with tempfile.TemporaryDirectory() as folder:
            p=Path(folder)/'data';p.write_bytes(b'changed')
            ref=lp.Artifact(p,H)
            result=lp.classify(plan(),lp.EvidenceBundle(ref,ref,ref))
            self.assertEqual(result['result'],'FAIL');self.assertIn('SHA',result['failures'][0])

    def test_wrong_process_source_is_not_a_new_admission(self):
        a=lp._Audit(plan(),None);a.store=sqlite3.connect(':memory:');a.store.row_factory=sqlite3.Row
        self.addCleanup(a.store.close)
        a.store.execute('CREATE TABLE processes(role TEXT,source TEXT)')
        a.store.executemany('INSERT INTO processes VALUES(?,?)',[('host',H),('client','2'*64)])
        with self.assertRaisesRegex(lp.PolicyError,'wrong process/source'):a.processes_and_frames()

    def test_actual_payload_rewrite_is_not_hidden_by_zero_summary(self):
        a=lp._Audit(plan(),None);a.raw=dict(fx_changed=0,fx_extra=0,decision_changed=0,decision_extra=0)
        a.store=sqlite3.connect(':memory:');self.addCleanup(a.store.close)
        a.store.execute('CREATE TABLE decisions(role TEXT,id TEXT,body BLOB)')
        a.store.execute('CREATE TABLE fx(role TEXT,id TEXT,settled BLOB)')
        a.store.executemany('INSERT INTO fx VALUES(?,?,?)',[('host','[1,105,[1,7]]',b'original'),('client','[1,105,[1,7]]',b'changed')])
        with self.assertRaisesRegex(lp.PolicyError,'payload/provenance rewrite'):a.missing_and_global()

    def test_actual_finite_store_budget_exhaustion_fails(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);manifest=root/'source.json';manifest.write_bytes(b'{}\n')
            source=hashlib.sha256(manifest.read_bytes()).hexdigest()
            p=lp.make_plan('synthetic','kit',36600,dict(host=source,client=source),64*1024*1024,16*1024*1024,4*1024*1024,execution=execution())
            store=root/'store.sqlite'
            with store.open('wb') as f:f.truncate(64*1024*1024+1)
            events=root/'events.sqlite';events.write_bytes(b'not-opened')
            refs={name:lp.Artifact(path,lp._sha(path)) for name,path in (('store',store),('events',events))}
            build=root/'build.json';build.write_text(json.dumps(dict(result='PASS',source_fence_unchanged=True,framework='kit',source_manifest=str(manifest),source_manifest_sha256=source)))
            report=root/'report.json';report.write_text(json.dumps(dict(framework='kit',plan=cli(p),long_policy=dict(policy_id=lp.POLICY_ID,policy_sha256=lp.plan_digest(p),run_id='synthetic',marker_event_id=1,prelaunch=True),source_changes=[],driver_source_changes=[],source_fence_unchanged=True,compiled_build=dict(path=str(build),sha256=lp._sha(build)),observation_archive=dict(path=str(events),sha256=refs['events'].sha256),rolling_database=dict(path=str(store),sha256=refs['store'].sha256))))
            result=lp.classify(p,lp.EvidenceBundle(lp.Artifact(report,lp._sha(report)),refs['events'],refs['store']))
            self.assertEqual(result['result'],'FAIL')
            self.assertIn('budget exceeded',result['failures'][0])

    def test_execution_seed_impairment_duration_and_budget_are_bound(self):
        p=plan();lp._execution_binding(p,dict(plan=cli(p)))
        for field,new in (('seed',1),('ticks',35999),('minimum_wall_seconds',599),('timeout',901),
                          ('latency',10),('jitter',1),('loss',1),('end_tick',36601),('store_mib',4096)):
            c=cli(p);c[field]=new
            with self.subTest(field=field):
                with self.assertRaises(lp.PolicyError):lp._execution_binding(p,dict(plan=c))
        for field,new in (('seed',0),('required_ticks',35999),('minimum_wall_seconds',599),
                          ('timeout_seconds',600),('duplicate_percent',1),('reorder',True),('lifecycle','other')):
            q=copy.deepcopy(p);q['execution'][field]=new
            with self.subTest(field=field):
                with self.assertRaises(lp.PolicyError):lp.validate_plan(q)

    def test_ready_seed_uses_bound_rules_descriptor_not_cli_label(self):
        p=plan();manifest={'examples/replay_box3d/shared/adapter/model.odin':H,'examples/box3d_common/rules.odin':'2'*64}
        expected=lp.expected_replay_rules(manifest,32,17)
        from accept import CHANNELS
        ready=dict(baseline=1,target=36600,game_rules=expected,impairment=dict(
            request=dict(latency_ms=0,jitter_ms=0,loss_percent=0,duplicate_percent=0,reorder=False),
            effective=dict(latency_ms=0,jitter_ms=0,loss_permyriad=0,duplicate_permyriad=0,delay_active=False,unreliable_may_reorder=False),
            channel=CHANNELS['replay']))
        with self.assertRaises(lp.Unavailable):lp._ready_execution(p,ready)
        proof=dict(bound_game_rules=expected)
        lp._ready_execution(p,ready,proof)
        bad=copy.deepcopy(ready);bad['game_rules']=lp.expected_replay_rules(manifest,32,1)
        with self.assertRaises(lp.PolicyError):lp._ready_execution(p,bad,proof)
        bad=copy.deepcopy(ready);bad['impairment']['request']['latency_ms']=10
        with self.assertRaises(Exception):lp._ready_execution(p,bad,proof)
        bad=copy.deepcopy(ready);bad['seed']=1
        with self.assertRaises(lp.PolicyError):lp._ready_execution(p,bad,proof)

    def test_public_codec_oracle_binds_both_descriptors_and_signature_identity(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);p,manifest,sig,data=oracle_fixture(root)
            proof=lp.load_replay_rule_oracle(p,manifest,dict(domain=dict(build=H,target='2'*64)))
            self.assertNotEqual(proof['application_rules'],proof['bound_game_rules'])
            lp.validate_oracle_signature(proof,sig)
            for offset in (32,40,72,104):
                bad=bytearray(sig);bad[offset]^=1;bad[448:]=hashlib.sha256(bad[:448]).digest()
                with self.subTest(offset=offset):
                    with self.assertRaises(lp.PolicyError):lp.validate_oracle_signature(proof,bytes(bad))
            with self.assertRaises(lp.PolicyError):lp.load_replay_rule_oracle(p,manifest,dict(domain=dict(build='3'*64,target='2'*64)))
            wrong=copy.deepcopy(p);wrong['execution']['seed']=1
            with self.assertRaises(lp.PolicyError):lp.load_replay_rule_oracle(wrong,manifest)
            changed=dict(manifest);changed[lp.SEED_SOURCES[0]]='5'*64
            with self.assertRaises(lp.PolicyError):lp.load_replay_rule_oracle(p,changed)
            (root/'provider_config.values.bin').write_bytes(b'changed')
            with self.assertRaises(lp.PolicyError):lp.load_replay_rule_oracle(p,manifest)

    def test_oracle_public_failure_is_not_blessed_by_fresh_json_hash(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);p,manifest,_,data=oracle_fixture(root)
            data['cleanup']['provider_live']=1
            (root/'oracle.json').write_text(json.dumps(data))
            p['replay_rule_oracle']['sha256']=lp._sha(root/'oracle.json')
            with self.assertRaises(lp.PolicyError):lp.load_replay_rule_oracle(p,manifest)
        q=plan();q['replay_rule_oracle']=None
        with self.assertRaises(lp.PolicyError):lp.validate_plan(q)
        q=plan('kit');q['replay_rule_oracle']=dict(path='/unit',sha256=H)
        with self.assertRaises(lp.PolicyError):lp.validate_plan(q)

    def test_gap_uses_actual_per_role_time_and_settled_boundary(self):
        a=audit_gaps();a.qualified_gaps()
        self.assertEqual(a.gaps[0]['observation_interval_seconds'],2)
        self.assertEqual(a.gaps[0]['previously_confirmed'],100)
        a=audit_gaps();a.roles['client'].frames[1]['observed_at']=None
        with self.assertRaises(lp.Unavailable):a.qualified_gaps()
        a=audit_gaps();a.roles['client'].frames[1]['observed_at']=6
        with self.assertRaisesRegex(lp.PolicyError,'5s'):a.qualified_gaps()
        a=audit_gaps();a.roles['client'].frames[0]['confirmed']=101
        with self.assertRaisesRegex(lp.PolicyError,'settled'):a.qualified_gaps()

    def test_gap_qualification_count_length_latest_and_chain_caps(self):
        for mutate in (lambda a:a.roles['client'].marks[0]['row'].update(cause='ordinary_catchup'),
                       lambda a:a.roles['client'].marks[0]['row'].update(new_serial=1),
                       lambda a:a.roles['client'].marks[0]['row'].update(old_baseline=2),
                       lambda a:a.roles['client'].marks[0]['row'].update(new_baseline=229,new_head=229)):
            a=audit_gaps();mutate(a)
            with self.assertRaises(lp.PolicyError):a.qualified_gaps()
        with self.assertRaisesRegex(lp.PolicyError,'count'):audit_gaps(9).qualified_gaps()
        a=audit_gaps();a.roles['client'].marks[0]['row'].update(old_head=3600,new_baseline=3608,new_head=3608)
        a.roles['client'].frames[0].update(tick=3600,head=3600,confirmed=3600)
        a.roles['client'].frames[1].update(tick=3608,head=3608,confirmed=3608);a.matched={3608}
        with self.assertRaisesRegex(lp.PolicyError,'late recovery'):a.qualified_gaps()

    def test_complete_cycle_density_keeps_all_denominator_and_tail(self):
        a=audit_cycles();self.addCleanup(a.store.close);a.intents_and_cycles()
        self.assertEqual(a.summary['cycles']['denominator'],152)
        self.assertEqual(a.summary['cycles']['verified'],152)
        self.assertEqual(a.summary['cycles']['consecutive_after_last_gap'],152)
        self.assertEqual(len(a.summary['immutable_issue_joins']),1064)
        b=audit_cycles();self.addCleanup(b.store.close)
        b.gaps=[dict(id=1,start_exclusive=0,end_inclusive=8000)]
        with self.assertRaisesRegex(lp.PolicyError,'count/density'):b.intents_and_cycles()
        b=audit_cycles();self.addCleanup(b.store.close)
        b.gaps=[dict(id=1,start_exclusive=30000,end_inclusive=30008)]
        with self.assertRaisesRegex(lp.PolicyError,'post-gap'):b.intents_and_cycles()

    def test_wrong_cycle_kind_scope_sequence_and_target_fail(self):
        changes=(lambda a:a.roles['client'].issues[0]['row'].update(original_requested_tick=41),
                 lambda a:a.roles['client'].issues[0]['row'].update(kind='Motor'),
                 lambda a:a.roles['client'].issues[0]['row'].update(serial=2),
                 lambda a:a.roles['client'].issues[1]['row'].update(sequence=1),
                 lambda a:a.roles['client'].issues[0]['row'].update(sampled_head=30),
                 lambda a:a.roles['client'].issues[0]['row'].update(submitted_tick=49))
        for change in changes:
            a=audit_cycles();self.addCleanup(a.store.close);change(a)
            with self.assertRaises(lp.PolicyError):a.intents_and_cycles()

    def test_remove_between_spawns_and_all_six_cannot_be_borrowed(self):
        a=audit_cycles();self.addCleanup(a.store.close)
        for event in a.roles['host'].actions:
            row=event['row']
            if row['seat']==2 and row['kind']=='Spawn':
                row['tick']+=20
                event['id']=row['tick']*10+row['seat']+3
        with self.assertRaisesRegex(lp.PolicyError,'count/density'):a.intents_and_cycles()
        a=audit_cycles();self.addCleanup(a.store.close)
        for event in a.roles['host'].actions:
            if event['row']['kind']=='Motor':event['row']['applied']=False
        with self.assertRaisesRegex(lp.PolicyError,'count/density'):a.intents_and_cycles()

    def test_kit_publication_contract_and_per_seat_fifo_are_not_skipped(self):
        a=audit_cycles();self.addCleanup(a.store.close);a.plan=plan('kit')
        with self.assertRaisesRegex(lp.PolicyError,'Kit public'):a.intents_and_cycles()
        a=audit_cycles();self.addCleanup(a.store.close)
        for event in a.roles['host'].actions:
            if event['row']['seat']==2 and event['row']['sequence']==2:
                event['row']['tick']=1
                event['id']=15
        with self.assertRaisesRegex(lp.PolicyError,'FIFO'):a.intents_and_cycles()

    def test_long_scheduled_pair_uses_each_real_target_and_same_original_due(self):
        a=audit_cycles();self.addCleanup(a.store.close)
        for role in a.roles.values():
            role.ready['row']['action_timing']='Scheduled'
            for event in role.issues:
                issue=event['row'];issue['action_timing']='Scheduled'
                if role is a.roles['client']:
                    issue['sampled_head']+=1;issue['sampled_tick']+=1;issue['submitted_tick']+=1
        for event in a.roles['host'].actions:event['row']['action_timing']='Scheduled'
        a.intents_and_cycles()
        self.assertEqual(a.summary['cycles']['verified'],152)
        pair=a.summary['cycles']['rows'][0]['contested_pair']
        self.assertEqual(pair['original_due'],40)
        self.assertEqual([pair[k]['tick'] for k in ('winner','rejected')],[40,41])
        joins,events=spawn_pair(winner_seat=2)
        self.assertEqual(lp._long_spawn_pair(joins,events,'Scheduled')['winner']['seat'],2)
        for change in ('due','target','sequence'):
            joins,events=spawn_pair()
            if change=='due':joins[1]['issued']['original_requested_tick']=280
            elif change=='target':joins[1]['issued']['submitted_tick']=40
            else:joins[1]['authority']=dict(joins[1]['authority'],sequence=2)
            with self.subTest(change=change):
                with self.assertRaises(lp.PolicyError):lp._long_spawn_pair(joins,events,'Scheduled')

    def test_equal_actual_tick_keeps_semantic_seat_order(self):
        joins,events=spawn_pair(ticks=(40,40))
        proof=lp._long_spawn_pair(joins,events,'Scheduled')
        self.assertEqual(proof['execution_order'],'semantic seat order at a shared tick')
        joins,events=spawn_pair(ticks=(40,40),winner_seat=2)
        with self.assertRaisesRegex(lp.PolicyError,'semantic seat order'):
            lp._long_spawn_pair(joins,events,'Scheduled')
        joins,events=spawn_pair(ticks=(40,40));events[0]['id'],events[1]['id']=30,10
        with self.assertRaisesRegex(lp.PolicyError,'semantic seat order'):
            lp._long_spawn_pair(joins,events,'Scheduled')

    def test_same_tick_remove_or_replacement_is_intervening_by_actual_event_order(self):
        for ticks,remove_tick in (((40,41),40),((40,41),41),((40,40),40)):
            joins,events=spawn_pair(ticks=ticks)
            remove=dict(id=20,row=dict(epoch=1,seat=1,sequence=2,kind='Remove',tick=remove_tick,applied=True))
            with self.subTest(ticks=ticks,remove_tick=remove_tick):
                with self.assertRaisesRegex(lp.NotContested,'including same tick'):
                    lp._long_spawn_pair(joins,events+[remove],'Scheduled')
                replacement=dict(id=25,row=dict(epoch=1,seat=1,sequence=3,kind='Spawn',tick=remove_tick,applied=True))
                with self.assertRaisesRegex(lp.NotContested,'intervening'):
                    lp._long_spawn_pair(joins,events+[remove,replacement],'Scheduled')
        for event_id,tick in ((5,40),(40,41)):
            joins,events=spawn_pair()
            remove=dict(id=event_id,row=dict(epoch=1,seat=1,sequence=2,kind='Remove',tick=tick,applied=True))
            self.assertEqual(lp._long_spawn_pair(joins,events+[remove],'Scheduled')['original_due'],40)
        joins,events=spawn_pair()
        rejected_remove=dict(id=20,row=dict(epoch=1,seat=1,sequence=2,kind='Remove',tick=40,applied=False))
        self.assertEqual(lp._long_spawn_pair(joins,events+[rejected_remove],'Scheduled')['original_due'],40)

    def test_double_success_without_real_remove_is_hard_even_in_interrupted_cycle(self):
        for rejected_remove in (False,True):
            joins,events=spawn_pair();joins[1]['authority'].update(applied=True,reason='None')
            if rejected_remove:
                events.append(dict(id=20,row=dict(epoch=1,seat=1,sequence=2,kind='Remove',tick=40,applied=False)))
            with self.subTest(rejected_remove=rejected_remove):
                with self.assertRaisesRegex(lp.PolicyError,'impossible two successful'):
                    lp._long_spawn_pair(joins,events,'Scheduled')
        joins,events=spawn_pair();joins[1]['authority'].update(applied=True,reason='None')
        remove=dict(id=20,row=dict(epoch=1,seat=1,sequence=2,kind='Remove',tick=40,applied=True))
        with self.assertRaises(lp.NotContested):lp._long_spawn_pair(joins,events+[remove],'Scheduled')
        joins,events=spawn_pair()
        replacement=dict(id=20,row=dict(epoch=1,seat=1,sequence=2,kind='Spawn',tick=40,applied=True))
        with self.assertRaisesRegex(lp.PolicyError,'impossible two successful'):
            lp._long_spawn_pair(joins,events+[replacement],'Scheduled')
        a=audit_cycles();self.addCleanup(a.store.close)
        a.gaps=[dict(id=1,start_exclusive=39,end_inclusive=48)]
        a.roles['host'].actions[5]['row'].update(applied=True,reason='None')
        with self.assertRaisesRegex(lp.PolicyError,'impossible two successful'):
            a.intents_and_cycles()

    def test_unavailable_target_or_short_wall_duration_is_not_success(self):
        a=audit_cycles();self.addCleanup(a.store.close)
        for r in a.roles.values():r.go=dict(observed_at=0);r.frames=[]
        with self.assertRaises(lp.Unavailable):a.time_and_duration()
        for r in a.roles.values():r.frames=[dict(tick=36600,observed_at=599)]
        with self.assertRaises(lp.PolicyError):a.time_and_duration()
        for r in a.roles.values():r.frames=[dict(tick=36600,observed_at=None)]
        with self.assertRaises(lp.Unavailable):a.time_and_duration()

    def test_full_canonical_part_checks_and_missing_raw_are_hard(self):
        parts=(b'solver',b'game',b'',b'observations',b'occurrences')
        sig=signature_for(parts,1,10);payload=zlib.compress(b''.join(parts))
        self.assertEqual(lp._parts(sig,payload),b''.join(parts))
        with self.assertRaises(lp.PolicyError):lp._parts(sig,zlib.compress(b'S'+b''.join(parts)[1:]))
        with self.assertRaises(lp.Unavailable):lp._parts(sig,None)
        with self.assertRaises(lp.PolicyError):lp._parts(sig,payload+b'extra')


if __name__=='__main__':unittest.main()
