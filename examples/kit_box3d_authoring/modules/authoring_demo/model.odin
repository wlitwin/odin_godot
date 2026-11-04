package kit_authoring_demo

import b "godot:box3d"
import p "godot:kit/physics"
import k "godot:kit/sim"
import n "godot:kit/net"

// Five canonical wire bytes; local Odin padding is handled by Typed_Codec.
Control :: struct {x,z:i16,pulse:bool}
Side :: struct {
 tick:u64,player,pendulum:b.Body_Key,hinge:b.Joint_Key,
 players:[2]u16,controls_applied,pulses:[2]u64,
 sensor_begins,sensor_ends,query_total:u64,query_last:u32,
}
Proxy :: struct {pose:b.Pose,tick:u64}

sample_control :: proc(user:rawptr,tick:u64,out:rawptr){
 rt:=cast(^Demo)user;value:=rt.input
 if rt.scripted{
  value={};axis:=i16((tick/60)%2==0?1:-1)
  if rt.seat==1{value.x=axis}else{value.z=axis}
  value.pulse=tick%45==0
 }else{value.pulse=rt.pulse_pending;rt.pulse_pending=false}
 rt.sampled+=1;(cast(^Control)out)^=value
}
validate_control :: proc(_:rawptr,value:rawptr)->bool{control:=(cast(^Control)value)^;return control.x>= -1&&control.x<=1&&control.z>= -1&&control.z<=1}
model_step :: proc(user:rawptr,tick:u64){
 rt:=cast(^Demo)user;side:=p.state(&rt.physics)
 if side==nil{k.lane_world_fail(&rt.lane,.Invalid);return}
 world,error:=p.world(&rt.physics);if error!=.Ok{k.lane_world_fail(&rt.lane,error);return}
 player,status:=b.body_resolve(world,side.player);if status!=.Ok{_=p.require(&rt.physics,status);return}
 for id,i in rt.players{
  control,_:=k.lane_input_of(&rt.lane,id,Control)
  if control.x!=0||control.z!=0||control.pulse{
   impulse:=b.Vec3{f32(control.x)*0.04,control.pulse?0.2:0,f32(control.z)*0.04}
   if status=b.body_apply_impulse(player,impulse);status!=.Ok{_=p.require(&rt.physics,status);return}
   side.controls_applied[i]+=1;if control.pulse{side.pulses[i]+=1}
  }
 }
 side.tick=tick
}
model_settle :: proc(user:rawptr,tick:u64){
 rt:=cast(^Demo)user;side:=p.state(&rt.physics);events,error:=p.sensor_observations(&rt.physics)
 if error!=.Ok{k.lane_world_fail(&rt.lane,error);return}
 for event in events.events[:events.count]{if event.began!=0{side.sensor_begins+=1}else{side.sensor_ends+=1}}
 world,world_error:=p.world(&rt.physics);if world_error!=.Ok{k.lane_world_fail(&rt.lane,world_error);return}
 player,status:=b.body_resolve(world,side.player);if status!=.Ok{_=p.require(&rt.physics,status);return}
 pose,pose_status:=b.body_get_pose(player);if pose_status!=.Ok{_=p.require(&rt.physics,pose_status);return}
 hits:[b.MOTION_MAX_HITS]b.Motion_Hit
 count,qe:=p.motion_ray(&rt.physics,{pose.position.x,pose.position.y+0.5,pose.position.z},{0,-3,0},b.Motion_Filter{category_bits=1,mask_bits=max(u64),exclude_body=side.player,include_sensors=1},hits[:])
 if qe!=.Ok{k.lane_world_fail(&rt.lane,qe);return};side.query_last=count;side.query_total+=u64(count)
 for &proxy,i in rt.proxies[:rt.body_count]{
  body,bs:=b.body_resolve(world,rt.built.bodies[i].key);if bs!=.Ok{_=p.require(&rt.physics,bs);return}
  proxy.pose,bs=b.body_get_pose(body);proxy.tick=tick;if bs!=.Ok{_=p.require(&rt.physics,bs);return}
 }
}

model_create :: proc(rt:^Demo)->bool{
 if !rt.ses.joined{return false}
 roster:=s_roster(rt);if !roster{return false}
 k.lane_init(&rt.lane,&rt.ses,size_of(Control),cfg={slots=128,snap_every=3},allocator=rt.allocator)
 rt.lane_ready=true;k.lane_set_sim(&rt.lane,rt,sample_control,model_step)
 k.lane_class_set_type(&rt.lane,0,Control);k.lane_class_set_validate(&rt.lane,0,validate_control)
 @(static) fields:=[]n.Field_Desc{{offset=offset_of(Proxy,pose),size=size_of(b.Pose),name="pose",flags={.Predicted}},{offset=offset_of(Proxy,tick),size=8,name="tick",flags={.Predicted}}}
 rt.descriptor={fields=fields};types:[35]k.World_Field_Type
 initial:=Side{players={u16(rt.players[0]),u16(rt.players[1])}}
 for body,i in rt.baked.data.bodies{
  rt.proxies[i]={pose=body.definition.pose};k.lane_track(&rt.lane,n.Net_Id(i+1),&rt.proxies[i],&rt.descriptor,rt.ses.me);types[i]=k.world_field_type(n.Net_Id(i+1),Proxy)
  if body.stable_key=="player"{initial.player=rt.built.bodies[i].key}
  if body.stable_key=="pendulum"{initial.pendulum=rt.built.bodies[i].key}
 }
 if len(rt.built.joints)==1{initial.hinge=rt.built.joints[0].key}
 if initial.player==0||initial.pendulum==0||initial.hinge==0{fail(rt,"authored.required_keys",.Invalid);return false}
 cfg:=p.sdk_context_config(rt.sdk,0,provider=rt.owners[1],author=rt.owners[0],effects=rt.owners[0])
 error:=p.authoring_attach(&rt.physics,&rt.lane,&rt.built,initial,types[:rt.body_count],cfg,model_settle)
 if error!=.Ok{fail(rt,"authoring_attach",error);return false}
 if error=p.codec_init(&rt.controls,allocator=rt.allocator,ownership=rt.owners[3]);error!=.Ok{fail(rt,"control.codec",error);return false}
 if error=p.codec_init(&rt.proxy_codec,&rt.descriptor,rt.allocator,ownership=rt.owners[4]);error!=.Ok{fail(rt,"proxy.codec",error);return false}
 wire_fields:[35]k.World_Wire_Field;for &field,i in wire_fields[:rt.body_count]{field={n.Net_Id(i+1),rt.proxy_codec.value}}
 // Neutral prevents a missing control from turning one pulse into a new pulse.
 inputs:=[]k.World_Wire_Input{{0,rt.controls.value,.Neutral}}
 drivers:=[2]k.World_Driver{{rt.players[0],0},{rt.players[1],0}}
 error=p.network_attach(&rt.network,&rt.physics,&rt.built.catalog,wire_fields[:rt.body_count],inputs,drivers[:],nil,rt.rules,ownership=rt.owners[2])
 if error!=.Ok{fail(rt,"network_attach",error);return false}
 rt.model_ready=true;return true
}
