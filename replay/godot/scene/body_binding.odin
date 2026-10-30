package replay_godot_scene

import replaygd "godot:replay/godot"

import "core:math"
import gd "godot:godot"
import own "godot:replay/owned"
import v "godot:replay/view"

Body_Frame :: struct {available:bool,error:own.Error}
// Explicitly distinct from cooperative Body2/Body3. World owns the pose and
// Godot's solver never publishes observations back through this binding.

Simulation_Body2 :: struct {body:Body2,scope:v.View_Scope,cut:u64,placed:bool}
simulation_body2_attach :: proc(p:^Simulation_Body2,body:gd.Physics_Body2d,kind:Body2_Kind,skin:gd.Node2d=nil)->bool {return body2_attach(&p.body,body,kind,skin)}
simulation_body2_destroy :: proc(p:^Simulation_Body2) {body2_suspend(&p.body);body2_destroy(&p.body);p^={}}
simulation_body2_present :: proc(p:^Simulation_Body2,scope:v.View_Scope,pose:v.Pose2,cut:u64=0)->own.Error {
    if !p.body.ready {return .Not_Ready}
    if scope.epoch==0 || (p.placed && scope.epoch<p.scope.epoch) {return .Invalid_Epoch}
    for x in pose.position {if math.is_nan(x) || math.is_inf(x) {return .Invalid_Value}}
    if math.is_nan(pose.angle) || math.is_inf(pose.angle) {return .Invalid_Value}
    value:=own.Pose2{position=pose.position,rotation=pose.angle}
    if p.body.kind==.Rigid {gd.rigid_body2d_set_freeze_enabled(cast(gd.Rigid_Body2d)p.body.body,true)}
    discontinuity:=!p.placed || p.scope!=scope || p.cut!=cut
    body2_place(&p.body,value,discontinuity)
    p.scope,p.cut,p.placed=scope,cut,true;return .None
}
// Select only from the latest authority frame. Presentation sampling never
// enables publication. Missing/fenced state suspends the body automatically.
session_body2_frame :: proc(s:^replaygd.Session($S,$C,$A,$E,$N),p:^Body2,dt:f64,
                            select_body:proc(rawptr,S)->(own.State(own.Pose2),bool),user:rawptr=nil,
                            eligible:bool=true,presentation:^own.State(own.Pose2)=nil)->Body_Frame {
    if !p.ready {return {error=.Not_Ready}}
    if select_body==nil || dt<0 || math.is_nan(dt) || math.is_inf(dt) {body2_suspend(p);return {error=.Invalid_Value}}
    frame,available:=replaygd.session_authority_state(s)
    if !available {body2_suspend(p,dt);return {}}
    state,found:=select_body(user,frame.state)
    if !found {body2_suspend(p,dt);return {}}
    epoch:=s.authority ? s.server.cfg.epoch : s.client.cfg.epoch
    error:=body2_sync(p,state,replaygd.session_seat(s),epoch,frame.tick,eligible && !s.clock.paused,dt,presentation)
    return {available=true,error=error}
}
// Call after frame binding and any local solver step. Recheck session fencing so
// a transport/recovery transition cannot publish a cached observation as new work.
session_body2_sample :: proc(s:^replaygd.Session($S,$C,$A,$E,$N),p:^Body2,physics_frame:u64)->(own.Sample(own.Pose2),own.Error) {
    if !p.ready {return {},.Not_Ready}
    epoch:=s.authority ? s.server.cfg.epoch : s.client.cfg.epoch
    if !s.ready || s.fenced || s.clock.paused || (!s.authority && s.client.phase!=.Running) || p.driver.epoch!=epoch {
        body2_suspend(p);return {},.None
    }
    return body2_sample(p,physics_frame)
}

Simulation_Body3 :: struct {body:Body3,scope:v.View_Scope,cut:u64,placed:bool}
simulation_body3_attach :: proc(p:^Simulation_Body3,body:gd.Physics_Body3d,kind:Body3_Kind,skin:gd.Node3d=nil)->bool {return body3_attach(&p.body,body,kind,skin)}
simulation_body3_destroy :: proc(p:^Simulation_Body3) {body3_suspend(&p.body);body3_destroy(&p.body);p^={}}
simulation_body3_present :: proc(p:^Simulation_Body3,scope:v.View_Scope,pose:v.Pose3,cut:u64=0)->own.Error {
    if !p.body.ready {return .Not_Ready}
    if scope.epoch==0 || (p.placed && scope.epoch<p.scope.epoch) {return .Invalid_Epoch}
    for x in pose.position {if math.is_nan(x) || math.is_inf(x) {return .Invalid_Value}}
    norm:f64
    for q in pose.rotation {if math.is_nan(q) || math.is_inf(q) {return .Invalid_Value};norm+=f64(q)*f64(q)}
    if abs(norm-1)>0.001 {return .Invalid_Value}
    value:=own.Pose3{position=pose.position,rotation=pose.rotation}
    if p.body.kind==.Rigid {gd.rigid_body3d_set_freeze_enabled(cast(gd.Rigid_Body3d)p.body.body,true)}
    discontinuity:=!p.placed || p.scope!=scope || p.cut!=cut
    body3_place(&p.body,value,discontinuity)
    p.scope,p.cut,p.placed=scope,cut,true;return .None
}
// Select only from the latest authority frame. Presentation sampling never
// enables publication. Missing/fenced state suspends the body automatically.
session_body3_frame :: proc(s:^replaygd.Session($S,$C,$A,$E,$N),p:^Body3,dt:f64,
                            select_body:proc(rawptr,S)->(own.State(own.Pose3),bool),user:rawptr=nil,
                            eligible:bool=true,presentation:^own.State(own.Pose3)=nil)->Body_Frame {
    if !p.ready {return {error=.Not_Ready}}
    if select_body==nil || dt<0 || math.is_nan(dt) || math.is_inf(dt) {body3_suspend(p);return {error=.Invalid_Value}}
    frame,available:=replaygd.session_authority_state(s)
    if !available {body3_suspend(p,dt);return {}}
    state,found:=select_body(user,frame.state)
    if !found {body3_suspend(p,dt);return {}}
    epoch:=s.authority ? s.server.cfg.epoch : s.client.cfg.epoch
    error:=body3_sync(p,state,replaygd.session_seat(s),epoch,frame.tick,eligible && !s.clock.paused,dt,presentation)
    return {available=true,error=error}
}
// Call after frame binding and any local solver step. Recheck session fencing so
// a transport/recovery transition cannot publish a cached observation as new work.
session_body3_sample :: proc(s:^replaygd.Session($S,$C,$A,$E,$N),p:^Body3,physics_frame:u64)->(own.Sample(own.Pose3),own.Error) {
    if !p.ready {return {},.Not_Ready}
    epoch:=s.authority ? s.server.cfg.epoch : s.client.cfg.epoch
    if !s.ready || s.fenced || s.clock.paused || (!s.authority && s.client.phase!=.Running) || p.driver.epoch!=epoch {
        body3_suspend(p);return {},.None
    }
    return body3_sample(p,physics_frame)
}
