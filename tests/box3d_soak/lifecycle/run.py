#!/usr/bin/env python3
"""Explicit small lifecycle cases around existing frozen Godot scenes.

No simulation, protocol, parser, or production/checker replacement lives here.
Default invocation stages a plan only. Every execution needs a separate grant.
"""
from pathlib import Path
import argparse
import copy
import hashlib
import json
import os
import shutil
import signal
import socket
import sys
import threading
import time

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'tests/box3d_soak/controller'))
import run as shared
from evidence import EndpointEvidence, verify_pair, load_frame, json_bytes, require, action_name
from rolling import RollingStore, RollingConfig, ProcessScope
from stream import Actor, StreamBounds


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def driver_hashes():
    files = [p for folder in ('controller', 'shared')
             for p in (ROOT / 'tests/box3d_soak' / folder).glob('*.py')]
    files += [ROOT / 'tests/box3d_slices/harness/evidence.py',
              ROOT / 'tests/box3d_presentation/scene_controls/accept.py']
    files += [p for p in Path(__file__).parent.iterdir() if p.suffix in ('.py', '.gd')]
    return {str(p.resolve()):sha(p) for p in sorted(files)}


def semantic_view(kind, row):
    # Raw record remains unmodified in EventArchive. This is the same diagnostic
    # process-generation envelope already excluded by the existing verifiers.
    if kind not in ('INPUT', 'ACCEPTED', 'APPLIED', 'ACTION', 'FX', 'EFFECT'):
        return row
    view = dict(row)
    if 'session_generation' in view:
        view['process_generation'] = view.pop('session_generation')
    return view


def pair_interval_views(host, client):
    """Scope only Host publications proven outside this actual client interval.

    No request-tick heuristic: a missing/ambiguous authority join stays in the
    unchanged verifier and fails. Client lifetime issues/outcomes are never cut.
    """
    epoch, baseline = client.baseline
    common = sorted(key for key in host.frames.keys() & client.frames.keys()
                    if key[0] == epoch and key[1] > baseline)
    require(common, 'no actual common confirmed interval')
    end = common[-1][1]
    policy = host.ready.get('action_timing')
    require(policy in ('Scheduled', 'Receipt') and client.ready.get('action_timing') == policy,
            'explicit matching action timing required for interval projection')

    def key(row):
        return (int(row['epoch']), int(row['seat']), int(row['sequence']), action_name(row['kind']))

    decisions = {}
    for row in host.actions:
        decisions.setdefault(key(row), []).append(row)
    kept, excluded = [], []
    for order, issue in host.issue_marks:
        matches = decisions.get(key(issue), [])
        decision = matches[0] if len(matches) == 1 else None
        outside = decision is not None and (int(decision['epoch']) != epoch
                    or int(decision['tick']) <= baseline or int(decision['tick']) > end)
        if outside and policy == 'Scheduled' and (decision['applied']
                or str(decision.get('reason', 'None')).lower() == 'none'):
            # Do not project away an already visible scheduled-target defect.
            outside = int(decision['tick']) == int(issue['submitted_tick'])
        if outside:
            excluded.append(dict(event_order=order, logical_key=list(key(issue)),
                                 issue=issue, unique_authority_decision=decision))
        else:
            kept.append((order, issue))
    host_view, client_view = copy.copy(host), copy.copy(client)
    host_view.frames = {k:v for k,v in host.frames.items() if k[0] == epoch and baseline < k[1] <= end}
    client_view.frames = {k:v for k,v in client.frames.items() if k[0] == epoch and baseline < k[1] <= end}
    host_view.issue_marks = kept
    host_view.issued = [issue for _, issue in kept]
    interval = dict(epoch=epoch, actual_Welcome_baseline=baseline, last_common_confirmed=end,
                    comparison_interval='(actual_Welcome_baseline,last_common_confirmed]',
                    action_timing=policy, Host_issues_excluded_by_unique_actual_outside_decision=excluded,
                    Host_issue_marks_kept=len(kept), Client_issue_marks_kept=len(client.issue_marks),
                    Client_lifetime_issues_and_outcomes_unfiltered=True)
    return host_view, client_view, common, interval


class Endpoint:
    def __init__(self, owner, actor, generation):
        self.owner, self.actor, self.generation = owner, actor, generation
        self.evidence = EndpointEvidence(owner.args.framework, actor.role, actor.output)
        self.evidence.require_go = True
        self.scope = None
        self.last_head = self.last_confirmed = 0
        self.finished = False
        self.lifecycle_markers = []

    def receive(self, kind, row, observed_at=None):
        run = self.owner
        run.archive.append(self.actor.role, kind, row, observed_at=observed_at)
        if run.args.framework == 'kit' and kind in ('REJOIN_SOURCE_STOP', 'REJOIN_ACCEPTED', 'REJOIN_GUARD', 'REJOIN_ADMITTED', 'REJOIN_OPEN'):
            require(len(self.lifecycle_markers) < 8, 'known lifecycle marker bound exceeded')
            self.lifecycle_markers.append((kind, dict(row)))
            self.evidence.receive('STATUS', row)
        else:
            self.evidence.receive(kind, semantic_view(kind, row))
        require(kind not in ('ERROR', 'INTENT_UNEXERCISED'), ('actual scene failure', self.actor.role, row))
        if kind == 'READY':
            shared.verify_ready(row, run.args.framework, run.impairment)
            expected_seat = {'host':1, 'client':2, 'observer':0}[self.actor.role]
            expected_token = {'host':101, 'client':202, 'observer':303}[self.actor.role]
            token = int.from_bytes(bytes.fromhex(row['token_hex'])[:8], 'little') if 'token_hex' in row else row['token']
            require(row['seat'] == expected_seat and token == expected_token, 'actual seat/token differs from declared actor')
            require(row.get('session_generation', row.get('process_generation', 1)) == self.generation,
                    'actual source generation differs from launched generation')
            if run.args.framework == 'kit':
                require(row.get('intent_contract_version') == 2 and row.get('world_wire_revision') == 2,
                        'current Kit v2 READY required')
            require(row['target'] == run.args.end_tick, 'actual target differs')
            require(row['baseline'] + run.args.ticks <= row['target'], 'insufficient future admission span')
            self.scope = f'{self.actor.role}-p{self.actor.process.pid}-g{self.generation}'
            run.store.register_process(ProcessScope(self.actor.role, self.scope, self.actor.process.pid,
                                                    run.source_sha, row['epoch'], row['baseline']))
        self.last_head = max(self.last_head, int(row.get('head', row.get('tick', 0))))
        self.last_confirmed = max(self.last_confirmed, int(row.get('confirmed', 0)))
        if kind == 'FRAME':
            require(self.scope is not None, 'frame before actual admission')
            frame = load_frame(self.actor.output, row)
            context = dict(from_tick=frame.tick, to_tick=frame.tick, depth=0, source=1, sequence=0,
                           sequence_available=False,
                           accepted_inputs=json_bytes(run.archive.window('host', ('INPUT', 'APPLIED'), frame.epoch, frame.tick)),
                           predicted_inputs=b'', provenance=dict(scope='actual exported lifecycle comparison',
                               pid=self.actor.process.pid, process_scope=self.scope,
                               predicted_history_available=False))
            registered = run.store.register_frame(self.actor.role, self.scope, frame, context=context)
            for ref in registered.frames:
                run.store.compare_and_seal(ref)
        elif self.scope is not None and kind in ('INPUT', 'ACCEPTED', 'APPLIED', 'ACTION'):
            run.store.record_decision(self.actor.role, self.scope, semantic_view(kind, row))
        elif self.scope is not None and kind in ('FX', 'EFFECT'):
            run.store.record_fx(self.actor.role, self.scope, semantic_view(kind, row))
        elif self.scope is not None and kind in ('RECOVERY', 'RECOVERED'):
            run.store.record_recovery(self.actor.role, self.scope, row)

    def markers(self, kind):
        return ([x for x in self.evidence.statuses if x.get('event') == kind]
                + [row for actual_kind, row in self.lifecycle_markers if actual_kind == kind])


class Lifecycle:
    def __init__(self, args):
        self.args = args
        self.out = args.out.resolve()
        self.out.mkdir(parents=True, exist_ok=False)
        self.source_before = shared.source_manifest(args.framework)
        self.drivers_before = driver_hashes()
        self.binding = json.loads(args.build_record.read_text())
        source_path = Path(self.binding['source_manifest'])
        self.source_sha = sha(source_path)
        require(json.loads(source_path.read_text()) == self.source_before, 'current compilation source graph differs')
        require(self.binding.get('result') == 'PASS' and self.binding.get('exit_code') == 0,
                'successful imported frozen build binding required')
        require(Path(self.binding['project']).resolve() == args.project.resolve(), 'project binding differs')
        self.tree = shared.tree_manifest(args.project)
        require(self.tree == self.binding['frozen_project_files'], 'frozen project differs')
        if args.framework == 'kit' and args.case == 'recovery':
            driver = args.project / 'lifecycle_ui.gd'
            require(driver.is_file() and sha(driver) == sha(Path(__file__).with_name('ui_driver.gd')),
                    'Kit recovery needs test-only copied-project UI autoload, ordinary import and derived binding first')
            require('LifecycleUI=' in (args.project / 'project.godot').read_text(), 'actual UI autoload setting absent')
        self.wake = threading.Event()
        self.endpoints = []
        self.impairment = dict(zip(('B3_LATENCY', 'B3_JITTER', 'B3_LOSS', 'B3_DUPLICATE', 'B3_REORDER'),
                                   map(str, (args.latency, args.jitter, args.loss, 0, 0))))
        followers = ('client', 'observer') if args.case == 'observer' else ('client',)
        self.store = RollingStore(RollingConfig(self.out / 'rolling', 'host', followers,
            {role:(self.source_sha,) for role in ('host',) + followers}, args.store_mib * 1024**2,
            frame_policy='all_follower_exports_required', decision_coverage='after_admission_baseline'))
        self.archive = shared.EventArchive(self.out / 'observations.sqlite', args.event_mib * 1024**2)
        self.report = dict(result='INCOMPLETE', scope='explicit lifecycle case, NOT primary LONG/GateB',
                           case=args.case, plan={k:str(v) if isinstance(v, Path) else v for k,v in vars(args).items()},
                           driver_files_before=self.drivers_before,
                           build_record_sha256=sha(args.build_record), steps={'build':'REUSED', 'import':'REUSED'},
                           interventions=[], old_primary_checker_unmodified=True, semantic_envelope_projection=
                           'Only session_generation -> existing process_generation for compared decisions/effects; raw archive unchanged')
        if args.case == 'fact_recovery':
            self.report['scope'] = ('NEW Replay same-scope signed-fact catchup after actual process blackout; '
                                    'NOT canonical Reset recovery, a replacement/retro-pass of recovery, '
                                    'primary LONG or GateB')
            self.report['fact_recovery_contract'] = dict(
                seed=42, blackout_ms=300, end_tick=1200, future_ticks=240,
                intervention='existing actual owned Client SIGSTOP/SIGCONT',
                scope_evidence='actual READY + Host MEMBER + published remote class0 generation/serial',
                required='observed resume Host head minus stopped Client head>8; unchanged scope; '
                         'no RECOVERY/resync_notice; final confirmed full5/ACK; all Client issue/FX joins; '
                         'both-role future240 controls; unchanged raw rolling PASS, cleanup/intake/fences',
                recovery_or_comparison_gap_exemptions=False)
        self.recovery_binding = None
        self.recovery_policy = None
        if getattr(args, 'recovery_plan', None):
            import recovery_policy
            self.recovery_policy = recovery_policy
            self.recovery_binding = recovery_policy.make_binding(
                args.recovery_plan, args.recovery_plan_sha256, run_id=self.out.name,
                source_sha256=self.source_sha, build_sha256=sha(args.build_record),
                plan=self.report['plan'])
            self.report[recovery_policy.REPORT_KEY] = self.recovery_binding
            self.report['scoped_classification'] = dict(
                path=str(self.out / 'intentional-reset-classification.json'),
                required_result='INTENTIONAL_RESET_LIFECYCLE_COVERAGE_PASS',
                scope='declared intentional Reset lifecycle ONLY, not primary LONG or GateB',
                status='PENDING_CLOSED_ARTIFACT_AUDIT')
            require(self.archive.count == 0, 'recovery policy marker must be first')
            self.archive.append('controller', recovery_policy.EVENT, self.recovery_binding)
        else:
            self.report['plan'].pop('recovery_plan', None)
            self.report['plan'].pop('recovery_plan_sha256', None)
        self.paused = None
        self.resume_at = None
        self.intervention_done = False
        self.replacement = self.observer = None
        self.publish()

    def publish(self):
        (self.out / 'report.json').write_bytes(json_bytes(self.report) + b'\n')

    def spawn(self, role, generation=1, prior=None):
        suffix = '' if generation == 1 else f'-g{generation}'
        name = role + suffix
        project = self.out / (name + '-project')
        shutil.copytree(self.args.project, project, ignore=shutil.ignore_patterns('*.r*.p*.dylib', '*.r*.p*.so', '__pycache__'))
        require(shared.tree_manifest(project) == self.tree, 'frozen role copy differs')
        env = {k:v for k,v in os.environ.items() if not k.startswith('B3_')}
        token = {'host':101, 'client':202, 'observer':303}[role]
        extension = '.dylib' if sys.platform == 'darwin' else '.so'
        env.update(ROOT=str(ROOT), ODIN_GODOT_ROOT=str(ROOT),
            ODIN_SCRIPTS_DLL=str(project / 'bin' / ('libodinscripts' + extension)),
            B3_FRAMEWORK=self.args.framework, B3_ROLE=role, B3_ACTOR=role, B3_TOKEN=str(token),
            B3_PORT=str(self.port), B3_ADDRESS='127.0.0.1', B3_SCRIPTED='1', B3_BODIES='32',
            B3_SEED=str(self.args.seed), B3_TICKS=str(self.args.ticks), B3_END_TICK=str(self.args.end_tick),
            B3_EXPECT_OBSERVERS='0', B3_GENERATION=str(generation), B3_OUTPUT=str(self.out / name),
            B3_DEBUG_TIMEOUT_FRAMES=str(self.args.end_tick * 4), **self.impairment)
        if self.args.framework == 'kit':
            env['B3_SERVICE_FPS'] = '120'
            if self.args.case == 'recovery' and role == 'client':
                env['B3_LIFECYCLE_UI_FILE'] = str(self.out / 'public-ui-command.json')
        if role == 'client' and self.args.case == 'reconnect' and generation == 1:
            env['B3_EXIT_AT'] = str(self.args.exit_at)
        if prior is not None:
            ready = prior.evidence.ready
            env.update(B3_EXPECT_EPOCH=str(ready['epoch']), B3_EXPECT_SEAT=str(ready['seat']))
            if self.args.framework == 'kit':
                env.update(B3_SOURCE_GEN=str(prior.generation), B3_EXPECT_PLAYER=str(ready['me']),
                           B3_EXPECT_PLAYER1=str(ready['players'][0]), B3_EXPECT_PLAYER2=str(ready['players'][1]))
            else:
                env['B3_EXPECT_TOKEN'] = str(token)
        identity = dict(role=role, generation=generation, source_manifest_sha256=self.source_sha,
                        build_record_sha256=sha(self.args.build_record))
        if self.recovery_binding is not None:
            identity['compiled_build_sha256'] = sha(self.args.build_record)
        actor = Actor(role=role, godot=self.args.godot, project=project, environment=env,
            output=self.out / name, bounds=StreamBounds(log_bytes=self.args.log_mib * 1024**2,
            index_bytes=self.args.log_mib * 1024**2), wake=self.wake,
            identity=identity)
        endpoint = Endpoint(self, actor, generation)
        self.endpoints.append(endpoint)
        self.archive.append('controller', 'ACTOR_STARTED', dict(role=role, generation=generation, pid=actor.process.pid))
        return endpoint

    def intervention(self, host, client):
        now = time.monotonic()  # Controller supervision only, never simulation time.
        if self.paused is not None and now >= self.resume_at:
            if self.args.framework == 'kit':
                (self.out / 'public-ui-command.json').write_bytes(json_bytes(dict(id=1, action='reset')) + b'\n')
            os.kill(self.paused.actor.process.pid, signal.SIGCONT)
            self.report['interventions'].append(dict(action='SIGCONT', pid=self.paused.actor.process.pid,
                observed_host_head=host.last_head, controller_at=now,
                elapsed_controller_seconds=now-self.report['interventions'][-1]['controller_at']))
            self.paused = None
        if not host.evidence.go_seen or not client.evidence.go_seen:
            return
        if self.args.case in ('recovery', 'fact_recovery') and not self.intervention_done and client.last_confirmed >= self.args.trigger_tick:
            os.kill(client.actor.process.pid, signal.SIGSTOP)
            self.paused, self.resume_at = client, now + self.args.blackout_ms / 1000
            self.report['interventions'].append(dict(action='SIGSTOP', pid=client.actor.process.pid,
                observed_client_head=client.last_head, observed_client_confirmed=client.last_confirmed,
                observed_host_head=host.last_head, controller_at=now, requested_ms=self.args.blackout_ms))
            self.intervention_done = True
        if self.args.case == 'observer' and self.observer is None and host.last_head >= self.args.trigger_tick:
            self.observer = self.spawn('observer')
            self.report['interventions'].append(dict(action='late_observer_launch', actual_host_head=host.last_head))
        if self.args.case == 'reconnect' and self.replacement is None and client.finished:
            old = client.evidence.ready
            left = ([x for x in host.markers('PLAYER_LEFT') if x.get('player') == old['me'] and x.get('epoch') == old['epoch']]
                    if self.args.framework == 'kit' else
                    [x for x in host.markers('MEMBER') if x.get('stage') == 'disconnected'
                     and x.get('seat') == old['seat'] and x.get('token_hex') == old['token_hex']])
            if left:
                self.replacement = self.spawn('client', 2, prior=client)
                self.report['interventions'].append(dict(action='fresh_same_token_client', old_pid=client.actor.process.pid,
                                                        new_pid=self.replacement.actor.process.pid))

    def finish_endpoint(self, ep, abort):
        facts = ep.actor.finish(abort=abort)
        error = shared.drain_actor(ep.actor, ep.receive)
        facts['intake'] = ep.actor.intake_facts()
        facts['pending_events'] = ep.actor.pending_event_count
        facts['reader_eof'] = ep.actor.reader_eof
        ep.actor.close()
        facts['intake'] = ep.actor.intake_facts()
        ep.finished = True
        self.report.setdefault('exits', {})[str(ep.actor.process.pid)] = facts
        if error:
            raise error
        require(not abort and facts['exit_code'] == 0 and facts['natural'], 'forced/nonzero exit is not cleanup proof')
        require(facts['pending_events'] == 0 and facts['reader_eof'] and ep.actor.error is None, 'intake incomplete')
        checked = ep.evidence.teardown(facts['exit_code'], interim=(self.args.case == 'reconnect' and ep.generation == 1 and ep.actor.role == 'client'))
        if ep.scope:
            self.store.register_exit(ep.actor.role, ep.scope, exit_code=facts['exit_code'],
                last_epoch=ep.evidence.ready['epoch'], last_confirmed=ep.last_confirmed,
                cleanup=dict(ok=True, native_live_bytes=checked['engine'], snapshot_live_bytes=checked['wrapper'],
                             host_application_live_bytes=checked['meter'], all_explicit_drops_ok=True,
                             core_shutdown_clean=ep.actor.error is None))

    def validate(self, host, original):
        clients = [x for x in self.endpoints if x.actor.role != 'host']
        scoped = [(ep, pair_interval_views(host.evidence, ep.evidence)) for ep in clients]
        self.report['compared_intervals'] = [dict(role=ep.actor.role, generation=ep.generation,
                                                 pid=ep.actor.process.pid, **views[3]) for ep, views in scoped]
        self.report['comparison_gaps'] = []
        ordered = sorted((x for x in self.report['compared_intervals'] if x['role'] == 'client'),
                         key=lambda x:(x['epoch'], x['actual_Welcome_baseline']))
        for previous, current in zip(ordered, ordered[1:]):
            if previous['epoch'] == current['epoch'] and previous['last_common_confirmed'] < current['actual_Welcome_baseline']:
                self.report['comparison_gaps'].append(dict(epoch=current['epoch'],
                    after_last_common_confirmed=previous['last_common_confirmed'],
                    through_next_actual_Welcome_baseline=current['actual_Welcome_baseline'],
                    scope='not compared by pair views; raw endpoints/archive and mandatory rolling verdict unchanged'))
        gates = []
        for ep, (host_view, client_view, compared, interval) in scoped:
            gates.append(dict(role=ep.actor.role, generation=ep.generation,
                              result=verify_pair(host_view, client_view, self.args.ticks, compared)))
        self.report['existing_pair_gates'] = gates
        require(any(x.get('stage') == 'final_received' and x.get('from_role') == 'client'
                    and x.get('matched') is True and x.get('tick') == self.args.end_tick for x in host.markers('TAIL')),
                'actual authority final client ACK absent')
        if self.args.case == 'recovery':
            recovery = original.markers('RECOVERED') or original.markers('RECOVERY')
            require(self.intervention_done and recovery, 'actual blackout/reset recovery not observed')
            stopped = next(x for x in self.report['interventions'] if x['action'] == 'SIGSTOP')
            resumed = next(x for x in self.report['interventions'] if x['action'] == 'SIGCONT')
            require(resumed['observed_host_head'] - stopped['observed_client_head'] > 8,
                    'actual observed blackout did not exceed the ordinary window')
            baseline = int(recovery[-1].get('baseline', recovery[-1].get('new_baseline', 0)))
            require(self.args.end_tick-baseline >= self.args.future_ticks, 'insufficient complete future suffix')
            epoch = original.evidence.ready['epoch']
            suffix = {(epoch, tick, seat) for tick in range(self.args.end_tick-self.args.future_ticks+1, self.args.end_tick+1)
                      for seat in (1, 2)}
            for ep in (host, original):
                actual = {(int(x['epoch']), int(x['tick']), int(x['seat'])) for x in ep.evidence.accepted
                          if x.get('class', 0) == 0}
                require(suffix <= actual, 'complete actual future control suffix unavailable')
            self.report['actual_recovery'] = recovery
        elif self.args.case == 'fact_recovery':
            require(self.args.framework == 'replay' and len(clients) == 1,
                    'fact recovery is one original Replay Client, not replacement/observer admission')
            stopped = [x for x in self.report['interventions'] if x['action'] == 'SIGSTOP']
            resumed = [x for x in self.report['interventions'] if x['action'] == 'SIGCONT']
            require(self.intervention_done and len(stopped) == len(resumed) == 1,
                    'one actual completed process blackout required')
            stopped, resumed = stopped[0], resumed[0]
            require(stopped['pid'] == resumed['pid'] == original.actor.process.pid,
                    'fact recovery must retain the actual original process')
            gap = resumed['observed_host_head'] - stopped['observed_client_head']
            require(gap > 8, 'actual observed blackout did not exceed the ordinary window')
            ready_rows = [json.loads(body) for body, in self.archive.db.execute(
                "SELECT body FROM events WHERE role='client' AND kind='READY' ORDER BY id")]
            require(len(ready_rows) == 1, 'same-scope fact recovery needs exactly one actual Client READY')
            ready = ready_rows[0]
            epoch, generation, serial = ready['epoch'], ready['generation'], ready['serial']
            require(all(type(x) is int and x > 0 for x in (epoch, generation, serial)),
                    'actual Replay scope unavailable')
            notices = []
            for event_id, role, kind, body in self.archive.db.execute(
                    "SELECT id,role,kind,body FROM events WHERE kind IN ('RECOVERY','RECOVERED','STATUS') ORDER BY id"):
                row = json.loads(body)
                if kind != 'STATUS' or row.get('where') == 'resync_notice':
                    notices.append(dict(event_id=event_id, role=role, kind=kind, row=row))
            self.report['fact_recovery_notices'] = notices
            require(not notices, 'same-scope signed-fact recovery must not use canonical recovery/resync_notice')
            members = [x for x in host.markers('MEMBER') if x.get('stage') == 'running'
                       and x.get('seat') == ready['seat'] and x.get('token_hex') == ready['token_hex']]
            require(members and all((x.get('epoch'), x.get('generation'), x.get('serial')) ==
                                   (epoch, generation, serial) for x in members),
                    'actual Host membership scope changed/unavailable')
            require(not self.report['comparison_gaps'], 'fact recovery has no comparison-gap exemption')
            require((epoch, self.args.end_tick) in scoped[0][1][2],
                    'actual final common confirmed full5 unavailable')
            suffix = {(epoch, tick, seat) for tick in range(self.args.end_tick-self.args.future_ticks+1,
                                                          self.args.end_tick+1) for seat in (1, 2)}
            coverage = []
            for ep in (host, original):
                actual = {(int(x['epoch']), int(x['tick']), int(x['seat'])) for x in ep.evidence.accepted
                          if x.get('class', 0) == 0}
                require(suffix <= actual, 'complete actual future240 class0 controls unavailable')
                remote = [x for x in ep.evidence.accepted if x.get('class', 0) == 0
                          and int(x['seat']) == ready['seat']
                          and (int(x['epoch']) != epoch or int(x['tick']) > ready['baseline'])]
                require(remote and all(type(x.get('generation')) is int and type(x.get('serial')) is int
                                       and (x.get('epoch'), x['generation'], x['serial']) ==
                                           (epoch, generation, serial) for x in remote),
                        'actual remote control scope changed/unavailable')
                coverage.append(dict(role=ep.actor.role, actual_future_keys=len(suffix & actual),
                                     required_future_keys=len(suffix), scope_checked_remote_rows=len(remote)))
            self.report['actual_fact_recovery'] = dict(
                stopped=stopped, resumed=resumed, observed_head_gap=gap,
                original_pid=original.actor.process.pid, actual_READY=ready,
                actual_Host_membership=members, future_controls=coverage,
                final_common_confirmed_tick=self.args.end_tick,
                proof_scope='observed public heads and published driver scope; no private Client counter invented',
                issue_FX_full5_gate='unchanged verify_pair; Client lifetime issues/outcomes unfiltered',
                raw_rolling='required unchanged PASS below; no gap exemption')
        elif self.args.case == 'reconnect':
            require(self.replacement is not None and original.evidence.session_exit is not None, 'fresh replacement/old cleanup absent')
            a, b = original.evidence.ready, self.replacement.evidence.ready
            require(a['epoch'] == b['epoch'] and a['seat'] == b['seat'], 'replacement identity changed')
            require(a.get('token_hex', a.get('token')) == b.get('token_hex', b.get('token')), 'replacement token changed')
            if self.args.framework == 'kit':
                require(a['me'] == b['me'] and a['players'] == b['players'], 'replacement logical player/roster changed')
                admitted = [x for x in host.markers('REJOIN_ACCEPTED') if x.get('player') == a['me']
                            and x.get('matched') is True and x.get('old_peer') != x.get('peer')
                            and x.get('inherited_ack') is False]
            else:
                require(b['generation'] > a['generation'], 'replacement membership scope did not advance')
                admitted = [x for x in host.markers('MEMBER') if x.get('stage') == 'running'
                            and x.get('seat') == b['seat'] and x.get('token_hex') == b['token_hex']
                            and x.get('generation') == b['generation']]
            require(admitted, 'actual authority new peer/scope admission absent')
            self.report['actual_rejoin'] = admitted
        else:
            require(self.observer is not None, 'late observer never launched')
            require(any(x.get('from_role') == 'observer' and x.get('matched') is True for x in host.markers('TAIL')),
                    'admitted late observer missing actual authority final ACK/cohort retention')
        raw = self.store.finalize()
        self.report['rolling'] = raw
        if self.recovery_binding is None:
            require(raw.get('result') == 'PASS', ('unchanged rolling evidence failed', raw.get('findings')))

    def classify_recovery(self, otherwise_clean):
        """New bound run only; audit never edits the saved report or raw ledger."""
        try:
            require(all(ep.finished for ep in self.endpoints), 'actors/intake close unavailable')
            require(not self.report.get('ledger_close_findings'), 'ledger close unavailable')
            classification = self.recovery_policy.audit(
                self.args.recovery_plan, self.args.recovery_plan_sha256, self.out / 'report.json')
        except Exception as error:
            classification = dict(result='FAIL', failures=[repr(error)], unavailable=[])
        classification['runner_otherwise_clean'] = otherwise_clean
        classification['scope'] = 'declared intentional Reset lifecycle ONLY; not whole GateB'
        with (self.out / 'intentional-reset-classification.json').open('x') as output:
            json.dump(classification, output, indent=2)
            output.write('\n')
        return (otherwise_clean
                and classification.get('result') == 'INTENTIONAL_RESET_LIFECYCLE_COVERAGE_PASS'
                and not classification.get('failures') and not classification.get('unavailable'))

    def execute(self):
        failure = None
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
                sock.bind(('127.0.0.1', 0)); self.port = sock.getsockname()[1]
            host, client = self.spawn('host'), self.spawn('client')
            deadline = time.monotonic() + self.args.timeout
            while True:
                self.wake.clear()
                for ep in list(self.endpoints):
                    if ep.finished:
                        continue
                    ep.actor.consume(ep.receive, max_records=64)
                    if ep.actor.process.poll() is not None and ep.actor.reader_eof and ep.actor.pending_event_count == 0:
                        self.finish_endpoint(ep, False)
                self.intervention(host, client)
                if all(x.finished for x in self.endpoints):
                    break
                require(time.monotonic() < deadline, 'lifecycle timeout')
                self.wake.wait(0.01)
            self.validate(host, client)
            self.report['result'] = ('INTENTIONAL_RESET_LIFECYCLE_CLASSIFICATION_PENDING'
                                     if self.recovery_binding is not None else 'PASS')
        except Exception as error:
            failure = repr(error)
            self.report['result'], self.report['error'] = 'FAIL', failure
        finally:
            if self.paused is not None:
                try:
                    os.kill(self.paused.actor.process.pid, signal.SIGCONT)
                except ProcessLookupError:
                    pass
                self.paused = None
            for ep in self.endpoints:
                if not ep.finished:
                    try:
                        self.finish_endpoint(ep, True)
                    except Exception as error:
                        self.report.setdefault('cleanup_findings', []).append(repr(error))
            if self.recovery_binding is not None:
                for name, close in (('rolling', self.store.close), ('archive', self.archive.db.close)):
                    try:
                        close()
                    except Exception as error:
                        self.report['result'] = 'FAIL'
                        self.report.setdefault('ledger_close_findings', []).append(dict(ledger=name, error=repr(error)))
            self.report['source_fence_unchanged'] = shared.source_manifest(self.args.framework) == self.source_before
            self.report['project_fence_unchanged'] = shared.tree_manifest(self.args.project) == self.tree
            self.report['driver_fence_unchanged'] = driver_hashes() == self.drivers_before
            if not (self.report['source_fence_unchanged'] and self.report['project_fence_unchanged']
                    and self.report['driver_fence_unchanged']):
                self.report['result'] = 'FAIL'
                self.report.setdefault('fence_findings', []).append('source/project/driver changed')
            self.publish()
            if self.recovery_binding is None:
                self.store.close()
                self.archive.db.close()
        if self.recovery_binding is not None:
            otherwise_clean = (failure is None
                and self.report['result'] == 'INTENTIONAL_RESET_LIFECYCLE_CLASSIFICATION_PENDING'
                and not any(self.report.get(k) for k in ('error', 'cleanup_findings', 'fence_findings', 'ledger_close_findings')))
            return 0 if self.classify_recovery(otherwise_clean) else 1
        return 0 if self.report['result'] == 'PASS' else 1


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--case', choices=('recovery', 'reconnect', 'observer', 'fact_recovery'), required=True)
    p.add_argument('--framework', choices=('kit', 'replay'), required=True)
    p.add_argument('--project', type=Path, required=True)
    p.add_argument('--build-record', type=Path, required=True)
    p.add_argument('--out', type=Path, required=True)
    p.add_argument('--godot', default='/Applications/Godot.app/Contents/MacOS/Godot')
    p.add_argument('--seed', type=int, default=42)
    p.add_argument('--ticks', type=int, default=240)
    p.add_argument('--end-tick', type=int, default=1200)
    p.add_argument('--trigger-tick', type=int, default=240)
    p.add_argument('--exit-at', type=int, default=400)
    p.add_argument('--future-ticks', type=int, default=240)
    p.add_argument('--blackout-ms', type=int, default=200)
    p.add_argument('--latency', type=int, default=10)
    p.add_argument('--jitter', type=int, default=1)
    p.add_argument('--loss', type=int, default=0)
    p.add_argument('--timeout', type=float, default=90)
    p.add_argument('--store-mib', type=int, default=1536)
    p.add_argument('--event-mib', type=int, default=256)
    p.add_argument('--log-mib', type=int, default=128)
    p.add_argument('--recovery-plan', type=Path)
    p.add_argument('--recovery-plan-sha256')
    p.add_argument('--execute', action='store_true')
    a = p.parse_args()
    require(bool(a.recovery_plan) == bool(a.recovery_plan_sha256), 'recovery plan and SHA256 must be supplied together')
    require(not a.recovery_plan or (a.framework == 'kit' and a.case == 'recovery'),
            'intentional Reset policy is restricted to explicit Kit recovery')
    if a.case == 'fact_recovery':
        require(a.framework == 'replay', 'fact_recovery is Replay ONLY')
        require((a.seed, a.blackout_ms, a.end_tick, a.future_ticks) == (42, 300, 1200, 240),
                'fact_recovery requires explicit seed42/blackout300/end1200/future240')
    require(0 < a.seed < 2**31 and 240 <= a.ticks <= a.end_tick <= 65535, 'invalid finite lifecycle plan')
    require(8 < a.trigger_tick < a.exit_at < a.end_tick and 134 <= a.blackout_ms <= 1000, 'invalid intervention bounds')
    if not a.execute:
        a.out.mkdir(parents=True, exist_ok=False)
        plan = {k:str(v) if isinstance(v, Path) else v for k,v in vars(a).items()}
        if not a.recovery_plan:
            plan.pop('recovery_plan', None)
            plan.pop('recovery_plan_sha256', None)
        plan.update(status='STAGED_ONLY_NO_PROCESSES', scope='separate lifecycle validation; no LONG/GateB claim',
                    Kit_UI_requires='copied-project ui_driver.gd as lifecycle_ui.gd + LifecycleUI autoload + ordinary import/derived frozen binding',
                    Replay_recovery='real automatic public Resync after owned process blackout; no nonexistent Reset UI invented',
                    observer='actual after-GO join; missing frozen final cohort/ACK must FAIL',
                    known_evidence_limit='unchanged verify_pair/rolling verdict retained, including genuine recovery-gap findings; no automatic exception')
        if a.case == 'fact_recovery':
            plan['scope'] = 'NEW Replay signed-fact blackout recovery ONLY; not canonical Reset recovery or retro-pass'
            plan['Replay_fact_recovery'] = ('same actual SIGSTOP/CONT; observed gap>8; same scope/no RECOVERY or resync_notice; '
                                            'final1200 full5/ACK + both-role future240 controls + unchanged pair/rolling PASS')
        (a.out / 'plan.json').write_bytes(json_bytes(plan) + b'\n')
        return 0
    try:
        return Lifecycle(a).execute()
    except Exception as error:
        a.out.mkdir(parents=True, exist_ok=True)
        if not (a.out / 'report.json').exists():
            (a.out / 'report.json').write_bytes(json_bytes(dict(result='SETUP_FAIL', error=repr(error),
                scope='no lifecycle acceptance; preserve setup failure', execution_not_assumed=True)) + b'\n')
        raise


if __name__ == '__main__':
    raise SystemExit(main())
