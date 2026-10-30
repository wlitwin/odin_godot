from pathlib import Path
import hashlib,json,os,subprocess,sys
root=Path(__file__).resolve().parents[2];out=Path(sys.argv[1]).resolve()
subprocess.run([sys.executable,str(root/'tests/replay_browser_stress/prepare.py'),str(out)],check=True)
project=out/'replay/project';p=project/'web_stress.gd';s=p.read_text()
s=s.replace('started=Time.get_ticks_msec();run.call_deferred()','started=Time.get_ticks_msec()\n if not bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has(\'stress_return\')",true)):run.call_deferred()')
s=s.replace('"resume":game.set_process(true)','''"resume":game.set_process(true)
    "load":game.compare_start();game.compare_swarm(true);game.compare_move(0,1);game.compare_trigger(true)
    "snapshot_capture":
     JavaScriptBridge.eval("globalThis.replaySnapshotPair="+JSON.stringify({"base":game.browser_snapshot_capture(0),"target":game.browser_snapshot_capture(1),"meta":game.browser_snapshot_capture(2)})+";0",true)
    "stopload":game.compare_swarm(false);game.compare_trigger(false);game.compare_move(0,0);game.compare_stop()
    "handoff":
     var accepted:bool=game.handoff()
     assert(accepted)''')
s=s.replace('"backup_tick"]','"backup_tick","prepared_tick","prepared_bytes","known_tick","rollback_limit","too_old","claims","wire_bytes","raw_bytes","layout_archives","layout_saved","capture_channel","reply_reliable","capture_tick","capture_started","offer_acked","sent_chunks","acked_chunks","transfer_retries","transfer_deferred","incoming_tick","incoming_started","incoming_chunks","incoming_latest","candidate_tick","public_snapshot_bytes","public_excluded_fields","snapshot_shuffle_available"]')
s=s.replace('"resyncs","resync_reason"','"epoch","authority","seat","recovery_tick","recovery_ready","recovery_kind","lost_ticks","restored_exact","room_phase","control_error","resyncs","resync_reason"')
s=s.replace('"dashes":game.probe("dashes",2)','"dashes":game.probe("dashes",1)')
s=s.replace('func _process(_dt:float):', 'var snapshot_apply_trace:=false\nfunc _process(_dt:float):\n if snapshot_apply_trace:\n  var began:=Time.get_ticks_usec()\n  var data:String=game.browser_snapshot_state()\n  var cost:=Time.get_ticks_usec()-began\n  JavaScriptBridge.eval("(()=>{const t=globalThis.replaySnapshotApplyTrace;if(t.rows.length<t.limit)t.rows.push(Object.assign("+data+",{at_ms:performance.timeOrigin+performance.now(),phase:"+JSON.stringify(phase)+",probe_us:"+str(cost)+"}));else t.overflow++;})();0",true)')
s=s.replace('started=Time.get_ticks_msec()\n if not', 'snapshot_apply_trace=bool(JavaScriptBridge.eval("Boolean(globalThis.replaySnapshotApplyTrace)",true))\n started=Time.get_ticks_msec()\n if not')
s=s.replace('stress_query_handled=query;var value=', 'game.compare_census()\n  stress_query_handled=query;var value=')
s=s.replace('"dash_pending":game.dash_probe("pending")','"living":game.compare_combat_probe("living",1),"spent1":game.compare_probe("spent",1),"spent2":game.compare_probe("spent",2),"dash_pending":game.dash_probe("pending")')
p.write_text(s)
p=project/'scripts/browser_stress.odin'  ;s=p.read_text();key=' if key=="rtc_failed"';i=s.index(key);s=s[:i]+''' if key=="public_snapshot_bytes" {return gd.Int(self.session.authority ? self.session.server.codecs.snapshot.wire_size : self.session.client.codecs.snapshot.wire_size)}
 if key=="public_excluded_fields" {return gd.Int(self.session.authority ? self.session.server.codecs.snapshot.excluded_fields : self.session.client.codecs.snapshot.excluded_fields)}
 if key=="snapshot_shuffle_available" {
  if !self.session.authority {return gd.Int(self.session.client.snapshot_shuffle_enabled)}
  for peer,i in self.session.server.peers {if !peer.local && peer.seat==2 && peer.phase==.Running {return gd.Int(self.session.server.snapshot_tx[i].shuffle_enabled)}}
  return 0
 }
 if key=="capture_channel" {return gd.Int(self.session.link.outgoing.channel)}
 if key=="reply_reliable" {return gd.Int(self.session.link.incoming.reliable_replies)}
 if key=="capture_tick" {return gd.Int(self.session.link.outgoing.archive.tick)}
 if key=="capture_started" {return gd.Int(self.session.link.outgoing.started)}
 if key=="offer_acked" {return gd.Int(self.session.link.outgoing.offer_acked)}
 if key=="sent_chunks" {n:=0;for sent in self.session.link.outgoing.sent {if sent {n+=1}};return gd.Int(n)}
 if key=="acked_chunks" {n:=0;for acked in self.session.link.outgoing.acked {if acked {n+=1}};return gd.Int(n)}
 if key=="transfer_retries" {return gd.Int(self.session.link.outgoing.stats.retries)}
 if key=="transfer_deferred" {return gd.Int(self.session.link.outgoing.stats.deferred)}
 if key=="incoming_tick" {return gd.Int(self.session.link.incoming.offer.archive.tick)}
 if key=="incoming_started" {return gd.Int(self.session.link.incoming.started)}
 if key=="incoming_chunks" {return gd.Int(self.session.link.incoming.count)}
 if key=="incoming_latest" {return gd.Int(self.session.link.incoming.latest.archive.tick)}
 if key=="candidate_tick" {return self.room.candidate.ready ? gd.Int(self.room.candidate.point.archive.tick) : -1}
 if key=="layout_archives" {return self.session.authority ? gd.Int(self.session.link.outgoing.stats.shuffled_archives) : gd.Int(self.session.link.incoming.stats.shuffled_archives)}
 if key=="layout_saved" {return gd.Int(self.session.link.outgoing.stats.shuffle_bytes_saved)}
 if key=="wire_bytes" {return gd.Int(len(self.session.link.outgoing.wire_bytes))}
 if key=="raw_bytes" {return gd.Int(len(self.session.link.outgoing.bytes))}
 if key=="prepared_tick" {return self.room.prepared.ready ? gd.Int(self.room.prepared.point.archive.tick) : -1}
 if key=="prepared_bytes" {return self.room.prepared.ready ? gd.Int(self.room.prepared.point.archive.bytes) : 0}
 if key=="known_tick" {return gd.Int(self.room.lease.view.last_known_tick)}
 if key=="rollback_limit" {return gd.Int(self.room.lease.view.policy.max_known_rollback)}
 if key=="too_old" {return gd.Int(self.room.last_result==.Too_Old)}
 if key=="claims" {return gd.Int(self.room.claim_rejections)}
'''+s[i:];p.write_text(s)
p=project/'scripts/browser_stress.odin';s=p.read_text().replace('import gd "godot:godot"','import gd "godot:godot"\nimport "core:fmt"')
s+='''
@(gd_method)
replay_scrapyard_browser_snapshot_state :: proc(self:^ReplayScrapyard)->string {
 if self.session==nil || !self.session.ready {return "{}"}
 c:=&self.session.client
 latest,eligible:=u64(0),u64(0)
 for id,i in c.snapshot_rx.ids {if id!=0 {
  tick:=c.snapshot_ticks[i]
  if id==c.snapshot_latest {latest=tick}
  if tick<=c.facts_contiguous && tick>c.timeline.confirmed {eligible=max(eligible,tick)}
 }}
 return fmt.tprintf(`%s"clock_ms":%d,"authority":%d,"epoch":%d,"generation":%d,"serial":%d,"observed":%d,"confirmed":%d,"predicted":%d,"journal":%d,"facts":%d,"latest_id":%d,"latest_tick":%d,"pending":%d,"eligible":%d%s`,
  "{",gd.time_get_ticks_msec(gd.singleton_time()),self.session.authority ? 1 : 0,c.cfg.epoch,c.generation,c.serial,c.authority_frame.tick,c.timeline.confirmed,c.timeline.head,c.journal.confirmed,c.facts_contiguous,c.snapshot_latest,latest,c.has_pending ? i64(c.pending.frame.tick) : -1,eligible,"}")
}
'''
p.write_text(s)
p=project/'scripts/browser_stress.odin';s=p.read_text().replace('import "core:fmt"','import "core:fmt"\nimport base64 "core:encoding/base64"')
s+='''
@(gd_method)
replay_scrapyard_browser_snapshot_capture :: proc(self:^ReplayScrapyard,which:gd.Int)->string {
 if self.session==nil || !self.session.ready || !self.session.authority {return ""}
 for peer,i in self.session.server.peers {if !peer.local && peer.seat==2 && peer.phase==.Running {
  tx:=&self.session.server.snapshot_tx[i]
  if tx.baseline_id==0 || len(tx.baseline)==0 || len(tx.baseline)>65535 {return ""}
  if which==2 {return fmt.tprintf(`%s"baseline_id":"%d","target_id":"%d","baseline_hash":"%d","bytes":%d,"schema":"%d"%s`,"{",tx.baseline_id,tx.next_id,tx.baseline_hash,len(tx.baseline),self.session.server.codecs.snapshot.fingerprint,"}")}
  if which!=0 && which!=1 {return ""}
  bytes:=which==0 ? tx.baseline : tx.scratch
  encoded:=base64.encode(bytes);defer delete(encoded)
  return fmt.tprintf("%s",string(encoded))
 }}
 return ""
}
'''
p.write_text(s)
background_bytes=int(os.environ.get('REPLAY_BACKGROUND_BYTES','0'))
if background_bytes:
 assert 1152<=background_bytes<=16384
 target=project/'scripts/scrapyard.odin';text=target.read_text();marker='options.network.content, options.network.hz,';assert text.count(marker)==1
 text=text.replace(marker,f'options.replication.transfer.bytes_per_update = {background_bytes}\n\t'+marker,1);target.write_text(text)
 (out/'background-plan.json').write_text(json.dumps({'bytes_per_update':background_bytes,'scope':'test-only transfer pacing; existing gameplay/recovery gates unchanged'})+'\n')
files=[p for p in out.rglob('*') if p.is_file() and p.suffix in ('.odin','.gd','.tscn','.tres','.png','.wav','.mp3') and not p.name.endswith('.gen.odin')]
(out/'source-sha256.txt').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+str(p.relative_to(out))+'\n' for p in sorted(files)))
print('REPLAY_LOADED_MIGRATION_PREPARED')

contract=json.loads((out/'browser-contract.json').read_text());contract.pop('credit_blackout_ms',None)
contract['migration']={'load_before_trigger_ms':5000,'maximum_known_rollback_ticks':120,'modes':['planned','crash'],'population_at_trigger':[32,44]}
(out/'browser-contract.json').write_text(json.dumps(contract,indent=2)+'\n')
