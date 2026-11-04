#!/usr/bin/env python3
"""Independent process gate driver. Stdin commands carry no solver truth."""
from __future__ import annotations
import argparse,collections,hashlib,json,pathlib,queue,subprocess,sys,threading,time,struct
from relay import Relay
def signature_bytes(text,epoch=None,tick=None):
 data=bytes.fromhex(text);assert len(data)==480 and data[:8]==b'OGB3SIG1' and struct.unpack_from('<II',data,8)==(1,0)
 assert hashlib.sha256(data[:448]).digest()==data[448:]
 actual_epoch,actual_tick=struct.unpack_from('<QQ',data,232)
 if epoch is not None:assert actual_epoch==epoch and actual_tick==tick
 assert all(any(data[o:o+32]) for o in (40,72,104,136,168,200))
 assert struct.unpack_from('<Q',data,248)[0]>0
 return data

def saved_frame(node,epoch,tick):
 prefix=node.out/f'frame-{epoch}-{tick}';sig=(pathlib.Path(str(prefix)+'.sig')).read_bytes();signature_bytes(sig.hex(),epoch,tick)
 parts=[]
 for i in range(5):
  part=pathlib.Path(str(prefix)+f'.part{i}').read_bytes();length=struct.unpack_from('<Q',sig,248+40*i)[0];assert len(part)==length and hashlib.sha256(part).digest()==sig[256+40*i:288+40*i];parts.append(part)
 return sig,parts

def preserve_trace(out,host,client,epoch,tick):
 expected,eparts=saved_frame(host,epoch,tick);actual,aparts=saved_frame(client,epoch,tick)
 accepted=json.dumps(list(host.inputs)[-32:],sort_keys=True,separators=(',',':')).encode();predicted=json.dumps(list(client.predictions)[-32:],sort_keys=True,separators=(',',':')).encode()
 depth=0;start=tick # Read-only confirmed comparison, not an active rewind.
 payload=b''.join(eparts+aparts)+accepted+predicted;total=1040+len(payload)+32
 header=struct.pack('<8sIIQQQQIIQQQ',b'OGB3TRC1',1,0,start,tick,1,0,depth,0,len(accepted),len(predicted),total)+expected+actual
 assert len(header)==1040;body=header+payload;path=pathlib.Path(out)/'first-mismatch.trace';path.write_bytes(body+hashlib.sha256(body).digest())
 (pathlib.Path(out)/'first-mismatch-context.json').write_text(json.dumps({'kind':'read_only_confirmed_comparison','from_tick':tick,'to_tick':tick,'depth':0,'source':1,'sequence':0,'sequence_meaning':'unavailable; out-of-band comparison, not a received correction','accepted_window':'actual authority public ledger log','predicted_window':'actual client used-input log','production_trace':'separate first.trace retains observed runtime repair context'},indent=2)+'\n')
 return str(path)

class Node:
 def __init__(self,exe,role,relay,out,variant='clean',generation=1,epoch=1):
  self.role=role;self.generation=generation;self.exit_code=None;self.decisions={};self.rejected_diagnostics=[];self.journal=[];self.expected_effects={};self.delivered_effects={};self.baselines=[];self.out=pathlib.Path(out);self.out.mkdir(parents=True,exist_ok=True)
  self.log=open(self.out/'stdout.jsonl','w',buffering=1);self.err=open(self.out/'stderr.log','w');self.events=queue.Queue(maxsize=8192);self.acks=queue.Queue(maxsize=64);self.started=threading.Event();self.closed=None;self.latest={};self.local_state=None;self.probe_equal=None;self.inputs=collections.deque(maxlen=2048);self.predictions=collections.deque(maxlen=256);self.accepted={};self.first_trace=False;self.simulation_runs={};self.maximum_simulated_run=0;self.maximum_correction_staged_index=0;self.signatures={};self.games={};self.packet_count=0;self.nonjson=[];self.awaiting_reset=False;self.effects_during_reset=[]
  self.command_line=[str(exe),str(role),str(relay.port),str(self.out),variant,str(generation),str(epoch)]
  self.process=subprocess.Popen(self.command_line,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=self.err,text=True,bufsize=1)
  self.thread=threading.Thread(target=self._read,daemon=True);self.thread.start()
  if not self.started.wait(15):
   self.process.terminate();self.process.wait(timeout=5);self.thread.join(1);self.log.close();self.err.close();raise RuntimeError(('start failed',role,self.process.returncode,(self.out/'stderr.log').read_text()))
 def _read(self):
  for line in self.process.stdout:
   self.log.write(line)
   try:event=json.loads(line)
   except json.JSONDecodeError:self.nonjson.append(line[:512]);continue
   kind=event.get('event')
   if kind=='started':self.started.set()
   elif kind=='ack':self.latest=event;self.acks.put(event)
   elif kind=='accepted':
    self.inputs.append(event);key=(event['epoch'],event['tick'],event.get('player',0),event.get('class',0));self.accepted[key]=event
   elif kind=='used_input':self.predictions.append(event)
   elif kind=='action_decision':self.decisions[event['epoch'],event['tick'],event['player']]=event
   elif kind=='journal_change':self.journal.append(event)
   elif kind=='recovery_baseline':
    event=dict(event,previous_confirmed=self.latest.get('confirmed',0),previous_epoch=self.latest.get('epoch',event['epoch']));self.baselines.append(event)
    if event.get('kind')=='reset':self.awaiting_reset=False
   elif kind=='epoch_baseline' and event.get('ready'):
    event=dict(event,kind='committed_epoch_reset',previous_confirmed=self.latest.get('confirmed',0),previous_epoch=self.latest.get('epoch',event['epoch']));self.baselines.append(event)
   elif kind in ('expected_effect','effect'):
    key=(event['epoch'],event['tick'],event.get('source',event.get('kind',1)),event['key']);table=self.expected_effects if kind=='expected_effect' else self.delivered_effects
    if key in table:self.nonjson.append('DUPLICATE EFFECT '+repr(key))
    table[key]=event.get('payload',{})
    if kind=='effect' and self.awaiting_reset:self.effects_during_reset.append(event)
   elif kind=='local_state':self.local_state=event
   elif kind=='probe_equal':self.probe_equal=event['equal']
   elif kind=='diagnostic_rejected':self.rejected_diagnostics.append(event)
   elif kind=='first_trace':self.first_trace=True
   elif kind=='simulated':
    self.maximum_correction_staged_index=max(self.maximum_correction_staged_index,event.get('staged_before',0));key=event['command_serial'];run=self.simulation_runs.get(key,[])
    if run and event['tick']!=run[-1]+1:run=[]
    run.append(event['tick']);self.simulation_runs[key]=run;self.maximum_simulated_run=max(self.maximum_simulated_run,len(run))
   elif kind=='signature':
    signature_bytes(event['hex'],event['epoch'],event['tick']);self.signatures[event['epoch'],event['tick']]=event['hex']
   elif kind=='game':self.games[event['epoch'],event['tick']]=event['state']
   elif kind=='packet_received':self.packet_count+=1
   elif kind=='closed':self.closed=event
  self.started.set()
 def command(self,text,timeout=20):
  if self.process.poll() is not None:raise RuntimeError(('node exited',self.role,self.process.returncode,(self.out/'stderr.log').read_text(),self.nonjson[-2:]))
  if self.role==2 and text.split()[0]=='RESET':self.awaiting_reset=True
  self.process.stdin.write(text+'\n');self.process.stdin.flush()
  try:ack=self.acks.get(timeout=timeout)
  except queue.Empty:raise TimeoutError(('command stalled',self.role,text,self.process.poll(),(self.out/'stderr.log').read_text(),self.nonjson[-2:]))
  assert not self.nonjson,('invalid endpoint observation stream',self.role,self.nonjson[-2:])
  assert ack['command']==text.split()[0],(text,ack)
  return ack
 def close(self):
  if self.exit_code is not None:return self.exit_code
  if self.process.poll() is None:
   try:self.command('QUIT')
   except Exception:self.process.terminate()
  try:code=self.process.wait(timeout=5)
  except subprocess.TimeoutExpired:self.process.kill();code=self.process.wait()
  self.thread.join(2);self.log.close();self.err.close();self.exit_code=code
  return code
class Case:
 def __init__(self,exe,framework,out,seed=1,variant='clean'):
  self.exe=pathlib.Path(exe);self.framework=framework;self.out=pathlib.Path(out);
  if self.out.exists() and any(self.out.iterdir()):raise FileExistsError('immutable case output already exists: '+str(self.out))
  self.out.mkdir(parents=True,exist_ok=True);self.relay=Relay(self.out/'delivery.jsonl',seed,ordered=framework=='kit');self.nodes=[];self.retired=[];self.round=0;self.features={};self.compared=set();self.mismatch=None;self.variant=variant
 def start(self,role,variant='clean',generation=1,exe=None,epoch=1):
  node=Node(exe or self.exe,role,self.relay,self.out/f'role{role}-generation{generation}',variant,generation,epoch)
  if role==2 and len(self.nodes)==2:self.retired.append(self.nodes.pop())
  self.nodes.append(node);return node
 def command(self,node,text):
  ack=node.command(text)
  # C adapter retains partial socket output; drain it through public PUMP calls.
  for _ in range(32):
   if not ack.get('tx_pending'):break
   ack=node.command(f'PUMP {self.round}')
  assert not ack.get('tx_pending'),('endpoint bounded output stalled',ack)
  self.relay.wait_sent(node.role,ack.get('out_sequence',0))
  return ack
 def pump(self,repeats=3):
  for _ in range(repeats):
   self.relay.advance(self.round)
   for node in self.nodes:self.command(node,f'PUMP {self.round}')
 def advance(self):self.round+=1;self.relay.advance(self.round)
 def compare(self):
  if len(self.nodes)!=2:return
  host,client=self.nodes;h,c=host.latest,client.latest
  if not c.get('ready') or c.get('needs_resync') or not c.get('confirmed'):return
  epoch,tick=c['epoch'],c['confirmed'];key=epoch,tick;scope_key=client.generation,epoch,tick
  if h.get('epoch')!=epoch or scope_key in self.compared:return
  self.command(host,f'SIG {tick}');self.command(client,f'SIG {tick}')
  left,right=host.signatures.get(key),client.signatures.get(key)
  if left is None or right is None:raise RuntimeError(('missing retained confirmed signature',key,h,c))
  if left!=right:
   self.mismatch={'epoch':epoch,'tick':tick,'expected':left,'actual':right}
   # Stop before any control-plane reset can hide this first mismatch.
   self.command(host,f'DIAG {tick}');self.command(client,f'DIAG {tick}')
   self.mismatch['trace']=preserve_trace(self.out,host,client,epoch,tick)
   (self.out/'first-mismatch.json').write_text(json.dumps(self.mismatch,indent=2)+'\n')
   raise AssertionError(('first confirmed full-signature mismatch',key))
  # Do not infer game behavior from the digest alone.
  assert host.games[key]==client.games[key],('typed confirmed game differs',key)
  overlap=[k for k in client.accepted if k[0]==epoch and k[1]<=tick and k in host.accepted]
  for record_key in overlap:
   if host.accepted[record_key]!=client.accepted[record_key]:
    self.command(host,f'DIAG {tick}');self.command(client,f'DIAG {tick}')
    mismatch={'kind':'accepted_decision_provenance','key':record_key,'authority':host.accepted[record_key],'client':client.accepted[record_key],'confirmed_epoch':epoch,'confirmed_tick':tick}
    (self.out/'first-accepted-mismatch.json').write_text(json.dumps(mismatch,indent=2)+'\n');raise AssertionError(mismatch)
  self.compared.add(scope_key)
 def finish(self,success,error=None):
  all_nodes=self.retired+self.nodes;exits=[n.close() for n in all_nodes]
  shutdown_ok=all(code==0 for code in exits) and all(n.closed is not None and all(n.closed.get(k)==0 for k in ('engine_live','wrapper_live','provider_live','odin_live','socket_live')) for n in all_nodes)
  success=bool(success and shutdown_ok)
  if not shutdown_ok:error=repr(('shutdown verification failed',exits,[n.closed for n in self.nodes],error))
  summary={'framework':self.framework,'success':success,'error':error,'commands':[n.command_line for n in all_nodes],'exit_codes':exits,'compared_confirmed_frames':len(self.compared),'accepted_overlap_records_by_generation':{str(n.generation):sum(1 for k in n.accepted if k in self.nodes[0].accepted) for n in all_nodes if n.role==2},'first_mismatch':self.mismatch,'features':self.features,'relay':self.relay.summary(),'roles':[{'final':n.latest,'closed':n.closed,'actual_packets_consumed':n.packet_count,'maximum_simulated_run':n.maximum_simulated_run,'maximum_correction_staged_index':n.maximum_correction_staged_index,'first_trace':n.first_trace,'generation':n.generation} for n in all_nodes]}
  self.relay.close();(self.out/'result.json').write_text(json.dumps(summary,indent=2)+'\n')
  return summary
 def bootstrap(self,presteps=20,client_variant='clean',client_exe=None):
  host=self.start(1);self.command(host,'STATUS')
  for _ in range(presteps):self.advance();self.command(host,f'STEP {self.round}')
  client=self.start(2,client_variant,exe=client_exe)
  for _ in range(6):self.advance();self.pump()
  if self.framework=='kit':self.command(host,'WELCOME')
  else:self.command(host,f'STEP {self.round}')
  for _ in range(8):self.advance();self.pump()
  return host,client
 def ticks(self,count):
  host,client=self.nodes
  for _ in range(count):
   self.advance();self.command(client,f'STEP {self.round}');self.pump(1);self.command(host,f'STEP {self.round}');self.pump(2);self.compare()
   assert not client.first_trace,('unexpected production divergence trace',self.out)
 def drain(self,require_match=True):
  host,client=self.nodes;self.relay.configure()
  if self.framework=='kit' and require_match:self.command(host,'CHECKPOINT')
  for _ in range(128):
   self.advance();self.pump(3)
   if require_match:self.compare()
   with self.relay.lock:empty=self.relay._bytes()==0;delivered=dict(self.relay.scheduled_generations)
   if empty and all(n.latest.get('tx_pending')==0 and n.latest.get('rx_pending')==0 and n.packet_count>=delivered.get(f'{n.role}:{n.generation}',0) for n in self.nodes) and (not require_match or client.latest['confirmed']==host.latest['head']):return
  raise AssertionError(('tail not consumed/confirmed',host.latest,client.latest,self.relay.summary()))
 def assert_lifecycle(self):
  host,client=self.nodes;h=host.latest
  assert h.get('body_peak')==35 and h.get('shape_peak')==35 and h.get('contact_peak',999)<=147 and h.get('joint_peak')==1,h
  assert h.get('births')==(4 if self.framework=='kit' else 36) and h.get('deaths')==4 and h.get('exact_extra_ends')==4,h
  for node in self.nodes:
   assert node.latest.get('duplicate_effects')==0
   if self.framework=='kit':assert node.maximum_correction_staged_index<=8
   if node.role==2 and node.latest.get('ready'):assert node.latest['head']-node.latest['confirmed']<=8
   assert node.latest.get('actual_requested',2**64)<=64*1024*1024,node.latest
  kinds={24:1,32:2,40:1,48:2,80:3 if self.framework=='kit' else 5,84:4 if self.framework=='kit' else 6,96:5 if self.framework=='kit' else 3,104:6 if self.framework=='kit' else 4,160:1,168:2,176:1,184:2,260:3 if self.framework=='kit' else 5,264:4 if self.framework=='kit' else 6}
  for tick,kind in kinds.items():
   if self.framework=='kit':
    decision=host.decisions.get((1,tick,1));assert decision and decision['kind']==kind and decision['applied'],('scripted action did not apply',tick,decision)
   else:
    record=host.accepted.get((1,tick,0,0));assert record,('missing action ledger',tick)
    entry=record['record'];assert entry['batch']['has_action'][0] and entry['batch']['actions'][0]['kind']==kind and entry['decisions']['applied'][0] and entry['decisions']['verdicts'][0]==0,('scripted action rejected',tick,entry)
  keys=[host.decisions[(1,tick,1)]['body_key'] for tick in (24,40,160,176)];shapes=[host.decisions[(1,tick,1)]['shape_key'] for tick in (24,40,160,176)]
  # These are canonical flat-C keys (index1 low32,generation high32), not raw
  # private native handles or durable game entity identities.
  assert len(set(keys))==4 and len({k&0xffffffff for k in keys})==1 and all((keys[i]>>32)<(keys[i+1]>>32) for i in range(3)),('native allocation slot was not recycled',keys)
  assert len(set(shapes))==4 and len({k&0xffffffff for k in shapes})==1
  self.features['recycled_native_keys']=keys
  if self.framework=='replay':assert self.nodes[1].journal and any(e['confirmed'] for e in self.nodes[1].journal),'no actual journal confirmations'
  self.features['scripted_lifecycle_and_pending_deadlines']=True
  self.assert_effects()
 def assert_effects(self,client=None,require_transitions=True):
  host=self.nodes[0];client=client or self.nodes[1];epoch=client.latest['epoch'];confirmed=client.latest['confirmed']
  def admitted(key):
   ep,tick=key[:2];baselines=[e for e in client.baselines if e['epoch']==ep]
   if not baselines or tick<=min(e['tick'] for e in baselines):return False
   if ep==epoch and tick>confirmed:return False
   for reset in baselines:
    if reset.get('kind')=='reset' and reset.get('previous_epoch')==ep and reset.get('previous_confirmed',0)<tick<=reset['tick']:return False
   return True
  expected=host.expected_effects if self.framework=='replay' else host.delivered_effects
  wanted={k:value for k,value in expected.items() if admitted(k)}
  delivered={k:value for k,value in client.delivered_effects.items() if admitted(k)}
  assert wanted==delivered,('confirmed effect IDs/payloads missing or different',set(wanted)-set(delivered),set(delivered)-set(wanted))
  assert not any('DUPLICATE EFFECT' in e for e in client.nonjson),client.nonjson
  assert not client.effects_during_reset,('new cosmetic emitted while awaiting full reset',client.effects_during_reset)
  if self.framework=='replay':
   states={};counts=collections.Counter()
   for event in client.journal:
    key=(event['epoch'],event['tick'],event['source'],event['key']);kind=event['change'];payload=event['payload'];scope=(event['scope_epoch'],event['scope_generation'],event['scope_serial']);old=states.get(key)
    counts[kind]+=1
    if kind=='Begin':
     assert old is None or not old['active'],('duplicate active Begin',key)
     states[key]={'active':True,'final':event['confirmed'],'payload':payload,'scope':scope}
    elif kind=='Update':
     assert old and old['active'] and not old['final'] and old['payload']==event['previous'],('invalid speculative Update',key,event,old)
     old['payload']=payload
    elif kind=='Cancel':
     assert old and old['active'] and old['payload']==payload,('invalid Cancel',key,event,old)
     assert not old['final'] or (event['confirmed'] and old['scope']!=scope),('confirmed effect canceled without scope change',key)
     old['active']=False
    elif kind=='Confirm':
     assert old and old['active'] and not old['final'] and old['payload']==payload and event['confirmed'],('invalid Confirm',key,event,old)
     old['final']=True
    else:raise AssertionError(('unknown journal change',event))
   if require_transitions:assert all(counts[k]>0 for k in ('Begin','Update','Cancel','Confirm')),('speculative transitions not exercised',counts)
   self.features.setdefault('actual_journal_lifecycle_counts_by_generation',{})[str(client.generation)]=dict(counts)
  self.features.setdefault('confirmed_effect_ids_payloads_by_generation',{})[str(client.generation)]=len(wanted)
  self.features.setdefault('confirmed_effect_ids_payloads_by_generation_epoch',{})[str(client.generation)]={str(ep):sum(1 for k in wanted if k[0]==ep) for ep in {k[0] for k in wanted}}
 def blackout(self):
  host,client=self.nodes;before=client.latest.copy();self.relay.configure(blackout=True,loss=10000)
  held=False;requested=False;request_count=0
  for _ in range(24):
   self.advance();ack=self.command(client,f'STEP {self.round}');self.pump(1);self.command(host,f'STEP {self.round}');self.pump(1)
   local_hold=ack['steps']==0 and ack['head']-ack['confirmed']==8
   held|=local_hold
   if self.framework=='kit' and local_hold and not requested:
    self.features['observed_local_prediction_hold']={k:ack[k] for k in ('head','confirmed','steps','round')}
    self.command(client,'PROBE_SAVE');effects=client.latest['effects']
    self.command(client,'RESET');requested=True;request_count+=1
    self.command(client,'PROBE_CHECK');assert client.probe_equal is True and client.latest['effects']==effects
   elif self.framework=='kit' and requested:
    self.command(client,'PROBE_CHECK');assert client.probe_equal is True,'published pair changed while reliable recovery was held'
  assert held,('local prediction hold at exactly8 was not observed',before,client.latest)
  assert host.latest['head']-before['confirmed']>8
  self.relay.configure()
  for _ in range(128):
   self.advance();self.pump(2)
   if self.framework=='replay' and client.latest.get('resyncs',0)>before.get('resyncs',0):requested=True
   if requested and client.latest.get('ready') and not client.latest.get('needs_resync') and client.latest['confirmed']==host.latest['head']:break
   if self.framework=='replay' and _%8==7:self.command(host,f'STEP {self.round}')
  assert requested and client.latest.get('ready') and not client.latest.get('needs_resync'),('no explicit complete recovery',client.latest)
  if self.framework=='kit':assert request_count==1 and not client.effects_during_reset
  self.features['explicit_reset_request_count']=request_count if self.framework=='kit' else 'existing runner automatic resync'
  self.drain();self.features['age_over8_hold_resync']=True
 def epoch(self):
  host,client=self.nodes;old=host.latest['epoch'];epoch=old+2
  if self.framework=='replay':self.command(client,f'EPOCH {epoch}')
  self.command(host,f'EPOCH {epoch}')
  for _ in range(32):
   self.advance();self.pump(2)
   if self.framework=='replay' and _%4==3:self.command(host,f'STEP {self.round}')
   if client.latest.get('ready') and client.latest['epoch']==epoch:break
  assert client.latest['epoch']==epoch and client.latest.get('ready'),client.latest
  self.ticks(8);self.drain();before=client.latest.copy();self.command(client,'PROBE_SAVE');self.command(host,'STALE')
  self.advance();self.pump(4);self.compare()
  assert client.latest['epoch']==epoch and client.latest['confirmed']==before['confirmed'] and client.latest.get('ready') and not client.latest.get('needs_resync'),('stale epoch poisoned readiness/publication',before,client.latest)
  self.command(client,'PROBE_CHECK');assert client.probe_equal is True,'stale epoch changed complete published bytes'
  self.ticks(8);self.drain();self.assert_effects(client,False)
  epoch_counts=self.features['confirmed_effect_ids_payloads_by_generation_epoch'][str(client.generation)];assert epoch_counts.get(str(epoch),0)>0,('post-epoch effect audit empty',epoch_counts)
  self.features['epoch_reset_and_stale_packet']=True
 def rejoin(self):
  host,old=self.nodes;code=old.close();assert code==0 and old.closed and old.closed['engine_live']==0
  for _ in range(4):self.advance();self.command(host,f'PUMP {self.round}')
  client=self.start(2,generation=2,epoch=host.latest['epoch'])
  for _ in range(8):self.advance();self.pump(2)
  if self.framework=='kit':self.command(host,'WELCOME')
  else:self.command(host,f'STEP {self.round}')
  for _ in range(32):
   self.advance();self.pump(2)
   if client.latest.get('ready'):break
   if self.framework=='replay' and _%4==3:self.command(host,f'STEP {self.round}')
  assert client.latest.get('ready'),client.latest
  baseline=client.latest.copy()
  self.ticks(max(12,424-host.latest['head']));self.drain()
  assert client.latest.get('body_peak')==35 and client.latest.get('shape_peak')==35
  assert client.latest['births']==baseline['births']+2 and client.latest['deaths']==baseline['deaths']+2 and client.latest['exact_extra_ends']==baseline['exact_extra_ends']+2,('post-rejoin lifecycle did not execute',baseline,client.latest)
  for tick,kind in ((392,1),(400,2),(408,1),(416,2)):
   for node in (host,client):
    decision=node.decisions.get((host.latest['epoch'],tick,1));assert decision and decision['applied'] and decision['kind']==kind,('post-rejoin action rejected/missing',node.role,tick,decision)
  self.assert_effects(old,False);self.assert_effects(client,False);self.features['rejoin_new_process_generation']=True;self.features['post_rejoin_applied_lifecycle_deltas']={'births':2,'deaths':2,'pending_ends':2}

 def corpus(self,ticks=300):
  host,client=self.bootstrap();assert client.latest.get('ready'),client.latest;self.compare()
  self.relay.configure(latency=1,jitter=1,loss=300,duplicate=700,reorder=1000)
  self.ticks(ticks);self.drain();self.assert_lifecycle()
  assert host.latest['head']>128 and len(self.compared)>40
  old=host.latest['head']-128;before=len(host.rejected_diagnostics);self.command(host,f'DIAG {old}');assert len(host.rejected_diagnostics)==before+1 and host.rejected_diagnostics[-1].get('error')=='History_Missing'
  self.features['H128_wrap']=True
  counts=self.relay.summary()['counts'];assert counts.get('drop_unreliable',0)>0 and counts.get('duplicate_delivery',0)>0,('faults not exercised',counts)
  assert counts.get('drop_stale_ordered' if self.framework=='kit' else 'reordered_delivery',0)>0,('reorder path not exercised',counts)
  tick=client.latest['confirmed'];epoch=client.latest['epoch'];self.command(host,f'DIAG {tick}');self.command(client,f'DIAG {tick}')
  hs,hp=saved_frame(host,epoch,tick);cs,cp=saved_frame(client,epoch,tick);assert hs==cs and hp==cp
  self.features['exact_final_five_parts_bytes']=True
  self.blackout();self.epoch();self.rejoin()
 def lifetime(self,ticks=0):
  host=self.start(1);self.command(host,'STATUS')
  for _ in range(31):self.advance();self.command(host,f'STEP {self.round}')
  client=self.start(2)
  for _ in range(6):self.advance();self.pump(2)
  self.relay.configure(blackout=True,loss=10000)
  self.command(host,f'STEP {self.round}')
  assert host.latest['head']==32
  if self.framework=='kit':self.command(host,'WELCOME')
  self.command(host,'DIAG 32');expected=host.signatures[1,32];expected_game=host.games[1,32]
  self.command(host,'RELEASE');assert host.latest['engine_live']==0 and host.latest['wrapper_live']==0 and host.latest['provider_live']==0,host.latest
  self.relay.configure()
  for _ in range(64):
   self.advance();self.pump(2)
   if client.latest.get('ready') and client.latest['confirmed']==32:break
  assert client.latest.get('ready') and client.latest['confirmed']==32,client.latest
  self.command(client,'DIAG 32');assert client.signatures[1,32]==expected and client.games[1,32]==expected_game
  for _ in range(4):
   if client.latest['head']>=34:break
   self.advance();self.command(client,f'STEP {self.round}')
  assert client.latest['exact_extra_ends']==1,client.latest
  self.command(client,'STATE');self.drain(require_match=False);self.features['source_destroyed_before_actual_complete_import']=True;self.features['pending_end_after_source_death_exactly_once']=True;self.compared.add((1,32))
 def incompatible(self,ticks=0,mode='assets',client_exe=None):
  host,client=self.bootstrap(client_variant=mode,client_exe=client_exe)
  for _ in range(12):self.advance();self.pump(2)
  assert not client.latest.get('ready') and client.latest['head']==0 and client.latest['confirmed']==0,client.latest
  self.command(client,'STATE');before=client.local_state
  for _ in range(8):self.advance();self.pump(2)
  self.command(client,'STATE');assert before==client.local_state,('incompatible recovery mutated published client',before,client.local_state)
  self.drain(require_match=False);self.features['incompatible_'+mode+'_no_publication']=True
 def malformed(self,ticks=0):
  host,client=self.bootstrap();assert client.latest.get('ready');self.drain()
  before=client.latest.copy();self.command(client,'PROBE_SAVE');self.command(host,'MALFORMED')
  for _ in range(8):self.advance();self.pump(2)
  self.command(client,'PROBE_CHECK');assert client.probe_equal is True
  assert client.latest['head']==before['head'] and client.latest['confirmed']==before['confirmed']
  self.features['malformed_actual_authority_packet_no_publication']=True
 def fault(self,ticks=0):
  host,client=self.bootstrap(client_variant='fault');assert client.latest.get('ready')
  for _ in range(64):
   self.advance();self.command(client,f'STEP {self.round}');self.pump(1);self.command(host,f'STEP {self.round}');self.pump(2)
   if client.first_trace:break
  assert client.first_trace and (client.out/'first.trace').exists(),'intentional model violation did not retain first production trace'
  before=(client.out/'first.trace').read_bytes()
  # Do not resync; preserve the first mismatch and real correction input/depth.
  self.features['intentional_model_contract_violation_first_trace']=hashlib.sha256(before).hexdigest()
 def smoke(self,ticks=40):
  host,client=self.bootstrap();assert client.latest.get('ready'),client.latest;self.compare()
  self.relay.configure(latency=1,jitter=1,loss=300,duplicate=700,reorder=1000);self.ticks(ticks);self.drain();assert len(self.compared)>10

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--exe',required=True);ap.add_argument('--framework',choices=['kit','replay'],required=True);ap.add_argument('--out',required=True);ap.add_argument('--seed',type=int,default=1);ap.add_argument('--ticks',type=int,default=300);ap.add_argument('--scenario',choices=['smoke','corpus','lifetime','incompatible','malformed','fault'],default='corpus');ap.add_argument('--mode',default='assets');ap.add_argument('--client-exe');a=ap.parse_args()
 case=Case(a.exe,a.framework,a.out,a.seed)
 (case.out/'run-manifest.json').write_text(json.dumps({'command':sys.argv,'seed':a.seed,'scenario':a.scenario,'mode':a.mode,'endpoint_sha256':hashlib.sha256(pathlib.Path(a.exe).read_bytes()).hexdigest(),'controller_sources':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in [pathlib.Path(__file__),pathlib.Path(__file__).with_name('relay.py')]},'executable_manifest':str(pathlib.Path(a.exe).parent/'endpoint-manifest.json')},indent=2)+'\n')
 try:
  if a.scenario=='incompatible':case.incompatible(a.ticks,a.mode,a.client_exe)
  else:getattr(case,a.scenario)(a.ticks)
 except BaseException as error:
  print(repr(error),file=sys.stderr);case.finish(False,repr(error));raise
 result=case.finish(True)
 assert result['success'],result
 print(json.dumps(result,sort_keys=True))
if __name__=='__main__':main()
