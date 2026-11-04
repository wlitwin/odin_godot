package box3d_authoring_frameworks_test

// Actual Native + existing framework APIs; standalone nilOwner/static linkage.
// The separate Godot authoring fixture covers SDK extraction/resource lifetimes.
import "core:mem"
import "core:testing"
import b "godot:box3d"
import bd "godot:box3d/diagnostics"
import ba "godot:box3d/authoring"
import kn "godot:kit/net"
import ks "godot:kit/session"
import k "godot:kit/sim"
import kp "godot:kit/physics"
import r "godot:replay"
import rp "godot:replay/physics"
import rn "godot:replay/net"
import tr "godot:replay/transport"
import view "godot:replay/view"

State :: struct {tick:u64}
Parcel :: struct {to:ks.Peer_Id,bytes:[]u8,channel:ks.Channel}
Kit_Box :: struct {
 peer:ks.Peer_Id,ses:ks.Session,lane:k.Lane,
 physics:kp.Instance(State),network:kp.Network(State),control:kp.Typed_Codec(u8),
 built:ba.Built_Scene,out:[dynamic]Parcel,
}
kit_send :: proc(user:rawptr,to:ks.Peer_Id,bytes:[]u8,channel:ks.Channel){
 box:=cast(^Kit_Box)user;owned:=make([]u8,len(bytes));copy(owned,bytes)
 append(&box.out,Parcel{to,owned,channel})
}
kit_pump :: proc(boxes:[]^Kit_Box){
 for progress:=true;progress; {
  progress=false
  for box in boxes{for len(box.out)>0{
   parcel:=box.out[0];ordered_remove(&box.out,0)
   for dest in boxes{if dest.peer!=box.peer && (parcel.to==ks.BROADCAST_PEER || parcel.to==dest.peer){reader:=kn.reader_make(parcel.bytes);ks.session_handle_packet(&dest.ses,box.peer,&reader)}}
   delete(parcel.bytes);progress=true
  }}
 }
}
kit_sample :: proc(_:rawptr,_:u64,out:rawptr){(cast(^u8)out)^=0}
kit_step :: proc(user:rawptr,tick:u64){box:=cast(^Kit_Box)user;kp.state(&box.physics).tick=tick}
kit_setup :: proc(t:^testing.T,box:^Kit_Box,scene:^ba.Baked_Scene)->bool {
 built,diag:=ba.build(scene,PROFILE);testing.expect_value(t,diag.error,ba.Error.None);if diag.error!=.None{return false};box.built=built
 k.lane_init(&box.lane,&box.ses,size_of(u8),cfg={slots=128,snap_every=3})
 k.lane_set_sim(&box.lane,box,kit_sample,kit_step);k.lane_class_set_type(&box.lane,0,u8)
 error:=kp.authoring_attach(&box.physics,&box.lane,&box.built,State{},nil,{})
 testing.expect_value(t,error,k.World_Error.Ok);if error!=.Ok{return false}
 error=kp.codec_init(&box.control);testing.expect_value(t,error,k.World_Error.Ok);if error!=.Ok{return false}
 inputs:=[]k.World_Wire_Input{{0,box.control.value,.Hold}}
 drivers:=[]k.World_Driver{{1,0},{2,0}}
 rules:=bd.hash_bytes(transmute([]u8)string("box3d-authoring-frameworks.v1"))
 error=kp.network_attach(&box.network,&box.physics,&box.built.catalog,nil,inputs,drivers,nil,rules)
 testing.expect_value(t,error,k.World_Error.Ok);return error==.Ok
}
kit_destroy :: proc(t:^testing.T,box:^Kit_Box){
 testing.expect_value(t,kp.network_destroy(&box.network),k.World_Error.Ok)
 testing.expect_value(t,kp.detach(&box.physics),k.World_Error.Ok)
 kp.codec_destroy(&box.control);k.lane_destroy(&box.lane);ks.session_destroy(&box.ses)
 for item in box.out{delete(item.bytes)};delete(box.out)
 testing.expect_value(t,ba.built_destroy(&box.built),b.Status.Ok)
}
kit_same :: proc(t:^testing.T,a,z:^Kit_Box,tick:u64)->bool{
 left,right:k.World_Diagnostic_Frame
 ae:=k.lane_world_diagnostic_frame(&a.lane,tick,&left);defer k.world_diagnostic_frame_destroy(&left)
 ze:=k.lane_world_diagnostic_frame(&z.lane,tick,&right);defer k.world_diagnostic_frame_destroy(&right)
 testing.expect(t,ae==.Ok && ze==.Ok);if ae!=.Ok || ze!=.Ok{return false}
 same:=bd.compare(left.signature,right.signature)==.Match
 for part in bd.Part{same=mem.compare(left.view.parts[part],right.view.parts[part])==0 && same}
 testing.expect(t,same,"actual Kit complete5 includes advanced authored geometry");return same
}

@(test)
kit_authored_six_shapes_and_sensor_canonical_welcome_and_reset :: proc(t:^testing.T){
 input:=scene_input();defer scene_input_destroy(&input)
 scene,diag:=ba.bake(input);testing.expect_value(t,diag.error,ba.Error.None);if diag.error!=.None{return};defer ba.destroy(&scene)
 host,client:=new(Kit_Box),new(Kit_Box);defer free(host);defer free(client)
 defer kit_destroy(t,host);defer kit_destroy(t,client)
 host.peer=ks.HOST_PEER;client.peer=100
 for box in ([]^Kit_Box{host,client}){box.ses.send=kit_send;box.ses.send_user=box}
 ks.session_host_start(&host.ses,"authority");ks.session_client_start(&client.ses,0xabc,"client");ks.session_client_join(&client.ses);kit_pump({host,client})
 if !kit_setup(t,host,&scene) || !kit_setup(t,client,&scene){return}
 // Catalogs/worlds/maps are detached owners, not borrowed Resource/bake storage.
 ba.destroy(&scene)
 testing.expect_value(t,k.lane_world_send_checkpoint(&host.lane,client.peer,.Welcome),k.World_Error.Ok)
 kit_pump({host,client});_=k.lane_frame(&client.lane,0)
 if !kit_same(t,host,client,0){return}
 for _ in 0..<3{_=k.lane_frame(&client.lane,1.0/60)}
 kit_pump({host,client})
 for _ in 0..<3{testing.expect_value(t,k.lane_frame(&host.lane,1.0/60),1)}
 kit_pump({host,client});_=k.lane_frame(&client.lane,0)
 if !kit_same(t,host,client,3){return}
 testing.expect_value(t,k.lane_world_request_reset(&client.lane),k.World_Error.Ok)
 kit_pump({host,client});_=k.lane_frame(&host.lane,0) // service the genuine queued request
 kit_pump({host,client});_=k.lane_frame(&client.lane,0)
 testing.expect(t,k.lane_world_network_status(&client.lane).ready)
 kit_same(t,host,client,3)
}

replay_step :: proc(game:^State,_:[2]u8,_,_:u64,ctx:^r.Step(u8)){
 if rp.step(ctx.execution)!=.None{r.abort(ctx);return};game.tick=ctx.tick
}
replay_same :: proc(t:^testing.T,server:^rn.Server(State,u8,u8,u8,2),client:^rn.Client(State,u8,u8,u8,2),codec:^rp.Network_Codec(State,u8,u8,u8,2),tick:u64)->bool{
 a,ae:=r.capture_complete(&server.timeline,tick);if ae!=.None{return false};defer r.complete_checkpoint_destroy(&a)
 z,ze:=r.capture_complete(&client.timeline,tick);if ze!=.None{return false};defer r.complete_checkpoint_destroy(&z)
 av,ave:=rn.complete_view(codec.value,&a,&server.physics.schemas.state,&server.physics.schemas.occurrence);if ave!=.None{return false};defer rn.complete_view_destroy(&av)
 zv,zve:=rn.complete_view(codec.value,&z,&client.physics.schemas.state,&client.physics.schemas.occurrence);if zve!=.None{return false};defer rn.complete_view_destroy(&zv)
 same:=true;for part in bd.Part{same=mem.compare(av.frame.parts[part],zv.frame.parts[part])==0 && same}
 testing.expect(t,same,"actual Replay complete5 includes advanced authored geometry");return same
}
@(test)
replay_authored_six_shapes_and_sensor_canonical_welcome_and_confirmation :: proc(t:^testing.T){
 input:=scene_input();defer scene_input_destroy(&input)
 scene,diag:=ba.bake(input);testing.expect_value(t,diag.error,ba.Error.None);if diag.error!=.None{return};defer ba.destroy(&scene)
 cfg,ce:=rp.authoring_config(&scene);testing.expect_value(t,ce,r.Error.None);if ce!=.None{return}
 built,build_error:=ba.build(&scene,PROFILE);testing.expect_value(t,build_error.error,ba.Error.None);if build_error.error!=.None{return};defer ba.built_destroy(&built)
 initial,ie:=rp.authoring_checkpoint(&built,cfg,r.Frame(State){},rn.Net_Event(u8));testing.expect_value(t,ie,r.Error.None);if ie!=.None{return};defer r.complete_checkpoint_destroy(&initial)
 codec:=new(rp.Network_Codec(State,u8,u8,u8,2));defer free(codec);defer rp.network_codec_destroy(codec)
 ne:=rp.network_codec_init(codec,&built.catalog,cfg,bd.hash_bytes(transmute([]u8)string("box3d-authoring-frameworks.v1")));testing.expect_value(t,ne,rn.Error.None);if ne!=.None{return}
 ba.destroy(&scene)
 memory:=new(tr.Memory);defer free(memory)
 if !tr.memory_init(memory,cfg={2,128,tr.MAX_PACKET_BYTES,4096}){testing.expect(t,false);return};defer tr.memory_destroy(memory)
 endpoints:[2]tr.Memory_Endpoint
 for &endpoint,index in endpoints{if !tr.memory_open(memory,&endpoint,tr.Peer_Id(index+1)){testing.expect(t,false);return}}
 server:=new(rn.Server(State,u8,u8,u8,2));client:=new(rn.Client(State,u8,u8,u8,2));defer free(server);defer free(client);defer rn.server_destroy(server);defer rn.client_destroy(client)
 model:=rn.Model(State,u8,u8,u8,2){complete_state=true,complete_codec=codec.value,step=replay_step,hold=proc(value:u8)->u8{return value},control_valid=proc(value:u8)->bool{return value==0},action_valid=proc(value:u8)->bool{return value==0},state_valid=proc(value:State)->bool{return value.tick<100}}
 network:=rn.physics_config_default();network.snapshot_every=1
 testing.expect_value(t,rn.server_init_complete(server,&initial,model,tr.memory_transport(&endpoints[0]),network,local_seat=1),rn.Error.None)
 testing.expect_value(t,rn.server_set_local_token(server,rn.Token{0=1}),rn.Error.None)
 testing.expect_value(t,rn.client_init(client,model,tr.memory_transport(&endpoints[1]),rn.Token{0=2},cfg=network),rn.Error.None)
 testing.expect_value(t,rn.client_pump(client,0),rn.Error.None);tr.memory_advance(memory,0)
 testing.expect_value(t,rn.server_pump(server,0),rn.Error.None);testing.expect_value(t,rn.server_step(server),rn.Error.None);tr.memory_advance(memory,0)
 testing.expect_value(t,rn.client_pump(client,0),rn.Error.None);tr.memory_advance(memory,0);_=rn.server_pump(server,0)
 if !replay_same(t,server,client,codec,1){return}
 for tick in u64(2)..=6{
  testing.expect_value(t,rn.server_local(server,u8(0)),rn.Error.None);testing.expect_value(t,rn.server_step(server),rn.Error.None)
  for _ in 0..<4{tr.memory_advance(memory,tick*17);testing.expect_value(t,rn.client_pump(client,tick*17),rn.Error.None);changes:[512]view.Change(rn.Net_Event(u8));view.drain(&client.journal,changes[:]);tr.memory_advance(memory,tick*17);_=rn.server_pump(server,tick*17);if client.timeline.confirmed>=tick{break}}
  if !replay_same(t,server,client,codec,tick){return}
 }
}
