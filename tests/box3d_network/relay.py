#!/usr/bin/env python3
"""Bounded real TCP callback-channel relay; no simulation or truth import.
Reliable stays in order and retained; logical Unreliable impairment is explicit.
Kit ordered Stream additionally fences old copies at the adapter boundary.
"""
from __future__ import annotations
import dataclasses,hashlib,json,selectors,socket,struct,threading,time,pathlib
HEADER=struct.Struct('<4sIIIQ')
HELLO=struct.Struct('<4sIQ')
PACKET=65536
QUEUE_BYTES=2*1024*1024
QUEUE_PACKETS=256
@dataclasses.dataclass
class Frame:
 source:int; target:int; generation:int; target_generation:int; channel:int; sequence:int; origin_round:int; due:int; ordinal:int; data:bytes; copy:int=0
class Relay:
 def __init__(self,path,seed=1,ordered=False):
  self.log=open(path,'w',buffering=1);self.packet_dir=pathlib.Path(str(path)+'.packets');self.packet_dir.mkdir(exist_ok=True);self.capture_bytes=0;self.seed=seed;self.rng=seed;self.ordered=ordered
  self.lock=threading.RLock();self.changed=threading.Condition(self.lock);self.selector=selectors.DefaultSelector()
  self.listener=socket.socket();self.listener.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1);self.listener.bind(('127.0.0.1',0));self.listener.listen(8);self.listener.setblocking(False);self.selector.register(self.listener,selectors.EVENT_READ,None)
  self.port=self.listener.getsockname()[1];self.nodes={};self.peers={};self.generations={1:0,2:0};self.queue=[];self.seen={1:0,2:0};self.round=0;self.ordinal=0;self.delivery=0;self.scheduled_targets={1:0,2:0};self.scheduled_generations={};self.reliable_due={1:0,2:0};self.last_ordered={1:0,2:0};self.delivery_highwater={};self.delivery_seen=set()
  self.latency=0;self.jitter=0;self.loss=0;self.duplicate=0;self.reorder=0;self.blackout=False;self.stop=False;self.failure=None;self.peak=0;self.counts={}
  self.thread=threading.Thread(target=self._run,name='bounded-tcp-relay',daemon=True);self.thread.start()
 def _event(self,kind,**kw):
  self.counts[kind]=self.counts.get(kind,0)+1;self.log.write(json.dumps(dict(event=kind,round=self.round,**kw),sort_keys=True)+'\n')
 def _random(self):
  self.rng=(self.rng*6364136223846793005+1442695040888963407)&((1<<64)-1);return self.rng>>32
 def configure(self,*,latency=0,jitter=0,loss=0,duplicate=0,reorder=0,blackout=False):
  with self.lock:
   self.latency,self.jitter,self.loss,self.duplicate,self.reorder,self.blackout=latency,jitter,loss,duplicate,reorder,blackout
   self._event('faults',latency=latency,jitter=jitter,loss=loss,duplicate=duplicate,reorder=reorder,blackout=blackout)
 def advance(self,round):
  with self.lock:
   assert round>=self.round;self.round=round;self._deliver()
 def _bytes(self):return sum(len(f.data) for f in self.queue)+sum(len(n['rx'])+len(n['tx']) for n in self.nodes.values())
 def _peak(self):
  size=self._bytes();self.peak=max(self.peak,size);assert size<=12*1024*1024,('relay total bound',size)
 def _notify(self,target,connected,generation):
  node=self.peers.get(target)
  if node:
   payload=struct.pack('<IQ',int(connected),max(1,generation));node['tx'].extend(HEADER.pack(b'B3PK',len(payload),2,self.round,0)+payload)
   assert len(node['tx'])<=QUEUE_BYTES
 def _close(self,node):
  fd=node['socket'];role=node.get('role')
  try:self.selector.unregister(fd)
  except Exception:pass
  fd.close();self.nodes.pop(id(fd),None)
  if role and self.peers.get(role) is node:
   self.peers.pop(role);self._event('disconnected',role=role,generation=node['generation']);self._notify(3-role,False,node['generation'])
 def _schedule(self,node,channel,seq,origin,data):
  source=node['role'];target=3-source;generation=node['generation'];target_generation=max(1,self.generations[target]);digest=hashlib.sha256(data).hexdigest()
  capture=self.packet_dir/(digest+'.bin')
  if not capture.exists():
   assert self.capture_bytes+len(data)<=64*1024*1024,'bounded actual packet capture exceeded';capture.write_bytes(data);self.capture_bytes+=len(data)
  self.seen[source]=max(self.seen[source],seq);self._event('logical_send',source=source,target=target,generation=generation,channel=channel,sequence=seq,origin_round=origin,bytes=len(data),sha256=digest)
  if channel==1 and (self.blackout or self._random()%10000<self.loss):self._event('drop_unreliable',source=source,sequence=seq,sha256=digest);return
  delay=self.latency+(self._random()%(self.jitter+1) if self.jitter else 0)
  if channel==1 and self._random()%10000<self.reorder:delay+=3
  due=origin+delay
  if channel==0:due=max(due,self.reliable_due[source]);self.reliable_due[source]=due
  copies=2 if channel==1 and self._random()%10000<self.duplicate else 1
  for copy in range(copies):
   if len(self.queue)>=QUEUE_PACKETS or sum(len(f.data) for f in self.queue if f.target==target)+len(data)>QUEUE_BYTES:
    if channel==0:raise RuntimeError('bounded reliable relay capacity exhausted; no drop permitted')
    self._event('drop_unreliable_capacity',source=source,sequence=seq);continue
   self.ordinal+=1;f=Frame(source,target,generation,target_generation,channel,seq,origin,due+(copy if copies==2 else 0),self.ordinal,data,copy);self.queue.append(f)
   self._event('scheduled',source=source,target=target,channel=channel,sequence=seq,due=f.due,ordinal=f.ordinal,copy=copy,bytes=len(data),sha256=digest)
  self._peak()
 def _parse(self,node):
  rx=node['rx']
  if not node.get('role'):
   if len(rx)<HELLO.size:return
   magic,role,generation=HELLO.unpack(rx[:HELLO.size]);del rx[:HELLO.size]
   assert magic==b'B3NP' and role in (1,2) and generation>self.generations[role]
   if role in self.peers:self._close(self.peers[role])
   node.update(role=role,generation=generation);self.peers[role]=node;self.generations[role]=generation;self.seen[role]=0;self.last_ordered[3-role]=0;self.last_ordered[role]=0
   self._event('connected',role=role,generation=generation)
   self._notify(role,3-role in self.peers,self.generations[3-role]);self._notify(3-role,True,generation)
  while len(rx)>=HEADER.size:
   magic,count,channel,origin,seq=HEADER.unpack(rx[:HEADER.size]);assert magic==b'B3PK' and 0<count<=PACKET and channel in (0,1)
   if len(rx)<HEADER.size+count:return
   data=bytes(rx[HEADER.size:HEADER.size+count]);del rx[:HEADER.size+count];self._schedule(node,channel,seq,origin,data)
 def _deliver(self):
  pending=[]
  # Reliable ordering follows source send order, even when jittered. Unreliable
  # due/ordinal selection deliberately permits duplication and reordering.
  for f in sorted(self.queue,key=lambda f:(f.due,f.ordinal)):
   if f.generation!=self.generations[f.source] or f.target_generation!=max(1,self.generations[f.target]):self._event('retired_generation',source=f.source,sequence=f.sequence,channel=f.channel);continue
   node=self.peers.get(f.target)
   earlier_reliable=any(p.source==f.source and p.channel==0 and p.ordinal<f.ordinal for p in pending)
   if f.due>self.round or not node or (f.channel==0 and (self.blackout or earlier_reliable)):
    pending.append(f);continue
   if f.channel==1 and self.ordered and f.sequence<self.last_ordered[f.source]:self._event('drop_stale_ordered',source=f.source,sequence=f.sequence);continue
   packet=HEADER.pack(b'B3PK',len(f.data),f.channel,f.origin_round,f.sequence)+f.data
   if len(node['tx'])+len(packet)>QUEUE_BYTES:pending.append(f);continue
   delivery_key=(f.source,f.generation,f.channel);prior=self.delivery_highwater.get(delivery_key,0)
   if f.sequence<prior:self._event('reordered_delivery',source=f.source,channel=f.channel,sequence=f.sequence,prior=prior)
   full_key=delivery_key+(f.sequence,)
   if full_key in self.delivery_seen:self._event('duplicate_delivery',source=f.source,channel=f.channel,sequence=f.sequence)
   self.delivery_seen.add(full_key);self.delivery_highwater[delivery_key]=max(prior,f.sequence)
   node['tx'].extend(packet)
   if f.channel==1:self.last_ordered[f.source]=max(self.last_ordered[f.source],f.sequence)
   self.delivery+=1;self.scheduled_targets[f.target]+=1;scope=f"{f.target}:{f.target_generation}";self.scheduled_generations[scope]=self.scheduled_generations.get(scope,0)+1
   self._event('socket_scheduled',source=f.source,target=f.target,source_generation=f.generation,target_generation=f.target_generation,channel=f.channel,sequence=f.sequence,copy=f.copy,ordinal=f.ordinal,delivery=self.delivery,bytes=len(f.data),sha256=hashlib.sha256(f.data).hexdigest())
  self.queue=pending;self._peak()
 def _run(self):
  try:
   while not self.stop:
    events=self.selector.select(.002)
    with self.lock:
     for key,mask in events:
      if key.fileobj is self.listener:
       sock,_=self.listener.accept();sock.setblocking(False);sock.setsockopt(socket.IPPROTO_TCP,socket.TCP_NODELAY,1);node={'socket':sock,'rx':bytearray(),'tx':bytearray()};self.nodes[id(sock)]=node;self.selector.register(sock,selectors.EVENT_READ,node)
      else:
       node=key.data
       try:data=node['socket'].recv(min(65536,QUEUE_BYTES-len(node['rx'])))
       except BlockingIOError:continue
       if not data:self._close(node);continue
       node['rx'].extend(data);assert len(node['rx'])<=QUEUE_BYTES;self._parse(node)
     self._deliver()
     for node in list(self.nodes.values()):
      if node['tx']:
       try:n=node['socket'].send(node['tx'])
       except BlockingIOError:continue
       if n:del node['tx'][:n];self._event('socket_write',target=node.get('role',0),bytes=n)
     self.changed.notify_all()
  except BaseException as error:
   with self.lock:self.failure=repr(error);self._event('relay_failure',error=repr(error));self.changed.notify_all()
 def wait_sent(self,role,sequence,timeout=5):
  with self.changed:
   deadline=time.monotonic()+timeout
   while self.seen[role]<sequence:
    if self.failure:raise RuntimeError(self.failure)
    left=deadline-time.monotonic()
    if left<=0:raise TimeoutError(('relay send barrier',role,sequence,self.seen))
    self.changed.wait(min(left,.05))
 def summary(self):
  with self.lock:return {'counts':dict(self.counts),'peak_owned_payload_bytes':self.peak,'pending_bytes':self._bytes(),'captured_unique_bytes':self.capture_bytes,'failure':self.failure,'socket_scheduled_targets':dict(self.scheduled_targets),'socket_scheduled_generations':dict(self.scheduled_generations)}
 def close(self):
  self.stop=True;self.thread.join(2)
  with self.lock:
   for n in list(self.nodes.values()):self._close(n)
   self.listener.close();self.selector.close();self.log.close()
