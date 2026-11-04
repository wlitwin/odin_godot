package replay_authoring_demo

import b "godot:box3d"
import a "godot:box3d/authoring"
import bd "godot:box3d/diagnostics"
import bp "godot:box3d/presentation"
import r "godot:replay"
import ph "godot:replay/physics"
import net "godot:replay/net"

PROFILE :: u64(0x4155544853414d31)
BODY_NAMES :: [4]string{"ground","pendulum","player","sensor"}
Control :: struct {x,z:i16,pulse:bool}
Action :: struct {unused:bool}
Event :: struct {seat:u16,kind:u8,count:u32}
Game :: struct {
 tick:u64,
 logical:[4]u64,
 bodies:[4]b.Body_Key,
 assets:[4]u32,
 joint:b.Joint_Key,
 queries:u32,
 sensor_events,pulses:u64,
}
Codec :: ph.Network_Codec(Game,Control,Action,Event,2)

initial_game :: proc(scene:^a.Baked_Scene,built:^a.Built_Scene)->(Game,bool){
 if len(scene.data.bodies)!=4||len(scene.data.shapes)!=4||len(scene.data.joints)!=1{return {},false}
 game:Game
 for name,i in BODY_NAMES{
  for body in scene.data.bodies{if body.stable_key==name{game.logical[i]=body.logical_id;break}}
  if game.logical[i]==0{return {},false}
  for mapping in built.bodies{if mapping.logical_id==game.logical[i]{game.bodies[i]=mapping.key;break}}
  for shape in scene.data.shapes{if shape.body_id==game.logical[i]{game.assets[i]=shape.asset_id;break}}
  if game.bodies[i]==0||game.assets[i]==0{return {},false}
 }
 game.joint=built.joints[0].key;return game,game.joint!=0
}
control_valid :: proc(value:Control)->bool{return value.x>=-1&&value.x<=1&&value.z>=-1&&value.z<=1}
scripted_control :: proc(tick:u64,seat:u16)->Control{
 sign:=i16((tick/60)%2==0?1:-1)
 return {x=seat==1?sign:0,z=seat==2?sign:0,pulse=tick%45==0}
}
model_step :: proc(game:^Game,controls:[2]Control,_,_:u64,ctx:^r.Step(Event)){
 for value,seat in controls{
  if !control_valid(value){r.abort(ctx);return}
  impulse:=b.Vec3{f32(value.x)*0.04,value.pulse?0.2:0,f32(value.z)*0.04}
  if ph.body_impulse(ctx.execution,game.bodies[2],impulse)!=.None{r.abort(ctx);return}
  if value.pulse{game.pulses+=1;r.emit(ctx,1,u64(seat+1),Event{u16(seat+1),1,1})}
 }
 if ph.step(ctx.execution)!=.None{r.abort(ctx);return}
 pose,pe:=ph.body_pose(ctx.execution,game.bodies[2]);if pe!=.None{r.abort(ctx);return}
 hits:[b.MOTION_MAX_HITS]b.Motion_Hit
 count,qe:=ph.motion_ray(ctx.execution,{pose.position.x,pose.position.y+1,pose.position.z},{0,-3,0},{category_bits=1,mask_bits=max(u64),exclude_body=game.bodies[2]},hits[:])
 if qe!=.None{r.execution_fail(ctx.execution,qe);r.abort(ctx);return};game.queries=count
 events:[70]ph.Sensor_Event;sensor_count,se:=ph.sensor_events(ctx.execution,events[:]);if se!=.None{r.abort(ctx);return}
 game.sensor_events+=u64(sensor_count)
 for event,index in events[:sensor_count]{r.emit(ctx,2,u64(index+1),Event{0,event.began?u8(2):u8(3),1})}
 game.tick=ctx.tick
}
model :: proc(codec:^Codec)->net.Model(Game,Control,Action,Event,2){return {
 complete_state=true,complete_codec=codec.value,step=model_step,
 action=proc(_: ^Game,_:u16,_:Action,_:^r.Step(Event))->bool{return false},
 control_valid=control_valid,action_valid=proc(_:Action)->bool{return false},
 state_valid=proc(game:Game)->bool{for key,i in game.bodies{if key==0||game.logical[i]==0||game.assets[i]==0{return false}};return game.joint!=0},
 hold=proc(_:Control)->Control{return {}}, // missing/Held never reissues pulse
 event_owner=proc(value:Event)->u16{return value.seat},
}}
rules :: proc()->bd.Digest{return bd.hash_bytes(transmute([]u8)#load("model.odin"))}
project :: proc(game:Game,out:[]bp.Binding)->(u32,bp.Error){
 if len(out)<4{return 4,.Capacity}
 for key,i in game.bodies{out[i]={id={game.logical[i],1},body=bp.Body_Key(key),asset=game.assets[i],alive=true}}
 return 4,.None
}
