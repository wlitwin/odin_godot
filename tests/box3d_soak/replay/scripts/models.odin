// Two declared test workloads. No sibling runtime, timeline or wire implementation.
package replay_gate_b_probe

import b "godot:box3d"
import bd "godot:box3d/diagnostics"
import r "godot:replay"
import ph "godot:replay/physics"
import net "godot:replay/net"
import dense "godot:tests/replay_physics_net/fixture"
import common "godot:examples/box3d_common"
import adapter "godot:examples/replay_box3d/shared/adapter"

Fixture :: enum {Dense,Common}
dense_ops :: proc(execution:^r.Execution)->dense.Operations{return {
 execution=execution,
 impulse=proc(p:rawptr,key:b.Body_Key,v:b.Vec3)->bool{return ph.body_impulse((cast(^r.Execution)p)^,key,v)==.None},
 spawn=proc(p:rawptr,position:b.Vec3)->(b.Body_Key,bool){def:=b.body_def_default();def.type=.Dynamic;def.pose.position=position;key,error:=ph.spawn((cast(^r.Execution)p)^,4,def);return key,error==.None},
 remove=proc(p:rawptr,key:b.Body_Key)->bool{return ph.body_destroy((cast(^r.Execution)p)^,key)==.None},
 motor=proc(p:rawptr,key:b.Joint_Key,speed:f32)->bool{return ph.hinge_motor((cast(^r.Execution)p)^,key,true,speed,2)==.None},
 step=proc(p:rawptr)->bool{return ph.step((cast(^r.Execution)p)^)==.None},
 observations=proc(p:rawptr,out:[]dense.Observation)->(int,bool){events:[70]ph.Sensor_Event;count,error:=ph.sensor_events((cast(^r.Execution)p)^,events[:]);if error!=.None || int(count)>len(out){return 0,false};for event,index in events[:count]{out[index]={event.sensor,event.visitor,event.began}};return int(count),true},
}}
dense_step :: proc(game:^dense.Game,controls:[2]dense.Control,joins,leaves:u64,ctx:^r.Step(dense.Event)){
 execution:=ctx.execution;events:[70]dense.Event
 count,ok:=dense.advance(game,controls,dense_ops(&execution),events[:]);if !ok{r.abort(ctx);return}
 for event in events[:count]{r.emit(ctx,u64(event.source),event.key,event)}
}
dense_action :: proc(game:^dense.Game,seat:u16,value:dense.Action,ctx:^r.Step(dense.Event))->bool{execution:=ctx.execution;return dense.apply_action(game,seat,value,dense_ops(&execution))}
dense_model :: proc(codec:^ph.Network_Codec(dense.Game,dense.Control,dense.Action,dense.Event,2))->net.Model(dense.Game,dense.Control,dense.Action,dense.Event,2){return {
 complete_state=true,complete_codec=codec.value,step=dense_step,action=dense_action,control_valid=dense.control_valid,action_valid=dense.action_valid,hold=dense.hold,state_valid=proc(game:dense.Game)->bool{return game.initial>=2&&game.initial<=32},
}}
// Geometry matches the original reference profile; runtime/body differences must
// still be measured rather than asserting historical141 contacts as observed.
dense_catalog :: proc()->(b.Recovery_Catalog,b.Status){
 cfg:=b.recovery_config_default();cfg.profile=dense.PROFILE
 assets:[4]b.Recovery_Asset;for asset,index in dense.assets(){assets[index]={id=asset.id,kind=b.Recovery_Asset_Kind(asset.kind),a=asset.a,b=asset.b,radius=asset.radius}}
 return b.recovery_catalog_create(cfg,assets[:])
}
dense_config :: proc(catalog:^b.Recovery_Catalog)->ph.Config{
 id,status:=b.recovery_catalog_identity(catalog);assert(status==.Ok);build:u64;for byte,index in id.build_target[:8]{build|=u64(byte)<<uint(index*8)}
 config:=ph.config_default(dense.ASSET_DECLARATION,build);config.initial_dynamic_bodies=32;config.assets[0].id=3;config.assets[1].id=4;return config
}
dense_rules :: proc()->bd.Digest{
 fixture:=dense.game_rules();callbacks:=bd.hash_bytes(transmute([]u8)#load("models.odin"))
 result,error:=bd.hash_descriptors("gate-b.replay.dense-reference.v1",[]bd.Descriptor{{tag="callbacks",bytes=callbacks[:]},{tag="fixture",bytes=fixture[:]}});assert(error==.None);return result
}
common_catalog :: proc()->(b.Recovery_Catalog,b.Status){cfg:=b.recovery_config_default();cfg.profile=common.PROFILE;assets:=common.assets();return b.recovery_catalog_create(cfg,assets[:])}
observed_counts,observed_peak:b.World_Counters
observe_step :: proc(execution:r.Execution){
 value,error:=ph.observe(execution);if error!=.None{return};observed_counts=value.counts
 observed_peak.body_count=max(observed_peak.body_count,value.counts.body_count);observed_peak.shape_count=max(observed_peak.shape_count,value.counts.shape_count)
 observed_peak.contact_count=max(observed_peak.contact_count,value.counts.contact_count);observed_peak.joint_count=max(observed_peak.joint_count,value.counts.joint_count)
}
dense_observed :: proc(game:^dense.Game,controls:[2]dense.Control,joins,leaves:u64,ctx:^r.Step(dense.Event)){dense_step(game,controls,joins,leaves,ctx);observe_step(ctx.execution)}
common_observed :: proc(game:^common.Game,controls:[2]common.Control,joins,leaves:u64,ctx:^r.Step(common.Event)){adapter.step(game,controls,joins,leaves,ctx);observe_step(ctx.execution)}
dense_stimulus :: proc(s:^net.Server(dense.Game,dense.Control,dense.Action,dense.Event,2),tick:u64)->bool{
 if tick==40 || tick==41 || tick==95 || tick==115{_,error:=net.server_issue(s,dense.Action{kind=tick==95?.Remove:tick==115?.Motor:.Spawn});if error!=.None{return false}}
 return net.server_local(s,dense.Control{x=tick%2==0?10:-10})==.None
}
common_stimulus :: proc(s:^net.Server(common.Game,common.Control,common.Action,common.Event,2),tick:u64)->bool{
 // Explicit offline local-seat trajectory; remote held0 is part of descriptor.
 // The independent live two-player ENet soak remains Root-owned.
 action:=common.scripted_action(tick,1)
 if action.kind!=.None{_,error:=net.server_issue(s,action);if error!=.None{return false}}
 return net.server_local(s,common.scripted_control(tick,1))==.None
}
