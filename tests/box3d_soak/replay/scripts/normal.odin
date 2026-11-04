// Test-only normal operations over the existing public runner/transport APIs.
package replay_gate_b_probe

import "core:mem"
import "core:fmt"
import gd "godot:godot"
import bg "godot:box3d/godot"
import meter "godot:box3d/godot/meter"
import bd "godot:box3d/diagnostics"
import b "godot:box3d"
import r "godot:replay"
import net "godot:replay/net"
import rec "godot:replay/recovery"
import tr "godot:replay/transport"
import sc "godot:replay/schema"
import ph "godot:replay/physics"
import dense "godot:tests/replay_physics_net/fixture"

Probe_Mode :: enum {Repair8, Client_Normal, Authority_Normal}
Dense_Actor :: Actor(dense.Game,dense.Control,dense.Action,dense.Event)
NORMAL_NOW_MS :: u64(160*1000/60)
Normal_Proof :: struct {
 mode:Probe_Mode,
 head_before,head_after,confirmed_before,confirmed_after:u64,
 committed_tick_before,committed_tick_after:u64,
 successful_public_step,external_require_step,empty_truth,one_tick,wire_complete:bool,
 tx_before,tx_after,rx_before,rx_after,replayed_before,replayed_after,corrections_before,corrections_after,catchups_before,catchups_after:u64,
 request_sequence,request_sent_ms,snapshot_id:u64,
 capture_start,parts:int,
 stage:int,error:net.Error,
}
normal_kind :: proc(mode:Probe_Mode)->string{return mode==.Client_Normal?"client_prediction_send":"authority_step_requested_canonical"}
normal_ok :: proc(p:Normal_Proof)->bool{return p.error==.None && p.successful_public_step && p.external_require_step && p.one_tick && p.wire_complete}
normal_actor :: proc()->^Dense_Actor{
 a:=actor_create(dense.Game,dense.Control,dense.Action,dense.Event);if a==nil{return nil}
 catalog,status:=dense_catalog();if status!=.Ok{actor_destroy(&a);return nil}
 if !actor_codec(a,catalog,dense_config(&catalog),dense_rules()){actor_destroy(&a);return nil}
 return a
}
normal_model :: proc(a:^Dense_Actor)->net.Model(dense.Game,dense.Control,dense.Action,dense.Event,2){model:=dense_model(&a.codec);model.step=dense_observed;return model}
ph_checkpoint :: proc(a:^Dense_Actor,world:b.World,game:dense.Game)->(r.Complete_Checkpoint(dense.Game,net.Net_Event(dense.Event)),r.Error){
 cp,error:=ph.checkpoint_make(r.Frame(dense.Game){state=game},net.Net_Event(dense.Event),world,dense_config(&a.catalog),allocator=a.allocator,ownership=a.allocator_owner)
 owned_world:=world;status:=b.world_destroy(&owned_world)
 if error==.None && status!=.Ok{r.complete_checkpoint_destroy(&cp);return {},.External_State}
 return cp,error
}
normal_history :: proc(t:^r.Timeline($S,$I,$E))->bool{
 if len(t.records)!=128 || t.head<127 || !t.external.require_step{return false}
 for tick in t.head-127..=t.head{if _,found:=r.read_values(t,tick);!found{return false}}
 return true
}
normal_sink_drain :: proc(a:^Dense_Actor,endpoint:int)->bool{
 scratch:[tr.MAX_PACKET_BYTES]u8;wire:=tr.memory_transport(&a.endpoints[endpoint])
 for _ in 0..<64{packet:=tr.receive(&wire,scratch[:]);if packet.state==.Empty{return true};if packet.state!=.Received{return false}}
 return tr.receive(&wire,scratch[:]).state==.Empty
}
// Retain only explicit codec/catalog/byte-oracle contexts. No H128, execution,
// Link arrays or Memory queues survive before the next candidate is created.
normal_retire_runtime :: proc(a:^Dense_Actor)->bool{
 if net.client_destroy(&a.client)!=.None || net.server_destroy(&a.source)!=.None || rec.link_destroy(&a.link)!=.None{return false}
 if len(a.memory.packets)!=0{tr.memory_destroy(&a.memory)}
 return len(a.client.timeline.records)==0 && len(a.source.timeline.records)==0 && !a.link.ready && len(a.memory.packets)==0
}
normal_capture_oracle :: proc(a:^Dense_Actor,authority:bool)->bool{
 checkpoint:r.Complete_Checkpoint(dense.Game,net.Net_Event(dense.Event));error:r.Error
 if authority{checkpoint,error=r.capture_complete(&a.source.timeline,160,a.allocator)}else{checkpoint,error=r.capture_complete(&a.client.timeline,160,a.allocator)}
 if error!=.None{return false};defer r.complete_checkpoint_destroy(&checkpoint)
 view_error:net.Error
 if authority{a.golden,view_error=net.complete_view(a.codec.value,&checkpoint,&a.source.physics.schemas.state,&a.source.physics.schemas.occurrence,a.allocator)}else{a.golden,view_error=net.complete_view(a.codec.value,&checkpoint,&a.client.physics.schemas.state,&a.client.physics.schemas.occurrence,a.allocator)}
 return view_error==.None
}
verify_prediction_bytes :: proc(a:^Dense_Actor,store:^Prediction_Byte_Store,authority:bool=false)->(bd.Signature,bd.Signature,bool){
 checkpoint:r.Complete_Checkpoint(dense.Game,net.Net_Event(dense.Event));error:r.Error
 if authority{checkpoint,error=r.capture_complete(&a.source.timeline,160,a.allocator)}else{checkpoint,error=r.capture_complete(&a.client.timeline,160,a.allocator)}
 if error!=.None{return {},{},false};defer r.complete_checkpoint_destroy(&checkpoint)
 actual:net.Complete_View;view_error:net.Error
 if authority{actual,view_error=net.complete_view(a.codec.value,&checkpoint,&a.source.physics.schemas.state,&a.source.physics.schemas.occurrence,a.allocator)}else{actual,view_error=net.complete_view(a.codec.value,&checkpoint,&a.client.physics.schemas.state,&a.client.physics.schemas.occurrence,a.allocator)}
 if view_error!=.None{return {},{},false};defer net.complete_view_destroy(&actual)
 return byte_store_compare(store,actual.frame)
}

normal_client :: proc(a:^Dense_Actor)->Normal_Proof{
 c:=&a.client;p:=Normal_Proof{mode=.Client_Normal,error=.Invalid_Frame,stage=1}
 p.head_before=c.timeline.head;p.confirmed_before=c.timeline.confirmed;p.external_require_step=c.timeline.external.require_step
 before,found:=r.read_values(&c.timeline,c.timeline.head);if !found{return p};p.committed_tick_before=before.tick
 if c.phase!=.Running || p.head_before!=159 || p.confirmed_before!=152 || c.has_pending || c.physics.waiting_tick!=0{return p}
 p.rx_before=c.stats.rx_packets;p.replayed_before=c.stats.replayed_ticks;p.corrections_before=c.stats.corrections;p.catchups_before=c.stats.snapshot_catchups
 p.stage=2;if !rec.link_pump(&a.link,NORMAL_NOW_MS){p.error=.Invalid_Time;return p}
 // Public pump alone owns Client.now/lead/presentation observations. No setter.
 p.error=net.client_pump(c,NORMAL_NOW_MS);if p.error!=.None{return p}
 p.empty_truth=c.stats.rx_packets==p.rx_before && c.stats.replayed_ticks==p.replayed_before && c.stats.corrections==p.corrections_before && c.stats.snapshot_catchups==p.catchups_before && !c.has_pending
 if !p.empty_truth{p.error=.Invalid_Frame;return p}
 p.stage=3;p.tx_before=c.stats.tx_packets;deferred:=a.link.router.stats.deferred
 p.error=net.client_step(c,dense.Control{});p.successful_public_step=p.error==.None;if !p.successful_public_step{return p}
 actor_drain(a)
 p.head_after=c.timeline.head;p.confirmed_after=c.timeline.confirmed;p.tx_after=c.stats.tx_packets;p.rx_after=c.stats.rx_packets
 p.replayed_after=c.stats.replayed_ticks;p.corrections_after=c.stats.corrections;p.catchups_after=c.stats.snapshot_catchups
 after,ok:=r.read_values(&c.timeline,c.timeline.head);if !ok{p.error=.Invalid_Frame;return p};p.committed_tick_after=after.tick
 p.one_tick=p.head_after==160 && p.confirmed_after==152 && p.committed_tick_after==p.committed_tick_before+1 && p.replayed_after==p.replayed_before && p.corrections_after==p.corrections_before && p.catchups_after==p.catchups_before
 sent:=c.input_sent[160%u64(len(c.input_sent))]
 p.wire_complete=p.tx_after>p.tx_before && a.link.router.stats.deferred==deferred && sent.valid && sent.tick==160 && sent.at_ms==NORMAL_NOW_MS
 p.stage=4;if !p.one_tick || !p.wire_complete{p.error=.Invalid_Frame};return p
}
normal_input_oracle :: proc(a:^Dense_Actor)->bool{
 if !tr.memory_advance(&a.memory,160){return false}
 scratch:[tr.MAX_PACKET_BYTES]u8;wire:=tr.memory_transport(&a.endpoints[0]);found:=false
 for _ in 0..<64{
  packet:=tr.receive(&wire,scratch[:]);if packet.state==.Empty{return found};if packet.state!=.Received{return false}
  meta,fingerprint,report:=sc.inspect(scratch[:packet.count]);if report.error!=.None{return false}
  // Existing public envelope; both fixed and compact Input kinds use the
  // actual input Schema fingerprint. No private packet struct is recreated.
  if meta.tick==160 && (meta.kind==4 || meta.kind==15) && fingerprint==a.client.codecs.inputs.fingerprint{found=true}
 }
 return false
}

normal_authority_prefix :: proc(a:^Dense_Actor)->bool{
 world,game,status:=dense.world(32);if status!=.Ok{return false}
 initial,error:=ph_checkpoint(a,world,game);if error!=.None{return false};defer r.complete_checkpoint_destroy(&initial)
 if !actor_memory(a) || !actor_link(a,0) || !actor_server(a,&initial,normal_model(a),rec.link_game_transport(&a.link),true){return false}
 wire_owner,wire_error:=actor_alias(a,&a.endpoints[1],size_of(a.endpoints[1]));if wire_error!=.None{return false}
 if !actor_client(a,normal_model(a),tr.memory_transport(&a.endpoints[1]),wire_owner){return false}
 if net.client_pump(&a.client,0)!=.None || net.client_destroy(&a.client)!=.None{return false}
 if !tr.memory_advance(&a.memory,0) || !rec.link_pump(&a.link,0) || net.server_pump(&a.source,0)!=.None{return false}
 for tick in u64(1)..=159{
  now:=tick*1000/60
  if !tr.memory_advance(&a.memory,tick) || !rec.link_pump(&a.link,now) || net.server_pump(&a.source,now)!=.None{return false}
  if !dense_stimulus(&a.source,tick) || net.server_step(&a.source)!=.None{return false}
  if !tr.memory_advance(&a.memory,tick) || !normal_sink_drain(a,1){return false}
 }
 return a.source.timeline.head==159 && a.source.timeline.confirmed==159 && normal_history(&a.source.timeline)
}
normal_authority :: proc(a:^Dense_Actor)->Normal_Proof{
 s:=&a.source;p:=Normal_Proof{mode=.Authority_Normal,error=.Invalid_Frame,stage=10}
 p.head_before=s.timeline.head;p.confirmed_before=s.timeline.confirmed;p.external_require_step=s.timeline.external.require_step
 before,found:=r.read_values(&s.timeline,s.timeline.head);if !found{return p};p.committed_tick_before=before.tick
 if p.head_before!=159 || p.confirmed_before!=159{return p}
 if !tr.memory_advance(&a.memory,160) || !rec.link_pump(&a.link,NORMAL_NOW_MS){p.error=.Invalid_Time;return p}
 p.error=net.server_pump(s,NORMAL_NOW_MS);if p.error!=.None{return p}
 if !dense_stimulus(s,160){p.error=.Invalid_Input;return p}
 p.stage=11;p.error=net.server_step(s);p.successful_public_step=p.error==.None;if !p.successful_public_step{return p}
 p.head_after=s.timeline.head;p.confirmed_after=s.timeline.confirmed
 after,ok:=r.read_values(&s.timeline,s.timeline.head);if !ok{p.error=.Invalid_Frame;return p};p.committed_tick_after=after.tick
 p.one_tick=p.head_after==160 && p.confirmed_after==160 && p.committed_tick_after==p.committed_tick_before+1
 // Existing protocol request: generation,serial,sequence,sent_ms (four u64 LE).
 // It is validated by the public wire/Server path, never a private API call.
 peer:=s.peers[1];if peer.request_seen==max(u64) || s.codecs.request.wire_size!=32{p.error=.Invalid_Frame;return p}
 request:[sc.HEADER_BYTES+32]u8;body:=request[sc.HEADER_BYTES:]
 p.request_sequence=peer.request_seen+1;p.request_sent_ms=s.now
 values:=[4]u64{peer.generation,peer.serial,p.request_sequence,p.request_sent_ms}
 for value,index in values{for i in 0..<8{body[index*8+i]=u8(value>>uint(i*8))}}
 if sc.pack_bytes(s.codecs.request.fingerprint,{kind=31,epoch=s.cfg.epoch,tick=160,content=s.cfg.content},body,request[:]).error!=.None{p.error=.Invalid_Frame;return p}
 p.stage=12;p.capture_start=a.capture.count;p.tx_before=s.stats.tx_packets
 remote:=tr.memory_transport(&a.endpoints[1]);if tr.send(&remote,1,.Reliable,request[:])!=.Sent{p.error=.Capacity;return p}
 if !tr.memory_advance(&a.memory,160) || !rec.link_pump(&a.link,NORMAL_NOW_MS){p.error=.Invalid_Time;return p}
 p.error=net.server_pump(s,NORMAL_NOW_MS);if p.error!=.None{return p}
 tx:=&s.physics.tx[1];p.snapshot_id=tx.id;p.parts=tx.part;p.tx_after=s.stats.tx_packets
 p.wire_complete=s.peers[1].request_seen==p.request_sequence && tx.tick==160 && tx.purpose==.Snapshot && tx.waiting_ack && tx.part>0 && p.tx_after>p.tx_before
 p.stage=13;if !p.one_tick || !p.wire_complete{p.error=.Invalid_Frame};return p
}
normal_chunks_oracle :: proc(a:^Dense_Actor,p:Normal_Proof)->bool{
 tx:=&a.source.physics.tx[1];at,count:=0,0
 for saved in a.capture.packets[p.capture_start:a.capture.count]{
  if saved.kind!=28 || saved.tick!=160{continue}
  meta,fingerprint,report:=sc.inspect(saved.data.bytes)
  if report.error!=.None || fingerprint!=a.source.physics.schemas.chunk.fingerprint || meta.epoch!=a.source.cfg.epoch{return false}
  start:=sc.HEADER_BYTES+a.source.physics.schemas.chunk.wire_size
  if len(saved.data.bytes)<=start{return false};payload:=saved.data.bytes[start:]
  if at+len(payload)>len(tx.data.bytes) || mem.compare(payload,tx.data.bytes[at:at+len(payload)])!=0{return false}
  at+=len(payload);count+=1
 }
 if count!=p.parts || at!=len(tx.data.bytes) || count==0{return false}
 // EXTRA emission/roundtrip oracle, called only outside the operation timer.
 inspection,inspect_error:=net.complete_inspect(tx.data.bytes,a.codec.value.identity,a.source.cfg.epoch);if inspect_error!=.None{return false}
 frame,found:=r.read_values(&a.source.timeline,160);if !found{return false}
 checkpoint,decode_error:=net.complete_decode_image(a.codec.value,inspection,frame,&a.source.physics.schemas.state,&a.source.physics.schemas.occurrence,a.allocator)
 if decode_error!=.None{return false};return r.complete_checkpoint_destroy(&checkpoint)==.None
}

normal_prepare :: proc(self:^ReplayGateBProbe)->int{
 self.source_dense=normal_actor();if self.source_dense==nil{return 101}
 if self.mode==.Client_Normal{
  source:=self.source_dense;world,game,status:=dense.world(32);if status!=.Ok{return 102}
  if !actor_source_prepare(source,world,game,dense_config(&source.catalog),normal_model(source),dense_stimulus){return 103}
  self.oracle_dense=normal_actor();if self.oracle_dense==nil{return 104}
  reference:=self.oracle_dense
  if !actor_receiver_prepare(reference,source,normal_model(reference),159) || !normal_history(&reference.client.timeline){return 105}
  if !tr.memory_advance(&reference.memory,160) || !normal_sink_drain(reference,0){return 106}
  proof:=normal_client(reference);if !normal_ok(proof){self.normal=proof;return 107}
  if !normal_input_oracle(reference) || !normal_capture_oracle(reference,false){return 108}
  store_error:r.Error
  self.prediction_bytes,store_error=byte_store_create(reference.golden.frame);if store_error!=.None{return 112}
  before,bs:=meter.category_stats(bg.CATEGORY_REPLAY_PROVIDER);if bs!=bg.OK{return 113};self.reference_contexts_before=before.contexts
  if !actor_destroy(&self.oracle_dense){return 114}
  after,after_status:=meter.category_stats(bg.CATEGORY_REPLAY_PROVIDER);if after_status!=bg.OK{return 115};self.reference_contexts_after=after.contexts
  self.reference_fully_destroyed=self.oracle_dense==nil && before.contexts==after.contexts+1
  if !self.reference_fully_destroyed{return 116}
  self.client_dense=normal_actor();if self.client_dense==nil{return 109}
  candidate:=self.client_dense
  if !actor_receiver_prepare(candidate,source,normal_model(candidate),159) || !normal_history(&candidate.client.timeline){return 110}
  if !tr.memory_advance(&candidate.memory,160) || !normal_sink_drain(candidate,0){return 111}
 }else{
  reference:=self.source_dense
  if !normal_authority_prefix(reference){return 121}
  proof:=normal_authority(reference);if !normal_ok(proof){self.normal=proof;return 122}
  if !normal_chunks_oracle(reference,proof) || !normal_capture_oracle(reference,true){return 123}
  store_error:r.Error
  self.prediction_bytes,store_error=byte_store_create(reference.golden.frame);if store_error!=.None{return 126}
  before,bs:=meter.category_stats(bg.CATEGORY_REPLAY_PROVIDER);if bs!=bg.OK{return 127};self.reference_contexts_before=before.contexts
  if !actor_destroy(&self.source_dense){return 128}
  after,after_status:=meter.category_stats(bg.CATEGORY_REPLAY_PROVIDER);if after_status!=bg.OK{return 129};self.reference_contexts_after=after.contexts
  self.reference_fully_destroyed=self.source_dense==nil && before.contexts==after.contexts+1
  if !self.reference_fully_destroyed{return 130}
  self.client_dense=normal_actor();if self.client_dense==nil{return 124}
  if !normal_authority_prefix(self.client_dense){return 125}
 }
 return 0
}

normal_result :: proc(self:^ReplayGateBProbe)->gd.String{
 p:=self.normal
 return gd.new_string(fmt.tprintf("{{\"correctness_ok\":%v,\"normal_kind\":\"%s\",\"step_observation\":\"committed_tick_require_step\",\"operation\":{{\"head_before\":%d,\"head_after\":%d,\"confirmed_before\":%d,\"confirmed_after\":%d,\"actual_steps_before\":null,\"actual_steps_after\":null,\"successful_public_step\":%v,\"external_require_step\":%v,\"committed_tick_before\":%d,\"committed_tick_after\":%d,\"one_tick\":%v,\"wire_complete\":%v,\"stage\":%d,\"error\":%d}},\"expected_complete_sha256\":\"%s\",\"actual_complete_sha256\":\"%s\",\"oracle_scope\":\"independent_public_runner_full5_extra_after_return\",\"counts\":{{\"bodies\":%d,\"shapes\":%d,\"contacts\":%d,\"joints\":%d}},\"run_peak\":{{\"bodies\":%d,\"shapes\":%d,\"contacts\":%d,\"joints\":%d}},\"normal_details\":{{\"tx_before\":%d,\"tx_after\":%d,\"rx_before\":%d,\"rx_after\":%d,\"replayed_before\":%d,\"replayed_after\":%d,\"corrections_before\":%d,\"corrections_after\":%d,\"catchups_before\":%d,\"catchups_after\":%d,\"request_sequence\":%d,\"request_sent_ms\":%d,\"snapshot_id\":%d,\"parts\":%d}},\"cleanup\":{{\"native_live_bytes\":%d,\"snapshot_live_bytes\":%d,\"host_application_live_bytes\":%d,\"all_explicit_drops_ok\":%v,\"ownership_evidence\":\"checked explicit drops and Meter0; shutdown checked by controller\"}}}}",self.correct&&normal_ok(p),normal_kind(self.mode),p.head_before,p.head_after,p.confirmed_before,p.confirmed_after,p.successful_public_step,p.external_require_step,p.committed_tick_before,p.committed_tick_after,p.one_tick,p.wire_complete,p.stage,p.error,hex(self.expected.complete[:]),hex(self.actual.complete[:]),observed_counts.body_count,observed_counts.shape_count,observed_counts.contact_count,observed_counts.joint_count,observed_peak.body_count,observed_peak.shape_count,observed_peak.contact_count,observed_peak.joint_count,p.tx_before,p.tx_after,p.rx_before,p.rx_after,p.replayed_before,p.replayed_after,p.corrections_before,p.corrections_after,p.catchups_before,p.catchups_after,p.request_sequence,p.request_sent_ms,p.snapshot_id,p.parts,self.cleanup_native,self.cleanup_snapshot,self.cleanup_host,self.cleanup_ok))
}
normal_records :: proc(self:^ReplayGateBProbe,seq,start_us,end_us:gd.Int)->gd.String{
 contract,status:=b.domain_contract_get();ledger,ledger_status:=b.host_ledger_get(contract.cookie)
 quota:=status==.Ok && ledger_status==.Ok && ledger.live_bytes+ledger.host_reserved_bytes==ledger.admitted_bytes && ledger.admitted_bytes<=ledger.limit_bytes
 p:=self.normal;outcome:=self.correct&&normal_ok(p)?"committed":"error"
 return gd.new_string(fmt.tprintf("{{\"event\":\"GATE_B_SAMPLE\",\"schema\":1,\"run_id\":\"%s\",\"seq\":%d,\"operation\":\"normal\",\"normal_kind\":\"%s\",\"step_observation\":\"committed_tick_require_step\",\"epoch\":1,\"base_tick\":%d,\"head_before\":%d,\"head_after\":%d,\"confirmed_before\":%d,\"confirmed_after\":%d,\"requested_depth\":0,\"actual_steps_before\":null,\"actual_steps_after\":null,\"outcome\":\"%s\",\"outer_start_us\":%d,\"outer_end_us\":%d,\"whole_ns\":%d,\"included_work\":[\"public_dispatch\",\"normal_step_capture_admission\",\"required_serialization\",\"publication_events\",\"operation_cleanup\",\"core_return\"],\"proof\":{{\"full_state_equal\":%v,\"publication_atomic\":%v,\"quota_ok\":%v,\"expected_complete_sha256\":\"%s\",\"actual_complete_sha256\":\"%s\",\"successful_public_step\":%v,\"external_require_step\":%v,\"committed_tick_before\":%d,\"committed_tick_after\":%d}},\"counts\":{{\"bodies\":%d,\"shapes\":%d,\"contacts\":%d,\"joints\":%d}},\"counts_scope\":\"actual_candidate_fixed_step\",\"ledger\":{{\"live_bytes\":%d,\"reserved_bytes\":%d,\"admitted_bytes\":%d,\"limit_bytes\":%d,\"committed_peak_bytes\":%d,\"storage_bytes\":%d}},\"phases\":[]}}",gd.env_string("GATE_B_RUN_ID","unset"),seq,normal_kind(self.mode),p.head_before,p.head_before,p.head_after,p.confirmed_before,p.confirmed_after,outcome,start_us,end_us,(end_us-start_us)*1000,self.correct,p.one_tick&&p.successful_public_step,quota,hex(self.expected.complete[:]),hex(self.actual.complete[:]),p.successful_public_step,p.external_require_step,p.committed_tick_before,p.committed_tick_after,observed_counts.body_count,observed_counts.shape_count,observed_counts.contact_count,observed_counts.joint_count,ledger.live_bytes,ledger.host_reserved_bytes,ledger.admitted_bytes,ledger.limit_bytes,ledger.committed_peak_bytes,ledger.ledger_storage_bytes))
}
