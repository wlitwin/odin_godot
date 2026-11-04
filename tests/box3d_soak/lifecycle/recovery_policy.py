"""Prospective intentional-Reset lifecycle proof; never changes raw verdicts.

Before actors launch, Root calls make_binding(), writes the returned object to
report['intentional_reset_policy'], and appends that SAME object as the first
controller INTENTIONAL_RESET_POLICY event. audit() reads only closed artifacts.
The unchanged lifecycle verifier must have completed verify_pair beforehand.
"""
from __future__ import annotations

import copy
import hashlib
import json
import math
from pathlib import Path
import sqlite3
import struct
import sys
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'tests/box3d_slices/harness'))
from evidence import (EvidenceError, action_name, eligible_effects, effects,
                      json_bytes, observed_recovery_gaps, signature)

EVENT = 'INTENTIONAL_RESET_POLICY'
REPORT_KEY = 'intentional_reset_policy'
POLICY_ID = 'intentional_reset_lifecycle_v1'
VALUES = dict(version=1, framework='kit', seed=42, blackout_ms=300, bodies=32,
              target_tick=1200, minimum_future_ticks=240, max_recoveries=8,
              max_gap_ticks=128, max_union_ticks=1024, latest_gap_offset=3600,
              max_observed_request_to_recovery_seconds=5,
              required_actual_head_gap_gt=8, raw_rolling_report_preserved=True)
LIMITS = dict(history=128, prediction=8, ordinary_repair=8, tracked_bytes=67108864)
CAUSES = dict(manual_ui=[0], hold=[4, 6, 7])
MISSING_FINDINGS = {'actual settled FX missing/payload mismatch': 'fx_missing',
                    'actual decision/provenance missing/mismatch': 'decision_missing'}
MAX_EVENTS = 40000


class PolicyError(ValueError): pass
class Unavailable(PolicyError): pass


def need(value, message, error=PolicyError):
    if not value:
        raise error(message)


def integer(value, name, minimum=0):
    need(type(value) is int and minimum <= value < 2**64, name + ': invalid u64')
    return value


def digest(value):
    need(isinstance(value, str) and len(value) == 64 and value != '0' * 64 and
         all(c in '0123456789abcdef' for c in value), 'invalid binding SHA256')
    return value


def sha_file(path):
    value = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1048576), b''):
            value.update(block)
    return value.hexdigest()


def validate_policy(policy):
    need(policy.get('policy_id') == POLICY_ID, 'unknown recovery policy')
    for key, value in VALUES.items():
        need(type(policy.get(key)) is type(value) and policy[key] == value,
             'changed policy value: ' + key)
    need(policy.get('limits') == LIMITS and policy.get('causes') == CAUSES,
         'changed recovery limits/causes')
    need(all(type(v) is int for v in policy['limits'].values()) and
         all(type(v) is int for values in policy['causes'].values() for v in values),
         'incorrectly typed recovery limits/causes')
    return policy


def load_policy(path, expected_sha256):
    digest(expected_sha256)
    need(sha_file(path) == expected_sha256, 'predeclared policy file changed')
    return validate_policy(json.loads(Path(path).read_text()))


def make_binding(policy_path, policy_sha256, *, run_id, source_sha256,
                 build_sha256, plan):
    policy = load_policy(policy_path, policy_sha256)
    need(isinstance(run_id, str) and 0 < len(run_id) <= 128, 'invalid run ID')
    for key, expected in dict(framework='kit', case='recovery', seed=42,
                             blackout_ms=300, end_tick=1200, future_ticks=240).items():
        need(type(plan.get(key)) is type(expected) and plan[key] == expected,
             'execution differs: ' + key)
    need(Path(plan['out']).name == run_id, 'run ID/output differs')
    return dict(event=EVENT, schema=1, policy_id=POLICY_ID, run_id=run_id,
                policy_ref=dict(path=str(Path(policy_path).resolve()), sha256=policy_sha256),
                policy=copy.deepcopy(policy), source_manifest_sha256=digest(source_sha256),
                build_record_sha256=digest(build_sha256), plan=copy.deepcopy(plan))


def _semantic(kind, row):
    result = dict(row)
    if kind in ('INPUT', 'ACCEPTED', 'APPLIED', 'ACTION', 'FX', 'EFFECT') and 'session_generation' in result:
        result['process_generation'] = result.pop('session_generation')
    return result


def _key(value):
    key = json.loads(value)
    need(isinstance(key, list) and len(key) >= 2, 'malformed immutable ledger key')
    integer(key[0], 'key epoch', 1); integer(key[1], 'key tick')
    return key


def _in_gap(epoch, tick, gaps):
    return any(g['epoch'] == epoch and g['start_exclusive'] < tick <= g['end_inclusive'] for g in gaps)


def _endpoint(role, rows):
    endpoint = SimpleNamespace(framework='kit', role=role, ready=None, actions=[],
        issued=[], issue_marks=[], status_marks=[], recovery_marks=[], effects=[],
        effect_marks=[], frames={})
    for event in rows:
        if event['role'] != role:
            continue
        row, kind, order = _semantic(event['kind'], event['row']), event['kind'], event['id']
        if kind == 'READY':
            need(endpoint.ready is None, 'duplicate READY')
            endpoint.ready = row
        elif kind in ('APPLIED', 'ACTION'): endpoint.actions.append(row)
        elif kind in ('ISSUED', 'SUBMITTED'):
            endpoint.issued.append(row); endpoint.issue_marks.append((order, row))
        elif kind in ('FX', 'EFFECT'):
            endpoint.effects.append(row); endpoint.effect_marks.append((order, row))
        elif kind == 'FRAME':
            key = (integer(row['epoch'], 'frame epoch', 1), integer(row['tick'], 'frame tick'))
            need(key not in endpoint.frames, 'duplicate confirmed FRAME')
            # Actual archive records, not synthesized states. Their comparisons
            # are independently linked to sealed five-part receipts below.
            endpoint.frames[key] = row
        endpoint.status_marks.append((order, dict(row, event=kind)))
    need(endpoint.ready is not None, role + ' READY unavailable', Unavailable)
    return endpoint


def evaluate(policy, binding, report, events, store):
    """Pure policy layer over actual archive/ledger rows; synthetic-testable.

    store contains the read-only adapter's decisions/fx/matches/comparisons.
    The original rolling summary is always copied, including its FAIL result.
    """
    result = dict(policy_id=POLICY_ID, result='FAIL', failures=[], unavailable=[],
                  raw_rolling=copy.deepcopy(report.get('rolling')),
                  no_original_report_or_raw_result_changed=True)
    try:
        _evaluate(validate_policy(policy), binding, report, events, store, result)
        result['result'] = 'INTENTIONAL_RESET_LIFECYCLE_COVERAGE_PASS'
    except Unavailable as error:
        result['result'] = 'INCOMPLETE'; result['unavailable'].append(str(error))
    except (PolicyError, EvidenceError, KeyError, TypeError, ValueError) as error:
        result['failures'].append(str(error))
    return result


def _evaluate(policy, binding, report, events, store, result):
    need(binding is not None and report.get(REPORT_KEY) == binding,
         'actual prelaunch policy binding unavailable', Unavailable)
    need(binding.get('schema') == 1 and type(binding['schema']) is int and
         binding.get('policy_id') == POLICY_ID and binding.get('policy') == policy,
         'policy binding differs')
    need(events and events[0]['role'] == 'controller' and events[0]['kind'] == EVENT and
         events[0]['row'] == binding, 'policy marker must precede every actor record', Unavailable)
    need(report['plan'] == binding['plan'] and Path(report['plan']['out']).name == binding['run_id'],
         'actual execution differs from prelaunch binding')
    for key, value in dict(framework='kit', case='recovery', seed=42, blackout_ms=300,
                           end_tick=1200, future_ticks=240).items():
        need(type(report['plan'].get(key)) is type(value) and report['plan'][key] == value,
             'bound execution violates policy: ' + key)
    digest(binding['source_manifest_sha256']); digest(binding['build_record_sha256'])
    need(report['build_record_sha256'] == binding['build_record_sha256'], 'compiled build binding differs')
    need(all(report.get(key) is True for key in ('source_fence_unchanged',
         'driver_fence_unchanged', 'project_fence_unchanged')), 'source/driver/project fence failed')
    need(len(events) <= MAX_EVENTS, 'bounded lifecycle event count exceeded')
    host, client = _endpoint('host', events), _endpoint('client', events)
    epoch, baseline = integer(client.ready['epoch'], 'epoch', 1), integer(client.ready.get('baseline', 0), 'baseline')
    target = policy['target_tick']
    need(host.ready['epoch'] == epoch, 'endpoint epochs differ')
    need(len(report['exits']) == 2, 'intentional Reset requires one Host and one Client process')
    for endpoint in (host, client):
        need(endpoint.ready.get('world_wire_revision') == 2 and
             type(endpoint.ready['world_wire_revision']) is int, 'actual wire2 READY unavailable')
    for exit_record in report['exits'].values():
        intake = exit_record['intake']
        need(exit_record['natural'] is True and exit_record['exit_code'] == 0 and
             exit_record.get('reader_error') is None, 'nonzero/forced/reader exit')
        need(intake['records_seen'] == intake['records_published'] == intake['records_consumed'] and
             intake['pending_events'] == 0 and intake['reader_eof'] is True and
             intake['consumer_closed'] is True and intake['writer_closed'] is True and
             intake['final_flush_fsync_ok'] is True and intake['integrity_error'] is None,
             'intake incomplete')
        identity = intake['identity']['identity']
        need(identity['source_manifest_sha256'] == binding['source_manifest_sha256'] and
             identity['compiled_build_sha256'] == binding['build_record_sha256'], 'actual intake identity differs')
    for endpoint in (host, client):
        terminal = [e['row'] for e in events if e['role'] == endpoint.role and e['kind'] == 'RESULT']
        need(len(terminal) == 1 and terminal[0].get('ok') is True and terminal[0]['tick'] == target,
             'final application result absent/failed')
        need(all(type(terminal[0].get(k)) is int and terminal[0][k] == 0 for k in
                 ('errors', 'cleanup_errors', 'engine_live', 'wrapper_live', 'meter_live')), 'cleanup not zero')
    need(not any(e['kind'] in ('ERROR', 'INTENT_UNEXERCISED') for e in events), 'actual application/intent error')
    for role in ('host', 'client'):
        seen = set()
        for event in events:
            if event['role'] != role or event['kind'] not in ('INPUT', 'APPLIED', 'ACTION'): continue
            row = event['row']
            key = ((row['epoch'], row['tick'], row['seat'], row['class']) if event['kind'] == 'INPUT'
                   else (row['epoch'], row['seat'], row['sequence'], 'action'))
            need(key not in seen, 'duplicate raw decision identity'); seen.add(key)
    gates = report.get('existing_pair_gates', [])
    need(len(gates) == 1 and gates[0]['role'] == 'client' and gates[0]['generation'] == 1,
         'unchanged strict pair result unavailable', Unavailable)
    pair = gates[0]['result']
    need(pair['confirmed_end'] == target and pair['action_timing'] == 'Scheduled' and
         set(pair['actual_verdicts']) == {'Spawn','Remove','Motor','Sleep','Wake','Query'} and
         pair['compared_confirmed_frames'] > 0, 'strict pair incomplete')
    # The unchanged verifier's complete catalog/identity proof must account for
    # every actual lifetime issue, including those in a recovery interval.
    actual_joins = {(x['role'], json_bytes(x['issued'])): x['published'] for x in pair['intent_causality']}
    need(len(actual_joins) == len(pair['intent_causality']), 'duplicate pair issue proof')
    for endpoint in (host, client):
        seen = set()
        for issue in endpoint.issued:
            key = (issue['epoch'], issue['seat'], issue['sequence'])
            need(key not in seen, 'duplicate lifetime ISSUED identity'); seen.add(key)
            counterpart = [x for x in host.actions if (x['epoch'], x['seat'], x['sequence']) == key and
                           action_name(x['kind']) == action_name(issue['kind'])]
            need(len(counterpart) == 1 and (endpoint.role, json_bytes(issue)) in actual_joins,
                 'ISSUED lacks unique strict-pair authority join')
            need(counterpart[0]['tick'] == issue['submitted_tick'] and
                 actual_joins[(endpoint.role, json_bytes(issue))] == counterpart[0], 'issued publication changed')
    need(len(actual_joins) == len(host.issued) + len(client.issued), 'pair proof omitted/added issued identity')
    raw_gaps = observed_recovery_gaps(client, epoch)
    requests = [e for e in events if e['role'] == 'client' and e['kind'] == 'RECOVERY_REQUESTED']
    recoveries = [e for e in events if e['role'] == 'client' and e['kind'] == 'RECOVERED']
    need(0 < len(raw_gaps) == len(requests) == len(recoveries) <= policy['max_recoveries'], 'recovery count bound')
    need(all(any(e['role']==role and e['kind']=='GO' and e['id']<requests[0]['id'] for e in events)
             for role in ('host','client')), 'Reset before actual both-role GO')
    gaps, union, prior_scope = [], [], None
    for gap, req, rec in zip(raw_gaps, requests, recoveries):
        q, z = req['row'], rec['row']
        need(q.get('request_source') in policy['causes'] and type(q.get('reason')) is int and
             q['reason'] in policy['causes'][q['request_source']], 'unapproved actual recovery cause')
        need(z['epoch'] == epoch and req['id'] < rec['id'] and z['request_sequence'] > 0 and
             z['received_sequence'] > z['request_sequence'] and
             (prior_scope is None or z['request_sequence'] == prior_scope), 'recovery epoch/watermark differs')
        prior_scope = z['received_sequence']
        need('signature_hex' in z, 'validated Reset signature unavailable', Unavailable)
        sig = bytes.fromhex(z['signature_hex']); signature(sig, epoch, z['baseline'])
        lo, hi = gap['start_exclusive'], gap['end_inclusive']
        need(0 < hi-lo <= policy['max_gap_ticks'] and hi <= baseline + policy['latest_gap_offset'], 'recovery tick budget')
        times = [req.get('observed_at'), rec.get('observed_at')]
        need(all(type(x) in (int,float) and math.isfinite(x) and x >= 0 for x in times),
             'actual recovery observation timestamps unavailable', Unavailable)
        need(0 <= times[1]-times[0] <= policy['max_observed_request_to_recovery_seconds'], 'observed recovery interval')
        if union and lo <= union[-1][1]: union[-1][1] = max(hi, union[-1][1])
        else: union.append([lo, hi])
        gaps.append(dict(epoch=epoch, start_exclusive=lo, end_inclusive=hi,
                         request_event_id=req['id'], recovered_event_id=rec['id'],
                         observed_seconds=times[1]-times[0], received_sequence=prior_scope))
    need(sum(hi-lo for lo,hi in union) <= policy['max_union_ticks'], 'recovery union budget')
    stops = [x for x in report['interventions'] if x['action'] == 'SIGSTOP']
    resumes = [x for x in report['interventions'] if x['action'] == 'SIGCONT']
    need(len(stops) == len(resumes) == 1 and stops[0]['pid'] == resumes[0]['pid'] and
         stops[0]['requested_ms'] == policy['blackout_ms'] and
         resumes[0]['observed_host_head'] - requests[0]['row']['head'] > policy['required_actual_head_gap_gt'],
         'actual controlled blackout/head gap not exercised')
    for endpoint in (host, client):
        for item in endpoint.effects: integer(item['tick'], 'FX tick')
    effect_proof = eligible_effects(host, client, epoch, baseline, target)
    dec, fx = {}, {}
    for role in ('host','client'):
        dec[role], fx[role] = {}, {}
        for item in store['decisions']:
            if item['role'] == role:
                key = _key(item['id']); need(item['id'] not in dec[role], 'duplicate stored decision')
                if key[0] == epoch and baseline < key[1] <= target: dec[role][item['id']] = item['body']
        for item in store['fx']:
            if item['role'] == role and item['state'] == 'settled':
                key = _key(item['id']); need(item['id'] not in fx[role], 'duplicate settled FX')
                if key[0] == epoch and baseline < key[1] <= target: fx[role][item['id']] = item['payload']
        # A formerly observed settlement cannot disappear from the ledger.
        actual_effects = effects(host if role == 'host' else client, epoch, baseline, target)
        need(set(k.decode() for k in actual_effects) == set(fx[role]), 'already settled FX ID lost/added')
        need(all(fx[role][key.decode()] == json_bytes(value['payload'])
                 for key,value in actual_effects.items()), 'settled FX payload differs from raw observation')
    need(not (dec['client'].keys()-dec['host'].keys()) and not (fx['client'].keys()-fx['host'].keys()), 'extra decision/FX')
    need(all(dec['host'][k] == dec['client'][k] for k in dec['host'].keys() & dec['client'].keys()) and
         all(fx['host'][k] == fx['client'][k] for k in fx['host'].keys() & fx['client'].keys()), 'changed decision/FX')
    missing_dec = sorted(dec['host'].keys()-dec['client'].keys())
    missing_fx = sorted(fx['host'].keys()-fx['client'].keys())
    need(all(_in_gap(*_key(k)[:2], gaps) for k in missing_dec+missing_fx), 'missing exact key outside validated intervals')
    raw = report['rolling']
    need(raw['result'] in ('PASS','FAIL'), 'raw rolling result unavailable')
    need(raw['decision_missing'] == len(missing_dec) and raw['fx_missing'] == len(missing_fx), 'raw missing count/key mismatch')
    need(all(raw[k] == 0 for k in ('decision_changed','decision_extra','fx_changed','fx_extra',
         'unmatched_required_frames','final_tail_missing')), 'raw strict non-missing invariant failed')
    expected_findings = {name for name,key in MISSING_FINDINGS.items() if raw[key]}
    need(set(raw['findings']) == expected_findings, 'arbitrary raw finding cannot be excluded')
    allowed_error = repr(EvidenceError(str(('unchanged rolling evidence failed', raw['findings']))))
    need(report.get('error') in (None, allowed_error), 'non-rolling controller error')
    matches = {(integer(x['epoch'],'matched epoch',1), integer(x['tick'],'matched tick')) for x in store['matches'] if x['role']=='client'}
    need(len(matches) == raw['matched_comparisons'] == raw['required_follower_exports'], 'unmatched full5/count mismatch')
    need(matches == set(host.frames) & set(client.frames), 'raw FRAME/sealed comparison mismatch')
    need(all(len(x['parts']) == 5 and x['byte_comparison'] is True for x in store['comparisons']) and
         {(x['epoch'],x['tick']) for x in store['comparisons']} == matches, 'five-part comparison proof missing')
    need(all(key in matches or _in_gap(*key, gaps) for key in host.frames if baseline < key[1] <= target),
         'outside-gap authority frame unmatched')
    last = max(x['end_inclusive'] for x in gaps); future_end = last + policy['minimum_future_ticks']
    need(future_end <= target and (epoch,target) in matches, 'future confirmed tail absent')
    controls = {}
    for role in ('host','client'):
        controls[role] = {}
        for event in events:
            row = event['row']
            if event['role'] != role or event['kind'] != 'INPUT' or not last < row['tick'] <= future_end: continue
            key = (row['epoch'], row['tick'], row['seat'], row['class'])
            need(key not in controls[role] and row['accepted'] is True and type(row['status']) is int and row['status']==0 and
                 type(row['origin']) is int and row['origin'] in (1,2,3) and row['player']==row['seat'], 'malformed/duplicate future control')
            for axis in ('x','z'): need(type(row[axis]) is int and -32768 <= row[axis] <= 32767, 'invalid signed control')
            integer(row['sequence'],'control source sequence')
            controls[role][key] = {k:v for k,v in row.items() if k!='role'}
    want = {(epoch,tick,seat,0) for tick in range(last+1,future_end+1) for seat in (1,2)}
    need(set(controls['host']) == set(controls['client']) == want and controls['host']==controls['client'], 'future240 controls unavailable/differ')
    need(any(last < t <= future_end for e,t in matches if e==epoch) and
         any(last < x['tick'] <= future_end for x in effect_proof['post_recovery_matched_effects']), 'future240 full5/FX absent')
    bootstrap = [e['row'] for e in events if e['role']=='client' and e['kind']=='STATUS' and e['row'].get('stage')=='recovery_bootstrap']
    need(len(bootstrap)==1 and any(e['role']=='client' and e['kind']=='STATUS' and
         e['row']==bootstrap[0] and e['id']>recoveries[-1]['id'] for e in events),
         'owned bootstrap unavailable', Unavailable)
    boot=bootstrap[0]
    need(boot['bootstrap_sequence']==prior_scope and boot['anchor_baseline']==last and boot['owned_once'] is True and
         boot['progress_proven'] is True and boot['receipt']==2 and 0 < boot['returned_steps'] <= 8 and
         boot['before_head']+boot['returned_steps']==boot['after_head'] and
         boot['before_confirmed']==boot['after_confirmed']==boot['matched_signature_tick'] > last and
         boot['accepted_through'] >= boot['matched_signature_tick'], 'actual owned bootstrap proof differs')
    supplied=struct.unpack('<d',int(boot['supplied_bits'],16).to_bytes(8,'little'))[0]
    receipt=struct.unpack('<d',int(boot['receipt_bits'],16).to_bytes(8,'little'))[0]
    need(math.isfinite(supplied) and 0 < supplied <= 8/60 and supplied==receipt, 'bootstrap ownership receipt unavailable')
    need(any(e['role']=='host' and e['kind']=='TAIL' and e['row'].get('from_role')=='client' and
             e['row'].get('matched') is True and e['row'].get('tick')==target for e in events), 'actual final authority ACK absent')
    for role in ('host','client'):
        limits=[e['row'] for e in events if e['role']==role and e['kind']=='LIMITS']
        need(len(limits)==1 and limits[0]['history']==128 and limits[0]['max_prediction']==limits[0]['max_repair']==8 and
             limits[0]['process_limit_bytes']==67108864 and limits[0]['initial_cached_dynamic_bodies']==32, 'actual limits differ')
    result.update(gaps=gaps, union_ticks=sum(hi-lo for lo,hi in union), exact_missing_decisions=missing_dec,
                  exact_missing_FX=missing_fx, strict_pair_issue_joins=len(actual_joins),
                  future=dict(first_exclusive=last,end_inclusive=future_end,controls_each=len(want),
                              matched_full5=sum(e==epoch and last<t<=future_end for e,t in matches)),
                  bootstrap=boot, effect_eligibility_matched=effect_proof['matched'])


def audit(policy_path, policy_sha256, report_path):
    """Read closed SQLite/artifacts only; return a new classification object."""
    policy=load_policy(policy_path, policy_sha256); report_path=Path(report_path).resolve()
    report=json.loads(report_path.read_text()); root=report_path.parent
    def rows(path, query):
        connection=sqlite3.connect(path.as_uri()+'?mode=ro',uri=True)
        try: return connection.execute(query).fetchall()
        finally: connection.close()
    events=[dict(id=i,role=role,kind=kind,observed_at=t,row=json.loads(body)) for i,role,kind,t,body in
            rows(root/'observations.sqlite','SELECT id,role,kind,observed_at,body FROM events ORDER BY id LIMIT 40001')]
    store_path=root/'rolling/store.sqlite'
    store=dict(decisions=[dict(role=role,id=key,body=bytes(body)) for role,key,body in rows(store_path,'SELECT role,id,body FROM decisions')],
        fx=[dict(role=role,id=key,state=state,payload=bytes(body)) for role,key,state,body in rows(store_path,'SELECT role,id,state,payload FROM fx')],
        matches=[dict(role=role,epoch=int(epoch,16),tick=int(tick,16)) for role,epoch,tick in rows(store_path,'SELECT role,epoch,tick FROM matches')],
        comparisons=[json.loads(body) for body, in rows(store_path,"SELECT body FROM receipts WHERE kind='complete_comparison'")])
    binding=report.get(REPORT_KEY)
    if binding is not None:
        need(binding['policy_ref']['sha256']==policy_sha256 and binding['policy']==policy, 'bound policy reference differs')
        build_path=Path(report['plan']['build_record']);build=json.loads(build_path.read_text())
        need(sha_file(build_path)==binding['build_record_sha256'] and build['source_manifest_sha256']==binding['source_manifest_sha256'], 'actual build/source binding differs')
    result=evaluate(policy,binding,report,events,store)
    result['artifacts']=dict(report=str(report_path),report_sha256=sha_file(report_path),
                             policy=str(Path(policy_path).resolve()),policy_sha256=policy_sha256)
    return result
