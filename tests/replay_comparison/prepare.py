"""Prepare instrumented, isolated projects for a shared workload driver."""
from pathlib import Path
import hashlib,json,shutil,subprocess,sys,os,re,platform
root=Path(__file__).resolve().parents[2];out=Path(sys.argv[1]).resolve();out.mkdir(parents=True,exist_ok=True)
scenario=os.environ.get('REPLAY_COMPARISON_SCENARIO','idle')
assert scenario in ('idle','firing','combat'),scenario
old=out/'kit'/'project';new=out/'replay'/'project'
subprocess.run([sys.executable,str(root/'tests/replay_scrapyard/prepare_baseline.py'),str(root.parent/'scrapyard'),str(old),str(root)],check=True)
p=old/'project.godot';s=p.read_text().replace('config/name="replay_baseline_stress_kit"','config/name="replay_baseline_stress_'+out.name+'_kit"');p.write_text(s)
subprocess.run([sys.executable,str(root/'tests/replay_scrapyard/baseline_cleanup.py'),str(old)],check=True)
shutil.copytree(root/'examples/replay_scrapyard',new,ignore=shutil.ignore_patterns('.godot','bin','out','node_modules','*.gen.odin','*.uid','*.import','__pycache__'))
p=new/'project.godot';s=p.read_text().replace('config/custom_user_dir_name="replay_scrapyard"','config/custom_user_dir_name="replay_compare_'+out.name+'"');p.write_text(s)
if scenario in ('firing','combat'):
 # A small magazine forces repeat reloads; disable random jams so both real
 # weapon mechanisms receive the same deterministic workload. No sim is stubbed.
 for project in (old,new):
  p=project/'data/guns/bolter.tres';s=p.read_text()
  for key,value in [('mag',3),('jam_per_mille',0)]:
   s,n=re.subn(r'^'+key+r' = \d+$',key+' = '+str(value),s,flags=re.M);assert n==1
  p.write_text(s)
for project in [old,new]:shutil.copy2(root/'tests/replay_comparison/driver.gd',project/'comparison.gd')
for project,package,typ,prefix in [(old,'scrapyard_scripts','Scrapyard','scrapyard'),(new,'replay_scrapyard','ReplayScrapyard','replay_scrapyard')]:
 baseline=project==old
 start_extra='' if baseline else 'if gd.env_int("COMPARE_PHASES",0)==1 {replay_scrapyard_bench_start(self)}'
 stop_extra='' if baseline else 'if gd.env_int("COMPARE_PHASES",0)==1 {_ = replay_scrapyard_bench_finish(self)}'
 imports='import ks "godot:kit/session"\nimport kn "godot:kit/net"' if baseline else 'import rgd "godot:replay/godot"'
 probe='''
 if key=="ready" {return self.started ? 1 : 0}
 if key=="players" {return gd.Int(ks.session_count(&self.ses,connected_only=true))}
 if key=="stage" {return self.world!=nil ? gd.Int(self.world.stage)+1 : -1}
 if key=="mobs" {return gd.Int(len(self.mobs))}
 if key=="seed" {return self.world!=nil ? gd.Int(self.world.seed) : 0}
 if key=="tick" {return gd.Int(ks.session_tick_no(&self.ses))}
 if key=="projectiles" {return self.ses.is_host ? gd.Int(len(self.flying)) : -1}
 if key=="declared" {claim:=seat_claim(self,kn.Player_Id(seat));return claim.look==0 && claim.iron==0 ? 1 : 0}
 r,ok:=runner_of(self,kn.Player_Id(seat));if !ok {return -1}
 switch key {case "spent":return gd.Int(r.weapon.spent);case "ammo":return gd.Int(r.weapon.ammo);case "mode":return gd.Int(r.weapon.mode);
 case "mag":return gd.Int(r.weapon.def.mag);case "jam":return gd.Int(r.weapon.def.jam_per_mille);case "reload":return gd.Int(r.weapon.def.reload_ticks);case "cooldown":return gd.Int(gun_row(r.gun).cooldown)}
 switch key {case "x":return gd.Int(r.x);case "y":return gd.Int(r.y);case "hp":return gd.Int(r.health.hp);case "iron":return gd.Int(r.gun);case "look":return gd.Int(r.look)}
''' if baseline else '''
 frame,ok:=rgd.session_authority_state(self.session)
 if key=="baseline_misses" {return self.session.authority ? gd.Int(self.session.server.stats.rejected_acks) : gd.Int(self.session.client.stats.baseline_misses)}
 if key=="resyncs" {return self.session.authority ? 0 : gd.Int(self.session.client.stats.resyncs)}
 if key=="facts_head" {return self.session.authority ? gd.Int(frame.tick) : gd.Int(self.session.client.facts_contiguous)}
 if key=="latest_snapshot" {return self.session.authority ? 0 : gd.Int(self.session.client.snapshot_latest)}
 if key=="rejected_packets" {return self.session.authority ? gd.Int(self.session.server.stats.rejected_packets) : gd.Int(self.session.client.stats.rejected_packets)}
 if key=="input_turnaround_ms" {return self.session.authority ? 0 : gd.Int(self.session.client.input_timing.turnaround_ms)}
 if key=="arrival_lead_milli" {return self.session.authority ? 0 : gd.Int(self.session.client.input_timing.arrival_lead*1000)}
 if key=="clock_scale_milli" {return self.session.authority ? 1000 : gd.Int(self.session.client.clock_scale*1000)}
 if key=="timing_samples" {return self.session.authority ? 0 : gd.Int(self.session.client.stats.timing_samples)}
 if key=="lead_updates" {return self.session.authority ? 0 : gd.Int(self.session.client.stats.lead_updates)}
 if key=="lead_ticks" {return self.session.authority ? 0 : gd.Int(self.session.client.lead_ticks)}
 if key=="prediction_depth" {return self.session.authority ? 0 : gd.Int(self.session.client.timeline.head)-gd.Int(frame.tick)}
 if key=="replayed_ticks" {return self.session.authority ? 0 : gd.Int(self.session.client.stats.replayed_ticks)}
 if key=="ready" {return ok && frame.state.players[0].in_yard && frame.state.players[1].in_yard ? 1 : 0}
 if key=="tick" {return gd.Int(frame.tick)}
 if key=="stage" {return gd.Int(frame.state.stage)}
 if key=="seed" {return gd.Int(frame.state.seed)}
 if key=="mobs" {return gd.Int(frame.state.mobs.count)}
 if key=="projectiles" {return self.session.authority ? gd.Int(frame.state.shots.count) : -1}
 if key=="players" {count:=0;for p in frame.state.players {if p.connected {count+=1}};return gd.Int(count)}
 p:=frame.state.players[seat-1];gun:=frame.state.catalog.guns[p.gun_id]
 switch key {case "spent":return gd.Int(p.gun.spent);case "ammo":return gd.Int(p.gun.ammo);case "mode":return gd.Int(p.gun.mode);
 case "mag":return gd.Int(gun.mechanism.mag);case "jam":return gd.Int(gun.mechanism.jam_per_mille);case "reload":return gd.Int(gun.mechanism.reload_ticks);case "cooldown":return gd.Int(gun.cooldown)}
 if key=="declared" {return p.meta_claimed && p.profile.look==0 && p.profile.iron==0 ? 1 : 0}
 switch key {case "x":return gd.Int(p.position[0]);case "y":return gd.Int(p.position[1]);case "hp":return gd.Int(p.hp);case "iron":return gd.Int(p.gun_id);case "look":return gd.Int(p.profile.look)}
'''
 trigger='scrapyard_dev_autofire(self,enabled ? 60 : 0)' if baseline else 'replay_scrapyard_dev_aim(self,1,0,enabled)'
 meter='''
 tx:=u64(self.bytes_win)+compare_packets
 return gd.Int(tx)
''' if baseline else '''
 // Include every admitted application lane, including round-trip telemetry.
 if self.session.link.ready {return gd.Int(self.session.link.router.stats.tx_bytes)}
 return gd.Int(self.session.authority ? self.session.server.stats.tx_bytes : self.session.client.stats.tx_bytes)
'''
 (project/'scripts/comparison.odin').write_text(f'''package {package}
import gd "godot:godot"
{imports}
compare_active:bool
compare_samples:[4096]u64
compare_count,compare_dropped:int
compare_packets:u64
compare_note :: proc(start:u64) {{
 if !compare_active {{return}}
 if compare_count==len(compare_samples) {{compare_dropped+=1;return}}
 compare_samples[compare_count]=gd.time_get_ticks_usec(gd.singleton_time())-start;compare_count+=1
}}
@(gd_method)
{prefix}_compare_trigger :: proc(self:^{typ},enabled:bool) {{{trigger}}}
@(gd_method)
{prefix}_compare_start :: proc(self:^{typ}) {{compare_count,compare_dropped=0,0;compare_active=true;{start_extra}}}
@(gd_method)
{prefix}_compare_stop :: proc(self:^{typ}) {{compare_active=false;{stop_extra}}}
@(gd_method)
{prefix}_compare_sample :: proc(self:^{typ},index:gd.Int)->gd.Int {{
 if index==-1 {{return gd.Int(compare_count)}}
 if index==-2 {{return gd.Int(compare_dropped)}}
 if index<0 || index>=gd.Int(compare_count) {{return -1}}
 return gd.Int(compare_samples[index])
}}
@(gd_method)
{prefix}_compare_tx :: proc(self:^{typ})->gd.Int {{ {meter} }}
@(gd_method)
{prefix}_compare_probe :: proc(self:^{typ},key:string,seat:gd.Int)->gd.Int {{
 if seat<1 || seat>2 {{return -1}}
 {probe}
 return -1
}}
''')
 p=project/'scripts/scrapyard.odin';s=p.read_text();marker=f'{prefix}_process :: proc(self: ^{typ}, '+('delta: f64)' if baseline else 'dt: f64)')+' {';assert s.count(marker)==1
 s=s.replace(marker,marker+'\n compare_started:=compare_active ? gd.time_get_ticks_usec(gd.singleton_time()) : u64(0)\n defer if compare_started!=0 {compare_note(compare_started)}')
 p.write_text(s)
 if baseline:
  p=project/'scripts/bench.odin';s=p.read_text();marker='self.bytes_win += len(bytes)';assert s.count(marker)==1;p.write_text(s.replace(marker,marker+'\n\tcompare_packets+=1'))
if scenario=='combat':
 from combat_overlay import install
 install(old,True);install(new,False)
files=[p for p in out.rglob('*') if p.is_file() and p.suffix in ['.odin','.gd','.tscn','.tres','.png','.wav','.mp3'] and not p.name.endswith('.gen.odin')]
(out/'source-sha256.txt').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+str(p.relative_to(out))+'\n' for p in sorted(files)))
contract={'scenario':'firing_range' if scenario=='firing' else 'idle_arena','seed':1337,'players':2,'hz':60,'frame_cap':60,'warmup_ms':500,'steady_receive_warmup':{'duration_ms':500,'prediction_depth_limit':'measured lead + 4 ticks','facts_ahead_limit_ticks':4},'sample_ms':6000 if scenario=='firing' else 3000,'intents':'stationary, hold eastward fire until nine local observed rounds are spent, then release; no casts' if scenario=='firing' else 'zero movement/fire/casts','expected_positions':[[840,544],[880,544]],'expected_hp':10,'expected_look':0,'expected_iron':0,'population':0,'stage':'cleared empty single-wave floor','application_tx_scope':'all accepted Replay router lanes; Kit protocol bytes plus one-byte transport tag; excludes ENet framing/retransmission','frame_metric':'inclusive game process callback, not CPU-only; UI implementations differ','parity_limits':['authority models differ','UI/audio/presentation differs','no AI, damage or movement performance conclusion']}
if scenario in ('firing','combat'):
 contract.update(client_timing_observations=True,steady_receive_warmup={"duration_ms":500,"prediction_depth_limit":"measured lead + 4 ticks","facts_ahead_limit_ticks":4},weapon={'id':0,'mag':3,'cooldown_ticks':20,'reload_ticks':72,'jam_per_mille':0,'speed_px_per_tick':16,'ttl_ticks':40,'damage':2},
  completion={'shots_per_seat':9,'trigger_release':'at nine locally observed spent rounds; no later than sample end','minimum_reload_entries_per_seat':2,'maximum_authoritative_projectiles':4,'drain_timeout_ms':4000},
  trace_scope='per-process observations; host values authoritative, Kit client owner weapon may be predicted, Replay client uses received authority frames; projectile counts sampled on host only',
  input_barrier='both peers complete warmup before arming; local starts may differ by one process frame; ingress delay is retained',
  baseline_overlay='ownership/lifecycle repairs plus read-only timing/probes; bolter magazine=3 and jam probability=0 in both isolated content copies')
(out/'contract.json').write_text(json.dumps(contract,indent=2)+'\n')

if scenario=='combat':
 contract.update(scenario='combat_encounter',sample_ms=8000,population=4,
  intents='stationary; spawn four stock scrapbots near seat 2; after observing player damage, hold nearest-enemy fire until nine local spent rounds then release; no casts',
  expected_hp='alive, at most 10; at least one enemy hit required',
  spawn_offsets_from_seat2=[[80,-20],[80,0],[80,20],[100,0]],
  expected_spawn_positions=[[960,524],[960,544],[960,564],[980,544]],
  completion={'shots_per_seat':9,'kills':4,'damage':12,'scrap':12,'minimum_reload_entries_per_seat':2,'maximum_authoritative_projectiles':4,'drain_timeout_ms':4000},
  stage='cleared empty floor with an explicit four-mob encounter through existing development spawn paths',
  parity_limits=['authority models and presentation differ','spawn requests enter through existing APIs at different simulation boundaries',"target selection uses each game's nearest observed living mob",'damage attribution, received player damage and transient timing/populations may differ','single small encounter; no sustained-swarm or full-game conclusion'],
  observer_costs_separate=True,census='one extra read-only mob/drop/stat census outside the game callback per process frame; elapsed census/observation cost is retained',
  spawn_and_targeting_cost='executed inside the timed real game process callback')
 (out/'contract.json').write_text(json.dumps(contract,indent=2)+'\n')

contract['repetitions']=int(os.environ.get('REPLAY_COMPARISON_REPETITIONS','3'))
contract['faults']={'receive_delay_ms_per_process':120,'jitter_ms':0,'loss_permyriad':0,'duplicate_permyriad':0,'rtt_distribution_measured':False}
(out/'contract.json').write_text(json.dumps(contract,indent=2)+'\n')
directories=[name for name in ['core','godot','gdext','runtime','kit','play','replay','build','scriptgen'] if (root/name).is_dir()]
paths=subprocess.check_output(['rg','--files',*directories],cwd=root,text=True).splitlines()
framework={name:hashlib.sha256((root/name).read_bytes()).hexdigest() for name in sorted(paths) if Path(name).suffix in ['.odin','.sh','.py','.nix']}
(out/'framework-source.json').write_text(json.dumps({'root':str(root),'sha256':framework},indent=2)+'\n')
for name,repo in [('framework',root),('original',root.parent/'scrapyard')]:
 (out/(name+'-diff.patch')).write_bytes(subprocess.check_output(['git','diff','--binary','--no-ext-diff'],cwd=repo))
 (out/(name+'-status.txt')).write_bytes(subprocess.check_output(['git','status','--short'],cwd=repo))
info={'platform':platform.platform(),'machine':platform.machine(),'processor':platform.processor(),'gameplay_godot':os.environ.get('GODOT','godot'),
      'framework_revision':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),
      'original_revision':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root.parent/'scrapyard',text=True).strip(),
      'godot_version':subprocess.check_output([os.environ.get('GODOT','godot'),'--version'],text=True).strip(),
      'measurement_order':[['kit','replay'] if pair%2 else ['replay','kit'] for pair in range(1,contract['repetitions']+1)]}
if sys.platform=='darwin':
 for key,syskey in [('cpu','machdep.cpu.brand_string'),('memory_bytes','hw.memsize')]:
  result=subprocess.run(['sysctl','-n',syskey],capture_output=True,text=True)
  if result.returncode==0:info[key]=result.stdout.strip()
(out/'environment.json').write_text(json.dumps(info,indent=2)+'\n')

contract['input_timing_feedback']=True
(out/'contract.json').write_text(json.dumps(contract,indent=2)+'\n')
