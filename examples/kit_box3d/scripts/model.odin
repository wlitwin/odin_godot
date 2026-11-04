package kit_box3d

import b "godot:box3d"
import common "godot:examples/box3d_common"
import p "godot:kit/physics"
import k "godot:kit/sim"

Receipt :: struct {tick:u64,kind:common.Action_Kind,applied:bool}
Side :: struct {game:common.Game,players:[2]u16,receipts:[2]Receipt}
Proxy :: struct {pose:b.Pose,lifetime:u64,alive:bool}
Stamped_Event :: struct {epoch,tick:u64,value:common.Event}
FX_Sink :: struct {observed:[8192]Stamped_Event,count:u32,delivered:[8192]u64,delivered_count:u32}

sample_control :: proc(user:rawptr,tick:u64,out:rawptr) {
 rt:=cast(^Runtime)user
 value:=common.Control{}
 if rt.seat!=0 {if rt.scripted {value=common.scripted_control(tick,rt.seat)}else{value=rt.control}}
 (cast(^common.Control)out)^=value
}
sample_action :: proc(user:rawptr,tick:u64,out:rawptr) {
 rt:=cast(^Runtime)user;value:=common.Action{}
 if rt.seat!=0 {if rt.scripted {value=intent_sample(rt,tick)}else{value=rt.action;rt.action={}}}
 (cast(^common.Action)out)^=value
}
validate_control :: proc(_:rawptr,value:rawptr)->bool {return common.control_valid((cast(^common.Control)value)^)}
validate_action :: proc(_:rawptr,value:rawptr)->bool {return common.action_valid((cast(^common.Action)value)^)}
side_valid :: proc(value:Side)->bool {return common.game_valid(value.game)}
native_ok :: proc(rt:^Runtime,status:b.Status)->bool {
 if status==.Ok {return true};rt.native_failed=true;_=p.require(&rt.physics,status);return false
}
ops :: proc(rt:^Runtime)->common.Operations {
 return {user=rt,
  impulse=proc(user:rawptr,key:b.Body_Key,impulse:b.Vec3)->bool {rt:=cast(^Runtime)user;w,e:=p.world(&rt.physics);if e!=.Ok {return false};body,s:=b.body_resolve(w,key);return native_ok(rt,s)&&native_ok(rt,b.body_apply_impulse(body,impulse))},
  spawn=proc(user:rawptr,asset:u32,def:b.Body_Def)->(b.Body_Key,b.Shape_Key,bool) {
   rt:=cast(^Runtime)user;w,e:=p.world(&rt.physics);if e!=.Ok {return 0,0,false}
   body,status:=b.body_create(w,def);if !native_ok(rt,status) {return 0,0,false}
   shape_def:=b.shape_def_default();shape_def.enable_sensor_events=1
   if asset!=common.SPAWN_ASSET {rt.native_failed=true;k.lane_world_fail(&rt.lane,.Unsupported);_=b.body_destroy(&body);return 0,0,false}
   shape,ss:=b.shape_capsule(body,shape_def,{0,-.2,0},{0,.2,0},.2)
   if !native_ok(rt,ss) {_=b.body_destroy(&body);return 0,0,false}
   key,ks:=b.body_key(body);shape_key,sks:=b.shape_key(shape)
   return key,shape_key,native_ok(rt,ks)&&native_ok(rt,sks)
  },
  remove=proc(user:rawptr,key:b.Body_Key)->bool {rt:=cast(^Runtime)user;w,_:=p.world(&rt.physics);body,s:=b.body_resolve(w,key);return native_ok(rt,s)&&native_ok(rt,b.body_destroy(&body))},
  motor=proc(user:rawptr,key:b.Joint_Key,speed:f32)->bool {rt:=cast(^Runtime)user;w,_:=p.world(&rt.physics);joint,s:=b.joint_resolve(w,key);return native_ok(rt,s)&&native_ok(rt,b.joint_hinge_set_motor(joint,true,speed,2))},
  awake=proc(user:rawptr,key:b.Body_Key,awake:bool)->bool {rt:=cast(^Runtime)user;w,_:=p.world(&rt.physics);body,s:=b.body_resolve(w,key);return native_ok(rt,s)&&native_ok(rt,b.body_set_awake(body,awake))},
  query=proc(user:rawptr,key:b.Body_Key)->(u32,bool) {rt:=cast(^Runtime)user;w,_:=p.world(&rt.physics);body,s:=b.body_resolve(w,key);if !native_ok(rt,s) {return 0,false};pose,ps:=b.body_get_pose(body);if !native_ok(rt,ps) {return 0,false};hits:[35]b.Ray_Hit;count,qs:=b.query_ray(w,b.Vec3{pose.position.x,pose.position.y+.5,pose.position.z},b.Vec3{0,-2,0},b.QUERY_FILTER_ALL,hits[:]);return count,native_ok(rt,qs)},
 }
}
event_key :: proc(value:common.Event)->u64 {
 if value.serial>u64(max(u32)) || value.lifetime>0xffffff || value.seat>15 {return 0}
 return (value.serial<<32)|(value.lifetime<<8)|(u64(value.seat)<<4)|u64(value.kind)
}
record_effect :: proc(user:rawptr,tick,key:u64,args:[]u8) {
 sink:=cast(^FX_Sink)user
 if len(args)!=size_of(Stamped_Event) || sink.count>=u32(len(sink.observed)) {return}
 value:Stamped_Event;copy((cast([^]u8)&value)[:size_of(value)],args)
 sink.observed[sink.count]=value;sink.count+=1
}
emit :: proc(rt:^Runtime,tick:u64,value:common.Event) {
 if value.serial==0 {return}
 key:=event_key(value);if key==0 {k.lane_world_fail(&rt.lane,.Capacity);return}
 stamp:=Stamped_Event{epoch=k.lane_world_epoch(&rt.lane),tick=tick,value=value}
 if k.lane_world_emit(&rt.lane,key,record_effect,rt.sink,(cast([^]u8)&stamp)[:size_of(stamp)])!=.Ok {k.lane_world_fail(&rt.lane,.Rejected)}
}
model_step :: proc(user:rawptr,tick:u64) {
 rt:=cast(^Runtime)user;rt.actions={};rt.native_failed=false
 side:=p.state(&rt.physics);controls:[2]common.Control
 for player,i in rt.players {
  controls[i],_=k.lane_input_of(&rt.lane,player,common.Control)
  rt.actions[i],_=k.lane_input_of(&rt.lane,player,common.Action)
 }
 if !common.pre_step(&side.game,controls,ops(rt)) || side.game.tick!=tick {rt.actions={};k.lane_world_fail(&rt.lane,.Step_Failed)}
}
model_settle :: proc(user:rawptr,tick:u64) {
 rt:=cast(^Runtime)user;actions:=rt.actions;rt.actions={}
 side:=p.state(&rt.physics);observations,oe:=p.sensor_observations(&rt.physics)
 if oe!=.Ok {k.lane_world_fail(&rt.lane,oe);return}
 copied:[70]common.Observation
 if observations.count>u32(len(copied)) {k.lane_world_fail(&rt.lane,.Capacity);return}
 for value,i in observations.events[:observations.count] {copied[i]={sensor=value.sensor,visitor=value.visitor,began=value.began!=0}}
 events:[32]common.Event
 count,ok:=common.post_step(&side.game,copied[:observations.count],events[:])
 if !ok {k.lane_world_fail(&rt.lane,.Step_Failed);return}
 for value in events[:count] {emit(rt,tick,value)}
 for action,i in actions {
  event,applied:=common.apply_action(&side.game,u16(i+1),action,ops(rt))
  if rt.native_failed {k.lane_world_fail(&rt.lane,.Step_Failed);return}
  side.receipts[i]={tick=tick,kind=action.kind,applied=applied}
  if applied {emit(rt,tick,event)}
 }
 world,_:=p.world(&rt.physics)
 for &proxy,i in rt.proxies {
  proxy={alive=side.game.alive[i],lifetime=side.game.lifetimes[i]}
  if proxy.alive {body,bs:=b.body_resolve(world,side.game.bodies[i]);if !native_ok(rt,bs) {return};proxy.pose,bs=b.body_get_pose(body);if !native_ok(rt,bs) {return}}
 }
}
