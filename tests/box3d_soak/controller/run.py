#!/usr/bin/env python3
"""Stream one existing two-process scene into bounded Gate B evidence storage.

Without --execute this writes a plan only. CPU certification is separate from
this functional soak; a successful controller run cannot establish Gate B.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import shutil
import socket
import sqlite3
import sys
import threading
import time

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'tests/box3d_soak/shared'))
sys.path.insert(0, str(ROOT / 'tests/box3d_slices/harness'))
sys.path.insert(0, str(ROOT / 'tests/box3d_presentation/scene_controls'))
from evidence import EndpointEvidence, load_frame, require, json_bytes, strict_json, verify_pair
from rolling import RollingConfig, RollingStore, ProcessScope, EvidenceHold
from accept import verify_ready, tree_manifest
from stream import Actor, StreamBounds


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def source_manifest(framework):
    """Include generated bindings as consumed sources; keep caches/binaries separate."""
    roots = ('box3d', 'core', 'runtime', 'godot', 'gdext', 'decl', 'kit', 'replay',
             'build', 'scriptgen', 'play', 'examples/box3d_common',
             'examples/kit_box3d', 'examples/replay_box3d')
    suffixes = ('.odin', '.c', '.h', '.sh', '.py', '.gd', '.gdextension', '.godot', '.tscn', '.json')
    return {str(p.relative_to(ROOT)): sha(p) for name in roots for p in sorted((ROOT/name).rglob('*'))
            if p.is_file() and p.suffix in suffixes
            and not any(part in ('bin', '.godot', '__pycache__') for part in p.parts)}


def frozen_execution(args):
    return dict(seed=args.seed,required_ticks=args.ticks,
        minimum_wall_seconds=float(args.minimum_wall_seconds),timeout_seconds=float(args.timeout),
        latency_ms=args.latency,jitter_ms=args.jitter,loss_percent=args.loss,
        duplicate_percent=0,reorder=False,lifecycle='primary_pair_only_separate_cases_required')


def pending_events(actor):
    count=getattr(actor,'pending_event_count',None)
    if type(count) is int:
        require(count>=0,'negative intake cursor distance')
        return count
    queue=getattr(actor,'events',None)
    return queue.qsize() if queue is not None else 0


def reader_eof(actor):
    value=getattr(actor,'reader_eof',None)
    if type(value) is bool:return value
    thread=getattr(actor,'thread',None)
    return thread is None or not thread.is_alive()


def drain_actor(actor, callback):
    """After finish, consume every committed record, retaining the first error.

    A callback failure cannot hide a later real RESULT/cleanup record. A corrupt
    or unreadable prefix that cannot advance remains an explicit failure.
    """
    require(reader_eof(actor),'intake reader did not reach EOF')
    first=None
    while pending_events(actor):
        before=pending_events(actor)
        try:actor.consume(callback,max_records=64)
        except Exception as failure:first=first or failure
        if pending_events(actor)>=before:
            first=first or RuntimeError('committed intake prefix cannot advance')
            break
    return first


class EventArchive:
    """Finite on-disk observations; no whole-run Python event arrays."""
    def __init__(self, path, budget_bytes):
        self.db = sqlite3.connect(path)
        self.db.execute('PRAGMA page_size=4096')
        self.db.execute('PRAGMA journal_mode=DELETE')
        self.db.execute('PRAGMA synchronous=FULL')
        # Half main DB, half conservative rollback staging and64KiB slack.
        self.db.execute('PRAGMA max_page_count='+str((budget_bytes-65536)//8192))
        self.db.executescript('''
          CREATE TABLE events(id INTEGER PRIMARY KEY,role TEXT,kind TEXT,observed_at REAL,epoch INTEGER,
            indexed_tick INTEGER,seat INTEGER,sequence INTEGER,body TEXT,prev TEXT,hash TEXT);
          CREATE INDEX event_kind ON events(role,kind,epoch,indexed_tick);
        ''')
        self.count,self.head=0,'0'*64
        self.path=Path(path).resolve()

    def append(self, role, kind, row, observed_at=None):
        require(observed_at is None or (type(observed_at) in (int,float)
                and math.isfinite(observed_at) and observed_at>=0),
                'invalid actual observation time')
        observed_at=None if observed_at is None else float(observed_at)
        number=self.count+1
        value=hashlib.sha256(bytes.fromhex(self.head)+json_bytes(dict(id=number,role=role,
            kind=kind,row=row,observed_at=observed_at))).hexdigest()
        indexed_tick=row.get('submitted_tick') if kind in ('ISSUED','SUBMITTED') else row.get('tick')
        try:
            self.db.execute('INSERT INTO events VALUES(?,?,?,?,?,?,?,?,?,?,?)',
                (number,role,kind,observed_at,row.get('epoch'),indexed_tick,row.get('seat'),row.get('sequence'),
                 json_bytes(row).decode(),self.head,value))
            self.db.commit()
        except Exception:
            self.db.rollback()
            raise
        self.count,self.head=number,value

    def rows(self, role, kind):
        for body, in self.db.execute('SELECT body FROM events WHERE role=? AND kind=? ORDER BY id', (role,kind)):
            yield json.loads(body)

    def window(self, role, kinds, epoch, tick):
        query='SELECT body FROM events WHERE role=? AND kind IN ('+','.join('?' for _ in kinds)+') AND epoch=? AND indexed_tick BETWEEN ? AND ? ORDER BY id DESC LIMIT 32'
        return list(reversed([json.loads(x[0]) for x in self.db.execute(query,
            (role,*kinds,epoch,max(0,tick-127),tick))]))

    def verify_chain(self):
        previous='0'*64;number=0
        for row in self.db.execute('SELECT id,role,kind,body,prev,hash,observed_at FROM events ORDER BY id'):
            number+=1
            require(row[0]==number and row[4]==previous,'observation archive chain order changed')
            actual=hashlib.sha256(bytes.fromhex(previous)+json_bytes(dict(id=number,role=row[1],
                kind=row[2],row=json.loads(row[3]),observed_at=row[6]))).hexdigest()
            require(actual==row[5],'observation archive body changed')
            previous=actual
        require((number,previous)==(self.count,self.head),'observation archive tail changed')
        return dict(events=number,head_sha256=previous)


def verify_intent_contract(args, ready):
    expected=getattr(args,'kit_intent_contract',1)
    require(type(expected) is int and expected in (1,2),'invalid declared Kit intent contract')
    actual=ready.get('intent_contract_version',1)
    require(type(actual) is int and actual in (1,2),'invalid READY intent contract')
    if args.framework!='kit':
        require(expected==actual==1,'Replay cannot opt into the Kit intent contract')
    else:
        require(actual==expected,'Kit READY intent contract differs from prelaunch declaration')
        if expected==2:
            require(ready.get('intent_source')=='outside_sim_catalog_class1' and
                    ready.get('action_timing')=='Scheduled','V2 requires the actual Kit intent catalog')
    return expected


class Observation:
    def __init__(self, run, actor):
        self.run, self.actor = run, actor
        self.ready = self.result = self.scope = None
        self.go = False
        self.frames = self.fx = self.actions = 0
        self.last_frame = self.last_confirmed = 0
        self.limit_seen = False
        self.maximum_ledger = 0
        self.ledger_stages = set()
        self.envelope_seen = self.published35 = False
        self.final_ack = False
        self.before_admission = []
        self.go_at = self.target_at = None

    def deliver(self, kind, row):
        r, role = self.run, self.actor.role
        if self.scope is None:
            require(len(self.before_admission)<4096, 'pre-admission observation cap exceeded')
            self.before_admission.append((kind,row))
            return
        if kind in ('FX','EFFECT'):
            r.store.record_fx(role, self.scope, row)
            self.fx += 1
        elif kind in ('RECOVERY','RECOVERED'):
            r.store.record_recovery(role, self.scope, row)
        else:
            r.store.record_decision(role, self.scope, row)
            if kind in ('APPLIED','ACTION'):
                self.actions += 1

    def receive(self, kind, row, observed_at=None):
        r, role = self.run, self.actor.role
        require(isinstance(row, dict), 'observation must be an object')
        require(row.get('framework', r.args.framework) == r.args.framework, 'mixed framework')
        if 'role' in row:
            require(row['role'] == role, 'wrong diagnostic role')
        if 'actor' in row:
            require(row['actor'] == role, 'wrong diagnostic actor')
        r.archive.append(role, kind, row, observed_at=observed_at)
        require(kind != 'ERROR', ('scene reported failure', role, row))
        require(kind != 'INTENT_UNEXERCISED', ('required fresh intent unexercised',role,row))
        if kind == 'READY':
            require(self.ready is None and row.get('ready', True) is True, 'duplicate/invalid READY')
            require(row['target'] == r.args.end_tick, 'scene target differs from frozen plan')
            require(row['baseline']+r.args.ticks <= r.args.end_tick, 'insufficient admitted future span')
            verify_intent_contract(r.args,row)
            verify_ready(row, r.args.framework, r.impairment)
            self.ready = row
            self.scope = f'{role}-p{self.actor.process.pid}-g1'
            r.store.register_process(ProcessScope(role, self.scope, self.actor.process.pid,
                r.source_sha, row['epoch'], row['baseline']))
            expected_seat,expected_token=(1,101) if role=='host' else (2,202)
            require(row['seat']==expected_seat, 'unexpected semantic driver seat')
            token=int.from_bytes(bytes.fromhex(row['token_hex'])[:8],'little') if 'token_hex' in row else row['token']
            require(token==expected_token, 'actual token differs from plan')
            early,self.before_admission=self.before_admission,[]
            for early_kind,early_row in early:
                self.deliver(early_kind,early_row)
        elif kind == 'GO':
            require(self.ready is not None and not self.go, 'GO without one actual READY')
            self.go = True
            self.go_at = observed_at
            if all(x.go for x in r.observations.values()):
                if not getattr(r,'replaying_saved',False):
                    require(all(x.go_at is not None for x in r.observations.values()),'GO lacks observed receive time')
                    r.all_go_at = max(x.go_at for x in r.observations.values())
        elif kind == 'FRAME':
            require(self.ready is not None, 'FRAME before READY')
            require(row['tick']<=self.ready['baseline'] or self.go, 'post-baseline FRAME before GO')
            r.frame(self, row)
            if row['tick']==r.args.end_tick and self.target_at is None:
                self.target_at=observed_at
        elif kind in ('FX','EFFECT','INPUT','ACCEPTED','APPLIED','ACTION','RECOVERY','RECOVERED'):
            self.deliver(kind,row)
        elif kind == 'LIMITS':
            require(not self.limit_seen, 'duplicate profile declaration')
            expected = dict(initial_cached_dynamic_bodies=r.args.bodies,initial_cached_body_count=r.args.bodies+2,
                history=128,hz=60,substeps=4,max_prediction=8,max_repair=8,process_limit_bytes=67108864)
            require(all(row.get(k) == v for k,v in expected.items()), ('profile changed', role, row))
            self.limit_seen = True
        elif kind == 'ENVELOPE':
            require(row.get('observe_error') == 'None', 'native observation failed')
            if not self.envelope_seen:
                require(row['cached_dynamic_bodies']==r.args.bodies and row['cached_body_count']==r.args.bodies+2,
                        'declared initial body count was not observed')
            self.envelope_seen = True
            require(0<=row['cached_dynamic_bodies']<=33 and row['cached_body_count']<=35,
                    'published cache outside body envelope')
            for field, cap in zip(('body_count','shape_count','contact_count','joint_count'),(35,35,147,1)):
                require(0<=row['native_'+field]<=row['peak_'+field]<=cap, ('native envelope exceeded',field))
            if row['phase']=='published_cache_and_world_observation':
                require(row.get('native_scope')=='published_world_only'
                        and row['native_body_count']==row['cached_body_count'], 'cache/world mismatch')
            else:
                require(row['phase']=='published_cache_and_local_candidate_observation', 'unknown count scope')
            self.published35 |= row['cached_dynamic_bodies']==r.args.bodies+1 and row['cached_body_count']==r.args.bodies+3
        elif kind == 'LEDGER':
            require(row.get('status')==0 and row['limit_bytes']==67108864, 'ledger query/limit mismatch')
            require(row['live_bytes']==row['engine_live_bytes']+row['snapshot_live_bytes']+row['host_live_bytes'], 'ledger LIVE omission')
            require(row['admitted_bytes']==row['live_bytes']+row['host_reserved_bytes'], 'reservation omission')
            require(0<=row['admitted_bytes']<=67108864 and self.maximum_ledger<=row['committed_peak_bytes']<=67108864, 'ledger budget/peak failure')
            self.maximum_ledger=row['committed_peak_bytes']
            self.ledger_stages.add(row['stage'])
            if row['stage']=='after_cleanup':
                require(row['engine_live_bytes']==row['snapshot_live_bytes']==row['host_reserved_bytes']==0, 'ledger teardown not zero')
        elif kind == 'TAIL' and row.get('stage')=='final_received':
            require(row.get('matched') is True and row['tick']==r.args.end_tick, 'invalid terminal signature receipt')
            if role=='host':
                if r.args.framework=='kit' and 'from_role' not in row:
                    require(row.get('head')==row['tick'] and row.get('confirmed')==row['tick'],
                            'invalid authority self terminal notification')
                    return  # A self-signature is not the remote Client's receipt.
                require(row.get('from_role')=='client','terminal receipt lacks actual follower role')
                if r.args.framework=='replay':
                    require(bytes.fromhex(row['from_token_hex'])==(202).to_bytes(8,'little')+bytes(8)
                            and row['from_seat']==2 and row['from_generation']>0
                            and row['from_peer']>0, 'terminal receipt identity differs from admitted Client')
                else:
                    mask=(1<<64)-1
                    z=(202+0x9e3779b97f4a7c15)&mask
                    z=((z^(z>>30))*0xbf58476d1ce4e5b9)&mask
                    z=((z^(z>>27))*0x94d049bb133111eb)&mask
                    require(row['from_token_hash']==(z^(z>>31)) and row['from']>0 and row['peer']>0,
                            'terminal receipt token/peer differs from admitted Client')
            self.final_ack = True
        elif kind == 'RESULT':
            require(self.result is None, 'duplicate final RESULT')
            self.result = row
        else:
            require(kind in ('STATUS','BASELINE','STAGE','BOOT','WAIT','TAIL','FLOW','PUMP',
                'PLAYER_LEFT','RECOVERY_REQUESTED','RECOVERY_REQUEST_OBSERVED','RECOVERY_WIRE',
                'RECOVERY_WAIT','ISSUED','SUBMITTED','INTENT_ATTEMPT','INTENT_REBASE',
                'INTENT_BASELINE','MEMBER','CLOSE_TRACE'), ('unknown scene observation',kind))


class Soak:
    def __init__(self, args):
        self.args = args
        self.out = args.out.resolve()
        self.out.mkdir(parents=True,exist_ok=False)
        self.before = source_manifest(args.framework)
        self.driver_before={str(p.resolve()):sha(p) for folder in ('controller','shared')
            for p in sorted((ROOT/'tests/box3d_soak'/folder).glob('*.py'))}
        for path in (ROOT/'tests/box3d_slices/harness/evidence.py',
                     ROOT/'tests/box3d_slices/harness/runner.py',
                     ROOT/'tests/box3d_presentation/scene_controls/accept.py'):
            self.driver_before[str(path.resolve())]=sha(path)
        (self.out/'sources-before.json').write_bytes(json_bytes(self.before)+b'\n')
        self.source_sha = sha(self.out/'sources-before.json')
        self.impairment = {k:str(v) for k,v in zip(
            ('B3_LATENCY','B3_JITTER','B3_LOSS','B3_DUPLICATE','B3_REORDER'),
            (args.latency,args.jitter,args.loss,0,0))}
        self.actors = []
        self.observations = {}
        self.pending = []
        self.wake = threading.Event()
        self.all_go_at = None
        self.store = self.archive = None
        self.report = dict(result='INCOMPLETE',scope='functional two-process soak; CPU separate',
            gate_b='NOT_ESTABLISHED',framework=args.framework,plan=vars(args).copy(),
            frame_coverage='ALL actual follower confirmed exports required; all authority exports retained as references',
            decision_coverage='after actual admission baseline; no automatic recovery exclusions',
            steps={'build':'REUSED_NOT_EXECUTED','import':'REUSED_NOT_EXECUTED'})
        self.long_plan=args.bodies==32 and args.ticks>=36000 and args.minimum_wall_seconds>=600
        self.report['scope']='long functional two-process soak; CPU separate' if self.long_plan else 'bounded controller smoke; NOT a long-soak result'
        self.report['driver_files_before']=self.driver_before
        self.report['intake_policy']=dict(storage='raw_log_and_chained_disk_index',
            raw_log_limit_bytes_each=args.log_mib*1024*1024,
            index_limit_bytes_each=args.log_mib*1024*1024,
            index_record_bytes=96,max_records_per_turn=64,consume_bytes_per_turn=4*1024*1024,
            source='frozen Actor implementation; controller disk budgets separate from Native64MiB')
        self.report['plan']={k:str(v) if isinstance(v,Path) else v for k,v in self.report['plan'].items()}
        self.coverage_plan=None
        self.coverage_binding=None
        path=getattr(args,'long_policy_plan',None)
        digest=getattr(args,'long_policy_sha256',None)
        require(bool(path)==bool(digest),'LONG policy requires both a frozen plan and its canonical SHA256')
        if path:
            from long_policy import make_plan,plan_digest
            require(self.long_plan,'prospective policy is restricted to32-body600s/36000-tick LONG plans')
            plan=strict_json(Path(path).read_bytes())
            expected=make_plan(self.out.name,args.framework,args.end_tick,
                {role:self.source_sha for role in ('host','client')},args.store_mib*1024*1024,
                args.event_mib*1024*1024,args.log_mib*1024*1024,execution=frozen_execution(args),
                replay_rule_oracle=plan.get('replay_rule_oracle'))
            require(json_bytes(plan)==json_bytes(expected) and plan_digest(plan)==digest,
                    'LONG policy differs from frozen source/run/target/budgets or SHA256')
            if args.framework=='replay':
                from long_policy import load_replay_rule_oracle
                load_replay_rule_oracle(plan,self.before)
            self.coverage_plan=plan
            self.coverage_binding=dict(policy_id=plan['policy_id'],policy_sha256=digest,
                run_id=self.out.name,marker_event_id=1,prelaunch=True)
            (self.out/'long-policy-plan.json').write_bytes(json_bytes(plan)+b'\n')
            self.report['long_policy_plan_artifact']=dict(path=str(Path(path).resolve()),sha256=sha(path))
            self.report['decision_coverage']='explicit prospective LONG policy; raw strict findings retained'
        self.publish()

    def publish(self):
        (self.out/'report.json').write_bytes(json_bytes(self.report)+b'\n')

    def intake_identity(self, role):
        return dict(role=role,source_manifest_sha256=self.source_sha,
            compiled_build_sha256=sha(self.args.build_record),
            frozen_project_sha256=hashlib.sha256(json_bytes(self.frozen_before)).hexdigest())

    def frame(self, observation, row):
        role=observation.actor.role
        frame=load_frame(observation.actor.output,row)
        try:
            context=dict(from_tick=frame.tick,to_tick=frame.tick,depth=0,source=1,sequence=0,
                sequence_available=False,
                accepted_inputs=json_bytes(self.archive.window('host',('INPUT','ACCEPTED','APPLIED','ACTION'),frame.epoch,frame.tick)),
                predicted_inputs=b'',provenance=dict(scope='read-only actual confirmed comparison',
                    source_manifest_sha256=self.source_sha,role=role,scope_id=observation.scope,
                    pid=observation.actor.process.pid,unknown_predicted_inputs=True,
                    actual_issued_requests=self.archive.window('client',('ISSUED','SUBMITTED'),frame.epoch,frame.tick),
                    issued_requests_are_not_predicted_used_history=True,
                    archive_prefix=dict(path=str(self.archive.path),through_event_id=self.archive.count,
                        head_sha256=self.archive.head,epoch=frame.epoch,
                        tick_from=max(0,frame.tick-127),tick_to=frame.tick,
                        indexing='actual published row.tick; ISSUED uses actual row.submitted_tick, never authority execution tick',
                        note='exact observed prefix before comparison; later observations retained separately')))
            registered=self.store.register_frame(role,observation.scope,frame,context=context)
        except EvidenceHold:
            require(len(self.pending)<256, 'pending unbound identity/export cap reached')
            self.pending.append((observation,row))
            return
        ref=registered.frames[0]
        sealed=self.store.compare_and_seal(ref)
        if sealed.state=='matched':
            for matched in sealed.frames:
                self.store.retire(matched)
        if role=='host':
            outcome=self.store.retire(ref)
            require(outcome.state in ('reference_archived','duplicate','retired'), 'authority reference not safely archived')
        # register_frame has durably copied/validated all5 bytes. Source output
        # copies can now be removed; unmatched required rows remain in the store.
        if getattr(self,'consume_export_files',True):
            for path in frame.paths:
                path.unlink()
            Path(str(frame.paths[0])[:-6]+'.sig').unlink()
        observation.frames+=1
        observation.last_frame=max(observation.last_frame,frame.tick)
        observation.last_confirmed=max(observation.last_confirmed,int(row.get('confirmed',frame.tick)))
        if role=='host' and self.pending:
            pending,self.pending=self.pending,[]
            for actor,record in pending:
                self.frame(actor,record)

    def audit_endpoint(self, role):
        """Reuse existing action/intent/FX checks; raw states stay in rolling storage.

        The finite diagnostic subset is bounded independently from raw-frame
        history. INPUT and per-frame telemetry remain on disk and are checked by
        the rolling decision/ledger paths rather than loaded into Python arrays.
        """
        observed=self.observations[role]
        endpoint=EndpointEvidence(self.args.framework,role,observed.actor.output)
        endpoint.ready,endpoint.result=observed.ready,observed.result
        selected=('APPLIED','ACTION','ISSUED','SUBMITTED','FX','EFFECT','RECOVERY',
            'RECOVERY_REQUESTED','RECOVERED','INTENT_ATTEMPT','INTENT_REBASE','INTENT_UNEXERCISED')
        placeholders=','.join('?' for _ in selected)
        query='SELECT id,kind,body FROM events WHERE role=? AND kind IN ('+placeholders+') ORDER BY id'
        count=0
        for order,kind,body in self.archive.db.execute(query,(role,*selected)):
            count+=1
            require(count<=32768,'declared action/FX diagnostic working-set bound exceeded')
            row=json.loads(body)
            if kind in ('APPLIED','ACTION'):endpoint.actions.append(row)
            elif kind in ('ISSUED','SUBMITTED'):
                endpoint.issued.append(row);endpoint.issue_marks.append((order,row))
            elif kind in ('FX','EFFECT'):
                endpoint.effects.append(row);endpoint.effect_marks.append((order,row))
            else:
                marked=dict(row,event=kind)
                endpoint.statuses.append(marked);endpoint.status_marks.append((order,marked))
                if kind=='RECOVERY':endpoint.recovery_marks.append((order,row))
        # Metadata keys only, never a whole-run array of full solver images.
        keys=self.store.db.execute('SELECT epoch,tick FROM frames WHERE role=?',(role,))
        endpoint.frames={}
        for epoch,tick in keys:
            require(len(endpoint.frames)<65536,'declared comparison-key bound exceeded')
            endpoint.frames[int(epoch,16),int(tick,16)]=None
        return endpoint

    def run(self):
        error=None
        exits={}
        try:
            require('frame_policy' in RollingConfig.__dataclass_fields__, 'rolling reference policy not implemented yet')
            project=self.args.project.resolve()
            binding=json.loads(self.args.build_record.read_text())
            require(binding.get('result')=='PASS' and binding.get('exit_code')==0
                    and binding.get('source_fence_unchanged') is True,'missing successful compiled source binding')
            require(binding['framework']==self.args.framework and Path(binding['project']).resolve()==project,
                    'compiled project/framework binding differs')
            require(binding['source_manifest_sha256']==self.source_sha,
                    'frozen binaries were built from a different current production source manifest')
            require(sha(Path(binding['source_manifest']))==self.source_sha,'compiled source manifest file changed')
            require(binding.get('consumed_example_source_copy_verified') is True,
                    'compiled example copy/source binding unavailable')
            require((project/'.godot/extension_list.cfg').is_file(), 'frozen imported project metadata absent')
            self.frozen_before=tree_manifest(project)
            require(self.frozen_before==binding['frozen_project_files'],'compiled project/binaries changed')
            self.report['compiled_build']=dict(path=str(self.args.build_record.resolve()),sha256=sha(self.args.build_record))
            require(any(name.endswith('libogb3.dylib') or name.endswith('libogb3.so') for name in self.frozen_before), 'frozen project lacks shared Native')
            self.report['frozen_project']=dict(path=str(project),files=self.frozen_before)
            if self.coverage_plan is not None and self.args.framework=='replay':
                from long_policy import load_replay_rule_oracle
                metadata=project/'bin/box3d-runtime.json'
                require(metadata.is_file() and self.frozen_before.get('bin/box3d-runtime.json')==sha(metadata),
                        'frozen selected Native metadata unavailable')
                load_replay_rule_oracle(self.coverage_plan,self.before,
                    native_metadata=strict_json(metadata.read_bytes()))
            self.store=RollingStore(RollingConfig(directory=self.out/'rolling',authority_role='host',
                follower_roles=('client',),allowed_sources={r:(self.source_sha,) for r in ('host','client')},
                disk_budget_bytes=self.args.store_mib*1024*1024,frame_policy='all_follower_exports_required',
                decision_coverage='after_admission_baseline'))
            self.archive=EventArchive(self.out/'observations.sqlite',self.args.event_mib*1024*1024)
            if self.coverage_plan is not None:
                # Durable marker precedes every process launch; it is not a
                # retrospectively supplied label on a saved failed case.
                self.archive.append('controller','LONG_POLICY',self.coverage_binding)
                self.report['long_policy']=self.coverage_binding
                self.publish()
            with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as sock:
                sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
            self.report['port']=port
            for role,token in (('host',101),('client',202)):
                copied=self.out/(role+'-project')
                shutil.copytree(project,copied,ignore=shutil.ignore_patterns('*.r*.p*.dylib','*.r*.p*.so','__pycache__'))
                require(tree_manifest(copied)==self.frozen_before,'frozen copy mismatch')
                env={k:v for k,v in os.environ.items() if not k.startswith('B3_')}
                suffix='.dylib' if sys.platform=='darwin' else '.so'
                env.update(ROOT=str(ROOT),ODIN_GODOT_ROOT=str(ROOT),
                    ODIN_SCRIPTS_DLL=str(copied/'bin'/('libodinscripts'+suffix)),
                    B3_FRAMEWORK=self.args.framework,B3_ROLE=role,B3_ACTOR=role,B3_TOKEN=str(token),
                    B3_PORT=str(port),B3_ADDRESS='127.0.0.1',B3_SCRIPTED='1',B3_BODIES=str(self.args.bodies),
                    B3_SEED=str(self.args.seed),B3_TICKS=str(self.args.ticks),B3_END_TICK=str(self.args.end_tick),
                    B3_EXPECT_OBSERVERS='0',B3_DEBUG_TIMEOUT_FRAMES=str(self.args.end_tick*3),
                    B3_OUTPUT=str(self.out/role),**self.impairment)
                actor=Actor(role=role,godot=self.args.godot,project=copied,environment=env,
                    output=self.out/role,bounds=StreamBounds(log_bytes=self.args.log_mib*1024*1024,
                        index_bytes=self.args.log_mib*1024*1024),wake=self.wake,
                    identity=self.intake_identity(role))
                self.actors.append(actor)
                self.observations[role]=Observation(self,actor)
            deadline=time.monotonic()+self.args.timeout
            next_resource_sample=0
            while True:
                self.wake.clear()
                for actor in self.actors:
                    actor.consume(self.observations[actor.role].receive,max_records=64)
                    require(actor.process.poll() in (None,0), ('endpoint nonzero exit',actor.role,actor.process.poll()))
                if all(a.process.poll() is not None and reader_eof(a) and pending_events(a)==0
                       for a in self.actors):
                    break
                if time.monotonic()>=next_resource_sample:
                    for actor in self.actors:actor.sample_rss()
                    next_resource_sample=time.monotonic()+1
                require(time.monotonic()<deadline,'soak observation timeout')
                self.wake.wait(0.05)
        except Exception as failure:
            error=repr(failure)
        finally:
            for actor in self.actors:
                facts=None
                try:
                    facts=actor.finish(abort=error is not None)
                    exits[actor.role]=facts
                    consume_error=drain_actor(actor,self.observations[actor.role].receive)
                    if consume_error is not None:error=error or repr(consume_error)
                    facts['pending_events']=pending_events(actor)
                    if hasattr(actor,'records_consumed'):facts['records_consumed']=actor.records_consumed
                    facts['reader_eof']=reader_eof(actor)
                    intake_facts=getattr(actor,'intake_facts',None)
                    if intake_facts is not None:
                        facts['intake']=intake_facts()
                        intake=facts['intake']
                        require(intake['integrity_error'] is None and intake['final_flush_fsync_ok'] is True
                                and intake['writer_closed'] is True and intake['reader_eof'] is True,
                                'intake file integrity/EOF/fsync not verified')
                        require(intake['records_seen']==intake['records_published']==intake['records_consumed']
                                and intake['pending_events']==0,'valid intake observations were not all consumed')
                        require(intake['identity']==dict(schema=1,role=actor.role,identity=self.intake_identity(actor.role)),
                                'intake source/build/actor identity differs')
                    facts['reader_error']=getattr(actor,'error',None)
                    require(reader_eof(actor) and pending_events(actor)==0,'intake not fully consumed after EOF')
                    require(actor.error is None,('incomplete endpoint observations',actor.role,actor.error))
                    if intake_facts is not None:
                        actor.close()
                        facts['intake']=intake_facts()
                        require(facts['intake']['consumer_closed'] is True and actor.error is None,
                                'intake consumer closure/integrity failed')
                    observed=self.observations[actor.role]
                    endpoint=EndpointEvidence(self.args.framework,actor.role,actor.output)
                    endpoint.result=observed.result
                    checked=endpoint.teardown(facts['exit_code'])
                    require(facts['natural'], 'forced termination is not natural cleanup')
                    require(observed.ready is not None and observed.result['tick']==self.args.end_tick
                            and observed.last_frame==self.args.end_tick and (actor.role!='host' or observed.final_ack), 'missing actual target/terminal state/signature receipt')
                    require(observed.limit_seen and observed.envelope_seen and observed.published35, 'declared body scenario/envelope not exercised')
                    require({'published_frame','before_close','after_cleanup'}<=observed.ledger_stages, 'missing global ledger stages')
                    require(observed.fx>0 and observed.actions>0,'no actual effects/actions')
                    cleanup=dict(ok=True,native_live_bytes=checked['engine'],snapshot_live_bytes=checked['wrapper'],
                        host_application_live_bytes=checked['meter'],all_explicit_drops_ok=True,
                        core_shutdown_clean=actor.error is None)
                    if 'intake' in facts:cleanup['intake']=facts['intake']
                    self.store.register_exit(actor.role,observed.scope,exit_code=facts['exit_code'],
                        last_epoch=observed.ready['epoch'],last_confirmed=observed.result['tick'],cleanup=cleanup)
                except Exception as failure:
                    error=error or repr(failure)
                    exits.setdefault(actor.role,dict(pid=actor.process.pid,exit_code=actor.process.poll(),
                        natural=False,cleanup_verified=False,finish_error=repr(failure)))
                finally:
                    if facts is not None:
                        facts['pending_events']=pending_events(actor)
                        if hasattr(actor,'records_consumed'):facts['records_consumed']=actor.records_consumed
                        facts['reader_eof']=reader_eof(actor)
                        facts['reader_error']=getattr(actor,'error',None)
                    close=getattr(actor,'close',None)
                    if close is not None:
                        try:close()
                        except Exception as failure:error=error or repr(failure)
                    if facts is not None and getattr(actor,'intake_facts',None) is not None:
                        try:
                            facts['intake']=actor.intake_facts()
                            facts['reader_error']=actor.error
                            require(facts['intake']['consumer_closed'] is True and actor.error is None,
                                    'intake consumer closure/integrity failed')
                        except Exception as failure:error=error or repr(failure)
            if self.store is not None:
                try:
                    final=self.store.finalize()
                    self.report['rolling']=final
                    if self.coverage_plan is None and final['result']!='PASS':
                        error=error or repr(final['findings'])
                    if self.coverage_plan is not None:
                        self.report['existing_pair_gate']=dict(status='NOT_SELECTED',
                            reason='frozen prospective LONG cycle policy; short checker unchanged')
                    elif error is None:
                        host,client=(self.audit_endpoint(role) for role in ('host','client'))
                        compared={(int(e,16),int(t,16)) for e,t in self.store.db.execute('SELECT epoch,tick FROM matches WHERE role=?',('client',))}
                        self.report['existing_pair_gate']=verify_pair(host,client,self.args.ticks,compared)
                    self.report['receipt_segments']=self.store.export_receipts(self.out/'rolling/export')
                except Exception as failure:
                    error=error or repr(failure)
                finally:
                    self.store.close()
                    database=self.out/'rolling/store.sqlite'
                    self.report['rolling_database']=dict(path=str(database),sha256=sha(database),
                        first_mismatch_location='failure row1; complete expected/actual parts, signatures and bounded context')
            if self.archive is not None:
                try:
                    self.report['observation_chain']=self.archive.verify_chain()
                except Exception as failure:error=error or repr(failure)
                finally:self.archive.db.close()
                self.report['observation_archive']=dict(path=str(self.archive.path),sha256=sha(self.archive.path))
            targets=[x.target_at for x in self.observations.values()]
            elapsed=(min(targets)-self.all_go_at) if self.all_go_at is not None and len(targets)==2 and all(x is not None for x in targets) else 0
            if elapsed<self.args.minimum_wall_seconds:error=error or 'insufficient observed wall duration after all GO'
            if self.pending:error=error or 'unconsumed follower exports'
            after=source_manifest(self.args.framework)
            (self.out/'sources-after.json').write_bytes(json_bytes(after)+b'\n')
            changed=[p for p in set(self.before)|set(after) if self.before.get(p)!=after.get(p)]
            if changed:error=error or 'source fence changed'
            driver_changed=[name for name,want in self.driver_before.items()
                if not Path(name).is_file() or sha(name)!=want]
            if driver_changed:error=error or 'controller/shared evidence code changed during run'
            if hasattr(self,'frozen_before') and tree_manifest(self.args.project.resolve())!=self.frozen_before:
                error=error or 'supplied frozen project changed'
            result='FAIL' if error else ('LONG_POLICY_AUDIT_PENDING' if self.coverage_plan is not None else
                'FUNCTIONAL_SOAK_PASS' if self.long_plan else 'CONTROLLER_SMOKE_PASS')
            self.report.update(result=result,error=error,
                exits=exits,observed_seconds_after_all_GO_until_first_target=elapsed,
                duration_scope='controller stdout receive timestamps; excludes later auditing/cleanup/tail wait',source_changes=changed,
                source_manifest_sha256=self.source_sha,driver_source_changes=driver_changed,
                source_fence_unchanged=not changed)
            self.publish()
            if self.coverage_plan is not None:
                # Audit closed, hash-bound artifacts. Preserve this original
                # strict summary even when a prospective classification passes.
                original=self.out/'controller-before-long-audit.json'
                original.write_bytes(json_bytes(self.report)+b'\n')
                try:
                    from long_policy import Artifact,EvidenceBundle,classify
                    events=self.out/'observations.sqlite'
                    store=self.out/'rolling/store.sqlite'
                    audit=classify(self.coverage_plan,EvidenceBundle(
                        Artifact(original,sha(original)),Artifact(events,sha(events)),Artifact(store,sha(store))))
                except Exception as failure:
                    audit=dict(result='FAIL',failures=[repr(failure)],gate_b='NOT_ESTABLISHED')
                path=self.out/'long-coverage-audit.json'
                path.write_bytes(json_bytes(audit)+b'\n')
                self.report['prospective_long_audit']=dict(path=str(path),sha256=sha(path),result=audit['result'])
                passed=error is None and audit['result']=='PROSPECTIVE_LONG_COVERAGE_PASS'
                self.report['result']='FUNCTIONAL_SOAK_PASS' if passed else 'FAIL'
                if not passed:self.report['error']=error or 'prospective LONG coverage not established'
                self.publish()
        return self.report


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--framework',choices=('kit','replay'),required=True)
    p.add_argument('--kit-intent-contract',type=int,choices=(1,2),default=1,
                   help='prelaunch Kit intent proof version; fresh V2 producers require explicit2')
    p.add_argument('--project',type=Path,required=True,help='frozen already built/imported scene project')
    p.add_argument('--build-record',type=Path,required=True,help='controller/build.py binding for these exact binaries/current sources')
    p.add_argument('--out',type=Path,required=True)
    p.add_argument('--godot',default='/Applications/Godot.app/Contents/MacOS/Godot')
    p.add_argument('--execute',action='store_true')
    p.add_argument('--ticks',type=int,default=36000)
    p.add_argument('--end-tick',type=int,default=36600)
    p.add_argument('--seed',type=int,default=17)
    p.add_argument('--bodies',type=int,choices=(4,32),default=32,
                   help='4 is an explicitly labelled controller smoke, never a32-body soak substitute')
    p.add_argument('--minimum-wall-seconds',type=float,default=600)
    p.add_argument('--timeout',type=float,default=900)
    p.add_argument('--latency',type=int,default=10)
    p.add_argument('--jitter',type=int,default=1)
    p.add_argument('--loss',type=int,default=0)
    p.add_argument('--store-mib',type=int,default=1536)
    p.add_argument('--event-mib',type=int,default=256)
    p.add_argument('--log-mib',type=int,default=128)
    p.add_argument('--long-policy-plan',type=Path,
                   help='prospective LONG policy frozen before execution; strict default is unchanged')
    p.add_argument('--long-policy-sha256',help='canonical policy digest from long_policy.plan_digest')
    a=p.parse_args()
    p.error('Replay cannot opt into the Kit intent contract') if a.framework!='kit' and a.kit_intent_contract!=1 else None
    p.error('invalid duration/tick plan; comparison-key bound is65536') if not (240<=a.ticks<=a.end_tick<=65535 and 0<=a.minimum_wall_seconds<a.timeout<=3600) else None
    p.error('invalid seed or impairment') if not (0<a.seed<2**31 and 0<=a.latency<=10000 and 0<=a.jitter<=10000 and 0<=a.loss<=95) else None
    p.error('long soak requires the declared32-body profile') if a.ticks>=36000 and a.bodies!=32 else None
    p.error('evidence storage below declared minimum') if a.store_mib<64 or a.event_mib<16 or a.log_mib<4 else None
    p.error('LONG policy requires both frozen plan and canonical SHA256') if bool(a.long_policy_plan)!=bool(a.long_policy_sha256) else None
    if not a.execute:
        a.out.mkdir(parents=True,exist_ok=False)
        plan={k:str(v) if isinstance(v,Path) else v for k,v in vars(a).items()}
        plan.update(status='PLAN_ONLY_NO_PROCESSES',cpu_gate='SEPARATE_UNMET',
            lifecycle='primary pair only; deeper hold/reset/rejoin are separate required cases',
            frame_policy='all_follower_exports_required',decision_coverage='after_admission_baseline')
        (a.out/'plan.json').write_bytes(json_bytes(plan)+b'\n')
        print(a.out/'plan.json')
        return 0
    result=Soak(a).run()
    print(json.dumps(dict(result=result['result'],report=str(a.out/'report.json'))))
    return 0 if result['result'] in ('FUNCTIONAL_SOAK_PASS','CONTROLLER_SMOKE_PASS') else 1


if __name__=='__main__':raise SystemExit(main())
