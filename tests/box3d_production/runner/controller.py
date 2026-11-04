#!/usr/bin/env python3
"""Actual exported pairs with bounded disk intake; Root execution only."""
from pathlib import Path
import argparse,hashlib,importlib.util,json,os,re,signal,subprocess,sys,threading,time
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[3]
from intake import Actor,strict
from evidence import Aggregate,need,integer,frozen_marker,gap_proof
import overlay

def sha(p):
 h=hashlib.sha256()
 with Path(p).open('rb') as f:
  for chunk in iter(lambda:f.read(1024*1024),b''):h.update(chunk)
 return h.hexdigest()
def inventory(folder):return {str(p.relative_to(folder)):sha(p) for p in sorted(folder.rglob('*')) if p.is_file()}
def save(path,value):
 with Path(path).open('x') as f:json.dump(value,f,indent=2,allow_nan=False);f.write('\n');f.flush();os.fsync(f.fileno())
def load_sample():
 spec=importlib.util.spec_from_file_location('unchanged_sample_evidence',ROOT/'tests/box3d_samples/run.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m

def owned_state(pid):
 result=subprocess.run(['ps','-o','pid=,pgid=,stat=','-p',str(pid)],capture_output=True,text=True,timeout=1)
 fields=result.stdout.split()
 need(result.returncode==0 and len(fields)==3 and int(fields[0])==pid and int(fields[1])==pid,'owned process state unavailable')
 return fields[2]
def scope_outcome(before,after,pause_ms):
 if not before or not after or before.get('recovery_available') is not True or after.get('recovery_available') is not True:return 'UNAVAILABLE'
 keys=['epoch','recovery_serial','baseline']
 if before.get('generation') is not None or after.get('generation') is not None:keys.append('generation')
 if not all(integer(before.get(k)) and integer(after.get(k)) for k in keys+['recoveries']):return 'UNAVAILABLE'
 if after['recoveries']>before['recoveries'] and any(after[k]!=before[k] for k in keys):return 'validated_canonical_recovery'
 if after['recoveries']==before['recoveries'] and all(after[k]==before[k] for k in keys):return 'same_validated_scope'
 return 'UNPROVEN'
def require_workload(aggregates,rows,required_ticks):
 # Called after terminal(), final_view() and pair complete-five equality. A
 # terminal result can advance beyond the last bounded STATUS cadence.
 need(all(a.first_go is not None and a.last_live_at is not None for a in aggregates.values()),'actual bothGO observation unavailable')
 for role in aggregates:
  result=rows[role]['terminal']['result'];tick=rows[role]['manifest'].get('tick')
  need(integer(result.get('confirmed')) and result['confirmed']>=required_ticks and integer(tick) and tick>=required_ticks,'actual validated terminal workload unavailable')
def live_status_duration(aggregates):
 first={role:a.first_go for role,a in aggregates.items()};last={role:a.last_live_at for role,a in aggregates.items()}
 need(all(x is not None for x in [*first.values(),*last.values()]),'actual GO/live STATUS arrival anchors unavailable')
 start=max(first.values());end=min(last.values());interval=end-start
 return dict(available=interval>=0,signed_interval_seconds=interval,both_GO_observed=start,last_common_live_status_observed=end,first_GO_by_role=first,last_live_status_by_role=last,scope='external intake arrivals only; negative interval retained, no inferred producer wall duration')
def require_duration(observation,minimum):
 if minimum>0:need(observation['available'] and observation['signed_interval_seconds']>=minimum,'actual live-status duration below declared minimum')
def require_authority_inputs(framework,inputs):
 need(inputs is not None,'actual authority input summary absent')
 if framework=='kit':need(len(inputs.get('nonzero_by_seat',[]))==2 and all(x>0 for x in inputs['nonzero_by_seat']),'actual nonzero authority seats absent')
 else:
  counts=inputs.get('nonzero_by_seat')
  need(isinstance(counts,list) and len(counts)==2 and all(integer(x) and x>0 for x in counts),'actual committed nonzero controls for both authority seats unavailable')
def process_exit_failure(actor,aggregate):
 code=actor.process.poll()
 if code is None:return None
 if code<0:kind='signal_exit'
 else:
  # Ordinary exit may precede queued stdout/RESULT delivery. Judge missing
  # producer evidence only after actual EOF and all indexed rows are consumed.
  if not actor.eof or actor.consumed!=actor.seen:return None
  if code!=0:kind='ordinary_nonzero_exit'
  elif aggregate.result_count!=1:kind='ordinary_exit_missing_RESULT'
  else:return None
 return dict(role=actor.role,pid=actor.pid,actual_exit=code,signal_number=-code if code<0 else None,kind=kind,stdout_EOF_at_detection=actor.eof,records_seen=actor.seen,records_consumed=actor.consumed)
def rss_sample(actor,aggregate,measurements):
 try:
  r=subprocess.run(['ps','-o','rss=','-p',str(actor.pid)],capture_output=True,text=True,timeout=.5);text=r.stdout.strip()
  if r.returncode or not text.isdecimal():raise ValueError('RSS unavailable')
  now=time.monotonic();value=int(text)*1024;sample={'observed':now,'bytes':value};a=aggregate.rss
  if a['first'] is None:a['first']=sample
  a['last']=sample;a['count']+=1;a['peak_bytes']=max(a['peak_bytes'],value);a['min_bytes']=value if a['min_bytes'] is None else min(a['min_bytes'],value)
  measurements.write(json.dumps(dict(role=actor.role,pid=actor.pid,**sample))+'\n');measurements.flush();os.fsync(measurements.fileno())
 except (OSError,ValueError,subprocess.TimeoutExpired):aggregate.rss['unavailable']+=1

def module_fence(before,after,pids):
 pattern=r"((?:.*/)?libodinscripts[^/]*\.(dylib|so|dll))\.r([0-9]+)\.p([0-9]+)\.\2"
 prior={};derived={}
 for name,digest in before.items():
  m=re.fullmatch(pattern,name)
  if m and before.get(m[1])==digest:prior[name]={'source':m[1],'pid':int(m[4]),'sha256':digest}
 for name in after.keys()-before.keys():
  m=re.fullmatch(pattern,name)
  if m and int(m[4]) in pids and before.get(m[1])==after[name]:derived[name]={'source':m[1],'pid':int(m[4]),'sha256':after[name]}
 okay=all(after.get(k)==v for k,v in before.items() if k not in prior) and all(k not in after or after[k]==v['sha256'] for k,v in prior.items()) and set(after)-set(before)==set(derived)
 return okay,prior,derived

def run(args):
 record_path=args.record.resolve(strict=True);record=strict(record_path.read_bytes());framework=record.get('framework')
 need(record.get('result')=='PASS' and record.get('source_fence_unchanged') is True and framework in ('kit','replay'),'bound successful ordinary export required')
 bundle=Path(record['bundle_root']).resolve(strict=True);executable=Path(record['executable']).resolve(strict=True)
 need(executable.is_relative_to(bundle) and executable.is_file(),'actual exported executable absent')
 for name,digest in record['artifacts'].items():
  path=(bundle/name).resolve(strict=True);need(path.is_relative_to(bundle) and sha(path)==digest,'actual export artifact changed')
 need(record.get('project_overlay_fence_unchanged') is True and record.get('project_overlay',{}).get('sha256')==overlay.describe(Path(__file__).with_name('pause_overlay'))['sha256'] and record['project_overlay'].get('project_settings')==overlay.PROJECT_SETTINGS,'actual exported production/flush overlay binding absent')
 out=args.out.resolve();out.mkdir(parents=True,exist_ok=False);before=inventory(bundle);record_hash=sha(record_path)
 helpers={str(p):sha(p) for p in [Path(__file__),Path(__file__).with_name('intake.py'),Path(__file__).with_name('evidence.py'),Path(__file__).with_name('overlay.py'),ROOT/'tests/box3d_samples/run.py']}
 save(out/'bundle-before.json',before)
 actors=[];aggregates={};wake=threading.Event();error=None;cleanup=[];facts=[];process_failures={};evidence=None;duration_observation=None;pause=None;host_boundary=None;pause_verified=None;pause_deadline=None;resumed=False
 argv=[str(executable),'--headless']
 def receive(actor,row,at):
  nonlocal pause,host_boundary
  aggregates[actor.role].receive(row,at)
  if row['event']=='SAMPLE_PRODUCTION_HOST':
   need(actor.role=='host' and row.get('pid')==actor.pid and integer(row.get('head')),'host boundary ownership unavailable')
   raw=strict(row['status_json']);need(raw.get('go') is True and raw.get('head')==row['head'],'host boundary not actual live getter')
   host_boundary={'row':row,'observed':at}
  elif row['event']=='SAMPLE_PRODUCTION_PAUSE':
   need(args.pause_ms and pause is None,'unexpected/duplicate actual self-pause')
   raw=frozen_marker(row,actor.pid);need(row.get('requested_ms')==args.pause_ms,'pause declaration differs')
   pause={'row':row,'status':raw,'observed':at}
  elif row['event']=='SAMPLE_PRODUCTION_RESUME':
   need(actor.role=='client' and row.get('pid')==actor.pid and row.get('kill_exit')==0,'self-stop command/resume failed')
   need(pause is not None,'resume without real pause');pause['actual_resume_row']=row
 try:
  for role in ['host','client']:
   env={k:v for k,v in os.environ.items() if k not in ['ODIN_SCRIPTS_DLL','ODIN_GODOT_ROOT','BOX3D_NATIVE_LIBRARY'] and not k.startswith(('BOX3D_SAMPLE_','BOX3D_PRODUCTION_'))}
   folder=out/role;env.update(BOX3D_SAMPLE_ROLE=role,BOX3D_SAMPLE_PORT=str(args.port),BOX3D_SAMPLE_TICKS=str(args.ticks),BOX3D_SAMPLE_SCRIPTED='1',BOX3D_SAMPLE_OUTPUT=str(folder))
   if args.pause_ms:env.update(BOX3D_PRODUCTION_PAUSE_MS=str(args.pause_ms),BOX3D_PRODUCTION_PAUSE_AT=str(args.pause_at))
   actor=Actor(role,argv,env,folder,{'export_record_sha256':record_hash,'executable_sha256':sha(executable),'overlay':record.get('project_overlay')},wake);actors.append(actor);aggregates[role]=Aggregate(role)
  deadline=time.monotonic()+args.timeout;last_rss=0.0
  with (out/'rss.jsonl').open('x') as measurements:
   while True:
    wake.clear()
    for actor in actors:actor.consume(receive)
    for actor in actors:
     failure=process_exit_failure(actor,aggregates[actor.role])
     if failure is not None:
      process_failures[actor.role]=failure
      raise RuntimeError('actual owned subprocess exit '+str(failure))
    now=time.monotonic()
    if args.pause_ms and pause is not None and not resumed:
     client=actors[1]
     if pause_verified is None:
      state=owned_state(client.pid)
      if 'T' in state:
       pause_verified=now;pause_deadline=now+args.pause_ms/1000;pause['verified_owned_T']={'pid':client.pid,'state':state,'observed':now}
      need(now-pause['observed']<2,'self SIGSTOP did not reach verified owned T state')
     elif now>=pause_deadline:
      need(host_boundary is not None and host_boundary['observed']>=pause_verified and now-host_boundary['observed']<=.1,'fresh actual Host boundary unavailable at resume; not a1Hz estimate')
      gap=gap_proof(pause['row'],host_boundary['row'],args.pause_ms)
      state=owned_state(client.pid);need('T' in state,'owned Client no longer stopped before controller resume')
      os.kill(client.pid,signal.SIGCONT);resumed=True
      pause['controller_resume']={'observed':time.monotonic(),'state_before':state,'actual_stopped_seconds_since_T':now-pause_verified,'fresh_Host_boundary':host_boundary,'actual_observed_head_gap':gap}
    if now-last_rss>=1:
     for actor in actors:
      if actor.process.poll() is None:rss_sample(actor,aggregates[actor.role],measurements)
     last_rss=now
    if all(actor.done() for actor in actors):break
    need(now<deadline,'production supervisor timeout');wake.wait(.01)
  for actor in actors:
   fact=actor.finish();facts.append(fact);need(fact['natural'] and fact['actual_exit']==0 and fact['intake_drained'] and fact['error'] is None,'actual natural clean intake unavailable')
  sample=load_sample();rows={}
  for actor in actors:
   terminal=aggregates[actor.role].terminal(framework,args.ticks)
   manifest,parts,view=sample.final_view(actor.folder,args.ticks)
   need(manifest.get('content_sha256')==terminal['ready'].get('content_sha256'),'actual final content differs')
   rows[actor.role]={'terminal':terminal,'manifest':manifest,'parts':parts,'complete_view':view}
  need(rows['host']['manifest']['epoch']==rows['client']['manifest']['epoch'] and rows['host']['terminal']['ready']['content_sha256']==rows['client']['terminal']['ready']['content_sha256'] and all(rows['host']['parts'][p]==rows['client']['parts'][p] for p in sample.PARTS),'actual five-part confirmed bytes differ')
  host=aggregates['host'];client=aggregates['client'];inputs=host.inputs
  require_authority_inputs(framework,inputs)
  need(host.ack is not None and host.ack.get('tick')==args.ticks and host.ack.get('epoch')==rows['host']['manifest']['epoch'],'actual verified terminal signatureACK unavailable')
  require_workload(aggregates,rows,args.required_ticks)
  duration_observation=live_status_duration(aggregates);duration=duration_observation['signed_interval_seconds']
  require_duration(duration_observation,args.minimum_seconds)
  if args.minimum_seconds>0:need(all(a.rss['count']>=2 for a in aggregates.values()),'actual long RSS trend unavailable')
  pause_result=None
  if args.pause_ms:
   need(pause is not None and resumed and 'actual_resume_row' in pause,'actual pause/CONT completion unavailable')
   outcome=scope_outcome(pause['status'],client.latest,args.pause_ms);need(outcome not in ('UNAVAILABLE','UNPROVEN'),'validated catchup/recovery scope unavailable; no headjump inference')
   pause_result={'proof':pause,'outcome':'bounded_confirmed_catchup_same_validated_scope' if outcome=='same_validated_scope' else outcome,'confirmed_target_five_parts_verified':True,'scope_after':client.latest,'not_certified':'packet loss/jitter/native CPU'}
  evidence={role:{k:v for k,v in row.items() if k!='parts'} for role,row in rows.items()}
  evidence.update(all_five_byte_equal=True,authority_inputs=inputs,actual_final_ACK=host.ack,required_ticks=args.required_ticks,terminal_tick=args.ticks,observed_live_status_seconds_after_both_GO=duration,live_status_duration_available=duration_observation['available'],duration_requirement_applied=args.minimum_seconds>0,duration_scope='signed external GO/live STATUS arrival interval; no clamp or audit/cleanup time',pause=pause_result)
 except Exception as exc:error=repr(exc)
 finally:
  if error is not None:
   for actor in actors:
    # A live stdout descendant also needs cleanup after its leader exits.
    # Once EOF is observed, finishing the reader's index close is not a process.
    if actor.process.poll() is None or (not actor.eof and actor.thread.is_alive()):actor.kill_owned()
  for actor in actors:
   try:
    actor.process.wait(timeout=10);actor.thread.join(timeout=10)
    while actor.consumed<actor.seen:
     try:actor.consume(lambda _a,_r,_t:None)
     except Exception as exc:
      cleanup.append(repr(exc));break
    if not any(x['pid']==actor.pid for x in facts):facts.append(actor.finish())
   except Exception as exc:cleanup.append(repr(exc))
 after=inventory(bundle);fence,prior,copies=module_fence(before,after,{a.pid for a in actors});helper_fence=all(sha(p)==v for p,v in helpers.items()) and sha(record_path)==record_hash
 save(out/'bundle-after.json',after)
 report={'schema':1,'result':'PASS' if error is None and not cleanup and fence and helper_fence else 'FAIL','case':args.case,'framework':framework,'target':record['target'],'execution_mode':record.get('execution_mode','native'),'export_record':str(record_path),'export_record_sha256':record_hash,'executable':str(executable),'executable_sha256':sha(executable),'argv':argv,'required_ticks':args.required_ticks,'terminal_tick':args.ticks,'minimum_seconds':args.minimum_seconds,'timeout_seconds':args.timeout,'error':error,'cleanup_findings':cleanup,'evidence':evidence,'live_status_duration':duration_observation,'pause_attempt':pause,'actors':facts,'bundle_fence':fence,'prior_verified_copies':prior,'actual_script_module_copies':copies,'helper_fence':helper_fence,'helper_sources':helpers,'scope':'actual ordinary exported functional production evidence; no CPU/packetloss/cross-target equality claim','resource_scope':'64MiB actual cachedtracked admission; RSS separate sampledOS values'}
 report['sample_failures']={role:a.failure for role,a in aggregates.items() if a.failure is not None}
 report['process_failures']=process_failures
 save(out/'report.json',report);print(json.dumps({'result':report['result'],'report':str(out/'report.json'),'error':error}));return 0 if report['result']=='PASS' else 1

def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--record',type=Path,required=True);p.add_argument('--out',type=Path,required=True);p.add_argument('--case',choices=['functional','long','pause300','pause3000'],required=True)
 p.add_argument('--ticks',type=int,required=True);p.add_argument('--required-ticks',type=int,required=True);p.add_argument('--minimum-seconds',type=float,required=True);p.add_argument('--timeout',type=float,required=True);p.add_argument('--port',type=int,required=True);p.add_argument('--pause-at',type=int,default=240);p.add_argument('--pause-ms',type=int,choices=[0,300,3000],default=0)
 a=p.parse_args()
 if a.case=='long':need((a.required_ticks,a.ticks,a.minimum_seconds,a.timeout)==(108000,108600,1800,2400),'long declaration changed')
 return run(a)
if __name__=='__main__':raise SystemExit(main())
