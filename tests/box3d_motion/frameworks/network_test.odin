package box3d_motion_frameworks_test

import "core:mem"
import "core:testing"
import "core:fmt"
import b "godot:box3d"
import ba "godot:box3d/authoring"
import bd "godot:box3d/diagnostics"
import kn "godot:kit/net"
import ks "godot:kit/session"
import k "godot:kit/sim"
import kp "godot:kit/physics"
import r "godot:replay"
import rp "godot:replay/physics"
import rn "godot:replay/net"
import tr "godot:replay/transport"
import view "godot:replay/view"

Parcel :: struct {to:ks.Peer_Id,bytes:[]u8,channel:ks.Channel}
Net_Kit :: struct {box:Kit,peer:ks.Peer_Id,network:kp.Network(State),codec:kp.Typed_Codec(Input),out:[dynamic]Parcel}
kit_send :: proc(user:rawptr,to:ks.Peer_Id,bytes:[]u8,channel:ks.Channel){
 box:=cast(^Net_Kit)user;owned:=make([]u8,len(bytes));copy(owned,bytes);append(&box.out,Parcel{to,owned,channel})
}
kit_pump :: proc(boxes:[]^Net_Kit){
 for progress:=true;progress;{
  progress=false
  for box in boxes{for len(box.out)>0{
   packet:=box.out[0];ordered_remove(&box.out,0)
   for destination in boxes{if destination.peer!=box.peer&&(packet.to==ks.BROADCAST_PEER||packet.to==destination.peer){reader:=kn.reader_make(packet.bytes);ks.session_handle_packet(&destination.box.session,box.peer,&reader)}}
   delete(packet.bytes);progress=true
  }}
 }
}
kit_network_setup :: proc(t:^testing.T,box:^Net_Kit,scene:^ba.Baked_Scene)->bool{
 if !kit_setup(t,&box.box,scene,0,true){return false}
 identity,status:=b.recovery_catalog_identity(&box.box.built.catalog)
 testing.expect(t,status==.Ok&&identity.recovery_format==3)
 error:=kp.codec_init(&box.codec);testing.expect_value(t,error,k.World_Error.Ok);if error!=.Ok{return false}
 inputs:=[]k.World_Wire_Input{{0,box.codec.value,.Hold}}
 drivers:=[]k.World_Driver{{1,0},{2,0}}
 error=kp.network_attach(&box.network,&box.box.physics,&box.box.built.catalog,nil,inputs,drivers,nil,bd.hash_bytes(transmute([]u8)string("box3d-motion-frameworks.v1")))
 testing.expect_value(t,error,k.World_Error.Ok);return error==.Ok
}
kit_network_destroy :: proc(t:^testing.T,box:^Net_Kit){
 testing.expect_value(t,kp.network_destroy(&box.network),k.World_Error.Ok)
 kp.codec_destroy(&box.codec);kit_destroy(t,&box.box)
 for packet in box.out{delete(packet.bytes)};delete(box.out)
}
kit_network_same :: proc(t:^testing.T,a,z:^Net_Kit,tick:u64)->bool{
 left,right:k.World_Diagnostic_Frame
 ae:=k.lane_world_diagnostic_frame(&a.box.lane,tick,&left);defer k.world_diagnostic_frame_destroy(&left)
 ze:=k.lane_world_diagnostic_frame(&z.box.lane,tick,&right);defer k.world_diagnostic_frame_destroy(&right)
 testing.expect(t,ae==.Ok&&ze==.Ok);if ae!=.Ok||ze!=.Ok{return false}
 same:=bd.compare(left.signature,right.signature)==.Match
 for part in bd.Part{same=mem.compare(left.view.parts[part],right.view.parts[part])==0&&same}
 testing.expect(t,same,"Kit complete canonical five parts include current joint and character state");return same
}
kit_network_family :: proc(t:^testing.T,kind:string){
 input:=scene_input(kind);defer scene_input_destroy(&input)
 scene,diagnostic:=ba.bake(input);testing.expect_value(t,diagnostic.error,ba.Error.None);if diagnostic.error!=.None{return};defer ba.destroy(&scene)
 host,client:=new(Net_Kit),new(Net_Kit);defer free(host);defer free(client)
 defer kit_network_destroy(t,host);defer kit_network_destroy(t,client)
 host.peer=ks.HOST_PEER;client.peer=100
 for box in ([]^Net_Kit{host,client}){box.box.session.send=kit_send;box.box.session.send_user=box}
 ks.session_host_start(&host.box.session,"authority");ks.session_client_start(&client.box.session,0xabc,"client");ks.session_client_join(&client.box.session);kit_pump({host,client})
 if !kit_network_setup(t,host,&scene)||!kit_network_setup(t,client,&scene){fmt.printf("MOTION_FRAMEWORK_FAILURE framework=kit kind=%s stage=network_attach\n",kind);return}
 ba.destroy(&scene)
 testing.expect_value(t,k.lane_world_send_checkpoint(&host.box.lane,client.peer,.Welcome),k.World_Error.Ok)
 kit_pump({host,client});_=k.lane_frame(&client.box.lane,0)
 if !kit_network_same(t,host,client,0){return}
 for _ in 0..<3{_=k.lane_frame(&client.box.lane,1.0/60)}
 kit_pump({host,client})
 for _ in 0..<3{testing.expect_value(t,k.lane_frame(&host.box.lane,1.0/60),1)}
 kit_pump({host,client});_=k.lane_frame(&client.box.lane,0)
 if !kit_network_same(t,host,client,3){return}
 testing.expect_value(t,k.lane_world_request_reset(&client.box.lane),k.World_Error.Ok)
 kit_pump({host,client});_=k.lane_frame(&host.box.lane,0)
 kit_pump({host,client});_=k.lane_frame(&client.box.lane,0)
 testing.expect(t,k.lane_world_network_status(&client.box.lane).ready)
 kit_network_same(t,host,client,3)
}

@(test)
kit_each_joint_family_and_character_survive_canonical_welcome_reset :: proc(t:^testing.T){
 defer expect_cleanup(t)
 for kind in KINDS{kit_network_family(t,kind)}
}

replay_net_step :: proc(value:^State,inputs:[2]Input,_,_:u64,ctx:^r.Step(u8)){replay_step(value,inputs[0],ctx)}
replay_network_same :: proc(t:^testing.T,server:^rn.Server(State,Input,u8,u8,2),client:^rn.Client(State,Input,u8,u8,2),codec:^rp.Network_Codec(State,Input,u8,u8,2),tick:u64)->bool{
 left,le:=r.capture_complete(&server.timeline,tick);if le!=.None{testing.expect_value(t,le,r.Error.None);return false};defer r.complete_checkpoint_destroy(&left)
 right,re:=r.capture_complete(&client.timeline,tick);if re!=.None{testing.expect_value(t,re,r.Error.None);return false};defer r.complete_checkpoint_destroy(&right)
 a,ae:=rn.complete_view(codec.value,&left,&server.physics.schemas.state,&server.physics.schemas.occurrence);if ae!=.None{testing.expect_value(t,ae,rn.Error.None);return false};defer rn.complete_view_destroy(&a)
 z,ze:=rn.complete_view(codec.value,&right,&client.physics.schemas.state,&client.physics.schemas.occurrence);if ze!=.None{testing.expect_value(t,ze,rn.Error.None);return false};defer rn.complete_view_destroy(&z)
 same:=true;for part in bd.Part{same=mem.compare(a.frame.parts[part],z.frame.parts[part])==0&&same}
 testing.expect(t,same,"Replay complete canonical five parts include current joint and character state");return same
}
replay_network_family :: proc(t:^testing.T,kind:string){
 input:=scene_input(kind);defer scene_input_destroy(&input)
 scene,diagnostic:=ba.bake(input);testing.expect_value(t,diagnostic.error,ba.Error.None);if diagnostic.error!=.None{return};defer ba.destroy(&scene)
 config,ce:=rp.authoring_config(&scene);testing.expect_value(t,ce,r.Error.None);if ce!=.None{return}
 built,problem:=ba.build(&scene,PROFILE);testing.expect_value(t,problem.error,ba.Error.None);if problem.error!=.None{return};defer ba.built_destroy(&built)
 identity,status:=b.recovery_catalog_identity(&built.catalog);testing.expect(t,status==.Ok&&identity.recovery_format==3)
 movement:=built.characters[0].config
 initial,ie:=rp.authoring_checkpoint(&built,config,r.Frame(State){state=initial_state(&built)},rn.Net_Event(u8))
 testing.expect_value(t,ie,r.Error.None);if ie!=.None{return};defer r.complete_checkpoint_destroy(&initial)
 codec:=new(rp.Network_Codec(State,Input,u8,u8,2));defer free(codec);defer rp.network_codec_destroy(codec)
 ne:=rp.network_codec_init(codec,&built.catalog,config,bd.hash_bytes(transmute([]u8)string("box3d-motion-frameworks.v1")))
 testing.expect_value(t,ne,rn.Error.None);if ne!=.None{return}
 ba.destroy(&scene)
 memory:=new(tr.Memory);defer free(memory)
 if !tr.memory_init(memory,cfg={2,128,tr.MAX_PACKET_BYTES,4096}){testing.expect(t,false);return};defer tr.memory_destroy(memory)
 endpoints:[2]tr.Memory_Endpoint
 for &endpoint,index in endpoints{if !tr.memory_open(memory,&endpoint,tr.Peer_Id(index+1)){testing.expect(t,false);return}}
 server:=new(rn.Server(State,Input,u8,u8,2));client:=new(rn.Client(State,Input,u8,u8,2));defer free(server);defer free(client);defer rn.server_destroy(server);defer rn.client_destroy(client)
 model:=rn.Model(State,Input,u8,u8,2){complete_state=true,complete_codec=codec.value,step=replay_net_step,user=&movement,hold=proc(input:Input)->Input{return input},control_valid=proc(Input)->bool{return true},action_valid=proc(value:u8)->bool{return value==0},state_valid=proc(value:State)->bool{return value.tick<100}}
 cfg:=rn.physics_config_default();cfg.snapshot_every=1
 testing.expect_value(t,rn.server_init_complete(server,&initial,model,tr.memory_transport(&endpoints[0]),cfg,local_seat=1),rn.Error.None)
 testing.expect_value(t,rn.server_set_local_token(server,rn.Token{0=1}),rn.Error.None)
 testing.expect_value(t,rn.client_init(client,model,tr.memory_transport(&endpoints[1]),rn.Token{0=2},cfg=cfg),rn.Error.None)
 testing.expect_value(t,rn.client_pump(client,0),rn.Error.None);tr.memory_advance(memory,0)
 testing.expect_value(t,rn.server_pump(server,0),rn.Error.None)
 first_step:=rn.server_step(server);testing.expect_value(t,first_step,rn.Error.None)
 if first_step!=.None{fmt.printf("MOTION_FRAMEWORK_FAILURE framework=replay kind=%s stage=server_step tick=1 error=%v\n",kind,first_step);return}
 tr.memory_advance(memory,0)
 testing.expect_value(t,rn.client_pump(client,0),rn.Error.None);tr.memory_advance(memory,0);_=rn.server_pump(server,0)
 if !replay_network_same(t,server,client,codec,1){return}
 for tick in u64(2)..=6{
  testing.expect_value(t,rn.server_local(server,Input{}),rn.Error.None);testing.expect_value(t,rn.server_step(server),rn.Error.None)
  for _ in 0..<4{
   tr.memory_advance(memory,tick*17);testing.expect_value(t,rn.client_pump(client,tick*17),rn.Error.None)
   changes:[512]view.Change(rn.Net_Event(u8));view.drain(&client.journal,changes[:])
   tr.memory_advance(memory,tick*17);_=rn.server_pump(server,tick*17);if client.timeline.confirmed>=tick{break}
  }
  if !replay_network_same(t,server,client,codec,tick){return}
 }
}

@(test)
replay_each_joint_family_and_character_survive_canonical_welcome_confirmation :: proc(t:^testing.T){
 defer expect_cleanup(t)
 for kind in KINDS{replay_network_family(t,kind)}
}
