"""Prospective LONG classifications only. No launcher, clocks or database writes.

Strict rolling/short results are inputs, never modified. A missing prelaunch
binding cannot produce a prospective pass, including for every historical case.
"""
from __future__ import annotations

from dataclasses import dataclass
import bisect
import hashlib
import json
import math
from pathlib import Path
import re
import sqlite3
import struct
import sys
from types import SimpleNamespace
import zlib

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'tests/box3d_slices/harness'))
from evidence import (ACTION_NAMES, action_name, json_bytes, signature,
                      strict_json, verify_kit_intent_catalog)
sys.path.insert(0, str(ROOT / 'tests/box3d_presentation/scene_controls'))
from accept import verify_ready

POLICY_ID = 'long_recovery_cycle_coverage_v1'
PHASES = dict(Spawn=40, Remove=56, Motor=80, Sleep=120, Wake=136, Query=160)
FX_MISSING = 'actual settled FX missing/payload mismatch'
DECISION_MISSING = 'actual decision/provenance missing/mismatch'
FIXED = dict(origin=0, period=240, min_ticks=36000, min_seconds=600,
             min_cycles=120, fraction_numerator=4, fraction_denominator=5,
             consecutive_future_cycles=60, max_recoveries=8,
             max_gap_ticks=128, max_union_ticks=1024, latest_gap_offset=3600,
             max_observation_seconds=5, bodies=32, native_limit_bytes=67108864)
BOUNDS = dict(events=2_000_000, frames=131072, issues=4096, actions=8192,
              selected_bytes=64*1024*1024, event_body=1024*1024,
              missing_rows=65536, cycles=512)
HASH = re.compile(r'[0-9a-f]{64}\Z')
EXECUTION_KEYS = frozenset(('seed','required_ticks','minimum_wall_seconds','timeout_seconds',
    'latency_ms','jitter_ms','loss_percent','duplicate_percent','reorder','lifecycle'))
SEED_SOURCES = ('examples/replay_box3d/shared/adapter/model.odin',
                'examples/box3d_common/rules.odin')


class PolicyError(ValueError):
    pass


class Unavailable(PolicyError):
    pass


class NotContested(PolicyError):
    """Valid recorded commands did not exercise the required contention."""


def need(value, message, error=PolicyError):
    if not value:
        raise error(message)


def integer(value, name, minimum=0):
    need(type(value) is int and value >= minimum, name + ': invalid integer')
    return value


def hash_ok(value):
    return isinstance(value, str) and HASH.fullmatch(value) and value != '0'*64


def _sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for data in iter(lambda: stream.read(1024*1024), b''):
            h.update(data)
    return h.hexdigest()


def make_plan(run_id, framework, target_tick, source_hashes, rolling_budget_bytes,
              event_budget_bytes, log_budget_bytes, epoch=1, *, execution,
              replay_rule_oracle=None):
    plan = dict(policy_id=POLICY_ID, version=1, run_id=run_id, framework=framework,
                epoch=epoch, target_tick=target_tick, source_hashes=dict(source_hashes),
                execution=dict(execution),
                replay_rule_oracle=dict(replay_rule_oracle) if replay_rule_oracle is not None else None,
                phases=dict(PHASES), fixed=dict(FIXED), bounds=dict(BOUNDS),
                disk=dict(rolling_bytes=rolling_budget_bytes,
                          event_bytes=event_budget_bytes, log_bytes_each=log_budget_bytes))
    validate_plan(plan)
    return plan


def validate_plan(plan):
    need(plan.get('policy_id') == POLICY_ID and type(plan.get('version')) is int and plan['version'] == 1, 'unknown LONG policy')
    need(plan.get('framework') in ('kit', 'replay'), 'unknown framework')
    need(isinstance(plan.get('run_id'), str) and 0 < len(plan['run_id']) <= 128, 'run_id missing')
    integer(plan['epoch'], 'epoch', 1)
    need(36000 <= integer(plan['target_tick'], 'target_tick') <= 65535, 'target outside bounded LONG plan')
    need(plan['fixed'] == FIXED and plan['phases'] == PHASES and plan['bounds'] == BOUNDS,
         'unapproved policy/threshold/phase/bound change')
    for name,expected in (('fixed',FIXED),('phases',PHASES),('bounds',BOUNDS)):
        need(all(type(plan[name][k]) is int for k in expected), 'policy integers cannot be booleans/floats')
    need(set(plan['source_hashes']) == {'host', 'client'} and
         all(hash_ok(x) for x in plan['source_hashes'].values()), 'exact role source hashes missing')
    for key in ('rolling_bytes', 'event_bytes', 'log_bytes_each'):
        integer(plan['disk'][key], key, 1)
    need(plan['disk']['rolling_bytes'] >= 64*1024*1024 and
         plan['disk']['event_bytes'] >= 16*1024*1024 and
         plan['disk']['log_bytes_each'] >= 4*1024*1024, 'finite evidence budgets too small')
    execution=plan.get('execution')
    need(isinstance(execution,dict) and set(execution)==EXECUTION_KEYS,'exact execution payload missing/changed')
    need(0<integer(execution['seed'],'seed')<2**31,'seed outside supported CLI range')
    need(FIXED['min_ticks']<=integer(execution['required_ticks'],'required_ticks')<=plan['target_tick'],'required duration tick plan invalid')
    for key in ('minimum_wall_seconds','timeout_seconds'):
        value=execution[key]
        need(type(value) in (int,float) and math.isfinite(value),'execution duration must be finite actual CLI value')
    need(600<=execution['minimum_wall_seconds']<execution['timeout_seconds']<=3600,'frozen duration/timeout invalid')
    for key in ('latency_ms','jitter_ms'):
        need(0<=integer(execution[key],key)<=10000,'impairment bound')
    need(0<=integer(execution['loss_percent'],'loss_percent')<=95,'loss CLI bound')
    need(type(execution['duplicate_percent']) is int and execution['duplicate_percent']==0 and
         type(execution['reorder']) is bool and execution['reorder'] is False and
         execution['lifecycle']=='primary_pair_only_separate_cases_required','unapproved impairment/lifecycle plan')
    oracle=plan.get('replay_rule_oracle')
    if plan['framework']=='replay':
        need(isinstance(oracle,dict) and set(oracle)=={'path','sha256'} and
             isinstance(oracle['path'],str) and oracle['path'] and hash_ok(oracle['sha256']),
             'Replay requires exact immutable public codec oracle reference')
    else:need(oracle is None,'Kit plan must not borrow Replay oracle')
    return plan


def _intent_contract_binding(framework, actual_plan, ready=None):
    expected=actual_plan.get('kit_intent_contract',1)
    need(type(expected) is int and expected in (1,2),'unknown or incorrectly typed prelaunch Kit intent contract')
    need(framework=='kit' or expected==1,'Replay cannot opt into Kit intent contract2')
    if ready is not None:
        observed=ready.get('intent_contract_version',1)
        need(type(observed) is int and observed in (1,2),'unknown or incorrectly typed READY intent contract')
        need(observed==expected,'READY intent contract differs from actual prelaunch report.plan')
        if observed==2:
            need(framework=='kit' and ready.get('intent_source')=='outside_sim_catalog_class1'
                 and ready.get('action_timing')=='Scheduled','Kit intent contract2 lacks existing catalog/timing')
    return expected


def _kit_control_fields(key, body, epoch, players):
    """Validate actual confirmed class0 evidence, never a predicted substitute."""
    need(isinstance(key,list) and len(key)==4 and
         all(type(v) is int and 0<=v<2**64 for v in key), 'malformed Kit control key')
    need(isinstance(body,dict), 'unavailable/null Kit control body')
    need(isinstance(players,list) and len(players)==2 and
         all(type(v) is int and 0<v<2**64 for v in players) and len(set(players))==2,
         'actual Kit player mapping unavailable')
    need(key[0]==epoch and key[2] in (1,2) and key[3]==0, 'Kit control epoch/seat/class key differs')
    for name,value in zip(('epoch','tick','seat','class'),key):
        need(type(body.get(name)) is int and body[name]==value, 'Kit control body/key differs: '+name)
    need(body.get('accepted') is True and type(body.get('status')) is int and body['status']==0,
         'Kit control was not successfully observed/accepted')
    need('available' not in body and 'unavailable' not in body, 'unavailable Kit control is not an INPUT')
    for name in ('x','z'):
        need(type(body.get(name)) is int and -32768<=body[name]<=32767,
             'Kit control requires actual signed i16 '+name)
    need(type(body.get('origin')) is int and body['origin'] in (1,2,3), 'Kit control origin invalid/unknown')
    need(type(body.get('sequence')) is int and 0<=body['sequence']<2**64, 'Kit control source sequence is not u64')
    need(type(body.get('player')) is int and body['player']==players[key[2]-1], 'Kit control mapped player differs')
    return key[1],key[2]


def _kit_control_coverage(store, epoch, admission, target, players_by_role):
    need(type(target) is int and 0<target<=65535, 'Kit control target outside declared finite domain')
    counts={}
    for role in ('host','client'):
        seen=set();count=0
        for row in store.execute('SELECT id,body FROM decisions WHERE role=?',(role,)):
            key,body=strict_json(row['id']),strict_json(row['body'])
            # APPLIED class1 records keep their existing action proof path.
            control=(isinstance(key,list) and len(key)==4 and key[3]==0) or \
                    not isinstance(body,dict) or 'kind' not in body or \
                    body.get('class')==0 or 'x' in body or 'z' in body
            if not control:continue
            tick,seat=_kit_control_fields(key,body,epoch,players_by_role.get(role))
            need(tick<=target, 'Kit control tick exceeds declared target')
            need((tick,seat) not in seen, 'duplicate logical Kit control key')
            seen.add((tick,seat))
            if admission<tick:count+=1
        counts[role]=count
    return counts


def _execution_binding(plan, report):
    actual=report.get('plan',{});expected=plan['execution']
    _intent_contract_binding(plan['framework'],actual)
    for cli,key in (('seed','seed'),('ticks','required_ticks'),('minimum_wall_seconds','minimum_wall_seconds'),
                    ('timeout','timeout_seconds'),('latency','latency_ms'),('jitter','jitter_ms'),('loss','loss_percent')):
        need(cli in actual and type(actual[cli]) in (int,float) and type(actual[cli]) is not bool and actual[cli]==expected[key], 'actual CLI execution differs: '+cli)
    need(actual.get('framework')==plan['framework'] and actual.get('end_tick')==plan['target_tick'] and
         actual.get('bodies')==32,'actual framework/target/body CLI differs')
    for cli,key in (('store_mib','rolling_bytes'),('event_mib','event_bytes'),('log_mib','log_bytes_each')):
        need(type(actual.get(cli)) is int and actual[cli]*1024*1024==plan['disk'][key],'actual finite disk plan differs: '+cli)


def _descriptor(domain, fields):
    data=b'OGB3DESC1'+struct.pack('<Q',len(domain))+domain+struct.pack('<I',len(fields))
    for tag,blob in fields:
        encoded=tag.encode();data+=struct.pack('<I',len(encoded))+encoded+struct.pack('<Q',len(blob))+blob
    return data


def expected_replay_rules(manifest, initial, seed):
    """APPLICATION digest only: READY binds a SECOND provider descriptor."""
    need(isinstance(manifest,dict) and all(hash_ok(manifest.get(p)) for p in SEED_SOURCES), 'bound seed-descriptor source hashes unavailable',Unavailable)
    fields=(('adapter',bytes.fromhex(manifest[SEED_SOURCES[0]])),('common',bytes.fromhex(manifest[SEED_SOURCES[1]])),
            ('launch',struct.pack('<II',initial,seed)))
    return hashlib.sha256(_descriptor(b'odin-godot.replay-box3d-slice.v1',fields)).hexdigest()


def _digest_text(value):
    if isinstance(value,str) and value.startswith('sha256:'):value=value[7:]
    need(hash_ok(value),'invalid referenced digest')
    return value


def _digest_array(value):
    need(isinstance(value,list) and len(value)==32 and all(type(x) is int and 0<=x<=255 for x in value),'invalid public digest bytes')
    return bytes(value).hex()


def load_replay_rule_oracle(plan, source_manifest, native_metadata=None):
    """Verify preserved PUBLIC codec bytes; no Native call/private image decode.

    Optional native_metadata is the frozen deployed box3d-runtime.json for
    prelaunch checking. Full public signature identity is always checked later.
    """
    validate_plan(plan);need(plan['framework']=='replay','Replay oracle for wrong framework')
    ref=plan['replay_rule_oracle'];path=Path(ref['path']).resolve()
    need(path.is_file(),'public codec oracle unavailable',Unavailable)
    need(path.stat().st_size<=256*1024 and _sha(path)==ref['sha256'],'public codec oracle JSON changed')
    data=strict_json(path.read_bytes());base=path.parent
    need(data.get('schema')==1 and data.get('ok') is True and data['initial']==32 and
         data['seed']==plan['execution']['seed'],'oracle initial/seed/status mismatch')
    names=('application_rules.bin','provider_config.canonical.bin','provider_config.values.bin',
           'bound_game_rules.bin','network_bound_rules.descriptor.bin')
    need(set(data['bytes'])==set(names),'public oracle byte inventory changed')
    blobs={};refs={str(path):ref['sha256']}
    for name in names:
        p=base/name;entry=data['bytes'][name]
        need(p.is_file(),'oracle bytes unavailable',Unavailable)
        need(type(entry['length']) is int and 0<=entry['length']<=1024*1024+4096 and
             p.stat().st_size==entry['length'] and _sha(p)==entry['sha256'],'oracle byte length/SHA mismatch: '+name)
        blobs[name]=p.read_bytes();refs[str(p)]=entry['sha256']
    build=data['build'];binding_path=base/'build-binding.json'
    need(binding_path.is_file() and _sha(binding_path)==build['binding_sha256'],'oracle build binding unavailable/changed')
    binding=strict_json(binding_path.read_bytes());refs[str(binding_path)]=build['binding_sha256']
    need(build['exit']==build['run_exit']==binding['build_exit']==binding['run_exit']==0 and
         build['source_fence_unchanged'] is True and binding['source_fence_unchanged'] is True,'oracle build/run/source fence failed')
    for name in ('sources-before.json','sources-after.json'):
        p=base/name;need(p.is_file() and _sha(p)==build['source_manifest_sha256'],'oracle compiled source manifest changed')
        refs[str(p)]=build['source_manifest_sha256']
    oracle_sources=strict_json((base/'sources-before.json').read_bytes())
    for name in (*SEED_SOURCES,'replay/physics/network_codec.odin','box3d/diagnostics/descriptor.odin'):
        need(hash_ok(source_manifest.get(name)), 'oracle formula/provider source unavailable: '+name,Unavailable)
        need(oracle_sources.get(name)==source_manifest[name], 'oracle formula/provider source differs from selected manifest: '+name)
    need(binding['sources_before_sha256']==binding['sources_after_sha256']==build['source_manifest_sha256'],'oracle before/after source refs mismatch')
    native=Path(data['native_archive']);compiler=Path(build['compiler_path'])
    output=[x[5:] for x in binding['argv'] if x.startswith('-out:')]
    need(len(output)==1,'oracle executable reference unavailable',Unavailable)
    executable=Path(output[0]);need(executable.resolve().is_relative_to(base),'oracle binary outside artifact directory')
    for p,want in ((native,data['native_archive_sha256']),(compiler,build['compiler_sha256']),
                   (executable,build['binary_sha256']),(Path(binding['native_manifest']),binding['native_manifest_sha256'])):
        need(p.is_file(),'oracle build input unavailable: '+str(p),Unavailable)
        need(_sha(p)==want,'oracle compiled/native artifact changed: '+str(p));refs[str(p.resolve())]=want
    need(binding['native_archive_sha256']==data['native_archive_sha256'] and
         binding['binary_sha256']==build['binary_sha256'],'oracle native/executable binding mismatch')
    summary_path=base/'report.json';need(summary_path.is_file() and _sha(summary_path)==data['report_sha256'],'oracle actual report ref changed')
    actual_report=strict_json(summary_path.read_bytes());public=actual_report['public'];refs[str(summary_path)]=data['report_sha256']
    need(public['ok'] is True and public['files_written'] is True and public['initial']==32 and public['seed']==data['seed'],'actual public oracle result differs')
    expected_statuses={'catalog_create','identity_status','codec_init','config_encode','codec_destroy','catalog_destroy','engine_status','wrapper_status'}
    need(set(data['public_statuses'])==expected_statuses and all(type(v) is int and v==0 for v in data['public_statuses'].values()),'oracle public status failed')
    need(all(public[k]==v for k,v in data['public_statuses'].items()),'oracle public status/report mismatch')
    need(set(data['cleanup'])=={'engine_live','wrapper_live','provider_live','odin_live'} and
         all(type(v) is int and v==0 and public[k]==v for k,v in data['cleanup'].items()),'oracle cleanup failed/unavailable')
    app=expected_replay_rules(source_manifest,32,plan['execution']['seed'])
    need(len(blobs['application_rules.bin'])==32 and blobs['application_rules.bin'].hex()==app==
         _digest_text(data['application_rules'])==_digest_array(public['application_rules']),'actual public application descriptor mismatch')
    descriptor=_descriptor(b'odin-godot.replay.physics-rules.v1',(
        ('application',blobs['application_rules.bin']),('provider_schema',blobs['provider_config.canonical.bin']),
        ('provider_values',blobs['provider_config.values.bin'])))
    bound=hashlib.sha256(descriptor).hexdigest()
    need(descriptor==blobs['network_bound_rules.descriptor.bin'] and len(blobs['bound_game_rules.bin'])==32 and
         blobs['bound_game_rules.bin'].hex()==bound==_digest_text(data['actual_codec_game_rules'])==
         _digest_text(data['python_descriptor'])==_digest_array(public['bound_game_rules']),'actual bound provider rules mismatch')
    need(public['provider_canonical_bytes']==len(blobs['provider_config.canonical.bin']) and
         public['provider_value_bytes']==len(blobs['provider_config.values.bin']),'public schema/value lengths differ')
    catalog=dict(data['catalog_identity'])
    for key in ('build_target','assets','solver_schema'):
        catalog[key]=_digest_text(catalog[key]);need(catalog[key]==_digest_array(public['catalog_identity'][key]),'oracle catalog mismatch')
    for key in ('solver_format','recovery_format','profile'):
        need(type(catalog[key]) is int and catalog[key]==public['catalog_identity'][key] and catalog[key]>0,'oracle catalog scalar mismatch')
    native_build=_digest_text(data['native_build']);native_target=_digest_text(data['native_target'])
    need(native_build==_digest_array(public['native_build']) and native_target==_digest_array(public['native_target']),'actual public native identity mismatch')
    proof=dict(bound_game_rules=bound,application_rules=app,catalog_identity=catalog,native_build=native_build,
               native_target=native_target,artifact_refs=refs,public_only=True)
    if native_metadata is not None:
        domain=native_metadata.get('domain',{})
        need(_digest_text(domain.get('build'))==native_build and _digest_text(domain.get('target'))==native_target,'old oracle cannot qualify selected Native build/target')
    return proof


def validate_oracle_signature(proof, sig):
    signature(sig)
    identity=proof['catalog_identity']
    need(struct.unpack_from('<II',sig,16)==(identity['solver_format'],identity['recovery_format']) and
         struct.unpack_from('<Q',sig,32)[0]==identity['profile'] and
         all(sig[at:at+32].hex()==identity[key] for key,at in
             (('build_target',40),('assets',72),('solver_schema',104))), 'oracle catalog does not match selected public signature identity')


def _ready_execution(plan, ready, replay_proof=None):
    if plan['framework']=='replay':
        need(replay_proof is not None,'verified bound public Codec oracle unavailable',Unavailable)
        need('game_rules' in ready,'actual READY rules/seed evidence unavailable',Unavailable)
        need(ready['game_rules']==replay_proof['bound_game_rules'],'actual READY rules do not bind planned32/seed/source/Native')
        if 'seed' in ready:need(type(ready['seed']) is int and ready['seed']==plan['execution']['seed'],'actual READY seed differs')
    else:
        need('seed' in ready,'actual READY seed evidence unavailable',Unavailable)
        need(type(ready['seed']) is int and ready['seed']==plan['execution']['seed'],'actual READY seed differs')
    e=plan['execution']
    environment={key:str(value) for key,value in zip(('B3_LATENCY','B3_JITTER','B3_LOSS','B3_DUPLICATE','B3_REORDER'),
        (e['latency_ms'],e['jitter_ms'],e['loss_percent'],0,0))}
    verify_ready(ready,plan['framework'],environment)
    need(ready['baseline']+e['required_ticks']<=plan['target_tick'],'actual admission leaves insufficient frozen duration')


def plan_digest(plan):
    validate_plan(plan)
    return hashlib.sha256(json_bytes(plan)).hexdigest()


@dataclass(frozen=True)
class Artifact:
    path: Path
    sha256: str


@dataclass(frozen=True)
class EvidenceBundle:
    report: Artifact
    events: Artifact
    store: Artifact


def _key(value):
    need(isinstance(value, list), 'raw missing key is not an array')
    return json_bytes(value).decode()


def guard_raw_strict(raw, classification):
    """Pure missing-only guard; its ALLOW result is NEVER a LONG/GateB pass.

    classification holds independently enumerated raw key lists and the exact
    classified rows. classify() produces these from the immutable RO store.
    """
    errors = []
    expected_findings = set()
    for field in ('fx_changed', 'fx_extra', 'decision_changed', 'decision_extra',
                  'unmatched_required_frames', 'final_tail_missing'):
        if type(raw.get(field)) is not int or raw[field] != 0:
            errors.append('raw strict violation: ' + field)
    for label, count_field, finding in (('fx', 'fx_missing', FX_MISSING),
                                        ('decisions', 'decision_missing', DECISION_MISSING)):
        count = raw.get(count_field)
        if type(count) is not int or count < 0:
            errors.append('invalid raw missing count: ' + count_field)
            continue
        if count:
            expected_findings.add(finding)
        keys = classification.get('raw_missing_' + label)
        rows = classification.get('classified_' + label)
        if not isinstance(keys, list) or not isinstance(rows, list):
            errors.append('full exact missing classification unavailable: ' + label)
            continue
        try:
            actual = [_key(x) for x in keys]
            classified = [_key(x['key']) for x in rows]
            need(len(actual) == len(set(actual)) == count, 'duplicate/count mismatch in raw keys')
            need(len(classified) == len(set(classified)) == count and
                 set(actual) == set(classified), 'classified keys differ from exact raw keys')
            need(all(x.get('disposition') == 'UNOBSERVED_PAST' and x.get('gap_ids') and
                     x.get('previously_settled') is False and hash_ok(x.get('authority_body_sha256'))
                     for x in rows), 'missing key is not qualified unobserved past')
        except (PolicyError, KeyError, TypeError) as error:
            errors.append(label + ': ' + str(error))
    findings = raw.get('findings')
    if (not isinstance(findings, list) or not all(isinstance(x,str) for x in findings) or
            len(findings) != len(set(findings)) or set(findings) != expected_findings):
        errors.append('raw findings are not EXACTLY the two applicable missing-only classes')
    if raw.get('result') != ('FAIL' if expected_findings else 'PASS'):
        errors.append('raw result/findings inconsistent')
    return dict(status='FAIL' if errors else 'ALLOW_MISSING_ONLY_CLASSIFICATION', findings=errors,
                raw_result=raw.get('result'), raw_findings=findings,
                no_rolling_result_changed=True, not_an_overall_pass=True)


def _merged(intervals):
    merged = []
    for start, end in sorted(intervals):
        if merged and start <= merged[-1][1]:
            merged[-1] = (merged[-1][0], max(end, merged[-1][1]))
        else:
            merged.append((start, end))
    return merged


def _inside(tick, gaps):
    return [g for g in gaps if g['start_exclusive'] < tick <= g['end_inclusive']]


def _body(raw):
    return raw if isinstance(raw, bytes) else raw.encode()


def _slot_history(authority_events):
    """One-extra-slot model invariant; applies even to interrupted cycles."""
    last_success=None;last_tick=-1
    for event in sorted(authority_events,key=lambda e:e['id']):
        row=event['row'];need(row['tick']>=last_tick,'authority action observation order regressed');last_tick=row['tick']
        if not row['applied']:continue
        kind=action_name(row['kind'])
        if kind=='Remove':last_success=None
        elif kind=='Spawn':
            need(last_success is None,'impossible two successful Spawns without intervening valid Remove')
            last_success=event


def _long_spawn_pair(joins, authority_events, policy):
    """LONG original-due contract, deliberately independent of short helper."""
    need(policy in ('Scheduled','Receipt'),'unknown pair policy')
    need(len(joins)==2 and {j['issued']['seat'] for j in joins}=={1,2},'actual two-driver Spawn joins missing')
    original={(j['issued']['epoch'],j['issued']['original_requested_tick']) for j in joins}
    need(len(original)==1 and all(action_name(j['issued']['kind'])==action_name(j['authority']['kind'])=='Spawn' for j in joins),'wrong original-due Spawn pair')
    if policy=='Scheduled':
        need(all(j['authority']['tick']==j['issued']['submitted_tick'] for j in joins),'Scheduled pair changed own submitted target')
    ordered=sorted(authority_events,key=lambda e:e['id']);_slot_history(ordered)
    def locate(join):
        row=join['authority'];found=[e for e in ordered if (e['row']['epoch'],e['row']['seat'],e['row']['sequence'])==(row['epoch'],row['seat'],row['sequence'])]
        need(len(found)==1 and found[0]['row']==row,'pair lacks immutable authority event');return found[0]
    pair=[locate(j) for j in joins]
    same_tick=pair[0]['row']['tick']==pair[1]['row']['tick']
    if same_tick:
        need([e['row']['seat'] for e in sorted(pair,key=lambda e:e['id'])]==[1,2],
             'equal-tick Spawn semantic seat order changed')
    winners=[e for e in pair if e['row']['applied']];losers=[e for e in pair if not e['row']['applied']]
    if len(winners)!=1 or len(losers)!=1:raise NotContested('Spawn pair lacks one success and one Predicate rejection')
    winner,loser=winners[0],losers[0]
    if same_tick:
        need(winner['row']['seat']==1 and loser['row']['seat']==2,'equal-tick Spawn semantic seat order changed')
    if winner['id']>=loser['id'] or winner['row']['tick']>loser['row']['tick']:raise NotContested('Spawn rejection preceded success')
    between=[e for e in ordered if winner['id']<e['id']<loser['id'] and e['row']['applied'] and action_name(e['row']['kind']) in ('Remove','Spawn')]
    if between:raise NotContested('actual intervening Remove/replacement between Spawn verdicts (including same tick)')
    if policy=='Receipt' or 'reason' in loser['row']:
        need(str(loser['row'].get('reason','')).lower()=='predicate' and
             str(winner['row'].get('reason','')).lower()=='none','non-Predicate Spawn reason')
    return dict(policy=policy,winner=winner['row'],rejected=loser['row'],
                original_due=next(iter(original))[1],actual_event_ids=[winner['id'],loser['id']],
                execution_order='semantic seat order at a shared tick' if winner['row']['tick']==loser['row']['tick'] else 'actual authority order; each Scheduled target retained')


def _hex(value):
    integer(value, 'u64')
    need(value < 2**64, 'u64 overflow')
    return f'{value:016x}'


def _parts(sig, payload):
    _, _, lengths = signature(sig)
    need(payload is not None, 'retained canonical raw missing', Unavailable)
    decoder = zlib.decompressobj()
    raw = decoder.decompress(bytes(payload), sum(lengths)+1)
    need(decoder.eof and not decoder.unused_data and not decoder.unconsumed_tail and
         len(raw) == sum(lengths), 'bounded raw frame decompression mismatch')
    at = 0
    for index, size in enumerate(lengths):
        piece = raw[at:at+size]
        need(hashlib.sha256(piece).digest() == sig[256+40*index:288+40*index], 'canonical raw part SHA mismatch')
        at += size
    return raw


class _Audit:
    def __init__(self, plan, bundle):
        self.plan, self.bundle = plan, bundle
        self.failures, self.unavailable = [], []
        self.summary = dict(policy_id=POLICY_ID, policy_sha256=plan_digest(plan),
                            prospective_only=True, gate_b='NOT_ESTABLISHED', raw_strict=None)
        self.roles = {role: SimpleNamespace(ready=None, result=None, go=None, frames=[],
                      issues=[], actions=[], marks=[], recoveries=[], limits=False,
                      initial_counts=False, ledger_stages=set(), remote_final=False) for role in ('host', 'client')}
        self.selected_bytes = 0
        self.events = self.store = None
        self.replay_proof = None

    def add(self, message, unavailable=False):
        target = self.unavailable if unavailable else self.failures
        need(len(target) < 256, 'finding bound exhausted')
        target.append(str(message))

    def select(self, raw):
        self.selected_bytes += len(raw)
        need(self.selected_bytes <= BOUNDS['selected_bytes'], 'selected observation byte bound exhausted')

    def open(self):
        for ref in (self.bundle.report, self.bundle.events, self.bundle.store):
            need(hash_ok(ref.sha256) and Path(ref.path).is_file(), 'artifact/reference unavailable', Unavailable)
            need(_sha(ref.path) == ref.sha256, 'immutable artifact SHA mismatch')
        need(Path(self.bundle.report.path).stat().st_size<=16*1024*1024,'closed report byte bound')
        self.report = strict_json(Path(self.bundle.report.path).read_bytes())
        self.raw = self.report.get('rolling', {})
        self.summary['raw_strict'] = self.raw  # Preserve the input result/findings exactly.
        expected = dict(policy_id=POLICY_ID, policy_sha256=plan_digest(self.plan),
                        run_id=self.plan['run_id'], marker_event_id=1, prelaunch=True)
        binding=self.report.get('long_policy')
        need(binding == expected and type(binding.get('prelaunch')) is bool and type(binding.get('marker_event_id')) is int,
             'no exact prospectively bound policy; historical cases cannot pass', Unavailable)
        need(self.report.get('framework') == self.plan['framework'], 'mixed framework/source')
        _execution_binding(self.plan,self.report)
        build_ref=self.report.get('compiled_build',{})
        build_path=Path(build_ref.get('path',''))
        need(build_path.is_file() and hash_ok(build_ref.get('sha256')), 'compiled source binding unavailable',Unavailable)
        need(_sha(build_path)==build_ref['sha256'], 'compiled build record changed')
        build=strict_json(build_path.read_bytes())
        need(build.get('result')=='PASS' and build.get('source_fence_unchanged') is True and
             build.get('framework')==self.plan['framework'] and
             all(build.get('source_manifest_sha256')==x for x in self.plan['source_hashes'].values()), 'compiled/source identity mismatch')
        manifest=Path(build.get('source_manifest',''))
        need(manifest.is_file() and _sha(manifest)==build['source_manifest_sha256'], 'compiled source manifest unavailable/changed')
        self.source_manifest=strict_json(manifest.read_bytes())
        if self.plan['framework']=='replay':
            runtime=Path(build.get('project',''))/'bin/box3d-runtime.json'
            frozen_hash=build.get('frozen_project_files',{}).get('bin/box3d-runtime.json')
            need(runtime.is_file() and hash_ok(frozen_hash),'selected Native runtime metadata unavailable',Unavailable)
            need(_sha(runtime)==frozen_hash,'selected Native runtime metadata changed')
            self.replay_proof=load_replay_rule_oracle(self.plan,self.source_manifest,strict_json(runtime.read_bytes()))
            self.summary['replay_rule_oracle']=self.replay_proof
        for field in ('source_changes', 'driver_source_changes'):
            need(self.report.get(field) == [], 'source/driver fence changed or unavailable')
        need(self.report.get('source_fence_unchanged') is True, 'source fence not verified')
        for ref, key in ((self.bundle.events, 'observation_archive'), (self.bundle.store, 'rolling_database')):
            link = self.report.get(key, {})
            need(link.get('sha256') == ref.sha256 and Path(link.get('path', '')).resolve() == Path(ref.path).resolve(), 'report/archive link mismatch')
        for ref, limit in ((self.bundle.events, self.plan['disk']['event_bytes']),
                           (self.bundle.store, self.plan['disk']['rolling_bytes'])):
            need(Path(ref.path).stat().st_size <= limit, 'finite evidence disk budget exceeded')
        rolling_bytes = sum(p.stat().st_size for p in Path(self.bundle.store.path).parent.rglob('*') if p.is_file())
        need(rolling_bytes <= self.plan['disk']['rolling_bytes'], 'rolling archive/export budget exceeded')
        for role in self.roles:
            log = Path(self.bundle.report.path).parent/role/'godot.log'
            need(log.is_file(), 'raw endpoint log unavailable', Unavailable)
            need(log.stat().st_size <= self.plan['disk']['log_bytes_each'], 'raw log budget exceeded')
        self.events = sqlite3.connect(Path(self.bundle.events.path).resolve().as_uri()+'?mode=ro&immutable=1', uri=True)
        self.store = sqlite3.connect(Path(self.bundle.store.path).resolve().as_uri()+'?mode=ro&immutable=1', uri=True)
        self.events.row_factory = self.store.row_factory = sqlite3.Row

    def scan(self):
        columns = {r[1] for r in self.events.execute('PRAGMA table_info(events)')}
        need('observed_at' in columns, 'actual observation times unavailable', Unavailable)
        previous = '0'*64
        times = {}
        number = 0
        for number, row in enumerate(self.events.execute('SELECT * FROM events ORDER BY id'), 1):
            need(number <= BOUNDS['events'] and row['id'] == number and row['prev'] == previous, 'event count/order/chain bound')
            need(len(_body(row['body'])) <= BOUNDS['event_body'], 'event body bound')
            body = strict_json(row['body'])
            when = row['observed_at']
            need(when is None or (type(when) in (int, float) and math.isfinite(when) and when >= 0), 'invalid observation time')
            value = hashlib.sha256(bytes.fromhex(previous)+json_bytes(dict(id=number, role=row['role'], kind=row['kind'], row=body, observed_at=when))).hexdigest()
            need(value == row['hash'], 'event body/time hash tampered')
            previous = value
            if number == 1:
                need(row['role'] == 'controller' and row['kind'] == 'LONG_POLICY' and
                     body == self.report['long_policy'], 'policy marker was not the first controller observation', Unavailable)
                continue
            need(row['role'] in self.roles, 'unknown observation source')
            role = self.roles[row['role']]
            need(body.get('role',row['role'])==row['role'] and body.get('actor',row['role'])==row['role'], 'wrong diagnostic role/source')
            need(body.get('framework',self.plan['framework'])==self.plan['framework'], 'mixed framework observation')
            if when is not None:
                need(when >= times.get(row['role'], 0), 'per-role observed clock regressed')
                times[row['role']] = when
            kind = row['kind']
            need(kind not in ('ERROR', 'INTENT_UNEXERCISED'), 'actual endpoint fatal/scenario error')
            if 'epoch' in body:
                need(body['epoch'] == self.plan['epoch'], 'undeclared epoch transition')
            event = dict(id=number, role=row['role'], kind=kind, row=body, observed_at=when)
            if kind == 'READY':
                need(role.ready is None, 'duplicate admission')
                need(body['target'] == self.plan['target_tick'], 'endpoint target differs from plan')
                _intent_contract_binding(self.plan['framework'],self.report.get('plan',{}),body)
                _ready_execution(self.plan,body,self.replay_proof)
                role.ready = event
            elif kind == 'GO':
                need(role.ready is not None and role.go is None, 'GO/admission ordering')
                role.go = event
            elif kind == 'RESULT':
                need(role.result is None, 'duplicate endpoint RESULT')
                role.result = event
            elif kind == 'FRAME':
                need(role.ready is not None and len(role.frames) < BOUNDS['frames'], 'unadmitted/frame bound')
                need(body['tick'] <= body['confirmed'] <= body['head'], 'unconfirmed exported frame')
                role.frames.append(dict(id=number, tick=body['tick'], head=body['head'],
                                        confirmed=body['confirmed'], observed_at=when))
            elif kind in ('ISSUED', 'SUBMITTED', 'APPLIED', 'ACTION', 'RECOVERY', 'RECOVERED',
                          'RECOVERY_REQUESTED', 'INTENT_ATTEMPT', 'INTENT_REBASE'):
                self.select(_body(row['body']))
                if kind in ('ISSUED', 'SUBMITTED'):
                    need(len(role.issues) < BOUNDS['issues'], 'issue bound')
                    role.issues.append(event)
                elif kind in ('APPLIED', 'ACTION'):
                    need(len(role.actions) < BOUNDS['actions'], 'action bound')
                    role.actions.append(event)
                else:
                    need(len(role.marks) < BOUNDS['actions'], 'intent/recovery observation bound')
                    role.marks.append(event)
            elif kind == 'LIMITS':
                need(not role.limits and body['initial_cached_dynamic_bodies'] == 32 and body['initial_cached_body_count'] == 34 and
                     body['history'] == 128 and body['max_prediction'] == body['max_repair'] == 8 and
                     body['hz']==60 and body['substeps']==4 and body['process_limit_bytes'] == FIXED['native_limit_bytes'], 'actual32/H128/8/64MiB profile changed')
                role.limits=True
            elif kind == 'ENVELOPE':
                need(body.get('observe_error') == 'None', 'native count observation failed')
                if not role.initial_counts:
                    need(body['cached_dynamic_bodies']==32 and body['cached_body_count']==34, 'initial32 not actually observed')
                    role.initial_counts=True
                for field, cap in (('body_count', 35), ('shape_count', 35), ('contact_count', 147), ('joint_count', 1)):
                    need(0 <= body['native_'+field] <= body['peak_'+field] <= cap, 'native envelope exceeded')
            elif kind == 'LEDGER':
                need(body['status'] == 0 and body['limit_bytes'] == FIXED['native_limit_bytes'] and
                     0 <= body['admitted_bytes'] <= FIXED['native_limit_bytes'] and
                     body['admitted_bytes'] == body['live_bytes']+body['host_reserved_bytes'] and
                     body['live_bytes'] == body['engine_live_bytes']+body['snapshot_live_bytes']+body['host_live_bytes'] and
                     0 <= body['committed_peak_bytes'] <= FIXED['native_limit_bytes'], 'global native ledger violation')
                role.ledger_stages.add(body['stage'])
            elif kind=='TAIL' and body.get('stage')=='final_received' and row['role']=='host':
                if self.plan['framework']=='kit' and 'from_role' not in body:
                    need(body.get('head')==body.get('confirmed')==body.get('tick')==self.plan['target_tick'], 'invalid self terminal receipt')
                else:
                    need(body.get('from_role')=='client' and body.get('matched') is True and body['tick']==self.plan['target_tick'], 'remote final ACK invalid')
                    if self.plan['framework']=='replay':
                        need(bytes.fromhex(body['from_token_hex'])==(202).to_bytes(8,'little')+bytes(8) and
                             body['from_seat']==2 and body['from_generation']>0 and body['from_peer']>0, 'remote final token/scope mismatch')
                    else:
                        mask=2**64-1;z=(202+0x9e3779b97f4a7c15)&mask
                        z=((z^(z>>30))*0xbf58476d1ce4e5b9)&mask;z=((z^(z>>27))*0x94d049bb133111eb)&mask
                        need(body['from_token_hash']==(z^(z>>31)) and body['from']>0 and body['peer']>0, 'remote final token/peer mismatch')
                    role.remote_final=True
        chain = self.report.get('observation_chain', {})
        need(chain.get('events') == number and chain.get('head_sha256') == previous, 'observation archive tail/link mismatch')
        self.summary['observation_chain'] = chain

    def processes_and_frames(self):
        processes = list(self.store.execute('SELECT * FROM processes ORDER BY role'))
        need(len(processes) == 2 and {p['role'] for p in processes} == set(self.roles), 'exact two process scopes required')
        self.processes = {p['role']: p for p in processes}
        need(all(p['source']==self.plan['source_hashes'][name] for name,p in self.processes.items()), 'wrong process/source identity')
        for name, role in self.roles.items():
            process = self.processes[name]
            need(role.ready is not None and role.go is not None and role.result is not None, 'admission/GO/RESULT unavailable', Unavailable)
            need(role.limits and role.initial_counts and {'published_frame','before_close','after_cleanup'}<=role.ledger_stages,
                 'required actual profile/ledger observations unavailable',Unavailable)
            need(int(process['epoch'],16) == role.ready['row']['epoch'] == self.plan['epoch'] and
                 int(process['baseline'],16) == role.ready['row']['baseline'], 'process admission binding mismatch')
            exit = self.report.get('exits', {}).get(name, {})
            need(exit.get('pid') == process['pid'] and exit.get('exit_code') == 0 and exit.get('natural') is True and
                 exit.get('pending_events') == 0 and exit.get('reader_error') is None, 'natural exit/observation drain not proved')
            need(role.result['row'].get('ok') is True and role.result['row']['tick'] == self.plan['target_tick'], 'endpoint target/result failure')
            need(all(type(role.result['row'].get(k)) is int and role.result['row'][k]==0 for k in
                     ('engine_live','wrapper_live','meter_live')), 'endpoint resource counters unavailable/nonzero')
            cleanup = json.loads(process['cleanup']) if process['cleanup'] else {}
            need(process['exit_code'] == 0 and cleanup.get('ok') is True and
                 all(cleanup.get(k) is True for k in ('all_explicit_drops_ok','core_shutdown_clean')) and
                 all(type(cleanup.get(k)) is int and cleanup[k] == 0 for k in
                     ('native_live_bytes','snapshot_live_bytes','host_application_live_bytes')), 'ownership/shutdown not zero')
        need(self.roles['host'].remote_final,'actual authenticated remote final receipt unavailable',Unavailable)
        # Verify receipt chain without reconstructing a retired follower image.
        previous = '0'*64
        receipts = 0
        for row in self.store.execute('SELECT id,kind,body,prev,hash FROM receipts ORDER BY id'):
            receipts += 1
            need(receipts <= BOUNDS['events'] and row['id'] == receipts and row['prev'] == previous, 'rolling receipt order/bound')
            value = hashlib.sha256(bytes.fromhex(previous)+row['kind'].encode()+b'\0'+bytes(row['body'])).hexdigest()
            need(value == row['hash'], 'rolling receipt tampered')
            previous = value
        need(receipts == self.raw['receipt_count'] and previous == self.raw['receipt_chain_head'], 'rolling receipt tail mismatch')
        need(not self.store.execute('SELECT 1 FROM failure').fetchone(), 'preserved first divergence')
        identity = None
        counts = dict(host=0, client=0)
        for table in ('frames','canonical_frames'):
            need(self.store.execute(f'SELECT 1 FROM {table} WHERE length(payload)>? LIMIT 1',(2*1024*1024+4096,)).fetchone() is None,'compressed frame byte bound')
        for frame in self.store.execute('SELECT * FROM frames ORDER BY role,epoch,tick'):
            need(frame['role'] in counts, 'unknown frame source')
            counts[frame['role']] += 1
            need(sum(counts.values()) <= BOUNDS['frames'], 'frame row bound')
            sig = bytes(frame['sig']);epoch,tick,_ = signature(sig)
            need(epoch == self.plan['epoch'] and _hex(epoch) == frame['epoch'] and _hex(tick) == frame['tick'], 'frame epoch/tick mismatch')
            need(frame['scope'] == self.processes[frame['role']]['scope'], 'wrong frame process scope')
            if identity is None: identity = sig[16:232]
            need(sig[16:232] == identity, 'mixed complete frame identity')
            if self.replay_proof is not None:validate_oracle_signature(self.replay_proof,sig)
            canonical = self.store.execute('SELECT * FROM canonical_frames WHERE epoch=? AND tick=?',(frame['epoch'],frame['tick'])).fetchone()
            need(canonical is not None and canonical['payload'] is not None and bytes(canonical['sig']) == sig, 'authority full reference missing', Unavailable)
            raw = _parts(sig,canonical['payload'])
            if frame['payload'] is not None:
                need(_parts(sig,frame['payload']) == raw, 'actual retained five-part mismatch')
            if frame['role'] == 'client':
                match = self.store.execute('SELECT receipt FROM matches WHERE role=? AND scope=? AND epoch=? AND tick=?',('client',frame['scope'],frame['epoch'],frame['tick'])).fetchone()
                need(match is not None, 'required follower export unmatched')
                receipt = self.store.execute('SELECT kind,body FROM receipts WHERE id=?',(match[0],)).fetchone()
                body = json.loads(receipt['body'])
                need(receipt['kind'] == 'complete_comparison' and body['byte_comparison'] is True and
                     body['epoch'] == epoch and body['tick'] == tick and
                     body['signature_sha256'] == hashlib.sha256(sig).hexdigest(), 'sealed full-byte receipt missing/mismatched')
                for role in self.roles:
                    p=self.processes[role];side=body['authority' if role=='host' else 'follower']
                    need(all(side[k] == p[k] for k in ('role','scope','pid','source')), 'comparison receipt source mismatch')
            else:
                need(self.store.execute('SELECT 1 FROM reference_archives WHERE role=? AND scope=? AND epoch=? AND tick=?',('host',frame['scope'],frame['epoch'],frame['tick'])).fetchone() is not None, 'unarchived authority reference')
        need(counts['client'] > 0 and counts['client'] == self.raw['required_follower_exports'] == self.raw['required_follower_matches'] and
             counts['host'] == self.raw['authority_export_count'], 'full-export count reconciliation failed')
        for name,role in self.roles.items():
            need(len(role.frames)==counts[name], 'actual FRAME observations/store counts differ')
            for frame in role.frames:
                need(self.store.execute('SELECT 1 FROM frames WHERE role=? AND scope=? AND epoch=? AND tick=?',
                     (name,self.processes[name]['scope'],_hex(self.plan['epoch']),_hex(frame['tick']))).fetchone() is not None,'FRAME has no immutable stored image')
        match_count=self.store.execute("SELECT count(*) FROM matches WHERE role='client'").fetchone()[0]
        need(match_count==counts['client']==self.raw['matched_comparisons'],'orphan/extra comparison receipt count')
        self.matched = {int(x[0],16) for x in self.store.execute("SELECT tick FROM matches WHERE role='client' AND epoch=?",(_hex(self.plan['epoch']),))}
        need(self.plan['target_tick'] in self.matched, 'actual final full5 tail unmatched')
        self.summary['frames'] = dict(authority_references=counts['host'], required_follower_exports=counts['client'],
            sealed_byte_comparisons=counts['client'], unpaired_authority_references=self.raw['unmatched_authority_references'],
            coverage='sealed actual byte-comparison receipts + retained full authority bytes; no recreation of retired follower bytes')

    def qualified_gaps(self):
        follower = self.roles['client'];gaps=[];pending=None
        last_serial=follower.ready['row'].get('serial');last_baseline=follower.ready['row']['baseline']
        for event in follower.marks:
            row=event['row'];kind=event['kind']
            if kind == 'RECOVERY_REQUESTED':
                need(pending is None and row.get('published_preserved') is True and row.get('request_status') in (0,'Ok','OK'), 'invalid/repeated reset request')
                pending=event
            elif kind in ('RECOVERY','RECOVERED'):
                if kind == 'RECOVERY':
                    need(row.get('cause') == 'canonical_welcome' and row['new_serial'] > row['old_serial'] > 0 and
                         row['new_baseline'] > row['old_baseline'] and row.get('view_reset',0) > 0 and
                         (row.get('resyncs',0) > 0 or row.get('snapshot_catchups',0) > 0), 'unqualified recovery marker')
                    need(row['old_serial']==last_serial and row['old_baseline']==last_baseline, 'missing/broken validated recovery chain')
                    last_serial,last_baseline=row['new_serial'],row['new_baseline']
                    start,end=row['old_head'],row['new_baseline'];head=row['new_head'];before_id=event['id']
                else:
                    need(pending is not None, 'recovered without actual request')
                    req=pending['row'];need(row['previous_head'] == req['head'] and row['previous_confirmed'] == req['confirmed'] and
                         row['received_sequence'] > row['request_sequence'] and row['request_sequence'] >= 0, 'reset publication/request mismatch')
                    start,end=row['previous_confirmed'],row['baseline'];head=row['head'];before_id=pending['id'];pending=None
                need(head >= end and end > start and end-start <= FIXED['max_gap_ticks'], 'gap interval/publication cap failure')
                prior=[f for f in follower.frames if f['id'] < before_id]
                next_marker=min((m['id'] for m in follower.marks if m['id']>event['id'] and m['kind'] in ('RECOVERY','RECOVERED')),default=2**63-1)
                after=[f for f in follower.frames if event['id'] < f['id'] < next_marker and end <= f['tick'] <= head and f['tick'] in self.matched]
                need(prior and after, 'pre/post recovery matching full-frame evidence unavailable', Unavailable)
                pre=prior[-1];post=after[0]
                need(pre['confirmed'] <= start, 'gap overlaps previously settled follower state')
                need(all(x is not None for x in (pre['observed_at'],event['observed_at'],post['observed_at'])), 'recovery observation time unavailable', Unavailable)
                interval=post['observed_at']-pre['observed_at']
                need(0 <= interval <= FIXED['max_observation_seconds'], 'recovery observation interval exceeds5s')
                need(pre['observed_at'] <= event['observed_at'] <= post['observed_at'], 'per-role recovery observation order invalid')
                gaps.append(dict(id=event['id'],start_exclusive=start,end_inclusive=end,
                    previously_confirmed=pre['confirmed'],marker=event,preceding_frame=pre,matching_post_frame=post,
                    observation_interval_seconds=interval,interval_scope='same follower actual stdout observation interval, NOT transport latency'))
        need(pending is None, 'unfinished reset request')
        need(len(gaps) <= FIXED['max_recoveries'], 'recovery count exceeded')
        admission=max(x.ready['row']['baseline'] for x in self.roles.values())
        union=_merged((g['start_exclusive'],g['end_inclusive']) for g in gaps)
        need(sum(b-a for a,b in union) <= FIXED['max_union_ticks'], 'aggregate unobserved gap budget exceeded')
        need(all(g['end_inclusive'] <= admission+FIXED['latest_gap_offset'] for g in gaps), 'late recovery beyond frozen budget')
        self.gaps=gaps;self.admission=admission
        self.summary['gaps']=dict(rows=gaps,union=union,total_ticks=sum(b-a for a,b in union),
                                  no_ordinary_catchup_exception=True)

    def missing_and_global(self):
        for table,column,label in (('decisions','body','decision'),('fx','settled','fx')):
            clause=' AND a.settled IS NOT NULL AND b.settled IS NOT NULL' if table=='fx' else ''
            changed=self.store.execute(f"SELECT count(*) FROM {table} a JOIN {table} b ON b.id=a.id AND b.role='client' WHERE a.role='host'{clause} AND a.{column}!=b.{column}").fetchone()[0]
            need(changed==0 and self.raw[label+'_changed']==0, 'actual '+label+' payload/provenance rewrite')
            clause=' AND a.settled IS NOT NULL' if table=='fx' else ''
            bclause=' AND b.settled IS NOT NULL' if table=='fx' else ''
            extra=self.store.execute(f"SELECT count(*) FROM {table} a WHERE a.role='client'{clause} AND NOT EXISTS(SELECT 1 FROM {table} b WHERE b.role='host' AND b.id=a.id{bclause})").fetchone()[0]
            need(extra==0 and self.raw[label+'_extra']==0, 'extra actual '+label+' row')
        classification=dict(raw_missing_fx=[],classified_fx=[],raw_missing_decisions=[],classified_decisions=[])
        for table, label, datafield in (('decisions','decisions','body'),('fx','fx','settled')):
            settled=' AND a.settled IS NOT NULL' if table=='fx' else ''
            other=' AND b.settled IS NOT NULL' if table=='fx' else ''
            sql=f"SELECT a.id,a.{datafield} AS payload FROM {table} a LEFT JOIN {table} b ON b.role='client' AND b.id=a.id{other} WHERE a.role='host'{settled} AND b.id IS NULL"
            for row in self.store.execute(sql):
                key=json.loads(row['id']);tick=key[1]
                if key[0]!=self.plan['epoch'] or tick<=self.roles['client'].ready['row']['baseline']:continue
                need(len(classification['raw_missing_'+label]) < BOUNDS['missing_rows'], 'missing-row bound')
                matches=_inside(tick,self.gaps)
                classified=dict(key=key,authority_body_sha256=hashlib.sha256(_body(row['payload'])).hexdigest(),
                    disposition='UNOBSERVED_PAST' if matches else 'MISSING_OUTSIDE_QUALIFIED_GAP',
                    gap_ids=[g['id'] for g in matches],previously_settled=any(tick<=g['previously_confirmed'] for g in matches),
                    raw_reference=dict(artifact=self.bundle.store.sha256,table=table,role='host',id=row['id']))
                classification['raw_missing_'+label].append(key);classification['classified_'+label].append(classified)
        gate=guard_raw_strict(self.raw,classification)
        need(gate['status']=='ALLOW_MISSING_ONLY_CLASSIFICATION','strict integrity/missing classification failed: '+repr(gate['findings']))
        # No other controller failure can be hidden behind a missing-only raw list.
        need(self.report.get('error') in (None,repr(self.raw['findings'])), 'independent controller error remains')
        self.summary['exact_missing_classification']=classification;self.summary['raw_missing_guard']=gate
        # Complete control coverage after actual admission, including None controls.
        expected=(self.plan['target_tick']-self.admission)*2
        if self.plan['framework']=='kit':
            counts=_kit_control_coverage(self.store,self.plan['epoch'],self.admission,self.plan['target_tick'],
                {role:value.ready['row'].get('players') for role,value in self.roles.items()})
            count=counts['host']
        else:
            count=0
            for row in self.store.execute("SELECT id,body FROM decisions WHERE role='host'"):
                key=json.loads(row['id'])
                if key[0]==self.plan['epoch'] and self.admission<key[1]<=self.plan['target_tick'] and key[3]==0:
                    need(key[2] in (1,2), 'unexpected control seat');count+=1
        need(count==expected,'authority per-tick control coverage unavailable',Unavailable)
        self.summary['authority_controls']=dict(required=expected,actual=count)
        # Retain the existing P3.5 prohibition on NEW skipped-past cosmetics.
        for event in self.events.execute("SELECT id,body FROM events WHERE role='client' AND kind IN ('FX','EFFECT') ORDER BY id"):
            row=json.loads(event['body']);phase=str(row.get('phase','commit')).lower()
            confirmed=row.get('confirmed',phase in ('commit','confirm','confirmed'))
            if type(confirmed) is int:confirmed=row['tick']<=confirmed
            if confirmed and phase in ('begin','commit','confirmed'):
                need(not any(event['id']>g['id'] for g in _inside(row['tick'],self.gaps)), 'skipped past cosmetic newly started after recovery')

    def intents_and_cycles(self):
        authority={}
        for event in self.roles['host'].actions:
            a=event['row'];key=(a['epoch'],a['seat'],a['sequence'])
            need(a.get('accepted') is True and key not in authority,'unadmitted/duplicate authority action')
            authority[key]=event
        _slot_history(authority.values())
        joins=[]
        for name,role in self.roles.items():
            need(role.ready['row'].get('action_timing','Scheduled') in ('Scheduled','Receipt'),'unknown action policy')
            endpoint=SimpleNamespace(framework=self.plan['framework'],role=name,ready=role.ready['row'],
                issued=[e['row'] for e in role.issues],issue_marks=[(e['id'],e['row']) for e in role.issues],
                status_marks=[(e['id'],dict(e['row'],event=e['kind'])) for e in role.marks])
            catalog=verify_kit_intent_catalog(endpoint)
            need(self.plan['framework']!='kit' or catalog is not None, 'Kit public publication/reset-chain contract unavailable')
            seen=set()
            for event in role.issues:
                a=event['row'];key=(a['epoch'],a['seat'],a['sequence'])
                need(key not in seen and integer(key[2],'issue sequence',1)>0,'issued identity reused');seen.add(key)
                requested=a['requested_tick'];original=a.get('original_requested_tick',requested);sampled=a.get('sampled_tick',a['submitted_tick']);submitted=a['submitted_tick']
                need(requested<=sampled<=requested+8 and sampled<=submitted<=sampled+7 and sampled==a['sampled_head']+1,'actual sample/submission bound')
                if catalog is not None:need(key in catalog,'Kit publication/reset-chain proof missing')
                elif a.get('rebased_before_sampling',False):
                    matching=[g for g in self.gaps if g['id']<event['id'] and g['marker']['row'].get('new_serial')==a['recovery_serial']]
                    need(matching,'unsampled rebase lacks actual prior marker')
                    rec=matching[-1]['marker']['row']
                    need(rec['old_head']<original<=rec['new_head'] and requested==rec['new_head']+1,'invalid unsampled rebase')
                else:need(original==requested,'issued target retargeted without actual reset')
                need(key in authority,'ISSUED lacks immutable authority decision')
                decision=authority[key]['row'];kind=action_name(a['kind'])
                need(action_name(decision['kind'])==kind,'issued/authority kind mismatch')
                policy=role.ready['row'].get('action_timing','Scheduled')
                need(a.get('action_timing','Scheduled')==policy,'issued timing policy mismatch')
                if policy=='Scheduled':
                    need(decision['tick']==submitted,'Scheduled target changed')
                if policy=='Receipt':
                    need(decision.get('action_timing')=='Receipt' and isinstance(decision.get('reason'),str) and decision['reason'], 'Receipt identity/reason unavailable')
                    need(all(decision.get(k)==a.get(k) for k in ('generation','serial')), 'Receipt issued scope changed')
                phase=PHASES.get(kind);need(phase is not None and original>=phase and (original-phase)%240==0,'wrong original scenario cycle')
                cycle=(original-phase)//240
                joins.append(dict(role=name,issue_id=event['id'],issued=a,authority=decision,cycle=cycle))
        need(len(joins)==len(authority),'authority action lacks one actual issue join')
        policies={r.ready['row'].get('action_timing','Scheduled') for r in self.roles.values()};need(len(policies)==1,'sibling timing contracts differ')
        policy=next(iter(policies))
        if policy=='Receipt':
            left,right=(r.ready['row'] for r in self.roles.values())
            need(left['contract']==right['contract'] and integer(left['contract'],'Receipt contract',1)>0 and
                 all(hash_ok(left[k]) and left[k]==right[k] for k in ('game_rules','game_schema')),'Receipt identities differ')
        for seat in (1,2):
            ordered=sorted((x['row'] for x in authority.values() if x['row']['seat']==seat),key=lambda a:a['sequence'])
            need(all(a['tick']<=b['tick'] for a,b in zip(ordered,ordered[1:])),'per-seat authority FIFO changed')
        cycles=[]
        for cycle in range(BOUNDS['cycles']):
            due=40+240*cycle;start,end=due-1,due+239
            if end>self.plan['target_tick']:break
            items=[j for j in joins if j['cycle']==cycle]
            row=dict(epoch=self.plan['epoch'],cycle=cycle,spawn_original_due=due,start=start,end=end,status='NOT_VERIFIED',reasons=[])
            if self.admission>start:row['reasons'].append('admission-partial')
            if any(g['start_exclusive']<end and g['end_inclusive']>start for g in self.gaps):row['reasons'].append('recovery-interrupted')
            before=[t for t in self.matched if t<=start];after=[t for t in self.matched if t>=end]
            if not before or not after:row['reasons'].append('complete boundary evidence unavailable')
            pair=[j for j in items if action_name(j['issued']['kind'])=='Spawn']
            if not row['reasons']:
                need(len(pair)==2 and {j['issued']['seat'] for j in pair}=={1,2},'intact cycle missing actual Spawn issues')
                if any(j['issued'].get('rebased_before_sampling',False) or not start<=j['authority']['tick']<=end for j in pair):row['reasons'].append('pair rebased/crossed cycle')
                else:
                    try:
                        proof=_long_spawn_pair(pair,authority.values(),policy)
                        row['contested_pair']=proof
                    except NotContested as error:row['reasons'].append('not contested: '+str(error))
                kinds={action_name(j['authority']['kind']) for j in items if j['authority']['applied'] and start<=j['authority']['tick']<=end}
                if kinds!=set(PHASES):row['reasons'].append('all six successful kinds not observed in SAME original cycle')
            if not row['reasons']:row['status']='VERIFIED_CONTESTED_COMPLETE'
            row['issue_keys']=[[j['issued']['epoch'],j['issued']['seat'],j['issued']['sequence']] for j in items]
            cycles.append(row)
        need(cycles,'wholly scheduled cycles unavailable',Unavailable)
        verified=sum(x['status']=='VERIFIED_CONTESTED_COMPLETE' for x in cycles)
        last_gap=max((g['end_inclusive'] for g in self.gaps),default=self.admission)
        consecutive=best=0
        for row in cycles:
            if row['start']>=last_gap and row['status']=='VERIFIED_CONTESTED_COMPLETE':consecutive+=1;best=max(best,consecutive)
            else:consecutive=0
        need(verified>=120 and verified*5>=len(cycles)*4,'verified cycle count/density below frozen threshold')
        need(best>=60,'consecutive post-gap cycle coverage below60')
        need(any(json.loads(x[0])[1]>last_gap for x in self.store.execute("SELECT id FROM fx WHERE role='client' AND settled IS NOT NULL AND epoch=?",(_hex(self.plan['epoch']),))), 'nonempty actual future settled FX unavailable',Unavailable)
        self.summary['cycles']=dict(denominator=len(cycles),verified=verified,consecutive_after_last_gap=best,rows=cycles)
        self.summary['immutable_issue_joins']=joins

    def time_and_duration(self):
        go=[r.go['observed_at'] for r in self.roles.values()]
        target=[]
        for r in self.roles.values():
            frames=[f for f in r.frames if f['tick']==self.plan['target_tick']]
            need(frames,'actual target frame unavailable',Unavailable);target.append(frames[0]['observed_at'])
        need(all(x is not None for x in go+target),'actual duration observation unavailable',Unavailable)
        seconds=min(target)-max(go)
        need(seconds>=self.plan['execution']['minimum_wall_seconds'] and
             self.plan['target_tick']-self.admission>=self.plan['execution']['required_ticks'],'actual frozen wall/tick duration not reached')
        self.summary['duration']=dict(observed_seconds=seconds,after_both_GO=True,no_audit_or_cleanup_time=True,after_admission_ticks=self.plan['target_tick']-self.admission)

    def run(self):
        try:
            self.open();self.scan();self.processes_and_frames();self.qualified_gaps()
            self.missing_and_global();self.intents_and_cycles();self.time_and_duration()
        except Unavailable as error:self.add(error,True)
        except Exception as error:self.add(error)
        finally:
            for db in (self.events,self.store):
                if db is not None:db.close()
        for ref in (self.bundle.report,self.bundle.events,self.bundle.store):
            if Path(ref.path).is_file() and _sha(ref.path)!=ref.sha256:
                self.add('immutable input changed during classification')
        self.summary.update(result='FAIL' if self.failures else 'INCOMPLETE' if self.unavailable else 'PROSPECTIVE_LONG_COVERAGE_PASS',
            failures=self.failures,unavailable=self.unavailable,no_existing_report_or_result_changed=True,
            acceptance_scope='prospective coverage classification ONLY; CPU/impairment/other sibling/lifecycle/GateB remain separate')
        return self.summary


def classify(plan, bundle):
    """Return a report; never write artifacts, launch, measure or mutate a store."""
    validate_plan(plan)
    return _Audit(plan,bundle).run()
