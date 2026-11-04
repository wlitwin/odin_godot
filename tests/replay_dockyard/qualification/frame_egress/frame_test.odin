package frame_egress_test

import "core:testing"
import b "godot:box3d"
import bd "godot:box3d/diagnostics"
import r "godot:replay"
import net "godot:replay/net"
import ph "godot:replay/physics"
import tr "godot:replay/transport"
import f "godot:tests/replay_physics_net/fixture"
import n "godot:tests/replay_physics_net/native"

original:proc(rawptr,^r.Complete_Checkpoint(f.Game,net.Net_Event(f.Event)),bd.Part,[]u8)->(int,net.Error)
counting:bool
solver_fills:u64

diagnostic :: proc(user:rawptr,checkpoint:^r.Complete_Checkpoint(f.Game,net.Net_Event(f.Event)),part:bd.Part,dst:[]u8)->(int,net.Error){
 if counting&&part==.Solver&&len(dst)>0{solver_fills+=1}
 return original(user,checkpoint,part,dst)
}

@(test)
one_sdk_frame_publishes_current_head_once_after_delayed_ack :: proc(t:^testing.T){
 before,bs:=b.engine_allocation_stats();wrapper_before,ws:=b.snapshot_allocation_stats();provider_before:=ph.allocation_stats()
 testing.expect(t,bs==.Ok&&ws==.Ok)
 exercise(t,true)
 exercise(t,false)
 after,as:=b.engine_allocation_stats();wrapper_after,was:=b.snapshot_allocation_stats();provider_after:=ph.allocation_stats()
 testing.expect(t,as==.Ok&&was==.Ok)
 testing.expect_value(t,after.live_bytes,before.live_bytes)
 testing.expect_value(t,wrapper_after.live_bytes,wrapper_before.live_bytes)
 testing.expect_value(t,provider_after.live_bytes,provider_before.live_bytes)
}

exercise :: proc(t:^testing.T,advance:bool){
 defer {counting=false;original=nil}
 catalog:=n.catalog_make(t);defer b.recovery_catalog_destroy(&catalog)
 config:=n.config_make(&catalog,4)
 world,game,status:=f.world(4);if !testing.expect_value(t,status,b.Status.Ok){return}
 checkpoint,error:=ph.checkpoint_make(r.Frame(f.Game){state=game},net.Net_Event(f.Event),world,config)
 testing.expect_value(t,b.world_destroy(&world),b.Status.Ok)
 if !testing.expect_value(t,error,r.Error.None){return};defer r.complete_checkpoint_destroy(&checkpoint)
 codec:ph.Network_Codec(f.Game,f.Control,f.Action,f.Event,2)
 if !testing.expect_value(t,ph.network_codec_init(&codec,&catalog,config,n.network_rules()),net.Error.None){return};defer ph.network_codec_destroy(&codec)
 original=codec.value.diagnostic_part;model:=n.network_model(&codec);model.complete_codec.diagnostic_part=diagnostic
 cfg:=net.physics_config_default();cfg.snapshot_every=1
 memory:tr.Memory;if !testing.expect(t,tr.memory_init(&memory,cfg={2,64,tr.MAX_PACKET_BYTES,2048})){return};defer tr.memory_destroy(&memory)
 a,z:tr.Memory_Endpoint;if !testing.expect(t,tr.memory_open(&memory,&a,1)&&tr.memory_open(&memory,&z,2)){return}
 server:net.Server(f.Game,f.Control,f.Action,f.Event,2);client:net.Client(f.Game,f.Control,f.Action,f.Event,2)
 testing.expect_value(t,net.server_flush_pending(&server),net.Error.Not_Initialized)
 if !testing.expect_value(t,net.server_init_complete(&server,&checkpoint,model,tr.memory_transport(&a),cfg,local_seat=1),net.Error.None){return};defer net.server_destroy(&server)
 host_token,guest_token:net.Token;host_token[0]=1;guest_token[0]=2
 if !testing.expect_value(t,net.server_set_local_token(&server,host_token),net.Error.None){return}
 if !testing.expect_value(t,net.client_init(&client,model,tr.memory_transport(&z),guest_token,cfg=cfg),net.Error.None){return};defer net.client_destroy(&client)
 if !testing.expect_value(t,net.client_pump(&client,0),net.Error.None)||!testing.expect(t,tr.memory_advance(&memory,0))||!testing.expect_value(t,net.server_pump(&server,0),net.Error.None)||!testing.expect_value(t,net.server_step(&server),net.Error.None){return}
 for _ in 0..<8{
  if !testing.expect(t,tr.memory_advance(&memory,0))||!testing.expect_value(t,net.client_pump(&client,0),net.Error.None)||!testing.expect(t,tr.memory_advance(&memory,0))||!testing.expect_value(t,net.server_pump(&server,0),net.Error.None){return}
 }
 if !testing.expect(t,client.phase==.Running&&server.timeline.head==1){return}
 // Hold a tick2 Snapshot unacknowledged while tick3's fact is committed.
 for _ in 0..<2{
  if !testing.expect_value(t,net.server_local(&server,f.Control{x=20}),net.Error.None)||!testing.expect_value(t,net.server_step(&server),net.Error.None){return}
 }
 if !testing.expect_value(t,server.timeline.head,u64(3)){return}
 if !testing.expect(t,tr.memory_advance(&memory,0))||!testing.expect_value(t,net.client_pump(&client,0),net.Error.None)||!testing.expect(t,tr.memory_advance(&memory,0)){return}
 solver_fills=0;counting=true
 // Receive the delayed ACK, then let the step publish its current head.
 pump_error:=net.server_pump(&server,0,flush_egress=false)
 local_error,step_error:net.Error
 if advance{
  local_error=net.server_local(&server,f.Control{x=20})
  step_error=net.server_step(&server)
 }
 flush_error:=net.server_flush_pending(&server)
 counting=false
 if !testing.expect_value(t,pump_error,net.Error.None)||!testing.expect_value(t,local_error,net.Error.None)||!testing.expect_value(t,step_error,net.Error.None){return}
 if !testing.expect_value(t,flush_error,net.Error.None){return}
 testing.expect_value(t,solver_fills,u64(1))
 testing.expect_value(t,server.timeline.head,advance?u64(4):u64(3))
 found:=0
 for tx in server.physics.tx{
  if len(tx.data.bytes)==0||tx.purpose!=.Snapshot{continue}
  found+=1;testing.expect_value(t,tx.tick,server.timeline.head)
  inspected,inspect_error:=net.complete_inspect(tx.data.bytes,codec.value.identity,1)
  if !testing.expect_value(t,inspect_error,net.Error.None){return}
  truth,capture_error:=r.capture_complete(&server.timeline,tx.tick)
  if !testing.expect_value(t,capture_error,r.Error.None){return};defer r.complete_checkpoint_destroy(&truth)
  fresh,encode_error:=net.complete_encode(codec.value,&truth,.Snapshot,inspected.metadata,&server.physics.schemas.state,&server.physics.schemas.occurrence)
  if !testing.expect_value(t,encode_error,net.Error.None){return};defer net.complete_data_destroy(&fresh)
  testing.expect_value(t,string(tx.data.bytes),string(fresh.bytes))
 }
 testing.expect_value(t,found,1)
 // A revoked host permit cannot publish even a previously prepared image.
 before_id:=server.physics.next_id;before_sent:=server.stats.tx_packets;before_head:=server.timeline.head
 server.cfg.require_permit=true
 testing.expect_value(t,net.server_flush_pending(&server),net.Error.Fenced)
 testing.expect_value(t,net.server_pump(&server,0,flush_egress=false),net.Error.Fenced)
 testing.expect_value(t,server.physics.next_id,before_id)
 testing.expect_value(t,server.stats.tx_packets,before_sent)
 testing.expect_value(t,server.timeline.head,before_head)
 server.cfg.require_permit=false
 for _ in 0..<8{
  if !testing.expect(t,tr.memory_advance(&memory,0))||!testing.expect_value(t,net.client_pump(&client,0),net.Error.None)||!testing.expect(t,tr.memory_advance(&memory,0))||!testing.expect_value(t,net.server_pump(&server,0),net.Error.None){return}
 }
 testing.expect(t,client.timeline.confirmed>=server.timeline.head,"actual receiver confirms the committed signed current frame")
}
