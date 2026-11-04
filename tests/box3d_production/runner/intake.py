"""Bounded fsynced stdout +disk event index. No whole-run parsed-row list."""
from pathlib import Path
import hashlib,json,os,sqlite3,subprocess,threading,time
MAX_LINE=1024*1024
MAX_LOG=128*1024*1024
MAX_INDEX=128*1024*1024
MAX_ROWS=65536
BAD=('SCRIPT ERROR','ERROR:','instances were leaked','resources still in use','CLEANUP_FAIL')
def sha(path):
 h=hashlib.sha256()
 with Path(path).open('rb') as f:
  for chunk in iter(lambda:f.read(1024*1024),b''):h.update(chunk)
 return h.hexdigest()
def strict(raw):
 def pairs(items):
  out={}
  for k,v in items:
   if k in out:raise ValueError('duplicate JSON key')
   out[k]=v
  return out
 def constant(value):raise ValueError('nonfinite JSON '+value)
 return json.loads(raw,object_pairs_hook=pairs,parse_constant=constant)
def parse(raw):
 text=raw.decode('utf-8').strip()
 if any(x in text for x in BAD):raise ValueError('strict runtime log error')
 if not text.startswith('SAMPLE_') or ' ' not in text:return None
 event,payload=text.split(' ',1);row=strict(payload)
 if not isinstance(row,dict) or ('event' in row and row['event']!=event):raise ValueError('sample prefix/body mismatch')
 return dict(row,event=event)
class Actor:
 def __init__(self,role,argv,env,folder,identity,wake):
  self.role=role;self.folder=Path(folder);self.folder.mkdir();self.error=None;self.eof=False;self.forced=False;self.cursor=0;self.seen=self.consumed=self.bytes_seen=0;self.started=time.monotonic();self.wake=wake
  self.db_path=self.folder/'events.sqlite';db=sqlite3.connect(self.db_path);db.execute('create table events(seq integer primary key,event text,body text,observed real,offset integer,bytes integer,raw_sha256 text)');db.commit();db.close()
  self.process=subprocess.Popen(argv,cwd=self.folder,env=env,stdin=subprocess.DEVNULL,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,start_new_session=True)
  self.pid=self.process.pid
  (self.folder/'actor.json').write_text(json.dumps(dict(role=role,pid=self.pid,owned_pgid=self.pid,argv=argv,identity=identity,sample_environment={k:v for k,v in env.items() if k.startswith(('BOX3D_SAMPLE_','BOX3D_PRODUCTION_'))}),indent=2)+'\n')
  self.thread=threading.Thread(target=self._read,daemon=True);self.thread.start()
 def _read(self):
  db=None
  try:
   db=sqlite3.connect(self.db_path);db.execute('pragma synchronous=FULL');db.execute('pragma journal_mode=DELETE');db.execute('pragma max_page_count='+str(MAX_INDEX//4096))
   with (self.folder/'godot.log').open('xb',buffering=0) as log:
    while True:
     raw=self.process.stdout.readline(MAX_LINE+1)
     if not raw:self.eof=True;break
     offset=self.bytes_seen;self.bytes_seen+=len(raw)
     if len(raw)>MAX_LINE or self.bytes_seen>MAX_LOG:raise ValueError('raw stdout bound exceeded; incomplete evidence')
     log.write(raw);os.fsync(log.fileno())
     try:row=parse(raw)
     except Exception as exc:self.error=self.error or repr(exc);continue
     if row is None:continue
     self.seen+=1
     if self.seen>MAX_ROWS:raise ValueError('event index row bound exceeded')
     db.execute('insert into events values(?,?,?,?,?,?,?)',(self.seen,row['event'],json.dumps(row,allow_nan=False),time.monotonic(),offset,len(raw),hashlib.sha256(raw).hexdigest()));db.commit();self.wake.set()
  except Exception as exc:self.error=self.error or repr(exc)
  finally:
   if db is not None:db.close()
   self.process.stdout.close();self.wake.set()
 def consume(self,callback):
  with sqlite3.connect(self.db_path,timeout=2) as db:
   rows=db.execute('select seq,body,observed from events where seq>? order by seq limit 64',(self.cursor,)).fetchall()
  for seq,body,observed in rows:
   self.cursor=seq;self.consumed+=1;callback(self,strict(body),observed)
  if self.error:raise RuntimeError(self.role+': '+self.error)
 def done(self):return self.process.poll() is not None and self.eof and self.consumed==self.seen
 def kill_owned(self):
  self.forced=True
  try:os.killpg(self.pid,9)
  except ProcessLookupError:pass
 def finish(self):
  code=self.process.wait(timeout=10);self.thread.join(timeout=10)
  if self.thread.is_alive():raise RuntimeError('owned stdout descendant failed to drain')
  log=self.folder/'godot.log';identity=self.folder/'actor.json'
  return dict(role=self.role,pid=self.pid,owned_pgid=self.pid,actual_exit=code,signal_number=-code if code<0 else None,natural=not self.forced and code>=0,intake_drained=self.eof and self.consumed==self.seen,error=self.error,records_seen=self.seen,records_consumed=self.consumed,raw_bytes=self.bytes_seen,stdout_fsynced=self.eof and self.error is None,raw_log=str(log),raw_log_sha256=sha(log) if log.is_file() else None,event_index=str(self.db_path),event_index_sha256=sha(self.db_path),actor_identity=str(identity),actor_identity_sha256=sha(identity))
