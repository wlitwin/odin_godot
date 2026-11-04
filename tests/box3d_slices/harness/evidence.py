"""Readonly verification of existing framework diagnostics, never solver import."""
from __future__ import annotations
from dataclasses import dataclass
from pathlib import Path
import hashlib
import json
import struct

PART_NAMES = ('Solver', 'Game', 'Side', 'Observations', 'Occurrences')
MAX_PART = 1024 * 1024
MAX_FRAME = 2 * 1024 * 1024
MAX_FRAMES = 2048
PROFILE = 0x534C494345503031
ACTION_NAMES = ('None', 'Spawn', 'Remove', 'Motor', 'Sleep', 'Wake', 'Query')

class EvidenceError(RuntimeError):
    pass


def require(condition, message):
    if not condition:
        raise EvidenceError(str(message))


def digest(data):
    return hashlib.sha256(data).hexdigest()


def json_bytes(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()


def strict_json(text):
    def pairs(items):
        result = {}
        for key, value in items:
            require(key not in result, ('duplicate JSON key', key))
            result[key] = value
        return result
    def bad_number(value):
        raise EvidenceError('nonfinite JSON number: ' + value)
    return json.loads(text, object_pairs_hook=pairs, parse_constant=bad_number)


def bounded_read(path, maximum):
    require(path.is_file(), ('missing artifact', str(path)))
    size = path.stat().st_size
    require(0 <= size <= maximum, ('artifact size limit', str(path), size))
    with path.open('rb') as stream:
        value = stream.read(maximum + 1)
    require(len(value) == size, ('artifact changed while reading', str(path)))
    return value


def signature(data, epoch=None, tick=None):
    require(len(data) == 480 and data[:8] == b'OGB3SIG1', 'signature magic/size')
    require(struct.unpack_from('<II', data, 8) == (1, 0), 'signature version/reserved')
    require(hashlib.sha256(data[:448]).digest() == data[448:], 'signature checksum')
    require(all(struct.unpack_from('<IIII', data, 16)), 'missing format identity')
    require(struct.unpack_from('<Q', data, 32)[0] != 0, 'missing profile identity')
    require(all(any(data[off:off + 32]) for off in range(40, 232, 32)), 'zero schema/build identity')
    actual_epoch, actual_tick = struct.unpack_from('<QQ', data, 232)
    require(actual_epoch > 0, 'zero epoch')
    if epoch is not None:
        require((actual_epoch, actual_tick) == (epoch, tick), 'signature frame metadata')
    lengths = [struct.unpack_from('<Q', data, 248 + 40 * i)[0] for i in range(5)]
    require(lengths[0] > 0 and max(lengths) <= MAX_PART and sum(lengths) <= MAX_FRAME, 'signature part bounds')
    return actual_epoch, actual_tick, lengths


@dataclass(frozen=True)
class Frame:
    epoch: int
    tick: int
    sig: bytes
    paths: tuple[Path, ...]
    observation: dict

    def parts(self):
        result = []
        _, _, lengths = signature(self.sig, self.epoch, self.tick)
        for index, path in enumerate(self.paths):
            data = bounded_read(path, MAX_PART)
            require(len(data) == lengths[index], ('part length', PART_NAMES[index], self.epoch, self.tick))
            require(hashlib.sha256(data).digest() == self.sig[256 + 40 * index:288 + 40 * index],
                    ('part checksum', PART_NAMES[index], self.epoch, self.tick))
            result.append(data)
        return result


def load_frame(root, record):
    epoch, tick = int(record['epoch']), int(record['tick'])
    require(record.get('confirmed', tick) >= tick, ('unconfirmed diagnostic', epoch, tick))
    name = record.get('basePath', record.get('base_path', record.get('prefix')))
    require(isinstance(name, str) and name, 'FRAME must identify actual artifact prefix')
    prefix = Path(name)
    if not prefix.is_absolute():
        prefix = root / prefix
    if prefix.suffix == '.sig':
        prefix = prefix.with_suffix('')
    root = root.resolve()
    paths = tuple(Path(str(prefix) + suffix).resolve() for suffix in ('.sig', '.part0', '.part1', '.part2', '.part3', '.part4'))
    require(all(path.is_relative_to(root) for path in paths), 'artifact escapes endpoint evidence directory')
    sig = bounded_read(paths[0], 480)
    signature(sig, epoch, tick)
    frame = Frame(epoch, tick, sig, paths[1:], record)
    frame.parts()  # Validate bytes when endpoint publishes the observation.
    return frame


def input_tail(records, limit=65536):
    records = list(records)[-32:]
    while records:
        encoded = json_bytes(records)
        if len(encoded) <= limit:
            return encoded
        records.pop(0)
    return b'[]'


def preserve_mismatch(out, expected, actual, accepted, predicted):
    """Exact diagnostic trace1; read-only comparison has no active rewind."""
    out.mkdir(parents=True, exist_ok=False)
    left, right = expected.parts(), actual.parts()
    for side, frame, parts in (('expected', expected, left), ('actual', actual, right)):
        (out / (side + '.sig')).write_bytes(frame.sig)
        for index, data in enumerate(parts):
            (out / f'{side}.part{index}').write_bytes(data)
    a, b = input_tail(accepted), input_tail(predicted)
    payload = b''.join(left + right) + a + b
    total = 1040 + len(payload) + 32
    header = struct.pack('<8sIIQQQQIIQQQ', b'OGB3TRC1', 1, 0,
                         expected.tick, expected.tick, 1, 0, 0, 0, len(a), len(b), total)
    header += expected.sig + actual.sig
    require(len(header) == 1040, 'internal trace header')
    body = header + payload
    trace = out / 'first.trace'
    trace.write_bytes(body + hashlib.sha256(body).digest())
    context = dict(kind='readonly_confirmed_comparison', from_tick=expected.tick, to_tick=expected.tick,
                   depth=0, source=1, sequence=0, sequence_meaning='unavailable; not an active received correction',
                   accepted='actual authority ledger observations', predicted='actual client used-input observations')
    (out / 'context.json').write_bytes(json_bytes(context) + b'\n')
    return dict(path=str(trace), sha256=digest(trace.read_bytes()), context=context)


def action_name(value):
    if isinstance(value, int) and not isinstance(value, bool):
        require(0 <= value < len(ACTION_NAMES), ('unknown action kind', value))
        return ACTION_NAMES[value]
    name = str(value).lstrip('.').lower()
    for known in ACTION_NAMES:
        if name == known.lower():
            return known
    raise EvidenceError(('unknown action kind', value))


def semantic_record(record):
    return {key: value for key, value in record.items() if key not in ('framework', 'role', 'actor', 'event', 'pid', 'process_generation', 'observed_at')}


class EndpointEvidence:
    def __init__(self, framework, role, root):
        self.framework, self.role, self.root = framework, role, root
        self.ready = None
        self.result = None
        self.session_exit = None
        self.frames = {}
        self.actions = []
        self.issued = []
        self.issue_marks = []
        self.recovery_marks = []
        self.accepted = []
        self.predicted = []
        self.effects = []
        self.effect_marks=[]
        self.statuses = []
        self.status_marks=[]
        self.require_go=False
        self.go_seen=False
        self.events = 0
        self.errors = []

    def receive(self, kind, record):
        require(isinstance(record, dict), 'endpoint observation must be object')
        require(record.get('framework', self.framework) == self.framework, 'wrong framework observation')
        require(record.get('role', self.role) in (self.role,getattr(self,'app_role',self.role)), 'wrong role observation')
        if 'actor' in record:require(record['actor']==self.role,'diagnostic actor label differs from owned process')
        self.events += 1
        require(self.events <= 20000, 'endpoint observation count bound')
        if kind == 'ERROR':
            self.errors.append(record)
        elif kind == 'READY':
            require(self.ready is None, 'duplicate READY')
            require(record.get('ready', True) is True, 'READY does not establish protocol readiness')
            self.ready = record
        elif kind == 'GO':
            require(self.ready is not None and not self.go_seen,'GO before complete role readiness or duplicateGO')
            self.go_seen=True
            self.statuses.append(dict(record,event=kind))
        elif kind == 'FRAME':
            require(self.ready is not None, 'confirmed FRAME before complete READY')
            frame = load_frame(self.root, record)
            if self.require_go and frame.tick>self.baseline[1]:require(self.go_seen,'application frame before observed GO')
            require(struct.unpack_from('<Q', frame.sig, 32)[0] == PROFILE, 'wrong common profile')
            key = frame.epoch, frame.tick
            if key in self.frames:
                require(self.frames[key].sig == frame.sig, ('published confirmed frame changed', key))
            else:
                require(len(self.frames) < MAX_FRAMES, 'confirmed frame count bound')
                self.frames[key] = frame
        elif kind in ('APPLIED', 'ACTION'):
            require(isinstance(record.get('applied'), bool), 'action must contain actual boolean verdict')
            action_name(record['kind'])
            self.actions.append(record)
        elif kind in ('ISSUED','SUBMITTED'):
            if self.require_go:require(self.go_seen,'gameplay intent before observed GO')
            self.issued.append(record)
            self.issue_marks.append((self.events,record))
        elif kind in ('ACCEPTED','INPUT'):
            self.accepted.append(record)
        elif kind in ('PREDICTED', 'USED_INPUT'):
            self.predicted.append(record)
        elif kind in ('FX', 'EFFECT'):
            # Payload must be actual delivered presentation data, not an expected occurrence.
            require('payload' in record or all(key in record for key in ('serial', 'lifetime', 'seat', 'kind')),
                    'FX lacks actual payload')
            self.effects.append(record)
            self.effect_marks.append((self.events,record))
        elif kind == 'CLOSE_TRACE':
            require(self.framework=='kit' and record.get('stage') in ('wire_enter','wire_exit'),
                    'unknown Kit wire cleanup stage')
            self.statuses.append(dict(record,event=kind))
            self.status_marks.append((self.events,dict(record,event=kind)))
        elif kind == 'SESSION_EXIT':
            require(getattr(self,'app_role',self.role)=='client' and self.session_exit is None
                    and self.result is None,'duplicate or non-Client interim session exit')
            self.session_exit=record
            self.statuses.append(dict(record,event=kind))
            self.status_marks.append((self.events,dict(record,event=kind)))
        elif kind in ('INTENT_BASELINE','MEMBER'):
            require(self.framework=='replay','Replay rejoin record from another framework')
            if kind=='MEMBER':require(record.get('stage') in ('running','disconnected'),'unknown public membership stage')
            else:require(not any(x['event']=='INTENT_BASELINE' for x in self.statuses),'duplicate first-Welcome intent baseline')
            self.statuses.append(dict(record,event=kind))
            self.status_marks.append((self.events,dict(record,event=kind)))
        elif kind in ('INTENT_ATTEMPT', 'INTENT_REBASE', 'INTENT_UNEXERCISED'):
            require(self.framework == 'kit', 'Kit intent catalog record from another framework')
            if self.require_go:require(self.go_seen,'intent catalog activity before observed GO')
            self.statuses.append(dict(record,event=kind))
            self.status_marks.append((self.events,dict(record,event=kind)))
            if kind == 'INTENT_UNEXERCISED':self.errors.append(record)
        elif kind in ('STATUS', 'BASELINE', 'STAGE', 'BOOT', 'WAIT', 'RECOVERY_REQUESTED', 'RECOVERED', 'TAIL', 'RECOVERY', 'FLOW','PUMP','PLAYER_LEFT','RECOVERY_REQUEST_OBSERVED','RECOVERY_WIRE','RECOVERY_WAIT','LIMITS','ENVELOPE','LEDGER'):
            self.statuses.append(dict(record, event=kind))
            self.status_marks.append((self.events,dict(record,event=kind)))
            if kind=='RECOVERY':self.recovery_marks.append((self.events,record))
        elif kind == 'RESULT':
            require(self.result is None and self.session_exit is None, 'duplicate RESULT or final result after interim exit')
            self.result = record
        else:
            raise EvidenceError(('unknown observation', kind))

    @property
    def baseline(self):
        require(self.ready is not None, 'missing complete READY')
        return int(self.ready.get('epoch', 1)), int(self.ready.get('baseline',self.ready.get('confirmed', self.ready.get('tick', 0))))

    def teardown(self, exit_code, *, interim=False):
        require(exit_code == 0, (self.role, 'nonzero process exit', exit_code))
        value=self.session_exit if interim else self.result
        require(value is not None, (self.role, 'missing SESSION_EXIT' if interim else 'missing RESULT'))
        for flag in ('native_stats_ok','stats_ok'):
            if flag in value:
                require(value[flag] is True,(self.role,'cleanup counters not successfully queried',flag))
        if 'cleanup' in value:
            require(value['cleanup'] in ('None','Ok','OK',0), (self.role,'cleanup status',value['cleanup']))
        require(value.get('success', value.get('ok', True)) is True, (self.role, 'endpoint reported failure'))
        def metric(names):
            for name in names:
                if name in value:
                    result = value[name]
                    require(type(result) is int and result == 0, (self.role, 'nonzero cleanup', name, result))
                    return result
            raise EvidenceError((self.role, 'missing explicit cleanup metric', names))
        result = dict(engine=metric(('engine_live', 'native_live', 'engine_live_bytes')),
                      wrapper=metric(('wrapper_live', 'snapshot_live', 'wrapper_live_bytes')),
                      meter=metric(('meter_live', 'meter_live_bytes', 'host_producer_live')))
        if 'managed_callbacks_live' in value:
            result['managed_callbacks'] = metric(('managed_callbacks_live',))
            require(value.get('callback_status') == 0, (self.role,'managed callback stats query failed'))
        if any(name in value for name in ('owners_live','owner_live','owners')):
            result['owners'] = metric(('owners_live','owner_live','owners'))
        else:
            result['cleanup_errors'] = metric(('cleanup_errors',))
            result['owner_evidence'] = 'successful explicit owner drops + retained Meter bytes0 + checked Core shutdown no-not-empty; no direct owner count claimed'
        return result


def effects(endpoint, epoch, baseline, end):
    result, active = {}, {}
    for item in endpoint.effects:
        if int(item['epoch']) != epoch or not baseline < int(item['tick']) <= end:
            continue
        phase = str(item.get('phase', 'commit' if endpoint.framework == 'kit' else 'confirmed')).lower()
        identity = [item['source'],item['key']] if 'source' in item and 'key' in item else item.get('id', item.get('key',item.get('serial')))
        require(identity is not None, 'FX has no stable ID')
        key = json_bytes([epoch,int(item['tick']),identity])
        payload = item.get('payload', {k: item[k] for k in ('serial','lifetime','seat','kind','event_kind','applied','sequence','result','action') if k in item})
        value = dict(tick=int(item['tick']), payload=payload)
        confirmed = item.get('confirmed', phase in ('confirm','confirmed','commit'))
        if endpoint.framework=='kit' and type(confirmed) is int:
            confirmed = int(item['tick']) <= confirmed
        require(isinstance(confirmed,bool), 'FX confirmed must be boolean')
        if phase == 'begin':
            require(key not in active and key not in result, ('duplicate Begin', endpoint.role, key.decode()))
            active[key] = value
            if not confirmed:
                continue
        elif phase == 'update':
            require(key in active and key not in result, ('Update without unsettled Begin',endpoint.role,key.decode()))
            active[key] = value
            continue
        elif phase == 'cancel':
            require(key in active and key not in result, ('Cancel without unsettled Begin',endpoint.role,key.decode()))
            active.pop(key)
            continue
        elif phase == 'confirm':
            require(key in active, ('Confirm without Begin',endpoint.role,key.decode()))
            require(active[key] == value, ('confirmed effect payload changed without Update',endpoint.role,key.decode()))
        else:
            require(phase in ('commit', 'confirmed'), ('unknown FX phase', phase))
        require(confirmed and key not in result, (endpoint.role,'duplicate/unconfirmed effect settlement',key.decode()))
        result[key] = value
    return result


def observed_recovery_gaps(endpoint, epoch):
    """Only explicitly validated complete rebases may bound unobserved past."""
    gaps=[]
    for order,record in endpoint.recovery_marks:
        if int(record['epoch'])!=epoch:continue
        require(record['cause']=='canonical_welcome' and record['old_serial']>0 and record['new_serial']>record['old_serial'],('recovery serial evidence',record))
        require(record['new_baseline']>record['old_baseline'] and record.get('view_reset',0)>0 and (record.get('resyncs',0)>0 or record.get('snapshot_catchups',0)>0),('recovery baseline/resync evidence',record))
        start,end=int(record['old_head']),int(record['new_baseline'])
        require(int(record['new_head'])>=end,'recovered publication before complete baseline')
        if end>start:gaps.append(dict(start_exclusive=start,end_inclusive=end,order=order,evidence=record))
    pending=None
    for mark,record in endpoint.status_marks:
        if record['event']=='RECOVERY_REQUESTED':
            require(pending is None and record.get('published_preserved') is True and record.get('request_status') in (0,'Ok','OK'),'invalid/repeated public reset request')
            pending=record
        elif record['event']=='RECOVERED':
            require(pending is not None,'complete Reset without its recorded request')
            require(record['previous_head']==pending['head'] and record['previous_confirmed']==pending['confirmed'],'Reset previous publication evidence differs')
            if int(record['epoch'])==epoch:
                start,end=int(record['previous_confirmed']),int(record['baseline'])
                require(record['previous_confirmed']==pending['confirmed'],'Kit settled delivery boundary not observed at actual request')
                if end>start:gaps.append(dict(start_exclusive=start,end_inclusive=end,order=mark,boundary='actual pre-request public confirmed tick; Kit FX logs confirmed_events only',evidence=dict(request=pending,recovered=record)))
            pending=None
    require(pending is None,'unfinished public Reset')
    return gaps


def in_gap(tick,gaps):return any(x['start_exclusive']<tick<=x['end_inclusive'] for x in gaps)


def eligible_effects(authority, follower, epoch, baseline, end):
    gaps=observed_recovery_gaps(follower,epoch)
    expected=effects(authority,epoch,baseline,end)
    actual=effects(follower,epoch,baseline,end)
    # Keep duplicate/lifecycle checks over the FULL stream (effects() above).
    # A complete reset cannot newly start skipped past cosmetics after import.
    for order,item in follower.effect_marks:
        phase=str(item.get('phase','commit' if follower.framework=='kit' else 'confirmed')).lower()
        confirmed=item.get('confirmed',phase in ('commit','confirmed','confirm'))
        if follower.framework=='kit' and type(confirmed) is int:confirmed=int(item['tick'])<=confirmed
        if int(item['epoch'])!=epoch or not confirmed or phase not in ('begin','commit','confirmed'):continue
        for gap in gaps:
            if gap['order'] and order>gap['order'] and gap['start_exclusive']<int(item['tick'])<=gap['end_inclusive']:
                raise EvidenceError(('skipped past cosmetic replayed after complete recovery',item,gap))
    left={k:v for k,v in expected.items() if not in_gap(v['tick'],gaps)}
    right={k:v for k,v in actual.items() if not in_gap(v['tick'],gaps)}
    require(left,'authority eligible delivered effect evidence absent')
    require(left==right,('delivered confirmed effect ID/payload mismatch',{'missing':len(left.keys()-right.keys()),'extra':len(right.keys()-left.keys()),'changed':sum(left[k]!=right[k] for k in left.keys()&right.keys())}))
    future=[]
    if gaps:
        last=max(x['end_inclusive'] for x in gaps)
        future=[v for v in right.values() if v['tick']>last]
        require(future,'no matched nonempty future effect suffix after recovery')
        require(any(key[0]==epoch and key[1]>last for key in authority.frames.keys()&follower.frames.keys()),'no matched retained future state after recovery')
    return dict(matched=len(right),gaps=gaps,excluded_authority=[v for v in expected.values() if in_gap(v['tick'],gaps)],post_recovery_matched_effects=future,full_stream_authority_count=len(expected),full_stream_actual_count=len(actual))


def kit_intent_contract_version(ready):
    version=ready.get('intent_contract_version',1)
    require(type(version) is int and version in (1,2),'unknown or incorrectly typed Kit intent contract')
    return version


def _kit_intent_u64(row, field, minimum=0):
    value=row.get(field)
    require(type(value) is int and minimum<=value<2**64,('invalid V2 intent integer',field,value))
    return value


def verify_kit_intent_catalog(endpoint):
    """Join public publication records to candidate attempts and actual resets.

    Multiple resets may move an unsampled intent repeatedly. Each link starts
    at its current due tick; its original scenario tick remains immutable.
    """
    version=kit_intent_contract_version(endpoint.ready)
    require(endpoint.framework=='kit' or version==1,'Replay cannot opt into Kit intent contract2')
    if endpoint.ready.get('intent_source') != 'outside_sim_catalog_class1':
        require(version==1,'Kit intent contract2 requires the existing intent catalog')
        return None
    require(endpoint.framework == 'kit' and endpoint.ready.get('action_timing') == 'Scheduled',
            'intent catalog changed the existing Kit timing policy')
    states={}
    recovered=[]
    issued={}
    last_issued={}
    attempted_keys=set()
    events=sorted(endpoint.status_marks+[(at,dict(item,event='ISSUED')) for at,item in endpoint.issue_marks],key=lambda x:x[0])
    for order,item in events:
        event=item['event']
        if event=='RECOVERED':
            recovered.append((order,item))
            continue
        if event not in ('INTENT_ATTEMPT','INTENT_REBASE','INTENT_UNEXERCISED','ISSUED'):continue
        require(event!='INTENT_UNEXERCISED',('required fresh intent unexercised',item))
        key=(int(item['epoch']),int(item['seat']),int(item['original_requested_tick']))
        require(key[0]>0 and key[1] in (1,2) and key[2]>0,('invalid scenario intent identity',item))
        if version==2:
            require(item.get('framework','kit')=='kit'
                    and item.get('role',endpoint.role)==endpoint.role
                    and item.get('actor',endpoint.role)==endpoint.role,('V2 intent actor differs',item))
            require((_kit_intent_u64(item,'epoch',1),_kit_intent_u64(item,'seat',1))==
                    (_kit_intent_u64(endpoint.ready,'epoch',1),_kit_intent_u64(endpoint.ready,'seat',1)),
                    ('V2 intent actor epoch/seat differs',item))
            require(_kit_intent_u64(item,'session_generation')==
                    _kit_intent_u64(endpoint.ready,'session_generation'),('V2 intent generation differs',item))
            _kit_intent_u64(item,'original_requested_tick',1)
        state=states.setdefault(key,dict(due=key[2],links=[],attempt=None,committed=False))
        require(not state['committed'],('published intent changed or issued twice',item))
        if event=='INTENT_REBASE':
            require(item['cause']=='validated_reset' and item['committed'] is False,('invalid fresh intent rebase',item))
            old_due,new_due=int(item['old_current_due']),int(item['new_current_due'])
            old_head,new_head=int(item['old_head']),int(item['new_head'])
            old_serial,new_serial=int(item['old_serial']),int(item['new_serial'])
            marker=kit_intent_contract_version(item)
            require(marker==version,('intent rebase contract differs from READY',item))
            if version==1:
                require(old_due==state['due'] and old_head<old_due<=new_head and new_due==new_head+1,
                        ('broken current-due reset chain',item,state))
            else:
                for field in ('old_current_due','new_current_due','old_head','new_head','old_serial','new_serial'):
                    _kit_intent_u64(item,field)
                require(key not in attempted_keys and state['attempt'] is None,
                        ('attempted intent cannot be rebased under V2',item))
                for field in ('pre_attempted','pre_published','pre_transported'):
                    require(type(item.get(field)) is bool and item[field] is False,
                            ('V2 rebase lacks wholly unattempted pre-state',field,item))
                for field in ('pre_attempt_tick','pre_attempt_head','pre_packet_head','pre_row_sequence'):
                    require(_kit_intent_u64(item,field)==0,('V2 rebase has prior identity',field,item))
                prior_serial=int(state['links'][-1]['new_serial']) if state['links'] else 0
                require(_kit_intent_u64(item,'pre_recovery_serial')==prior_serial<=old_serial,
                        ('V2 prior recovery scope changed',item))
                require(_kit_intent_u64(item,'player',1)==_kit_intent_u64(endpoint.ready,'me',1)
                        and _kit_intent_u64(item,'class')==1,('V2 intent player/class differs',item))
                require(old_due==state['due'] and old_due<=new_head<2**64-1
                        and new_due==new_head+1 and new_due<=_kit_intent_u64(endpoint.ready,'target',1),
                        ('broken V2 unattempted current-due reset chain',item,state))
            require(new_serial>old_serial>=0,('reset received watermark did not advance',item))
            matching=[r for at,r in recovered if at<order and int(r['epoch'])==key[0]
                      and int(r['request_sequence'])==old_serial and int(r['received_sequence'])==new_serial
                      and int(r['previous_head'])==old_head and int(r['baseline'])==new_head
                      and (version==1 or (type(r.get('session_generation')) is int and
                           r['session_generation']==endpoint.ready['session_generation'] and
                           r.get('role',endpoint.role)==endpoint.role and
                           r.get('actor',endpoint.role)==endpoint.role))]
            require(len(matching)==1,('intent rebase lacks one preceding validated Reset',item))
            reset=matching[0]
            require(int(reset['head'])>=new_head and int(reset['confirmed'])>=new_head,'reset publication is incomplete')
            signature(bytes.fromhex(reset['signature_hex']),key[0],new_head)
            if version==2:
                for field in ('epoch','request_sequence','received_sequence','previous_head','baseline','head','confirmed'):
                    _kit_intent_u64(reset,field)
                require(_kit_intent_u64(reset,'previous_confirmed')<=old_head,
                        ('V2 Reset prior publication differs',item))
            state['due']=new_due
            state['attempt']=None
            state['links'].append(item)
            continue
        require(int(item['requested_tick'])==state['due'],('intent due changed without Reset chain',item))
        sampled=int(item['sampled_tick'])
        require(state['due']<=sampled<=state['due']+8 and sampled==int(item['sampled_head'])+1,
                ('intent candidate outside current input window',item))
        if event=='INTENT_ATTEMPT':
            require(item['candidate_only'] is True,'candidate attempt claimed publication')
            state['attempt']=item
            if version==2:attempted_keys.add(key)
            continue
        require(item['published'] is True and item['transport']=='existing_class1_input_stream',
                ('issued intent lacks existing input publication/transport proof',item))
        require(item['action_timing']=='Scheduled','Kit issued intent timing changed')
        require(int(item['submitted_tick'])==sampled and int(item['sequence'])==sampled
                and sampled<=int(item['packet_head'])<=sampled+7,('issued input row/packet identity differs',item))
        attempt=state['attempt']
        require(attempt is not None and int(attempt['sampled_tick'])==sampled
                and int(attempt['sampled_head'])==int(item['sampled_head']),('publication lacks its candidate attempt',item))
        require(item['rebased_before_sampling'] is bool(state['links']),('incorrect fresh rebase declaration',item))
        serial=int(item['recovery_serial'])
        require(serial==(int(state['links'][-1]['new_serial']) if state['links'] else 0),
                ('issued input does not retain its last reset chain',item))
        state['committed']=True
        if version==2:
            sequence=_kit_intent_u64(item,'sequence',1)
            require((key[0],key[1],sequence) not in issued and sequence>last_issued.get(key[:2],0),
                    ('V2 issued sequence duplicated or FIFO changed',item))
            last_issued[key[:2]]=sequence
        issued[(key[0],key[1],int(item['sequence']))]=dict(original_requested_tick=key[2],links=state['links'])
    return issued


def verify_spawn_conflict(actions, policy):
    """Both intents must exercise the same occupied-slot predicate.

    Scheduled intents execute together in semantic seat order. Receipt intents
    execute when admitted, so the remote request may win before the host's.
    """
    require(policy in ('Scheduled','Receipt'),'unknown Spawn timing policy')
    first=[]
    for seat in (1,2):
        entries=[x for x in actions if int(x['seat'])==seat and action_name(x['kind'])=='Spawn']
        require(entries,('missing actual Spawn decision for seat',seat))
        first.append(min(entries,key=lambda x:(int(x['tick']),int(x['sequence']))))
    require(all(x.get('accepted') is True for x in first),'Spawn conflict was not admitted')
    winners=[x for x in first if x['applied']]
    losers=[x for x in first if not x['applied']]
    require(len(winners)==len(losers)==1,'Spawn pair lacks one success and one predicate rejection')
    winner,loser=winners[0],losers[0]
    require(int(winner['tick'])<=int(loser['tick']),'Spawn rejection preceded occupied-slot success')
    require(not any(action_name(x['kind'])=='Remove' and x['applied']
                    and int(winner['tick'])<=int(x['tick'])<=int(loser['tick']) for x in actions),
            'Spawn pair crossed an intervening removal')
    if policy=='Scheduled' or winner['tick']==loser['tick']:
        require(winner['tick']==loser['tick'] and int(winner['seat'])==1 and int(loser['seat'])==2,
                'simultaneous Spawn did not follow semantic seat order')
    if policy=='Receipt':
        require(str(loser.get('reason','')).lower()=='predicate'
                and str(winner.get('reason','')).lower()=='none','Receipt Spawn rejected for a non-predicate reason')
    return dict(policy=policy,winner=winner,rejected=loser,
                execution_order='semantic seat order at a shared tick' if winner['tick']==loser['tick'] else 'actual authority Receipt execution order')


def verify_pair(host, client, ticks, compared):
    require(host.ready is not None and client.ready is not None, 'both endpoints must complete Welcome')
    epoch, baseline = client.baseline
    shared = sorted(key for key in host.frames.keys() & client.frames.keys() if key[0] == epoch and key[1] > baseline)
    require(shared and max(tick for _, tick in shared) - baseline >= ticks, ('missing confirmed tail', shared[-1:] if shared else [], ticks))
    require(len(compared) > 0, 'no exact confirmed five-part comparisons')
    common_end = shared[-1][1]
    policy=host.ready.get('action_timing','Scheduled')
    require(policy in ('Scheduled','Receipt'),'unknown declared action timing')
    require(client.ready.get('action_timing','Scheduled')==policy,'action timing contract differs')
    if policy=='Receipt':
        require(int(host.ready['contract'])==int(client.ready['contract']) and int(host.ready['contract'])>0,'Receipt negotiated contract differs')
        for name in ('game_rules','game_schema'):
            left,right=host.ready[name],client.ready[name]
            require(left==right and len(bytes.fromhex(left))==32 and any(bytes.fromhex(left)),('Receipt actual bound identity differs',name))
    verdicts = {}
    eligible = [x for x in host.actions if x['epoch'] == epoch and baseline < x['tick'] <= common_end]
    if policy=='Receipt':
        require(all(x.get('action_timing')=='Receipt' for x in eligible),'published Receipt policy not explicit')
    for name in ACTION_NAMES[1:]:
        entries = [x for x in eligible if action_name(x['kind']) == name and x['applied']]
        require(entries, ('no actual applied scripted action', name))
        verdicts[name] = entries
    rejected_spawn = [x for x in eligible if action_name(x['kind']) == 'Spawn' and not x['applied'] and int(x['seat']) == 2]
    spawn_conflict=verify_spawn_conflict(eligible,policy)
    # Compare actual overlapping decisions. Do not mistake a sampled request for verdict.
    index = lambda x: (x['epoch'], x['tick'], x['seat'], action_name(x['kind']))
    authority = {index(x): semantic_record(x) for x in eligible}
    overlap = 0
    for item in client.actions:
        key = index(item)
        if key in authority:
            require(semantic_record(item) == authority[key], ('accepted action/provenance differs', key))
            overlap += 1
    require(overlap > 0, 'no overlapping actual accepted action decisions')
    recovery=[]
    pending=False
    for record in client.statuses:
        if record['event']=='RECOVERY_REQUESTED':
            require(not pending, 'multiple reset requests before one validated recovery')
            require(record.get('published_preserved') is True, 'reset request changed published pair')
            require(record.get('request_status') in (0,'Ok','OK'), 'public reset request rejected')
            pending=True
            recovery.append(record)
        elif record['event']=='RECOVERED':
            require(pending, 'recovery without recorded public request')
            require(record['head']>=record['baseline'] and record['confirmed']>=record['baseline'], 'invalid recovered publication')
            pending=False
            recovery.append(record)
    require(not pending, 'unfinished full recovery')
    causality=[]
    for endpoint in (host,client):
        kit_catalog=verify_kit_intent_catalog(endpoint)
        seen_sequences=set()
        for order,item in endpoint.issue_marks:
            key=(int(item['epoch']),int(item['seat']),int(item['sequence']))
            require(key not in seen_sequences and key[2]>0, ('issued sequence reused',endpoint.role,key))
            seen_sequences.add(key)
            requested=int(item['requested_tick'])
            original=int(item.get('original_requested_tick',requested))
            sampled=int(item.get('sampled_tick',item['submitted_tick']))
            submitted=int(item['submitted_tick'])
            require(requested<=sampled<=requested+8 and sampled<=submitted<=sampled+7, ('actual sample/submission window',item))
            if 'sampled_head' in item:require(sampled==int(item['sampled_head'])+1, ('sample did not use current head',item))
            rebased=item.get('rebased_before_sampling',False)
            if kit_catalog is not None:
                require(key in kit_catalog,('issued Kit row lacks validated catalog publication',item))
            elif rebased:
                matching=[r for at,r in endpoint.recovery_marks if at<order and r['epoch']==key[0] and r['new_serial']==item['recovery_serial']]
                require(matching, ('fresh intent lacks prior observed rebase',item))
                r=matching[-1]
                require(r['cause']=='canonical_welcome' and r['old_serial']>0 and r['new_serial']>r['old_serial'] and r['new_baseline']>r['old_baseline'], ('invalid rebase evidence',r))
                require(r['old_head']<original<=r['new_head'] and requested==r['new_head']+1, ('unsampled threshold not crossed by rebase',item,r))
            else:
                require(original==requested, ('unexplained scenario intent retarget',item))
            published=[a for a in eligible if (a['epoch'],int(a['seat']),int(a['sequence']))==key and action_name(a['kind'])==action_name(item['kind'])]
            require(len(published)==1, ('issued intent lacks one actual published decision',item,published))
            actual=published[0]
            # This model uses the existing Scheduled action policy: successful
            # publication retains the packet's actual submitted target. Rejected
            # stale packets retain their real verdict rather than a fake retry.
            require(item.get('action_timing','Scheduled')==policy,'submitted timing differs from negotiated policy')
            if policy=='Scheduled' and (actual['applied'] or str(actual.get('reason','None')).lower()=='none'):
                require(actual['tick']==submitted, ('scheduled publication target changed',item,actual))
            if 'authority_execution_tick' in actual:require(actual['authority_execution_tick']==actual['tick'],'authority execution metadata differs from public decision')
            evidence=dict(role=endpoint.role,issued=item,published=actual)
            if kit_catalog is not None:evidence['reset_chain']=kit_catalog[key]['links']
            causality.append(evidence)
    for seat in (1,2):
        ordered=sorted((x for x in eligible if int(x['seat'])==seat),key=lambda x:int(x['sequence']))
        require(all(a['tick']<=b['tick'] for a,b in zip(ordered,ordered[1:])),'authority action FIFO order changed')
    fx=eligible_effects(host,client,epoch,baseline,common_end)
    return dict(epoch=epoch, welcome_baseline=baseline, confirmed_end=common_end,
                compared_confirmed_frames=len(compared), actual_verdicts=verdicts,
                rejected_second_spawn=rejected_spawn, spawn_conflict=spawn_conflict, overlapping_decisions=overlap,
                reconciled_effects=fx['matched'],effect_eligibility=fx,recovery=recovery,intent_causality=causality,action_timing=policy)


def verify_observer_cohort(endpoints, ticks, end_tick):
    """One bounded host/client/observer application barrier and terminal gate."""
    require(len(endpoints)==3,'observer cohort must have exactly3 independent actors')
    host,client,observer=endpoints
    require([x.role for x in endpoints]==['host','client','observer'],'cohort role mapping')
    expected={'host':(1,101),'client':(2,202),'observer':(0,303)}
    epochs=[]
    for endpoint in endpoints:
        epoch,baseline=endpoint.baseline
        epochs.append(epoch)
        require(baseline+ticks<=end_tick,('Welcome leaves insufficient cohort window',endpoint.role,baseline,ticks,end_tick))
        require((epoch,end_tick) in endpoint.frames,('missing actual retained cohort final',endpoint.role,end_tick))
        seat,token=expected[endpoint.role]
        require(int(endpoint.ready['seat'])==seat,('wrong semantic driver seat',endpoint.role,endpoint.ready))
        if 'token_hex' in endpoint.ready:
            raw=bytes.fromhex(endpoint.ready['token_hex'])
            require(len(raw)==16 and int.from_bytes(raw[:8],'little')==token,('token not fullwidth actual encoding',endpoint.role))
        else:
            require(int(endpoint.ready['token'])==token,('wrong declared actual token',endpoint.role))
        go=[x for x in endpoint.statuses if x['event']=='GO']
        require(len(go)==1,('missing/duplicate observed application GO',endpoint.role))
    require(len(set(epochs))==1,'cohort epochs differ')
    authority_go=[x for x in host.statuses if x['event']=='GO'][0]
    require(int(authority_go.get('ready_drivers',authority_go.get('drivers',0)))==2,'authority GO before both driver roles ready')
    require(int(authority_go.get('ready_observers',authority_go.get('observers',0)))==1,'authority GO before observer ready')
    require(not observer.issued,'observer submitted gameplay intent')
    require(not any(int(x['seat'])==0 for x in observer.actions),'observer acquired an input driver')
    flow={}
    if host.framework=='replay':
        for endpoint in endpoints:
            records=[x for x in endpoint.statuses if x['event']=='FLOW']
            require(records and any(x.get('stage')=='opened' for x in records) and any(x.get('stage')=='before_close' for x in records),('missing actual Link flow observations',endpoint.role))
            previous=0
            for item in records:
                require(item['snapshot_every']==1 and item['egress_per_second']==8*1024*1024 and item['egress_per_pump']==1024*1024 and item['burst_bytes']==1024*1024,('unexpected declared sample Link budget',item))
                require(item['bytes_per_lane']==256*1024 and item['packets_per_lane']==128,('sample Link queue bound changed',item))
                require(item['router_tx_bytes']>=previous,'router transmitted byte counter decreased')
                previous=item['router_tx_bytes']
            flow[endpoint.role]=records
    acked=set()
    for record in host.statuses:
        if record['event']!='TAIL' or record.get('stage')!='final_received':continue
        if int(record.get('tick',-1))!=end_tick:continue
        require(record.get('matched',True) is True,'authority accepted mismatching terminal signature')
        role=record.get('from_role',record.get('actor'))
        if role is None and 'head' in record and 'confirmed' in record:continue # own retained signature, not a follower ACK
        if role is None and 'token' in record:
            role={202:'client',303:'observer'}.get(int(record['token']))
        require(role in ('client','observer'),('terminal ACK lacks actual follower identity',record))
        acked.add(role)
    require(acked=={'client','observer'},'authority exited without both real terminal signature acknowledgements')
    epoch=epochs[0]
    common=set(host.frames)&set(client.frames)&set(observer.frames)
    for key in common:
        require(host.frames[key].sig==client.frames[key].sig==observer.frames[key].sig,('three-actor signature differs',key))
    return dict(epoch=epoch,end_tick=end_tick,minimum_confirmed_ticks_after_each_welcome=ticks,
                roles={x.role:dict(seat=expected[x.role][0],token=expected[x.role][1],baseline=x.baseline[1]) for x in endpoints},
                shared_three_actor_frames=len(common),shared_three_actor_keys=sorted(common),
                observer_issued=0,terminal_ack_roles=sorted(acked),application_go_observed=3, actual_link_flow=flow)


def verify_dedicated_cohort(endpoints,ticks,end_tick):
    require(len(endpoints)==3 and [x.role for x in endpoints]==['server','client1','client2'],'dedicated actor labels')
    server,c1,c2=endpoints
    require(int(server.ready['seat'])==0 and not server.issued,'dedicated authority acquired driver')
    require({int(c1.ready['seat']),int(c2.ready['seat'])}=={1,2},'admitted client seats must be a bijection, not forced by label')
    expected={'server':101,'client1':202,'client2':203};epoch=server.baseline[0]
    for node in endpoints:
        ep,baseline=node.baseline
        require(ep==epoch and baseline+ticks<=end_tick,'dedicated Welcome/end constraint')
        require((epoch,end_tick) in node.frames,'missing actual dedicated final frame')
        if node.framework=='kit':require(int(node.ready['token'])==expected[node.role],'Kit dedicated actual full-width token differs')
        else:
            token=bytes.fromhex(node.ready['token_hex'])
            require(len(token)==16 and int.from_bytes(token[:8],'little')==expected[node.role],'dedicated actual full-width token differs')
        go=[x for x in node.statuses if x['event']=='GO'];require(len(go)==1,'dedicated application GO missing/duplicate')
        if node.framework=='kit' and node is not server:
            require(go[0]['baseline']==baseline and go[0]['head']==baseline and go[0]['confirmed']==baseline,'Kit follower GO baseline/head/confirmation differs before prediction')
    authority_go=[x for x in server.statuses if x['event']=='GO'][0]
    require(authority_go['ready_drivers']==2 and authority_go['ready_observers']==0,'dedicated authority GO before two driver roles ready')
    acked=set()
    for row in server.statuses:
        if row['event']!='TAIL' or row.get('stage')!='final_received' or row.get('tick')!=end_tick:continue
        if row.get('from_role') is None and 'head' in row and 'confirmed' in row:continue # authority's own retained signature
        require(row.get('matched') is True and row.get('from_role')=='client','dedicated terminal signature receipt invalid')
        if server.framework=='kit':
            matches=[node for node in (c1,c2) if int(node.ready['me'])==int(row['from'])]
            require(len(matches)==1 and int(row['peer'])>0,'terminal receipt is not an admitted logical player')
            node=matches[0];value=expected[node.role]
            # Match the existing Session's declared token hash; diagnostic only,
            # never an authority/seat override or a protocol implementation.
            mask=(1<<64)-1;z=(value+0x9E3779B97F4A7C15)&mask
            z=((z^(z>>30))*0xBF58476D1CE4E5B9)&mask
            z=((z^(z>>27))*0x94D049BB133111EB)&mask
            require(int(row['from_token_hash'])==(z^(z>>31)),'Kit final receipt token differs from frozen admitted identity')
        else:
            token=bytes.fromhex(row['from_token_hex']);require(len(token)==16,'dedicated terminal token width')
            value=int.from_bytes(token[:8],'little');require(value in (202,203),'terminal receipt not an admitted client')
            node=c1 if value==202 else c2
            require(int(row['from_seat'])==int(node.ready['seat']) and int(row['from_generation'])>0 and int(row['from_peer'])>0,'terminal receipt identity differs from admitted client')
        acked.add(value)
    require(acked=={202,203},'dedicated authority exited without both actual token-bound final signatures')
    common=set(server.frames)&set(c1.frames)&set(c2.frames)
    require((epoch,end_tick) in common,'dedicated final not shared')
    return dict(epoch=epoch,end_tick=end_tick,minimum_confirmed_ticks_after_each_welcome=ticks,
                roles={x.role:dict(seat=int(x.ready['seat']),token=expected[x.role],baseline=x.baseline[1]) for x in endpoints},
                shared_three_actor_frames=len(common),shared_three_actor_keys=sorted(common),
                authority_issued=0,terminal_ack_tokens=sorted(acked),application_go_observed=3)


def verify_32_pair_envelope(endpoints):
    """Actual public cache/count/ledger observations; no image reconstruction."""
    require(len(endpoints)==2,'32-body scope is one Host and one Client only')
    result={};limit=64*1024*1024
    for endpoint in endpoints:
        declarations=[x for x in endpoint.statuses if x['event']=='LIMITS']
        require(len(declarations)==1,('missing actual 32/H128 configuration',endpoint.role))
        config=declarations[0]
        expected=dict(initial_cached_dynamic_bodies=32,initial_cached_body_count=34,history=128,hz=60,substeps=4,process_limit_bytes=limit)
        require(all(config.get(k)==v for k,v in expected.items()),('32-profile configuration differs',endpoint.role,config))
        require(0<=config['max_prediction']<=8 and 0<=config['max_repair']<=8,'deterministic prediction/repair limit changed')
        observed=[x for x in endpoint.statuses if x['event']=='ENVELOPE']
        require(observed,('missing actual native count/cache observations',endpoint.role))
        require(observed[0]['cached_dynamic_bodies']==32 and observed[0]['cached_body_count']==34,'initial32 not physically observed through public CP cache')
        maximum={name:0 for name in ('body_count','shape_count','contact_count','joint_count')}
        calls=0;count_scopes=set()
        for value in observed:
            phase=value['phase']
            if phase=='published_cache_and_local_candidate_observation':
                count_scopes.add('local_candidate_observations')
            elif phase=='published_cache_and_world_observation':
                require(value.get('native_scope')=='published_world_only','published observation scope missing')
                require(value['native_body_count']==value['cached_body_count'],'published world/cache frame mismatch')
                count_scopes.add('sampled_published_world_only')
            else:
                raise EvidenceError('unlabelled count observation provenance')
            require(value['observe_error']=='None' and value['observe_calls']>=calls,'native count observation failed/decreased')
            calls=value['observe_calls']
            require(0<=value['cached_dynamic_bodies']<=33 and value['cached_body_count']<=35,'published cache outside body envelope')
            for name,cap in zip(maximum,(35,35,147,1)):
                n=value['native_'+name];peak=value['peak_'+name]
                require(type(n) is int and type(peak) is int and 0<=n<=peak<=cap and peak>=maximum[name],('invalid/outside actual native count',name,n,peak))
                maximum[name]=peak
        # Candidate maxima can include aborted branches. Only this immutable
        # public current-CP cache establishes a published35-body observation.
        published=[x for x in observed if x['cached_body_count']==35 and x['cached_dynamic_bodies']==33]
        require(published,'no process-local published native cache reached35 bodies')
        require(calls>0 and maximum['body_count']==35 and maximum['shape_count']==35 and maximum['joint_count']==1,'required actual native topology not exercised')
        ledger=[x for x in endpoint.statuses if x['event']=='LEDGER']
        require(ledger and all(any(x.get('stage')==stage for x in ledger) for stage in ('published_frame','before_close','after_cleanup')),'missing actual shared global ledger lifecycle')
        previous_peak=0;reserved_sample_peak=0
        for value in ledger:
            require(value.get('status')==0 and value['limit_bytes']==limit,'shared ledger contract/query failed')
            fields=('engine_live_bytes','snapshot_live_bytes','host_live_bytes','host_reserved_bytes','live_bytes','admitted_bytes','committed_peak_bytes','ledger_storage_bytes')
            require(all(type(value[k]) is int and value[k]>=0 for k in fields),'invalid global ledger scalar')
            require(value['live_bytes']==value['engine_live_bytes']+value['snapshot_live_bytes']+value['host_live_bytes'],'shared ledger double count/omission')
            require(value['admitted_bytes']==value['live_bytes']+value['host_reserved_bytes'],'shared ledger reservation omission')
            require(value['admitted_bytes']<=limit and previous_peak<=value['committed_peak_bytes']<=limit,'shared64MiB admission/peak exceeded')
            previous_peak=value['committed_peak_bytes'];reserved_sample_peak=max(reserved_sample_peak,value['host_reserved_bytes'])
            if value['stage']=='after_cleanup':require(value['engine_live_bytes']==0 and value['snapshot_live_bytes']==0 and value['host_reserved_bytes']==0,'native/reservation cleanup incomplete')
        require(len(count_scopes)==1,'mixed count observation provenance')
        count_scope=next(iter(count_scopes))
        maxima_name='actual_native_candidate_count_maxima' if count_scope=='local_candidate_observations' else 'sampled_native_published_count_maxima'
        result[endpoint.role]=dict(configuration=config,native_count_scope=count_scope,**{maxima_name:maximum},
                                  initial_cache=observed[0],published35=published,observe_calls=calls,
                                  shared_committed_peak_bytes=previous_peak,sampled_reserved_peak_bytes=reserved_sample_peak,
                                  reservation_peak_scope='sampled actual ledger values; no unsampled reservation highwater invented',
                                  ledger_observations=ledger,overhead_scope='Host LIVE includes stable Core storage. Ledger metadata storage and Godot/allocator overhead explicit; no RSS64MiB claim')
    return result
