from pathlib import Path
import hashlib,json,shutil,subprocess,sys
root=Path(__file__).resolve().parents[2];here=Path(__file__).resolve().parent;out=Path(sys.argv[1]).resolve()
subprocess.run([sys.executable,str(root/'tests/replay_swarm_comparison/prepare.py'),str(out)],check=True)
shutil.copy2(out/'contract.json',out/'swarm-contract.json')
project=out/'replay/project';driver=(project/'comparison.gd').read_text()
driver=driver.replace('Time.get_ticks_msec()+2000\n if not await until(func():return Time.get_ticks_msec()>=settle_until)', 'Time.get_ticks_msec()+8000\n if not await until(func():return Time.get_ticks_msec()>=settle_until)')
# Network loss can omit a short-lived body from a client's observational census;
# authority conservation and replicated final game totals remain mandatory.
driver=driver.replace('"resyncs":0 if implementation=="kit" else p("resyncs"),', '"resyncs":0 if implementation=="kit" else p("resyncs"),"net_phase":int(game.probe("phase",1)),"part_rx":int(game.probe("snapshot_parts_received",1)),"part_expired":int(game.probe("snapshot_parts_expired",1)),"lz4":int(game.probe("lz4_snapshots",1)),')
driver=driver.replace('func census():\n', 'func census():\n if not p("ready"):\n  if phase=="measure":trace.append({"us":Time.get_ticks_usec()-measurement_started,"ready":false,"resyncs":p("resyncs")})\n  return\n')
driver=driver.replace('trace.append({"us":Time.get_ticks_usec()-measurement_started,"tick":', 'trace.append({"us":Time.get_ticks_usec()-measurement_started,"ready":true,"tick":')
driver=driver.replace('if not invariants():fail("measurement invariants")', 'if p("ready") and not invariants():fail("measurement invariants")')
driver=driver.replace('return p("projectiles")<=0 and p("mode",1)==0', 'return p("ready") and p("projectiles")<=0 and p("mode",1)==0')
driver=driver.replace('"known":seen.size(),"health_sum":', '"ready":bool(p("ready")),"tick":p("tick"),"resyncs":p("resyncs"),"known":seen.size(),"health_sum":')
driver=driver.replace('print("REPLAY_SWARM_PEER_OK "','print("REPLAY_NETWORK_FAULT_PEER_OK "')
driver=driver.replace('"net_phase":int(game.probe("phase",1)),', '"net_phase":int(game.probe("phase",1)),"pending_tick":p("pending_tick"),"confirmed":p("timeline_confirmed"),"journal":p("journal_confirmed"),"cache_ready":p("cache_ready"),"cache_oldest":p("cache_oldest"),"cache_newest":p("cache_newest"),"base_misses":p("baseline_misses"),"bad_packets":p("rejected_packets"),"resync_reason":int(game.probe("resync_reason",1)),')
probe=project/'scripts/comparison.odin';text=probe.read_text();anchor=' if key=="baseline_misses"'
extra='''
 if !self.session.authority {
  c:=&self.session.client
  if key=="pending_tick" {return c.has_pending ? gd.Int(c.pending.frame.tick) : -1}
  if key=="timeline_confirmed" {return gd.Int(c.timeline.confirmed)}
  if key=="journal_confirmed" {return gd.Int(c.journal.confirmed)}
  count:=0;oldest:=max(u64);newest:u64
  for id,i in c.snapshot_rx.ids {if id!=0 {
   tick:=c.snapshot_ticks[i];oldest=min(oldest,tick);newest=max(newest,tick)
   if tick>c.timeline.confirmed && tick<=c.facts_contiguous {count+=1}
  }}
  if key=="cache_ready" {return gd.Int(count)}
  if key=="cache_oldest" {return oldest==max(u64) ? -1 : gd.Int(oldest)}
  if key=="cache_newest" {return gd.Int(newest)}
 }
'''
assert text.count(anchor)==1;probe.write_text(text.replace(anchor,extra+anchor))
driver=driver.replace('"phase":phase,"ms":', '"phase":phase,"declared":[p("declared",1),p("declared",2)],"looks":[p("look",1),p("look",2)],"irons":[p("iron",1),p("iron",2)],"players":p("players"),"ms":')
(project/'comparison.gd').write_text(driver)
files=[p for p in out.rglob('*') if p.is_file() and p.suffix in ('.odin','.gd','.tscn','.tres','.png','.wav','.mp3') and not p.name.endswith('.gen.odin')]
(out/'source-sha256.txt').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+str(p.relative_to(out))+'\n' for p in sorted(files)))
shutil.copy2(here/'contract.json',out/'contract.json')
print('REPLAY_NETWORK_FAULT_PREPARED')
