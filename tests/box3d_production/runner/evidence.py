"""Pure event/status/terminal checks; unavailable never becomes zero."""
import math
LIMIT=67108864
def need(value,message):
 if not value:raise ValueError(message)
def integer(value):return type(value) is int and value>=0
class Aggregate:
 def __init__(self,role):
  self.role=role;self.ready=self.result=self.inputs=self.ack=None;self.ready_count=self.result_count=self.status_count=self.memory_count=self.memory_unavailable=0;self.first_go=None;self.last_live_at=None;self.latest=None;self.max_head=self.max_confirmed=0;self.peak_admitted=0;self.native_sampled_frame=None;self.first_scope=self.last_scope=None;self.rss={'count':0,'unavailable':0,'first':None,'last':None,'peak_bytes':0,'min_bytes':None}
  self.meter_count=self.meter_unavailable=self.peak_meter_bytes=0;self.meter_sampled_frame=None;self.resource_peaks={}
  self.failure=None
 def status(self,row,at):
  need(row.get('version')==1 and row.get('role')==self.role,'status identity unavailable');need(type(row.get('go')) is bool,'actual GO unavailable');need(integer(row.get('frames')),'actual diagnostic frame unavailable')
  head,cf=row.get('head'),row.get('confirmed')
  need((head is None or integer(head)) and (cf is None or integer(cf)),'live frontiers malformed')
  if head is not None and cf is not None:
   need(cf<=head and head-cf<=8,'actual ordinary prediction bound violated')
   self.max_head=max(self.max_head,head);self.max_confirmed=max(self.max_confirmed,cf)
   if row['go']:
    self.first_go=at if self.first_go is None else self.first_go;self.last_live_at=at
  self.latest=row;self.status_count+=1
  if row.get('recovery_available') is True:
   scope={k:row.get(k) for k in ['epoch','generation','recoveries','recovery_serial','baseline']}
   need(all(integer(scope[k]) for k in ['epoch','recoveries','recovery_serial','baseline']),'validated recovery scope unavailable')
   if self.first_scope is None:self.first_scope=scope
   self.last_scope=scope
  if row.get('native_observed') is True:
   frame=row.get('native_sampled_frame');admitted=row.get('admitted_bytes');limit=row.get('limit_bytes')
   fields=['native_live_bytes','wrapper_live_bytes','host_live_bytes','reserved_bytes','admitted_bytes','owner_count']
   need(integer(frame) and frame<=row['frames'] and all(integer(row.get(k)) for k in fields) and limit==LIMIT,'available Native observation malformed')
   need(admitted<=limit,'actual64MiB admission exceeded')
   self.peak_admitted=max(self.peak_admitted,admitted)
   for key in fields:self.resource_peaks[key]=max(self.resource_peaks.get(key,0),row[key])
   if self.native_sampled_frame!=frame:self.memory_count+=1;self.native_sampled_frame=frame
  else:self.memory_unavailable+=1
  if row.get('meter_observed') is True:
   frame=row.get('meter_sampled_frame');live=row.get('meter_live_bytes')
   need(integer(frame) and frame<=row['frames'] and integer(live),'available Meter observation malformed')
   self.peak_meter_bytes=max(self.peak_meter_bytes,live)
   if self.meter_sampled_frame!=frame:self.meter_count+=1;self.meter_sampled_frame=frame
  else:self.meter_unavailable+=1
 def receive(self,row,at):
  event=row['event']
  if event=='SAMPLE_STATUS':self.status(row,at)
  elif event=='SAMPLE_READY':self.ready_count+=1;self.ready=row
  elif event=='SAMPLE_RESULT':
   self.result_count+=1;self.result=row
   if row.get('ok') is False:
    self.failure=dict(row=row,observed=at)
    raise ValueError('actual failed SAMPLE_RESULT '+str(row))
  elif event=='SAMPLE_INPUTS':self.inputs=row
  elif event in ('SAMPLE_ACK','SAMPLE_TAIL') and self.role=='host':
   if (event=='SAMPLE_ACK' and row.get('scope')=='verified_terminal_signature_ack' and row.get('matched') is True) or (event=='SAMPLE_TAIL' and row.get('stage')=='final_accepted' and row.get('signature_match') is True):self.ack=row
  elif event in ('SAMPLE_ERROR','SAMPLE_FAILURE'):
   self.failure=dict(row=row,observed=at)
   raise ValueError('actual sample error '+str(row))
 def terminal(self,framework,ticks):
  need(self.ready_count==self.result_count==1,'exact actual READY/RESULT unavailable')
  need(str(self.ready.get('framework','')).lower()==framework and self.ready.get('role')==self.role and integer(self.ready.get('native_images')) and self.ready['native_images']==1,'actual framework/role/native census differs')
  result=self.result;need(str(result.get('framework','')).lower()==framework and result.get('role')==self.role and result.get('ok') is True and result.get('errors')==[] and integer(result.get('target')) and result['target']==ticks and integer(result.get('confirmed')) and result['confirmed']>=ticks,'actual final confirmed result failed')
  c=result.get('cleanup',{});need(all(integer(c.get(k)) and c[k]==0 for k in ['native','wrapper','meter','owners']) and c.get('owners_observed',c.get('observed')) is True and integer(c.get('owners_before')) and integer(c.get('owners_after')) and c['owners_before']==c['owners_after'],'actual cleanup/baseline unavailable')
  need(self.status_count>0 and self.memory_count>0 and self.meter_count>0,'status/admission/Meter observation unavailable')
  if self.rss['first'] and self.rss['last']:
   seconds=self.rss['last']['observed']-self.rss['first']['observed'];delta=self.rss['last']['bytes']-self.rss['first']['bytes']
   self.rss.update(observed_seconds=seconds,last_minus_first_bytes=delta,bytes_per_second=delta/seconds if seconds>0 else None,scope='sampledOS trend, not Native quota or proof of cause/leak')
  return dict(ready=self.ready,result=result,status_count=self.status_count,actual_memory_samples=self.memory_count,memory_unavailable_rows=self.memory_unavailable,peak_admitted_bytes=self.peak_admitted,limit_bytes=LIMIT,resource_field_peaks=self.resource_peaks,meter_samples=self.meter_count,meter_unavailable_rows=self.meter_unavailable,peak_meter_bytes=self.peak_meter_bytes,memory_scope='cached public observations with actual sampled-frame tags; component peaks are not summed',last_status=self.latest,first_validated_scope=self.first_scope,last_validated_scope=self.last_scope,rss=self.rss)
def frozen_marker(row,pid):
 need(row.get('pid')==pid and row.get('role')=='client','pause does not name actual owned Client')
 status=__import__('json').loads(row['status_json'])
 need(status.get('go') is True and integer(status.get('head')) and integer(status.get('confirmed')),'pause live public boundary unavailable')
 need(row.get('head')==status['head'] and row.get('confirmed')==status['confirmed'],'pause snapshot does not match actual raw getter')
 return status
def gap_proof(stopped,host,pause_ms):
 need(integer(stopped.get('head')) and integer(host.get('head')),'actual observed heads unavailable')
 gap=host['head']-stopped['head'];need(gap>(128 if pause_ms==3000 else 8),'actual observed gap insufficient')
 return gap
