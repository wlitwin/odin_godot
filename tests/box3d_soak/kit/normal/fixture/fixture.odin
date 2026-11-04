// TEST ONLY — distinct Client A and authority B public normal entries. No timer/production change.
package kit_normal_fixture

import "core:mem"
import b "godot:box3d"
import bd "godot:box3d/diagnostics"
import bg "godot:box3d/godot"
import bm "godot:box3d/godot/meter"
import p "godot:kit/physics"
import k "godot:kit/sim"
import s "godot:kit/session"
import n "godot:kit/net"
import f "godot:tests/box3d_soak/kit/fixture"

ORACLE_BYTES :: k.WORLD_NETWORK_BYTES
COUNTER_KIND :: "model_step_callback" // OBSERVED authored callback, NOT Native count
WIRE_INPUT_DECODER_AVAILABLE :: false // no private World-input wire parser here
Sink_Role :: enum {Client,Authority}
Send_Sink :: struct {
 allocator:mem.Allocator,
 role:Sink_Role,peer:s.Peer_Id,
 ok,expected_tag_stream_ok:bool,
 calls,copies,freed,bytes,input_packets,accepted_packets,world_chunks,signature_packets:u64,
 channels:[3]u64,fingerprint:u64,
 signature:bd.Signature,
}
// Heap data contains only owned plain parts/value metadata and the transport
// sink. No snapshot, codec, model, SDK handles or native lease lives here.
Oracle_Data :: struct {
 allocator:mem.Allocator,sink:Send_Sink,
 parts:[bd.Part][]u8,bytes:u64,
 identity:bd.Identity,signature:bd.Signature,wire_signature:bd.Signature,
 epoch,tick,asset_id,field_schema:u64,
}
// Cleanup capabilities live BY VALUE outside the allocation they eventually
// free. A declined drop/context close leaves its ACTUAL mutated handle here.
Oracle_Handle :: struct {
 sdk:p.SDK_Context,self_owner,sink_owner:p.SDK_User_Owner,data:^Oracle_Data,
}
Client_A :: struct {
 oracle_handle,proof_handle:Oracle_Handle,
 reference,candidate:^f.State,
 cp_cleanup:k.World_Checkpoint, // retry CP, never part of the plain Oracle_Data
 reference_cleanup,candidate_cleanup:f.Cleanup,
 fixture_cleanup_failed,reference_context_destroyed:bool,
 before_steps,after_steps,head_before,head_after,confirmed_before,confirmed_after:u64,
 returned_ticks:int,full5_equal:bool,actual:bd.Signature,
 explicit_corrections:u64,authority_peer:s.Peer_Id,
 signatures_before,signatures_after,full_before,full_after:u64,
 error,cleanup_error:k.World_Error,
}
first_error :: proc(state:^Client_A,e:k.World_Error,cleanup:bool=false) {
 if e==.Ok {return};if state.error==.Ok {state.error=e}
 if cleanup && state.cleanup_error==.Ok {state.cleanup_error=e}
}

// Actual public Session.send: bounded complete framed copy through the retained
// Meter, observed tag/target/.Stream, then free INSIDE callback. No noop send.
owned_send :: proc(user:rawptr,to:s.Peer_Id,bytes:[]u8,channel:s.Channel) {
 sink:=cast(^Send_Sink)user;sink.calls+=1
 if len(bytes)>k.WORLD_NETWORK_BYTES || int(channel)>=len(sink.channels) {sink.ok=false;return}
 out,e:=make([]u8,len(bytes),sink.allocator);if e!=nil {sink.ok=false;return}
 copy(out,bytes);sink.copies+=1;sink.bytes+=u64(len(out));sink.channels[int(channel)]+=1
 defer {delete(out,sink.allocator);sink.freed+=1}
 for byte in out {sink.fingerprint=(sink.fingerprint~u64(byte))*1099511628211}
 framed:=len(out)>2 && out[0]==s.SES_APP
 client_input:=framed && to==s.HOST_PEER && channel==.Stream && out[2]==k.SIM_WORLD_INPUT
 authority_accepted:=framed && (to==sink.peer || to==s.BROADCAST_PEER) && channel==.Reliable && out[2]==k.SIM_WORLD_ACCEPTED
 authority_chunks:=framed && (to==sink.peer || to==s.BROADCAST_PEER) && channel==.Reliable && out[2]==k.SIM_WORLD_CHUNK
 authority_signature:=framed && (to==sink.peer || to==s.BROADCAST_PEER) && channel==.Reliable && out[2]==k.SIM_WORLD_SIGNATURE
 if authority_signature {
  r:=n.reader_make(out[3:]);rev:=n.read_u32(&r);signature,se:=bd.signature_decode(n.reader_remaining(&r))
  if r.err || rev!=k.WORLD_NETWORK_REV || se!=.None || signature.tick!=162 {sink.ok=false}else{sink.signature=signature;sink.signature_packets+=1}
 }
 expected:=sink.role==.Client?client_input:(authority_accepted||authority_signature)
 sink.expected_tag_stream_ok=sink.expected_tag_stream_ok&&expected
 if client_input {sink.input_packets+=1}
 if authority_accepted {sink.accepted_packets+=1}
 if authority_chunks {sink.world_chunks+=1}
 if !expected {sink.ok=false}
}
store_create :: proc()->(handle:Oracle_Handle,error:k.World_Error) {
 sdk,e:=p.sdk_context_create();handle.sdk=sdk;if e!=.Ok {return handle,e}
 alloc:=bm.allocator(sdk.memory);data,ae:=new(Oracle_Data,alloc);handle.data=data
 if ae!=nil || data==nil {return handle,.Allocation_Failed}
 data.allocator=alloc;data.sink={allocator=alloc,ok=true,expected_tag_stream_ok=true,fingerprint=14695981039346656037}
 self,se:=p.sdk_user_owner_create(sdk.memory,data,u64(size_of(data^)),data,u64(size_of(data^)))
 handle.self_owner=self;if se!=.Ok {return handle,se}
 sink_owner,te:=p.sdk_user_owner_create(sdk.memory,data,u64(size_of(data^)),&data.sink,u64(size_of(data.sink)))
 handle.sink_owner=sink_owner;return handle,te // partial ownership returned intact
}
store_destroy :: proc(handle:^Oracle_Handle)->k.World_Error {
 if handle==nil {return .Ok}
 if handle.data!=nil {
  data:=handle.data
  for part in bd.Part {delete(data.parts[part],data.allocator);data.parts[part]=nil};data.bytes=0
  if e:=p.sdk_user_owner_destroy(&handle.sink_owner);e!=.Ok {return e}
  if e:=p.sdk_user_owner_destroy(&handle.self_owner);e!=.Ok {return e}
  alloc:=data.allocator;free(data,alloc);handle.data=nil
 }
 // Can retry even AFTER heap data is gone: SDK capabilities are in the handle.
 return p.sdk_context_destroy(&handle.sdk)
}
part_alloc :: proc(data:^Oracle_Data,part:bd.Part,count:int)->([]u8,k.World_Error) {
 if count<0 || u64(count)>ORACLE_BYTES-data.bytes {return nil,.Capacity}
 bytes,e:=make([]u8,count,data.allocator);if e!=nil {return nil,.Allocation_Failed}
 data.parts[part]=bytes;data.bytes+=u64(count);return bytes,.Ok
}

// Copy only public checkpoint fields/type-aware getters and existing typed
// value codecs while source is alive. Game=registered checkpoint fields is an
// explicit LOCAL PREDICTION contract, NOT canonical accepted-history Game wire.
copy_five :: proc(state:^Client_A,handle:^Oracle_Handle,ep:^f.Endpoint($G,$C,$A))->k.World_Error {
 if state.cp_cleanup.image!=nil || !k.world_owner_is_empty(state.cp_cleanup.owner) {return .Busy}
 epoch:=k.lane_world_epoch(&ep.lane);if epoch!=1 {return .Incompatible}
 cp,e:=k.lane_world_checkpoint(&ep.lane,ep.lane.ticker.tick);state.cp_cleanup=cp
 if e==.Ok {e=copy_five_body(handle.data,ep,&state.cp_cleanup,epoch)}
 first_error(state,e)
 drop:=k.world_checkpoint_destroy(&state.cp_cleanup)
 first_error(state,drop,true)
 return e==.Ok?drop:e
}
copy_five_body :: proc(data:^Oracle_Data,ep:^f.Endpoint($G,$C,$A),cp:^k.World_Checkpoint,epoch:u64)->k.World_Error {
 if data==nil {return .Missing_Attachment}
 data.epoch=epoch;data.tick=cp.tick;data.asset_id=cp.asset_id;data.field_schema=cp.field_schema
 required,de:=p.checkpoint_dump(cp,nil,G);if de!=.Ok {return de}
 bytes,ae:=part_alloc(data,.Solver,int(required));if ae!=.Ok {return ae}
 actual,fe:=p.checkpoint_dump(cp,bytes,G);if fe!=.Ok || actual!=required {return fe==.Ok?.Invalid:fe}
 bytes,ae=part_alloc(data,.Game,len(cp.fields));if ae!=.Ok {return ae};copy(bytes,cp.fields)
 side,se:=p.checkpoint_side(cp,G);if se!=.Ok {return se}
 codec:=ep.network.side.value
 bytes,ae=part_alloc(data,.Side,codec.wire_bytes);if ae!=.Ok {return ae}
 if e:=codec.encode(codec.user,(cast([^]u8)&side)[:size_of(side)],bytes);e!=.Ok {return e}
 observations,oe:=p.checkpoint_observations(cp,G);if oe!=.Ok {return oe}
 codec=ep.network.observations.value
 bytes,ae=part_alloc(data,.Observations,codec.wire_bytes);if ae!=.Ok {return ae}
 if e:=codec.encode(codec.user,(cast([^]u8)&observations)[:size_of(observations)],bytes);e!=.Ok {return e}
 if !cp.effects_known {return .Missing_Attachment}
 writer:=n.writer_make(64,data.allocator);defer n.writer_destroy(&writer)
 n.write_u8(&writer,u8(cp.effect_count))
 for &event in cp.effects[:cp.effect_count] {
  if event.kind!=1 || event.count!=ep.event.value.local_bytes {return .Incompatible}
  wire:[k.WORLD_EFFECT_BYTES]u8;codec=ep.event.value
  if e:=codec.encode(codec.user,event.args[:event.count],wire[:codec.wire_bytes]);e!=.Ok {return e}
  n.write_u16(&writer,event.kind);n.write_u64(&writer,event.key)
  for byte in wire[:codec.wire_bytes] {n.write_u8(&writer,byte)}
 }
 bytes,ae=part_alloc(data,.Occurrences,len(n.writer_bytes(&writer)));if ae!=.Ok {return ae};copy(bytes,n.writer_bytes(&writer))
 data.identity=ep.network.identity
 original:=data.identity.game_schema;contract:=bd.hash_bytes(transmute([]u8)#load("fixture.odin"))
 schema,he:=bd.hash_descriptors("kit-normal-public-checkpoint-five-v1",[]bd.Descriptor{{"model",original[:]},{"oracle-contract",contract[:]}})
 if he!=.None {return .Incompatible};data.identity.game_schema=schema
 signature,be:=bd.sign({data.identity,epoch,data.tick,data.parts})
 if be!=.None {return .Invalid};data.signature=signature;return .Ok
}

warm_152 :: proc(root:^f.State)->bool {
 // Full bootstrap152 is preparation only, never the measured normal entry.
 return root.bootstrap_tick==152 && f.receiver_start(root)
}

warm_159 :: proc(ep:^f.Endpoint($G,$C,$A))->bool {
 for _ in 0..<7 {if k.lane_frame(&ep.lane,1.0/60)!=1 {return false}}
 return ep.lane.ticker.tick==159 && k.lane_world_confirmed(&ep.lane)==152
}
bind_sink :: proc(handle:^Oracle_Handle,ep:^f.Endpoint($G,$C,$A)) {
 data:=handle.data;data.sink={allocator=data.allocator,ok=true,expected_tag_stream_ok=true,fingerprint=14695981039346656037}
 s.session_set_transport(&ep.ses,&data.sink,owned_send)
}
reference_tick :: proc(state:^Client_A,ep:^f.Endpoint($G,$C,$A))->bool {
 if !warm_159(ep) {first_error(state,.Step_Failed);return false}
 bind_sink(&state.oracle_handle,ep);before:=ep.steps
 if k.lane_frame(&ep.lane,1.0/60)!=1 || ep.steps!=before+1 || ep.lane.ticker.tick!=160 || k.lane_world_confirmed(&ep.lane)!=152 {first_error(state,.Step_Failed);return false}
 e:=copy_five(state,&state.oracle_handle,ep);return e==.Ok
}
close_fixture :: proc(state:^Client_A,reference:bool)->bool {
 // Existing f.destroy exposes checked success but cannot promise retry after
 // an internal declined release. Keep its failure as an explicit tombstone,
 // never erase Client_A or claim that remaining resources were released.
 if reference {
  if state.reference==nil {return !state.fixture_cleanup_failed}
  state.reference_cleanup=f.destroy(&state.reference)
  c:=state.reference_cleanup
  if !c.ok || !c.stats_ok || c.native_live!=0 || c.snapshot_live!=0 {state.fixture_cleanup_failed=true;first_error(state,.Rejected,true);return false}
 }else{
  if state.candidate==nil {return !state.fixture_cleanup_failed}
  state.candidate_cleanup=f.destroy(&state.candidate)
  c:=state.candidate_cleanup
  if !c.ok || !c.stats_ok || c.native_live!=0 || c.snapshot_live!=0 {state.fixture_cleanup_failed=true;first_error(state,.Rejected,true);return false}
 }
 return true
}
client_a_create :: proc(profile:f.Profile)->(state:Client_A,error:k.World_Error) {
 handle,se:=store_create();state.oracle_handle=handle
 if se!=.Ok {first_error(&state,se);first_error(&state,store_destroy(&state.oracle_handle),true);return state,state.error}
 reference,re:=f.create(profile,bootstrap_tick=152);state.reference=reference
 if re!=.Ok {first_error(&state,re);_=close_fixture(&state,true);return state,state.error}
 if !warm_152(reference) {first_error(&state,reference.last_error==.Ok?.Step_Failed:reference.last_error);_=close_fixture(&state,true);return state,state.error}
 good:=false
 if profile==.Dense {good=reference_tick(&state,reference.receiver_dense)}else{good=reference_tick(&state,reference.receiver_common)}
 if state.cp_cleanup.image!=nil || !k.world_owner_is_empty(state.cp_cleanup.owner) {return state,state.error}
 closed:=close_fixture(&state,true)
 stats,cs:=bm.category_stats(bg.CATEGORY_KIT_CORE)
 state.reference_context_destroyed=closed && state.reference==nil && cs==bg.OK && stats.contexts==1
 if !good || !state.reference_context_destroyed {first_error(&state,.Busy);return state,state.error}
 candidate,ce:=f.create(profile,bootstrap_tick=152);state.candidate=candidate
 if ce!=.Ok {first_error(&state,ce);_=close_fixture(&state,false);return state,state.error}
 if !warm_152(candidate) {first_error(&state,candidate.last_error==.Ok?.Step_Failed:candidate.last_error);_=close_fixture(&state,false);return state,state.error}
 if profile==.Dense {good=warm_159(candidate.receiver_dense);if good {bind_sink(&state.oracle_handle,candidate.receiver_dense);before(&state,candidate.receiver_dense)}
 }else{good=warm_159(candidate.receiver_common);if good {bind_sink(&state.oracle_handle,candidate.receiver_common);before(&state,candidate.receiver_common)}}
 if !good {first_error(&state,.Step_Failed);_=close_fixture(&state,false)}
 return state,state.error
}
before :: proc(state:^Client_A,ep:^f.Endpoint($G,$C,$A)) {
 state.before_steps=ep.steps;state.head_before=ep.lane.ticker.tick;state.confirmed_before=k.lane_world_confirmed(&ep.lane)
}

// ONE public normal entry; ep.steps is authored model-step CALLBACK evidence.
// Provider's existing one-fixed-step contract remains enabled. No Native step
// count is fabricated; no timer, restore, oracle read or synthetic send here.
client_a_operation :: proc(state:^Client_A)->bool {
 if state==nil || state.candidate==nil || !state.reference_context_destroyed {return false}
 if state.candidate.profile==.Dense {return operation_typed(state,state.candidate.receiver_dense)}
 return operation_typed(state,state.candidate.receiver_common)
}
operation_typed :: proc(state:^Client_A,ep:^f.Endpoint($G,$C,$A))->bool {
 state.returned_ticks=k.lane_frame(&ep.lane,1.0/60)
 state.after_steps=ep.steps;state.head_after=ep.lane.ticker.tick;state.confirmed_after=k.lane_world_confirmed(&ep.lane)
 first_error(state,k.lane_world_status(&ep.lane))
 sink:=&state.oracle_handle.data.sink
 return state.error==.Ok && state.returned_ticks==1 && state.after_steps==state.before_steps+1 && state.head_before==159 && state.head_after==160 && state.confirmed_before==152 && state.confirmed_after==152 && sink.ok && sink.expected_tag_stream_ok && sink.calls>0 && sink.input_packets==sink.calls && sink.calls==sink.copies && sink.copies==sink.freed && sink.bytes>0
}
client_a_proof :: proc(state:^Client_A)->bool {
 if state.proof_handle.data!=nil || state.proof_handle.sdk.memory!=nil {first_error(state,.Busy);return false}
 actual,ae:=store_create();state.proof_handle=actual
 if ae!=.Ok {first_error(state,ae);first_error(state,store_destroy(&state.proof_handle),true);return false}
 e:k.World_Error
 if state.candidate.profile==.Dense {e=copy_five(state,&state.proof_handle,state.candidate.receiver_dense)}else{e=copy_five(state,&state.proof_handle,state.candidate.receiver_common)}
 first_error(state,e)
 if e==.Ok {
  expected,observed:=state.oracle_handle.data,state.proof_handle.data
  state.full5_equal=observed.epoch==expected.epoch && observed.tick==expected.tick && observed.asset_id==expected.asset_id && observed.field_schema==expected.field_schema && bd.compare(observed.signature,expected.signature)==.Match
  for part in bd.Part {state.full5_equal=state.full5_equal && mem.compare(observed.parts[part],expected.parts[part])==0}
  state.actual=observed.signature
 }
 drop:=store_destroy(&state.proof_handle);first_error(state,drop,true)
 return e==.Ok && drop==.Ok && state.full5_equal
}
client_a_destroy :: proc(state:^Client_A)->f.Cleanup {
 if state==nil {return {ok=true,stats_ok=true}}
 cp_drop:=k.world_checkpoint_destroy(&state.cp_cleanup);first_error(state,cp_drop,true)
 ok:=cp_drop==.Ok
 if ok {e:=store_destroy(&state.proof_handle);first_error(state,e,true);ok=e==.Ok}
 if ok {ok=close_fixture(state,true)}
 if ok {ok=close_fixture(state,false)}
 if ok {e:=store_destroy(&state.oracle_handle);first_error(state,e,true);ok=e==.Ok}
 ok=ok && !state.fixture_cleanup_failed && state.cleanup_error==.Ok
 native,ne:=b.engine_allocation_stats();wrapper,we:=b.snapshot_allocation_stats();meter,me:=bm.category_stats(bg.CATEGORY_KIT_CORE);domain,de:=b.domain_contract_get();ledger,le:=b.host_ledger_get(domain.cookie)
 // No state-zeroing on failure: actual handles and/or explicit fixture failure
 // tombstones remain for the caller. Preserve the first operation error too.
 if ok && state.error==.Ok {state^={}}
 return {native.live_bytes,wrapper.live_bytes,meter.live_bytes,ledger.live_bytes,ledger.host_reserved_bytes,ledger.committed_peak_bytes,ok,ne==.Ok&&we==.Ok&&me==bg.OK&&de==.Ok&&le==.Ok}
}

// Authority B is a distinct normal composite. Same by-value handles and
// plain local-checkpoint-five oracle contract as A; no new runtime or timer.
Authority_B :: Client_A
bind_authority_sink :: proc(handle:^Oracle_Handle,ep:^f.Endpoint($G,$C,$A),peer:s.Peer_Id) {
 data:=handle.data
 data.sink={allocator=data.allocator,role=.Authority,peer=peer,ok=true,expected_tag_stream_ok=true,fingerprint=14695981039346656037}
 s.session_set_transport(&ep.ses,&data.sink,owned_send)
}
authority_prepare :: proc(state:^Authority_B,host,participant:^f.Endpoint($G,$C,$A))->bool {
 if host.lane.ticker.tick!=161 || k.lane_world_confirmed(&host.lane)!=161 || participant.lane.ticker.tick!=161 {first_error(state,.History_Missing);return false}
 // Existing public input participant supplies its actual162 proposal BEFORE
 // the authority entry. Original fixture transport dispatches it to authority;
 // no synthetic packet, accepted row, private apply or timeline setter.
 if k.lane_frame(&participant.lane,1.0/60)!=1 {first_error(state,.Step_Failed);return false}
 player,ok:=s.session_player(&host.ses,participant.ses.me)
 if !ok || player.peer==s.NO_PEER {first_error(state,.Incompatible);return false}
 state.authority_peer=player.peer;state.explicit_corrections=0
 bind_authority_sink(&state.oracle_handle,host,state.authority_peer);before(state,host)
 protocol:=k.lane_world_protocol_status(&host.lane);state.signatures_before=protocol.signatures_sent;state.full_before=protocol.full_states_sent
 return true
}
authority_entry_typed :: proc(state:^Authority_B,host:^f.Endpoint($G,$C,$A))->bool {
 // Public normal162 owes the actual ordinary v2 signature at cadence3.
 state.returned_ticks=k.lane_frame(&host.lane,1.0/60)
 state.after_steps=host.steps;state.head_after=host.lane.ticker.tick;state.confirmed_after=k.lane_world_confirmed(&host.lane)
 protocol:=k.lane_world_protocol_status(&host.lane);state.signatures_after=protocol.signatures_sent;state.full_after=protocol.full_states_sent
 first_error(state,k.lane_world_status(&host.lane));sink:=&state.oracle_handle.data.sink
 return state.error==.Ok && state.returned_ticks==1 && state.after_steps==state.before_steps+1 && state.head_before==161 && state.head_after==162 && state.confirmed_before==161 && state.confirmed_after==162 && state.explicit_corrections==0 && state.signatures_after==state.signatures_before+1 && state.full_after==state.full_before && sink.ok && sink.expected_tag_stream_ok && sink.accepted_packets==1 && sink.signature_packets==1 && sink.world_chunks==0 && sink.calls==sink.copies && sink.copies==sink.freed && sink.bytes>0
}

authority_b_create :: proc(profile:f.Profile)->(state:Authority_B,error:k.World_Error) {
 handle,se:=store_create();state.oracle_handle=handle
 if se!=.Ok {first_error(&state,se);first_error(&state,store_destroy(&state.oracle_handle),true);return state,state.error}
 reference,re:=f.create(profile,live_authority_tick=161);state.reference=reference
 if re!=.Ok {first_error(&state,re);_=close_fixture(&state,true);return state,state.error}
 good:=false
 if profile==.Dense {
  good=authority_prepare(&state,reference.source_dense,reference.ghost_dense)
  if good {good=authority_entry_typed(&state,reference.source_dense)}
  if good {good=copy_five(&state,&state.oracle_handle,reference.source_dense)==.Ok}
 }else{
  good=authority_prepare(&state,reference.source_common,reference.ghost_common)
  if good {good=authority_entry_typed(&state,reference.source_common)}
  if good {good=copy_five(&state,&state.oracle_handle,reference.source_common)==.Ok}
 }
 if state.cp_cleanup.image!=nil || !k.world_owner_is_empty(state.cp_cleanup.owner) {return state,state.error}
 if good {state.oracle_handle.data.wire_signature=state.oracle_handle.data.sink.signature}
 closed:=close_fixture(&state,true);stats,cs:=bm.category_stats(bg.CATEGORY_KIT_CORE)
 state.reference_context_destroyed=closed && state.reference==nil && cs==bg.OK && stats.contexts==1
 if !good || !state.reference_context_destroyed {first_error(&state,.Busy);return state,state.error}
 candidate,ce:=f.create(profile,live_authority_tick=161);state.candidate=candidate
 if ce!=.Ok {first_error(&state,ce);_=close_fixture(&state,false);return state,state.error}
 if profile==.Dense {good=authority_prepare(&state,candidate.source_dense,candidate.ghost_dense)}else{good=authority_prepare(&state,candidate.source_common,candidate.ghost_common)}
 if !good {_=close_fixture(&state,false)}
 return state,state.error
}
authority_b_operation :: proc(state:^Authority_B)->bool {
 if state==nil || state.candidate==nil || !state.reference_context_destroyed {return false}
 if state.candidate.profile==.Dense {return authority_entry_typed(state,state.candidate.source_dense)}
 return authority_entry_typed(state,state.candidate.source_common)
}
authority_b_proof :: proc(state:^Authority_B)->bool {
 if state.proof_handle.data!=nil || state.proof_handle.sdk.memory!=nil {first_error(state,.Busy);return false}
 actual,ae:=store_create();state.proof_handle=actual
 if ae!=.Ok {first_error(state,ae);first_error(state,store_destroy(&state.proof_handle),true);return false}
 e:k.World_Error
 if state.candidate.profile==.Dense {e=copy_five(state,&state.proof_handle,state.candidate.source_dense)}else{e=copy_five(state,&state.proof_handle,state.candidate.source_common)}
 first_error(state,e)
 if e==.Ok {
  expected,observed:=state.oracle_handle.data,state.proof_handle.data
  state.full5_equal=observed.epoch==expected.epoch && observed.tick==expected.tick && observed.asset_id==expected.asset_id && observed.field_schema==expected.field_schema && bd.compare(observed.signature,expected.signature)==.Match && bd.compare(state.oracle_handle.data.sink.signature,expected.wire_signature)==.Match
  for part in bd.Part {state.full5_equal=state.full5_equal && mem.compare(observed.parts[part],expected.parts[part])==0}
  state.actual=observed.signature
 }
 drop:=store_destroy(&state.proof_handle);first_error(state,drop,true)
 return e==.Ok && drop==.Ok && state.full5_equal
}
authority_b_destroy :: proc(state:^Authority_B)->f.Cleanup {return client_a_destroy(state)}
