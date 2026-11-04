"""Bounded controller evidence storage; no Native, solver, transport or clocks."""
from __future__ import annotations
from contextlib import contextmanager
from dataclasses import asdict, dataclass
import base64
import hashlib
import json
from pathlib import Path
import sqlite3
import sys
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'box3d_slices/harness'))
from evidence import signature as check_signature


class EvidenceError(RuntimeError): pass
class EvidenceHold(EvidenceError): pass
class EvidenceDivergence(EvidenceError): pass
class EvidenceBudget(EvidenceError): pass


@dataclass(frozen=True)
class RollingConfig:
    directory: Path
    authority_role: str
    follower_roles: tuple[str, ...]
    allowed_sources: dict[str, tuple[str, ...]]
    disk_budget_bytes: int
    expected_identity_hex: str | None = None
    max_hot_frames: int = 256
    mismatch_reserve_bytes: int = 6 * 1024 * 1024
    segment_target_bytes: int = 1024 * 1024
    raw_policy: str = 'canonical_archive'
    max_context_bytes: int = 1024 * 1024
    max_frame_bytes: int = 2 * 1024 * 1024
    max_part_bytes: int = 1024 * 1024
    frame_policy: str = 'all_exports_required'
    decision_coverage: str = 'all_registered'


@dataclass(frozen=True)
class ProcessScope:
    role: str
    scope_id: str
    pid: int
    source_sha256: str
    epoch: int
    baseline_tick: int


@dataclass(frozen=True)
class FrameRef:
    role: str
    scope_id: str
    epoch: int
    tick: int


@dataclass(frozen=True)
class StoreOutcome:
    state: str
    frames: tuple[FrameRef, ...] = ()
    receipt_ids: tuple[int, ...] = ()
    reason: str | None = None


def require(ok, message, error=EvidenceError):
    if not ok: raise error(message)


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()


def digest(data): return hashlib.sha256(data).hexdigest()


def u64(value):
    require(type(value) is int and 0 <= value < 2**64, 'invalid unsigned64')
    return f'{value:016x}'


def hash_valid(value):
    return isinstance(value, str) and len(value) == 64 and value != '0' * 64 and all(c in '0123456789abcdef' for c in value)


def name_valid(value): return isinstance(value, str) and 0 < len(value) <= 128


def _jsonable(value):
    if isinstance(value, bytes): return {'bytes_base64': base64.b64encode(value).decode()}
    if isinstance(value, dict): return {str(k): _jsonable(v) for k, v in value.items()}
    if isinstance(value, (tuple, list)): return [_jsonable(v) for v in value]
    return value


class RollingStore:
    def __init__(self, config: RollingConfig):
        self.config = config
        self.root = Path(config.directory).resolve()
        self.roles = (config.authority_role, *config.follower_roles)
        self._allowed_sources = {role:tuple(values) for role,values in config.allowed_sources.items()}
        require(len(self.roles) >= 2 and len(set(self.roles)) == len(self.roles), 'roles must be distinct')
        require(set(config.allowed_sources) == set(self.roles), 'source allowlist must cover exact roles')
        require(all(values and all(hash_valid(v) for v in values) for values in config.allowed_sources.values()), 'invalid source allowlist')
        require(config.raw_policy in ('canonical_archive', 'receipts_only'), 'unknown raw policy')
        require(config.frame_policy in ('all_exports_required','all_follower_exports_required'),'unknown frame policy')
        require(config.decision_coverage in ('all_registered','after_admission_baseline'),'unknown decision coverage')
        require(config.frame_policy!='all_follower_exports_required' or config.raw_policy=='canonical_archive','authority references require retained full canonical raw')
        require(config.max_hot_frames > 0 and config.segment_target_bytes >= 256, 'invalid hot/segment bound')
        require(0 < config.max_frame_bytes <= 2*1024*1024 and 0 < config.max_part_bytes <= 1024*1024, 'invalid frame bound')
        require(config.mismatch_reserve_bytes >= 2*config.max_frame_bytes + config.max_context_bytes + 2*480 + 4096, 'mismatch reserve insufficient')
        if config.expected_identity_hex is not None:
            require(len(config.expected_identity_hex) == 432, 'full identity hex must be216bytes')
            bytes.fromhex(config.expected_identity_hex)
        self.root.mkdir(parents=True, exist_ok=False)
        self.db = sqlite3.connect(self.root/'store.sqlite')
        self.db.row_factory = sqlite3.Row
        self.db.execute('PRAGMA page_size=4096')
        self.db.execute('PRAGMA journal_mode=DELETE')
        self.db.execute('PRAGMA synchronous=FULL')
        # Finite conservative budget: <=1/3 main DB, <=1/3 SQLite rollback
        # staging (including headers), <=1/3 receipt exports;64KiB slack.
        self.full_pages = (config.disk_budget_bytes-65536)//(3*4096)
        self.normal_pages = self.full_pages-(config.mismatch_reserve_bytes+4095)//4096
        require(self.normal_pages > 0, 'disk budget too small', EvidenceBudget)
        self.db.execute(f'PRAGMA max_page_count={self.full_pages}')
        self.db.executescript('''
          CREATE TABLE meta(k TEXT PRIMARY KEY,v TEXT);
          CREATE TABLE processes(role TEXT,scope TEXT,pid INTEGER,source TEXT,epoch TEXT,baseline TEXT,
            exit_code INTEGER,last_epoch TEXT,last_tick TEXT,cleanup TEXT,PRIMARY KEY(role,scope));
          CREATE TABLE frames(role TEXT,scope TEXT,epoch TEXT,tick TEXT,sig BLOB,payload BLOB,context TEXT,
            retired INTEGER DEFAULT0,PRIMARY KEY(role,scope,epoch,tick));
          CREATE INDEX frames_tick_lookup ON frames(epoch,tick,role,scope);
          CREATE TABLE canonical_frames(epoch TEXT,tick TEXT,sig BLOB,payload BLOB,scope TEXT,PRIMARY KEY(epoch,tick));
          CREATE TABLE matches(role TEXT,scope TEXT,epoch TEXT,tick TEXT,receipt INTEGER,PRIMARY KEY(role,scope,epoch,tick));
          CREATE TABLE pending_required_frames(role TEXT,scope TEXT,epoch TEXT,tick TEXT,
            PRIMARY KEY(role,scope,epoch,tick));
          CREATE TABLE reference_archives(role TEXT,scope TEXT,epoch TEXT,tick TEXT,receipt INTEGER,PRIMARY KEY(role,scope,epoch,tick));
          CREATE TABLE receipts(id INTEGER PRIMARY KEY AUTOINCREMENT,kind TEXT,body BLOB,prev TEXT,hash TEXT);
          CREATE TABLE fx(role TEXT,id TEXT,epoch TEXT,state TEXT,payload BLOB,settled BLOB,scope TEXT,PRIMARY KEY(role,id));
          CREATE TABLE decisions(role TEXT,id TEXT,body BLOB,scope TEXT,PRIMARY KEY(role,id));
          CREATE TABLE recoveries(id INTEGER PRIMARY KEY AUTOINCREMENT,role TEXT,scope TEXT,body BLOB);
          CREATE TABLE failure(id INTEGER PRIMARY KEY CHECK(id=1),kind TEXT,expected BLOB,actual BLOB,context BLOB);
        '''.replace('DEFAULT0','DEFAULT 0'))
        require(self.db.execute('PRAGMA page_count').fetchone()[0] <= self.normal_pages, 'schema exceeds normal disk budget', EvidenceBudget)
        self.db.execute(f'PRAGMA max_page_count={self.normal_pages}')
        cfg = asdict(config);cfg['directory']=str(self.root)
        self.db.execute('INSERT INTO meta VALUES(?,?)',('config',canonical(cfg).decode()))
        self.db.execute('INSERT INTO meta VALUES(?,?)',('identity',config.expected_identity_hex or ''))
        self.db.commit()

    @contextmanager
    def _transaction(self, terminal_ok=False):
        require(terminal_ok or not self.db.execute('SELECT1 FROM failure'.replace('SELECT1','SELECT 1')).fetchone(), 'store terminal after first divergence')
        try:
            self.db.execute('BEGIN IMMEDIATE')
            yield
            self.db.commit()
        except sqlite3.DatabaseError as error:
            self.db.rollback()
            if 'full' in str(error).lower(): raise EvidenceBudget('finite SQLite evidence budget exhausted') from error
            raise EvidenceError(str(error)) from error
        except Exception:
            self.db.rollback();raise

    def _scope(self, role, scope):
        row=self.db.execute('SELECT * FROM processes WHERE role=? AND scope=?',(role,scope)).fetchone()
        require(row is not None,'unregistered actual process scope')
        return row

    def _append(self, kind, body):
        encoded=canonical(_jsonable(body))
        require(len(encoded)+512<=self.config.segment_target_bytes, "one receipt exceeds declared segment bound", EvidenceBudget)
        prior=self.db.execute('SELECT hash FROM receipts ORDER BY id DESC LIMIT1'.replace('LIMIT1','LIMIT 1')).fetchone()
        previous=prior[0] if prior else '0'*64
        value=digest(bytes.fromhex(previous)+kind.encode()+b'\0'+encoded)
        cursor=self.db.execute('INSERT INTO receipts(kind,body,prev,hash) VALUES(?,?,?,?)',(kind,encoded,previous,value))
        return cursor.lastrowid

    def _context(self, context, tick):
        value=context or dict(from_tick=tick,to_tick=tick,depth=0,source=0,sequence=0,sequence_available=False,
                              accepted_inputs=b'',predicted_inputs=b'',provenance={'scope':'readonly_confirmed_comparison'})
        for key in ('from_tick','to_tick','depth','source','sequence'):u64(value[key])
        require(type(value['sequence_available']) is bool,'sequence availability must be explicit')
        if not value['sequence_available']:require(value['sequence']==0,'unknown sequence must use0 sentinel')
        if value['depth']==0:require(value['from_tick']==value['to_tick'],'readonly context invented rewind range')
        require(isinstance(value['accepted_inputs'],bytes) and isinstance(value['predicted_inputs'],bytes),'input windows must be exact bytes')
        encoded=canonical(_jsonable(value))
        require(len(encoded)<=self.config.max_context_bytes,'comparison context exceeds declared cap',EvidenceBudget)
        return encoded

    def _validate_frame(self, frame):
        sig=bytes(frame.sig)
        try:epoch,tick,lengths=check_signature(sig)
        except Exception as error:raise EvidenceError('invalid complete signature: '+str(error)) from error
        require((epoch,tick)==(frame.epoch,frame.tick),'frame metadata/signature differs')
        try:parts=tuple(bytes(v) for v in frame.parts())
        except FileNotFoundError as error:raise EvidenceHold('source artifacts disappeared before consumption') from error
        except Exception as error:raise EvidenceError('invalid full frame artifacts: '+str(error)) from error
        require(len(parts)==5 and sum(map(len,parts))<=self.config.max_frame_bytes,'full5part frame bound')
        for i,data in enumerate(parts):
            require(len(data)==lengths[i] and len(data)<=self.config.max_part_bytes,'part length bound')
            require(digest(data)==sig[256+40*i:288+40*i].hex(),'altered full part')
        return sig,parts

    def _unpack(self, sig, payload):
        if payload is None:raise EvidenceHold('reference raw bytes retired; receipt/hash is not a new byte comparison')
        _,_,lengths=check_signature(bytes(sig))
        decoder=zlib.decompressobj();data=decoder.decompress(bytes(payload),self.config.max_frame_bytes+1)
        require(decoder.eof and not decoder.unconsumed_tail and len(data)==sum(lengths),'stored compressed frame damaged')
        result=[];at=0
        for i,n in enumerate(lengths):
            part=data[at:at+n];at+=n
            require(digest(part)==bytes(sig)[256+40*i:288+40*i].hex(),'stored full part damaged')
            result.append(part)
        return tuple(result)

    def _identity(self, role, sig):
        identity=sig[16:232].hex()
        expected=self.db.execute('SELECT v FROM meta WHERE k=?',('identity',)).fetchone()[0]
        if not expected:
            require(role==self.config.authority_role,'follower cannot bind authority identity',EvidenceHold)
            self.db.execute('UPDATE meta SET v=? WHERE k=?',(identity,'identity'))
        else:require(identity==expected,'source/schema/build/asset identity mixed')

    def _failure(self, kind, expected, actual, context):
        if not self.db.execute('SELECT1 FROM failure'.replace('SELECT1','SELECT 1')).fetchone():
            self.db.execute(f'PRAGMA max_page_count={self.full_pages}')
            with self._transaction(terminal_ok=True):
                self.db.execute('INSERT INTO failure VALUES(1,?,?,?,?)',(kind,zlib.compress(canonical(_jsonable(expected))),zlib.compress(canonical(_jsonable(actual))),zlib.compress(context)))
                self._append('first_mismatch',dict(kind=kind,expected_sha256=digest(canonical(_jsonable(expected))),actual_sha256=digest(canonical(_jsonable(actual))),context_sha256=digest(context)))
        raise EvidenceDivergence('first '+kind+' divergence durably saved in store.sqlite/failure1')

    def register_process(self, scope:ProcessScope):
        require(scope.role in self.roles and name_valid(scope.scope_id) and type(scope.pid) is int and scope.pid>0,'invalid process scope')
        require(scope.source_sha256 in self._allowed_sources[scope.role],'source not in immutable allowlist')
        ep,tick=u64(scope.epoch),u64(scope.baseline_tick);require(scope.epoch>0,'epoch0')
        old=self.db.execute('SELECT * FROM processes WHERE role=? AND scope=?',(scope.role,scope.scope_id)).fetchone()
        if old:
            require((old['pid'],old['source'],old['epoch'],old['baseline'])==(scope.pid,scope.source_sha256,ep,tick),'process scope changed')
            return
        require(self.db.execute('SELECT count(*) FROM processes').fetchone()[0]<4096,'process scope bound reached',EvidenceBudget)
        with self._transaction():
            self.db.execute('INSERT INTO processes(role,scope,pid,source,epoch,baseline) VALUES(?,?,?,?,?,?)',(scope.role,scope.scope_id,scope.pid,scope.source_sha256,ep,tick))
            self._append('process',asdict(scope))

    def register_frame(self, role, scope_id, frame, context=None):
        scope=proc=self._scope(role,scope_id);sig,parts=self._validate_frame(frame)
        require(u64(frame.epoch)>=proc['epoch'] and (u64(frame.epoch)!=proc['epoch'] or u64(frame.tick)>=proc['baseline']),'frame predates actual process baseline')
        ep,tick=u64(frame.epoch),u64(frame.tick);ctx=self._context(context,frame.tick)
        old=self.db.execute('SELECT * FROM frames WHERE role=? AND scope=? AND epoch=? AND tick=?',(role,scope_id,ep,tick)).fetchone()
        if old:
            payload=old['payload']
            if payload is None:
                archive=self.db.execute('SELECT payload FROM canonical_frames WHERE epoch=? AND tick=?',(ep,tick)).fetchone()
                payload=archive[0] if archive else None
            prior=self._unpack(old['sig'],payload)
            if bytes(old['sig'])!=sig or prior!=parts:self._failure('confirmed_frame_mutation',dict(sig=bytes(old['sig']),parts=prior),dict(sig=sig,parts=parts),ctx)
            return StoreOutcome('duplicate',(FrameRef(role,scope_id,frame.epoch,frame.tick),))
        if self.config.frame_policy=='all_follower_exports_required':
            hot=self.db.execute('SELECT count(*) FROM pending_required_frames WHERE role=?',(role,)).fetchone()[0] if role!=self.config.authority_role else 0
        else:hot=self.db.execute('SELECT count(*) FROM frames WHERE role=? AND retired=0',(role,)).fetchone()[0]
        require(hot<self.config.max_hot_frames,'hot frame cap requires safe retirement; no silent eviction',EvidenceHold)
        with self._transaction():
            self._identity(role,sig)
            self.db.execute('INSERT INTO frames(role,scope,epoch,tick,sig,payload,context) VALUES(?,?,?,?,?,?,?)',(role,scope_id,ep,tick,sig,zlib.compress(b''.join(parts)),ctx.decode()))
            if self.config.frame_policy=='all_follower_exports_required' and role!=self.config.authority_role:
                self.db.execute('INSERT INTO pending_required_frames VALUES(?,?,?,?)',(role,scope_id,ep,tick))
        return StoreOutcome('stored',(FrameRef(role,scope_id,frame.epoch,frame.tick),))

    def compare_and_seal(self, ref:FrameRef):
        self._scope(ref.role,ref.scope_id);ep,tick=u64(ref.epoch),u64(ref.tick)
        row=self.db.execute('SELECT * FROM frames WHERE role=? AND scope=? AND epoch=? AND tick=?',(ref.role,ref.scope_id,ep,tick)).fetchone()
        require(row is not None,'frame not registered')
        authority=self.db.execute('SELECT * FROM frames WHERE role=? AND epoch=? AND tick=? ORDER BY scope LIMIT1'.replace('LIMIT1','LIMIT 1'),(self.config.authority_role,ep,tick)).fetchone()
        if authority is None:return StoreOutcome('hold',(ref,),reason='authority matching frame absent')
        # Preserve insertion order for multiple scopes while the tick index
        # bounds the candidate set before ordering it.
        followers=self.db.execute('SELECT * FROM frames WHERE role!=? AND epoch=? AND tick=? ORDER BY rowid',(self.config.authority_role,ep,tick)) if ref.role==self.config.authority_role else iter([row])
        canonical_row=self.db.execute('SELECT * FROM canonical_frames WHERE epoch=? AND tick=?',(ep,tick)).fetchone()
        authority_payload=authority['payload'] if authority['payload'] is not None else (canonical_row['payload'] if canonical_row else None)
        expected=self._unpack(authority['sig'],authority_payload)
        receipts=[];matched=[];found=False
        for follower in followers:
            found=True
            existing=self.db.execute('SELECT receipt FROM matches WHERE role=? AND scope=? AND epoch=? AND tick=?',(follower['role'],follower['scope'],ep,tick)).fetchone()
            if existing:receipts.append(existing[0]);continue
            actual=self._unpack(follower['sig'],follower['payload'])
            if bytes(authority['sig'])!=bytes(follower['sig']) or expected!=actual:
                self._failure('full5parts',dict(signature=bytes(authority['sig']),parts=expected,role=authority['role'],scope=authority['scope']),dict(signature=bytes(follower['sig']),parts=actual,role=follower['role'],scope=follower['scope']),follower['context'].encode())
            a=self._scope(authority['role'],authority['scope']);f=self._scope(follower['role'],follower['scope'])
            body=dict(epoch=ref.epoch,tick=ref.tick,identity_sha256=digest(bytes(authority['sig'])[16:232]),signature_sha256=digest(bytes(authority['sig'])),
                authority=dict(role=a['role'],scope=a['scope'],pid=a['pid'],source=a['source']),follower=dict(role=f['role'],scope=f['scope'],pid=f['pid'],source=f['source']),
                parts=[dict(length=len(data),sha256=digest(data)) for data in expected],byte_comparison=True,context_sha256=digest(follower['context'].encode()))
            with self._transaction():
                if canonical_row is None:
                    self.db.execute('INSERT INTO canonical_frames VALUES(?,?,?,?,?)',(ep,tick,authority['sig'],authority_payload,authority['scope']))
                receipt=self._append('complete_comparison',body)
                self.db.execute('INSERT INTO matches VALUES(?,?,?,?,?)',(follower['role'],follower['scope'],ep,tick,receipt))
                if self.config.frame_policy=='all_follower_exports_required':
                    removed=self.db.execute('DELETE FROM pending_required_frames WHERE role=? AND scope=? AND epoch=? AND tick=?',(follower['role'],follower['scope'],ep,tick))
                    require(removed.rowcount==1,'pending required-frame index missing at first match')
            canonical_row=True;receipts.append(receipt);matched.append(FrameRef(follower['role'],follower['scope'],ref.epoch,ref.tick))
        if not found:return StoreOutcome('hold',(ref,),reason='follower matching frame absent')
        return StoreOutcome('matched',tuple(matched or [ref]),tuple(receipts))

    def _covering_scopes(self, role, epoch, tick):
        result=[]
        for proc in self.db.execute('SELECT * FROM processes WHERE role=?',(role,)):
            if epoch<proc['epoch'] or (epoch==proc['epoch'] and tick<proc['baseline']):continue
            if proc['last_epoch'] is not None and (epoch>proc['last_epoch'] or (epoch==proc['last_epoch'] and tick>proc['last_tick'])):continue
            result.append(proc)
        return result

    def retire(self, ref:FrameRef):
        ep,tick=u64(ref.epoch),u64(ref.tick)
        row=self.db.execute('SELECT * FROM frames WHERE role=? AND scope=? AND epoch=? AND tick=?',(ref.role,ref.scope_id,ep,tick)).fetchone()
        require(row is not None,'unregistered retirement')
        if row['retired']:return StoreOutcome('duplicate',(ref,))
        if ref.role==self.config.authority_role and self.config.frame_policy=='all_follower_exports_required':
            archive=self.db.execute('SELECT * FROM canonical_frames WHERE epoch=? AND tick=?',(ep,tick)).fetchone()
            parts=self._unpack(row['sig'],row['payload'])
            if archive is not None:
                old_parts=self._unpack(archive['sig'],archive['payload'])
                if bytes(archive['sig'])!=bytes(row['sig']) or old_parts!=parts:
                    self._failure('authority_reference_mutation',dict(signature=bytes(archive['sig']),parts=old_parts),dict(signature=bytes(row['sig']),parts=parts),row['context'].encode())
            proc=self._scope(ref.role,ref.scope_id)
            body=dict(role=ref.role,scope=ref.scope_id,pid=proc['pid'],source=proc['source'],epoch=ref.epoch,tick=ref.tick,
                identity_sha256=digest(bytes(row['sig'])[16:232]),signature_sha256=digest(bytes(row['sig'])),
                parts=[dict(length=len(part),sha256=digest(part)) for part in parts],byte_comparison=False,
                coverage='authority_reference_archived_not_a_complete_comparison')
            with self._transaction():
                if archive is None:self.db.execute('INSERT INTO canonical_frames VALUES(?,?,?,?,?)',(ep,tick,row['sig'],row['payload'],ref.scope_id))
                receipt=self._append('authority_reference_archived',body)
                self.db.execute('INSERT INTO reference_archives VALUES(?,?,?,?,?)',(ref.role,ref.scope_id,ep,tick,receipt))
                self.db.execute('UPDATE frames SET payload=NULL,retired=1 WHERE role=? AND scope=? AND epoch=? AND tick=?',(ref.role,ref.scope_id,ep,tick))
            return StoreOutcome('reference_archived',(ref,),(receipt,),reason='full reference raw retained; not a matched-comparison claim')
        if ref.role==self.config.authority_role:
            relevant=[proc for role in self.config.follower_roles for proc in self._covering_scopes(role,ep,tick)]
            require(relevant,'no admitted follower coverage; cannot claim compared retirement',EvidenceHold)
            for proc in relevant:
                require(self.db.execute('SELECT 1 FROM matches WHERE role=? AND scope=? AND epoch=? AND tick=?',(proc['role'],proc['scope'],ep,tick)).fetchone(),'unmatched required authority retirement',EvidenceHold)
        else:
            require(self.db.execute('SELECT 1 FROM matches WHERE role=? AND scope=? AND epoch=? AND tick=?',(ref.role,ref.scope_id,ep,tick)).fetchone(),'unmatched required follower retirement',EvidenceHold)
        with self._transaction():
            self.db.execute('UPDATE frames SET payload=NULL,retired=1 WHERE role=? AND scope=? AND epoch=? AND tick=?',(ref.role,ref.scope_id,ep,tick))
            if self.config.raw_policy=='receipts_only':
                left=self.db.execute('SELECT count(*) FROM frames WHERE epoch=? AND tick=? AND retired=0',(ep,tick)).fetchone()[0]
                if left==0:self.db.execute('UPDATE canonical_frames SET payload=NULL WHERE epoch=? AND tick=?',(ep,tick))
        return StoreOutcome('retired',(ref,))

    def record_fx(self, role, scope_id, row):
        self._scope(role,scope_id)
        epoch,tick=row['epoch'],row['tick'];ep=u64(epoch);u64(tick)
        identity=[row['source'],row['key']] if 'source' in row else row.get('id',row.get('key',row.get('serial')))
        require(identity is not None,'actual FX stable ID missing')
        key=canonical([epoch,tick,identity]).decode()
        payload_keys=('serial','lifetime','seat','kind','event_kind','applied','sequence','result','action')
        require('payload' in row or any(key in row for key in payload_keys),'actual FX full payload missing')
        payload=row.get('payload',{k:row[k] for k in payload_keys if k in row})
        data=canonical(_jsonable(payload));phase=str(row.get('phase','commit')).lower()
        confirmed=row.get('confirmed',phase in ('commit','confirmed','confirm'))
        if type(confirmed) is int:confirmed=tick<=confirmed
        require(type(confirmed) is bool,'FX confirmation flag invalid')
        old=self.db.execute('SELECT * FROM fx WHERE role=? AND id=?',(role,key)).fetchone()
        state=old['state'] if old else None;settled=bytes(old['settled']) if old and old['settled'] is not None else None
        violation=None
        if phase=='begin':
            if state=='active' or settled is not None:violation='duplicate Begin/settled ID reuse'
            new_state='active';settle=confirmed
        elif phase=='update':
            if state!='active' or settled is not None or confirmed:violation='Update without unsettled Begin'
            new_state='active';settle=False
        elif phase=='cancel':
            if settled is not None:
                markers=self.db.execute('SELECT body FROM recoveries WHERE role=? AND scope=?',(role,scope_id)).fetchall()
                valid_marker=any((lambda m:m.get('kind')=='epoch_reset' and m.get('old_epoch')==epoch and type(m.get('epoch')) is int and m['epoch']>epoch)(json.loads(m[0])) for m in markers)
                if state=='cancelled' or not confirmed or settled!=data or not valid_marker:violation='settled Cancel lacks matching payload/actual epoch-reset marker'
            elif state!='active':violation='Cancel without active Begin'
            new_state='cancelled';settle=False
        elif phase in ('commit','confirmed','confirm'):
            if not confirmed or settled is not None:violation='duplicate/unconfirmed settlement'
            if phase=='confirm' and (state!='active' or old is None or bytes(old['payload'])!=data):violation='Confirm without matching Begin/Update payload'
            new_state='settled';settle=True
        else:raise EvidenceError('unknown actual FX phase')
        if settle:new_state='settled'
        if violation:self._failure('fx_lifecycle',dict(previous=dict(old) if old else None,reason=violation),row,self._context(row.get('context'),tick))
        with self._transaction():
            if old:self.db.execute('UPDATE fx SET state=?,payload=?,settled=?,scope=? WHERE role=? AND id=?',(new_state,data,data if settle else settled,scope_id,role,key))
            else:self.db.execute('INSERT INTO fx VALUES(?,?,?,?,?,?,?)',(role,key,ep,new_state,data,data if settle else None,scope_id))
            self._append('actual_fx',dict(role=role,scope=scope_id,row=row))

    def record_decision(self, role, scope_id, row):
        self._scope(role,scope_id)
        require(str(row.get('event','')).upper() not in ('ISSUED','SUBMITTED','INTENT_ATTEMPT'),'intent is not an accepted decision')
        if 'applied' in row:require(row.get('accepted') is True,'action decision lacks actual admission')
        logical_class=row.get('class',1 if 'kind' in row else 0)
        key=canonical([row['epoch'],row['tick'],row['seat'],logical_class]).decode()
        body={k:v for k,v in row.items() if k not in ('framework','role','actor','event','pid','process_generation','observed_at','context')}
        encoded=canonical(body)
        old=self.db.execute('SELECT body FROM decisions WHERE role=? AND id=?',(role,key)).fetchone()
        if old and bytes(old[0])!=encoded:self._failure('decision_mutation',json.loads(old[0]),body,self._context(row.get('context'),row['tick']))
        with self._transaction():
            self.db.execute('INSERT OR IGNORE INTO decisions VALUES(?,?,?,?)',(role,key,encoded,scope_id))
            self._append('actual_decision',dict(role=role,scope=scope_id,row=body))

    def record_recovery(self, role, scope_id, row):
        self._scope(role,scope_id);u64(row['epoch'])
        if row.get('kind')=='epoch_reset':require(type(row.get('old_epoch')) is int and 0<row['old_epoch']<row['epoch'] and row.get('observed') is True and row.get('basis')=='framework_epoch_reset','invalid actual epoch reset marker')
        with self._transaction():
            self.db.execute('INSERT INTO recoveries(role,scope,body) VALUES(?,?,?)',(role,scope_id,canonical(row)))
            self._append('observed_recovery',dict(role=role,scope=scope_id,row=row))

    def register_exit(self, role, scope_id, *, exit_code, last_epoch, last_confirmed, cleanup):
        proc=self._scope(role,scope_id)
        if proc['exit_code'] is not None:
            require((proc['exit_code'],proc['last_epoch'],proc['last_tick'],proc['cleanup'])==(exit_code,u64(last_epoch),u64(last_confirmed),canonical(cleanup).decode()),'actual exit changed')
            return
        with self._transaction(terminal_ok=True):
            self.db.execute('UPDATE processes SET exit_code=?,last_epoch=?,last_tick=?,cleanup=? WHERE role=? AND scope=?',(exit_code,u64(last_epoch),u64(last_confirmed),canonical(cleanup).decode(),role,scope_id))
            self._append('actual_exit',dict(role=role,scope=scope_id,exit_code=exit_code,last_epoch=last_epoch,last_confirmed=last_confirmed,cleanup=cleanup))

    def verify_chain(self):
        previous='0'*64;last=0
        for row in self.db.execute('SELECT * FROM receipts ORDER BY id'):
            require(row['id']==last+1 and row['prev']==previous,'receipt sequence/chain link changed')
            value=digest(bytes.fromhex(previous)+row['kind'].encode()+b'\0'+bytes(row['body']))
            require(value==row['hash'],'receipt body/hash changed')
            previous=value;last=row['id']
        return dict(count=last,head=previous)

    def _pending_required_findings(self):
        """Reconcile the derived hot index; never substitute it for raw proof."""
        if self.config.frame_policy!='all_follower_exports_required':
            return ['pending required-frame index populated under strict policy'] if self.db.execute('SELECT 1 FROM pending_required_frames LIMIT 1').fetchone() else []
        findings=[]
        orphan=self.db.execute('''SELECT 1 FROM pending_required_frames p
            LEFT JOIN frames f ON f.role=p.role AND f.scope=p.scope AND f.epoch=p.epoch AND f.tick=p.tick
            LEFT JOIN processes s ON s.role=p.role AND s.scope=p.scope
            WHERE f.role IS NULL OR s.role IS NULL OR p.role=? LIMIT 1''',(self.config.authority_role,)).fetchone()
        if orphan:findings.append('pending required-frame index orphan/authority row')
        matched=self.db.execute('''SELECT 1 FROM pending_required_frames p JOIN matches m
            ON m.role=p.role AND m.scope=p.scope AND m.epoch=p.epoch AND m.tick=p.tick LIMIT 1''').fetchone()
        if matched:findings.append('pending required-frame index contains matched row')
        missing=self.db.execute('''SELECT 1 FROM frames f WHERE f.role!=?
            AND NOT EXISTS(SELECT 1 FROM matches m WHERE m.role=f.role AND m.scope=f.scope AND m.epoch=f.epoch AND m.tick=f.tick)
            AND NOT EXISTS(SELECT 1 FROM pending_required_frames p WHERE p.role=f.role AND p.scope=f.scope AND p.epoch=f.epoch AND p.tick=f.tick)
            LIMIT 1''',(self.config.authority_role,)).fetchone()
        if missing:findings.append('pending required-frame index missing unmatched row')
        retired=self.db.execute('''SELECT 1 FROM frames f WHERE f.role!=? AND f.retired!=0
            AND NOT EXISTS(SELECT 1 FROM matches m WHERE m.role=f.role AND m.scope=f.scope AND m.epoch=f.epoch AND m.tick=f.tick)
            LIMIT 1''',(self.config.authority_role,)).fetchone()
        if retired:findings.append('retired unmatched required follower frame')
        return findings

    def finalize(self):
        processes=[dict(row) for row in self.db.execute('SELECT * FROM processes ORDER BY role,scope')]
        missing=self._pending_required_findings()
        try:self.verify_chain()
        except EvidenceError as error:missing.append(str(error))
        for p in processes:
            if p['exit_code']!=0 or p['cleanup'] is None:missing.append('missing/nonzero natural exit '+p['scope']);continue
            cleanup=json.loads(p['cleanup'])
            if cleanup.get('ok') is not True or cleanup.get('all_explicit_drops_ok') is not True or cleanup.get('core_shutdown_clean') is not True or any(type(cleanup.get(k)) is not int or cleanup[k]!=0 for k in ('native_live_bytes','snapshot_live_bytes','host_application_live_bytes')):missing.append('cleanup not verified '+p['scope'])
        unmatched=self.db.execute('SELECT count(*) FROM frames f WHERE role!=? AND NOT EXISTS(SELECT1 FROM matches m WHERE m.role=f.role AND m.scope=f.scope AND m.epoch=f.epoch AND m.tick=f.tick)'.replace('SELECT1','SELECT 1'),(self.config.authority_role,)).fetchone()[0]
        if unmatched:missing.append('unmatched required follower frames')
        authority_unmatched=0
        for frame in self.db.execute('SELECT epoch,tick FROM frames WHERE role=?',(self.config.authority_role,)):
            for role in self.config.follower_roles:
                for proc in self._covering_scopes(role,frame['epoch'],frame['tick']):
                    if not self.db.execute('SELECT 1 FROM matches WHERE role=? AND scope=? AND epoch=? AND tick=?',(role,proc['scope'],frame['epoch'],frame['tick'])).fetchone():authority_unmatched+=1
        if authority_unmatched and self.config.frame_policy=='all_exports_required':missing.append('unmatched required authority frames')
        if self.config.frame_policy=='all_exports_required':unmatched+=authority_unmatched
        fx_missing=fx_changed=fx_outside_scope=decision_missing=decision_changed=decision_outside_scope=0
        for row in self.db.execute('SELECT * FROM fx WHERE role=? AND settled IS NOT NULL',(self.config.authority_role,)):
            epoch,tick,_=json.loads(row['id']);ep,tk=u64(epoch),u64(tick)
            for role in self.config.follower_roles:
                eligible=[proc for proc in self._covering_scopes(role,ep,tk) if ep!=proc['epoch'] or tk>proc['baseline']]
                if not eligible:fx_outside_scope+=1;continue
                other=self.db.execute('SELECT settled FROM fx WHERE role=? AND id=?',(role,row['id'])).fetchone()
                if other is None or other[0] is None:fx_missing+=1
                elif bytes(other[0])!=bytes(row['settled']):fx_changed+=1
        for row in self.db.execute('SELECT * FROM decisions WHERE role=?',(self.config.authority_role,)):
            value=json.loads(row['body']);ep,tk=u64(value['epoch']),u64(value['tick'])
            for role in self.config.follower_roles:
                coverage=self._covering_scopes(role,ep,tk)
                if not coverage:continue
                eligible=coverage
                if self.config.decision_coverage=='after_admission_baseline':eligible=[proc for proc in coverage if ep!=proc['epoch'] or tk>proc['baseline']]
                other=self.db.execute('SELECT body FROM decisions WHERE role=? AND id=?',(role,row['id'])).fetchone()
                if not eligible:
                    decision_outside_scope+=1
                    if other is not None and bytes(other[0])!=bytes(row['body']):decision_changed+=1
                elif other is None:decision_missing+=1
                elif bytes(other[0])!=bytes(row['body']):decision_changed+=1
        fx_extra=decision_extra=0
        for role in self.config.follower_roles:
            for row in self.db.execute('SELECT id FROM fx WHERE role=? AND settled IS NOT NULL',(role,)):
                if not self.db.execute('SELECT 1 FROM fx WHERE role=? AND id=? AND settled IS NOT NULL',(self.config.authority_role,row['id'])).fetchone():fx_extra+=1
            for row in self.db.execute('SELECT id FROM decisions WHERE role=?',(role,)):
                if not self.db.execute('SELECT 1 FROM decisions WHERE role=? AND id=?',(self.config.authority_role,row['id'])).fetchone():decision_extra+=1
        if fx_extra:missing.append('extra actual settled follower FX')
        if decision_extra:missing.append('extra actual follower decisions')
        if fx_missing or fx_changed:missing.append('actual settled FX missing/payload mismatch')
        if decision_missing or decision_changed:missing.append('actual decision/provenance missing/mismatch')

        failure=self.db.execute('SELECT kind FROM failure').fetchone()
        if failure:missing.append('first divergence '+failure[0])
        tails_missing=0
        for proc in processes:
            if proc['exit_code'] is None or proc['last_epoch'] is None:continue
            tail=self.db.execute('SELECT 1 FROM frames WHERE role=? AND scope=? AND epoch=? AND tick=?',(proc['role'],proc['scope'],proc['last_epoch'],proc['last_tick'])).fetchone()
            if tail is None:tails_missing+=1;continue
            if proc['role']!=self.config.authority_role:
                if not self.db.execute('SELECT 1 FROM matches WHERE role=? AND scope=? AND epoch=? AND tick=?',(proc['role'],proc['scope'],proc['last_epoch'],proc['last_tick'])).fetchone():tails_missing+=1
            else:
                for role in self.config.follower_roles:
                    if not self.db.execute('SELECT 1 FROM matches WHERE role=? AND epoch=? AND tick=?',(role,proc['last_epoch'],proc['last_tick'])).fetchone():tails_missing+=1
        if tails_missing:missing.append('final actual tail not registered and all5matched')
        count=self.db.execute('SELECT count(*) FROM matches').fetchone()[0]
        if not count:missing.append('no full-byte comparisons')
        if {p['role'] for p in processes}!=set(self.roles):missing.append('required process role missing')
        head=self.db.execute('SELECT id,hash FROM receipts ORDER BY id DESC LIMIT1'.replace('LIMIT1','LIMIT 1')).fetchone()
        authority_exports=self.db.execute('SELECT count(*) FROM frames WHERE role=?',(self.config.authority_role,)).fetchone()[0]
        follower_exports=self.db.execute('SELECT count(*) FROM frames WHERE role!=?',(self.config.authority_role,)).fetchone()[0]
        unpaired_references=self.db.execute('SELECT count(*) FROM frames f WHERE role=? AND NOT EXISTS(SELECT 1 FROM matches m WHERE m.epoch=f.epoch AND m.tick=f.tick)',(self.config.authority_role,)).fetchone()[0]
        return dict(result='PASS' if not missing else 'FAIL',findings=missing,processes=processes,matched_comparisons=count,
            unmatched_required_frames=unmatched,frame_policy=self.config.frame_policy,decision_coverage=self.config.decision_coverage,decision_outside_admission_count=decision_outside_scope,final_tail_missing=tails_missing,authority_export_count=authority_exports,unmatched_authority_references=unpaired_references,authority_archived_reference_count=self.db.execute('SELECT count(*) FROM reference_archives').fetchone()[0],required_follower_exports=follower_exports,required_follower_matches=count,fx_missing=fx_missing,fx_changed=fx_changed,fx_outside_scope=fx_outside_scope,fx_extra=fx_extra,decision_extra=decision_extra,decision_missing=decision_missing,decision_changed=decision_changed,receipt_count=head[0] if head else 0,receipt_chain_head=head[1] if head else '0'*64,
            raw_policy=self.config.raw_policy,retained_canonical_frames=self.db.execute('SELECT count(*) FROM canonical_frames WHERE payload IS NOT NULL').fetchone()[0],
            sealed_comparison_receipts=count,raw_vs_receipt_coverage_explicit=True,settled_fx_ids=self.db.execute('SELECT count(*) FROM fx WHERE settled IS NOT NULL').fetchone()[0],
            disk_budget_bytes=self.config.disk_budget_bytes,main_db_max_bytes=self.full_pages*4096,normal_db_max_bytes=self.normal_pages*4096,
            disk_policy='three-way conservative mainDB/rollback-staging/receipt-export budget plus64KiB slack; logical quota, not OS-free-space guarantee')

    def export_receipts(self, directory):
        require(not self.db.execute("SELECT 1 FROM meta WHERE k='receipt_export'").fetchone(),'receipt export already sealed')
        target=Path(directory).resolve();require(target.is_relative_to(self.root),'receipt export must remain in budgeted store directory')
        with self._transaction(terminal_ok=True):self.db.execute('INSERT INTO meta VALUES(?,?)',('receipt_export',canonical({'state':'reserved','target':str(target)}).decode()))
        target.mkdir(parents=True,exist_ok=False)
        output=[];chunk=bytearray();used=0
        def flush():
            nonlocal chunk,used
            if not chunk:return
            data=zlib.compress(bytes(chunk));require(used+len(data)<=self.full_pages*4096,'receipt export disk budget exhausted',EvidenceBudget)
            path=target/f'receipts-{len(output)+1:06d}.jsonl.z';path.write_bytes(data);used+=len(data)
            output.append(dict(path=str(path),bytes=len(data),sha256=digest(data),uncompressed_bytes=len(chunk)));chunk=bytearray()
        for row in self.db.execute('SELECT id,kind,body,prev,hash FROM receipts ORDER BY id'):
            line=canonical(dict(id=row['id'],kind=row['kind'],body=json.loads(row['body']),prev=row['prev'],hash=row['hash']))+b'\n'
            require(len(line)<=self.config.segment_target_bytes,'one receipt exceeds segment bound',EvidenceBudget)
            if len(chunk)+len(line)>self.config.segment_target_bytes:flush()
            chunk.extend(line)
        flush()
        with self._transaction(terminal_ok=True):self.db.execute('UPDATE meta SET v=? WHERE k=?',(canonical(output).decode(),'receipt_export'))
        return output

    def first_mismatch(self):
        row=self.db.execute('SELECT * FROM failure WHERE id=1').fetchone()
        if row is None:return None
        def decode(value):
            data=json.loads(zlib.decompress(bytes(value)))
            def walk(item):
                if isinstance(item,dict) and set(item)=={'bytes_base64'}:return base64.b64decode(item['bytes_base64'],validate=True)
                if isinstance(item,dict):return {k:walk(v) for k,v in item.items()}
                if isinstance(item,list):return [walk(v) for v in item]
                return item
            return walk(data)
        return dict(kind=row['kind'],expected=decode(row['expected']),actual=decode(row['actual']),context=decode(row['context']))

    def close(self):self.db.close()
