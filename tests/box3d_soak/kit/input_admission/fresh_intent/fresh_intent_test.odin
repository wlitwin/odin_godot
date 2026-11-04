// Proposed eligibility RED only; no existing-helper guarantee is asserted.
package kit_fresh_intent_test

import "core:encoding/json"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:testing"
import b "godot:box3d"
import bd "godot:box3d/diagnostics"
import common "godot:examples/box3d_common"
import app "godot:examples/kit_box3d/scripts"
import k "godot:kit/sim"
import n "godot:kit/net"
import p "godot:kit/physics"
import s "godot:kit/session"

Parcel :: struct {to:s.Peer_Id,bytes:[]u8,channel:s.Channel}
Endpoint :: struct {runtime:app.Runtime,peer:s.Peer_Id,out:[dynamic]Parcel}
Observation :: struct {
 schema:u32,scope:string,
 client_head,client_confirmed,authority_head,epoch:u64,
 known40:common.Action,origin40:k.World_Input_Origin,sequence40:u64,
 accepted40_status,unknown41_status:k.World_Error,
 authority_receipt40:app.Receipt,
 before,after:app.Intent_Plan,returned:common.Action,
 proposed_criterion_pass,unknown41_within_original_window:bool,
 before_pair_equal,after_pair_equal,client_publication_unchanged,accepted_unchanged:bool,
 no_new_packets,effects_unchanged:bool,
 first_public_attempt_tick,first_public_source_sequence:u64,
 actual_sent41:common.Action,accepted41:common.Action,accepted41_origin:k.World_Input_Origin,
 authority_receipt41:app.Receipt,
 first41_fullparts_equal,first41_fx_equal,published_identity_preserved,host_known_slot_bypassed:bool,
 first41_packet_sha256:bd.Digest,
 native_live,wrapper_live,provider_live,checkpoint_live,diagnostic_live,odin_live:u64,
}

write_json :: proc(name:string,value:$T) {
 bytes,error:=json.marshal(value);assert(error==nil);defer delete(bytes)
 assert(os.write_entire_file(name,bytes)==nil)
}
write_part :: proc(stage,owner:string,part:bd.Part,bytes:[]u8) {
 name:=fmt.aprintf("%s.%s.part%d.bin",stage,owner,int(part));defer delete(name)
 assert(os.write_entire_file(name,bytes)==nil)
}
send :: proc(user:rawptr,to:s.Peer_Id,bytes:[]u8,channel:s.Channel) {
 endpoint:=cast(^Endpoint)user;copy_bytes:=make([]u8,len(bytes));copy(copy_bytes,bytes)
 append(&endpoint.out,Parcel{to,copy_bytes,channel})
}
drain :: proc(t:^testing.T,from,to:^Endpoint) {
 for packet in from.out {
  testing.expect(t,packet.to==s.BROADCAST_PEER || packet.to==to.peer)
  before:=bd.hash_bytes(packet.bytes);reader:=n.reader_make(packet.bytes)
  s.session_handle_packet(&to.runtime.ses,from.peer,&reader,packet.channel)
  testing.expect(t,!reader.err);testing.expect_value(t,bd.hash_bytes(packet.bytes),before)
  delete(packet.bytes)
 }
 clear(&from.out)
}
handshake :: proc(t:^testing.T,host,client:^Endpoint) {
 host.peer=s.HOST_PEER;client.peer=100
 for endpoint in ([]^Endpoint{host,client}) {
  rt:=&endpoint.runtime;rt.allocator=context.allocator;rt.initial=4;rt.seed=17;rt.target=300
  rt.sink=new(app.FX_Sink)
  rt.ses.send=send;rt.ses.send_user=endpoint
 }
 host.runtime.role=.Host;client.runtime.role=.Client
 s.session_host_start(&host.runtime.ses,"authority")
 s.session_client_start(&client.runtime.ses,0x1234,"client");s.session_client_join(&client.runtime.ses)
 for len(host.out)>0 || len(client.out)>0 {drain(t,client,host);drain(t,host,client)}
 testing.expect_value(t,host.runtime.ses.me,n.Player_Id(1));testing.expect_value(t,client.runtime.ses.me,n.Player_Id(2))
 // The actual example owns each Lane, provider, codec, catalog clone and Side.
 // No runtime_create/frame/destroy, Godot, SDK/realm override or Lane copy.
 assert(app.model_create(&host.runtime));assert(app.model_create(&client.runtime))
 testing.expect_value(t,k.lane_world_send_checkpoint(&host.runtime.lane,client.peer,.Welcome),k.World_Error.Ok)
 drain(t,host,client);testing.expect_value(t,k.lane_frame(&client.runtime.lane,0),0)
 testing.expect(t,k.lane_world_network_status(&client.runtime.lane).ready)
}
destroy :: proc(t:^testing.T,endpoint:^Endpoint) {
 rt:=&endpoint.runtime
 testing.expect_value(t,p.network_destroy(&rt.network),k.World_Error.Ok)
 testing.expect_value(t,p.codec_destroy(&rt.controls),k.World_Error.Ok)
 testing.expect_value(t,p.codec_destroy(&rt.action_codec),k.World_Error.Ok)
 testing.expect_value(t,p.codec_destroy(&rt.proxy_codec),k.World_Error.Ok)
 testing.expect_value(t,p.codec_destroy(&rt.event_codec),k.World_Error.Ok)
 testing.expect_value(t,p.detach(&rt.physics),k.World_Error.Ok)
 k.lane_destroy(&rt.lane);s.session_destroy(&rt.ses)
 free(rt.sink)
 for packet in endpoint.out {delete(packet.bytes)};delete(endpoint.out)
 free(endpoint)
}
pair :: proc(t:^testing.T,stage:string,host,client:^Endpoint,tick:u64=39)->bool {
 a,c:k.World_Diagnostic_Frame
 testing.expect_value(t,k.lane_world_diagnostic_frame(&host.runtime.lane,tick,&a),k.World_Error.Ok)
 testing.expect_value(t,k.lane_world_diagnostic_frame(&client.runtime.lane,tick,&c),k.World_Error.Ok)
 defer k.world_diagnostic_frame_destroy(&a);defer k.world_diagnostic_frame_destroy(&c)
 equal:=bd.compare(a.signature,c.signature)==.Match
 for part in bd.Part {
  equal=equal && mem.compare(a.view.parts[part],c.view.parts[part])==0
  write_part(stage,"authority",part,a.view.parts[part]);write_part(stage,"client",part,c.view.parts[part])
 }
 testing.expect(t,equal);return equal
}

sent41 :: proc(t:^testing.T,endpoint:^Endpoint)->(value:common.Action,sequence:u64,digest:bd.Digest) {
 found:=false
 for packet in endpoint.out {
  if len(packet.bytes)<3 || packet.bytes[2]!=k.SIM_WORLD_INPUT {continue}
  reader:=n.reader_make(packet.bytes)
  testing.expect_value(t,n.read_u8(&reader),s.SES_APP);_=n.read_u8(&reader);_=n.read_u8(&reader)
  testing.expect_value(t,n.read_u32(&reader),k.WORLD_NETWORK_REV);_=n.reader_view(&reader,32)
  testing.expect_value(t,n.read_u64(&reader),u64(1));testing.expect_value(t,n.read_u64(&reader),u64(41))
  first:=n.read_u64(&reader);count:=int(n.read_u8(&reader));entries:=int(n.read_u8(&reader))
  for j in 0..<count {for _ in 0..<entries {
   driver:=int(n.read_u8(&reader));origin:=k.World_Input_Origin(n.read_u8(&reader));source:=n.read_u64(&reader)
   declared:=endpoint.runtime.lane.world.network.drivers[driver]
   codec:=declared.class==0?endpoint.runtime.controls.value:endpoint.runtime.action_codec.value
   bytes:=n.reader_view(&reader,codec.wire_bytes)
   if first+u64(j)==41 && declared.player==endpoint.runtime.ses.me && declared.class==1 {
    testing.expect(t,!found);found=true
    testing.expect_value(t,origin,k.World_Input_Origin.Submitted);sequence=source
    testing.expect_value(t,codec.decode(codec.user,bytes,(cast([^]u8)&value)[:size_of(value)]),k.World_Error.Ok)
   }
  }}
  testing.expect(t,!reader.err && len(n.reader_remaining(&reader))==0)
  digest=bd.hash_bytes(packet.bytes);assert(os.write_entire_file("client.first41.stream.bin",packet.bytes)==nil)
 }
 testing.expect(t,found);return
}
spawn41 :: proc(rt:^app.Runtime)->(count:int,event:app.Stamped_Event) {
 for candidate in rt.sink.observed[:rt.sink.count] {
  if candidate.tick==41 && candidate.value.kind==.Spawn {count+=1;event=candidate}
 }
 return
}

@(test)
known_authority_none_must_leave_proposed_fresh_intent_unsampled :: proc(t:^testing.T) {
 tracking:mem.Tracking_Allocator;backing:=context.allocator
 mem.tracking_allocator_init(&tracking,backing,backing);context.allocator=mem.tracking_allocator(&tracking)
 observation:=Observation{schema=1,scope="fresh_eligibility_actual_imported_example_common4_static9c66_nilOwner_noSDK_noTiming"}
 host,client:=new(Endpoint),new(Endpoint);handshake(t,host,client)
 for _ in 0..<39 {
  testing.expect_value(t,k.lane_frame(&client.runtime.lane,1.0/60),1)
  drain(t,client,host);testing.expect_value(t,k.lane_frame(&host.runtime.lane,1.0/60),1)
  drain(t,host,client);testing.expect_value(t,k.lane_frame(&client.runtime.lane,0),0)
 }
 rt:=&client.runtime
 testing.expect_value(t,rt.lane.ticker.tick,u64(39));testing.expect_value(t,k.lane_world_confirmed(&rt.lane),u64(39))
 testing.expect(t,!rt.intents.initialized)
 testing.expect_value(t,k.lane_frame(&host.runtime.lane,1.0/60),1)
 // Only genuine accepted Stream40 exists; next automatic CP is42.
 for packet in host.out {
  testing.expect_value(t,packet.channel,s.Channel.Stream)
  testing.expect(t,len(packet.bytes)>2 && packet.bytes[2]==k.SIM_WORLD_ACCEPTED)
  assert(os.write_entire_file("authority.accepted40.stream.bin",packet.bytes)==nil)
 }
 drain(t,host,client);testing.expect_value(t,k.lane_frame(&rt.lane,0),0)
 known,origin,sequence,error:=k.lane_world_accepted_input(&rt.lane,40,rt.ses.me,1)
 testing.expect_value(t,error,k.World_Error.Ok);assert(len(known)==size_of(common.Action))
 copy((cast([^]u8)&observation.known40)[:size_of(common.Action)],known)
 observation.origin40=origin;observation.sequence40=sequence;observation.accepted40_status=error
 testing.expect_value(t,observation.known40,common.Action{})
 authority_known,authority_origin,authority_sequence,authority_error:=k.lane_world_accepted_input(&host.runtime.lane,40,rt.ses.me,1)
 testing.expect_value(t,authority_error,k.World_Error.Ok);testing.expect_value(t,mem.compare(known,authority_known),0)
 testing.expect_value(t,origin,authority_origin);testing.expect_value(t,sequence,authority_sequence)
 cp40,cp40_error:=k.lane_world_checkpoint(&host.runtime.lane,40)
 testing.expect_value(t,cp40_error,k.World_Error.Ok)
 side40,side40_error:=p.checkpoint_side(&cp40,app.Side);testing.expect_value(t,side40_error,k.World_Error.Ok)
 observation.authority_receipt40=side40.receipts[1]
 testing.expect_value(t,observation.authority_receipt40.tick,u64(40))
 testing.expect_value(t,observation.authority_receipt40.kind,common.Action_Kind.None)
 k.world_checkpoint_destroy(&cp40)
 _,_,_,unknown_error:=k.lane_world_accepted_input(&rt.lane,41,rt.ses.me,1)
 observation.unknown41_status=unknown_error;testing.expect_value(t,unknown_error,k.World_Error.History_Missing)
 observation.client_head=rt.lane.ticker.tick;observation.client_confirmed=k.lane_world_confirmed(&rt.lane)
 observation.authority_head=host.runtime.lane.ticker.tick;observation.epoch=k.lane_world_epoch(&rt.lane)
 observation.before_pair_equal=pair(t,"before",host,client)
 before,be:=k.lane_world_checkpoint(&rt.lane,39);testing.expect_value(t,be,k.World_Error.Ok)
 client_fx,host_fx:=rt.sink.count,host.runtime.sink.count
 client_packets,host_packets:=len(client.out),len(host.out)
 // Actual helper calls, only now enabling this fixture's script intent source.
 rt.scripted=true;app.intent_prepare(rt)
 testing.expect(t,rt.intents.initialized && rt.intents.armed)
 observation.before=rt.intents.plans[rt.intents.active]
 testing.expect(t,!observation.before.attempted && observation.before.original==40 && observation.before.due==40)
 observation.returned=app.intent_sample(rt,40)
 observation.after=rt.intents.plans[rt.intents.active]
 observation.proposed_criterion_pass=observation.returned.kind==.None && !observation.after.attempted && observation.after.attempt_tick==0
 // Original RED assertion, now the specifically authorized prospective policy.
 testing.expect(t,observation.proposed_criterion_pass,"proposed fresh eligibility: known authority None40 must remain UNSAMPLED")
 testing.expect_value(t,observation.after.original,u64(40));testing.expect_value(t,observation.after.due,u64(40))
 observation.unknown41_within_original_window=unknown_error==.History_Missing && 41>observation.after.original && 41<=observation.after.due+8
 testing.expect(t,observation.unknown41_within_original_window)
 after,ae:=k.lane_world_checkpoint(&rt.lane,39);testing.expect_value(t,ae,k.World_Error.Ok)
 same,se:=k.world_checkpoint_equal(&before,&after);testing.expect_value(t,se,k.World_Error.Ok)
 observation.client_publication_unchanged=same && rt.lane.ticker.tick==39 && k.lane_world_confirmed(&rt.lane)==39
 testing.expect(t,observation.client_publication_unchanged)
 k.world_checkpoint_destroy(&before);k.world_checkpoint_destroy(&after)
 now,no,ns,ne:=k.lane_world_accepted_input(&rt.lane,40,rt.ses.me,1)
 observation.accepted_unchanged=ne==.Ok && no==origin && ns==sequence && mem.compare(now,known)==0
 observation.no_new_packets=len(client.out)==client_packets && len(host.out)==host_packets
 observation.effects_unchanged=rt.sink.count==client_fx && host.runtime.sink.count==host_fx
 testing.expect(t,observation.accepted_unchanged && observation.no_new_packets && observation.effects_unchanged && !rt.failed)
 observation.after_pair_equal=pair(t,"after",host,client)
 // Ordinary existing normal paths now reach the FIRST eligible action sample41.
 testing.expect_value(t,k.lane_frame(&rt.lane,1.0/60),1)
 app.intent_published(rt)
 testing.expect(t,!rt.intents.plans[rt.intents.active].attempted)
 drain(t,client,host);testing.expect_value(t,k.lane_frame(&host.runtime.lane,0),0)
 testing.expect_value(t,k.lane_frame(&rt.lane,1.0/60),1)
 attempt:=rt.intents.plans[rt.intents.active]
 observation.first_public_attempt_tick=attempt.attempt_tick
 testing.expect(t,attempt.original==40 && attempt.due==40 && attempt.attempted && attempt.attempt_tick==41)
 observation.actual_sent41,observation.first_public_source_sequence,observation.first41_packet_sha256=sent41(t,client)
 testing.expect_value(t,observation.actual_sent41,common.Action{.Spawn})
 testing.expect_value(t,observation.first_public_source_sequence,u64(41))
 app.intent_published(rt) // Public ring+head verifies publication; no wire proof is fabricated.
 testing.expect(t,rt.intents.plans[rt.intents.active].published && !rt.intents.plans[rt.intents.active].transported)
 drain(t,client,host);testing.expect_value(t,k.lane_frame(&host.runtime.lane,0),0)
 testing.expect_value(t,k.lane_frame(&host.runtime.lane,1.0/60),1)
 accepted41,origin41,sequence41,status41:=k.lane_world_accepted_input(&host.runtime.lane,41,rt.ses.me,1)
 testing.expect_value(t,status41,k.World_Error.Ok);testing.expect_value(t,sequence41,u64(41))
 copy((cast([^]u8)&observation.accepted41)[:size_of(common.Action)],accepted41)
 observation.accepted41_origin=origin41
 testing.expect_value(t,observation.accepted41,common.Action{.Spawn});testing.expect_value(t,origin41,k.World_Input_Origin.Submitted)
 cp41,ce41:=k.lane_world_checkpoint(&host.runtime.lane,41);testing.expect_value(t,ce41,k.World_Error.Ok)
 side41,se41:=p.checkpoint_side(&cp41,app.Side);testing.expect_value(t,se41,k.World_Error.Ok)
 observation.authority_receipt41=side41.receipts[1]
 testing.expect(t,observation.authority_receipt41.tick==41 && observation.authority_receipt41.kind==.Spawn && observation.authority_receipt41.applied && side41.game.births==5)
 k.world_checkpoint_destroy(&cp41)
 testing.expect_value(t,k.lane_world_send_checkpoint(&host.runtime.lane,client.peer,.Correction),k.World_Error.Ok)
 drain(t,host,client);testing.expect_value(t,k.lane_frame(&rt.lane,0),0)
 observation.first41_fullparts_equal=pair(t,"published41",host,client,41)
 hc,he:=spawn41(&host.runtime);cc,ce:=spawn41(rt)
 observation.first41_fx_equal=hc==1 && cc==1 && he==ce
 testing.expect(t,observation.first41_fx_equal)
 immutable:=rt.intents.plans[rt.intents.active]
 testing.expect_value(t,app.intent_sample(rt,41),common.Action{.Spawn})
 testing.expect_value(t,app.intent_sample(rt,42),common.Action{})
 observation.published_identity_preserved=rt.intents.plans[rt.intents.active]==immutable
 testing.expect(t,observation.published_identity_preserved)
 // Authority keeps its original helper path even with an actual known slot.
 _,_,_,host_known:=k.lane_world_accepted_input(&host.runtime.lane,40,host.runtime.ses.me,1)
 testing.expect_value(t,host_known,k.World_Error.Ok)
 host.runtime.scripted=true;app.intent_prepare(&host.runtime)
 host_value:=app.intent_sample(&host.runtime,40)
 observation.host_known_slot_bypassed=host_value.kind==.Spawn && host.runtime.intents.plans[host.runtime.intents.active].attempt_tick==40
 testing.expect(t,observation.host_known_slot_bypassed)
 destroy(t,client);destroy(t,host)
 engine,es:=b.engine_allocation_stats();wrapper,ws:=b.snapshot_allocation_stats()
 testing.expect_value(t,es,b.Status.Ok);testing.expect_value(t,ws,b.Status.Ok)
 observation.native_live=engine.live_bytes;observation.wrapper_live=wrapper.live_bytes;observation.provider_live=p.owned_bytes()
 observation.checkpoint_live=k.world_checkpoint_owned_bytes();observation.diagnostic_live=k.world_diagnostic_frame_owned_bytes()
 observation.odin_live=u64(tracking.current_memory_allocated)
 testing.expect(t,observation.native_live==0 && observation.wrapper_live==0 && observation.provider_live==0 && observation.checkpoint_live==0 && observation.diagnostic_live==0 && observation.odin_live==0)
 context.allocator=backing;mem.tracking_allocator_destroy(&tracking)
 write_json("observation.json",observation)
}
