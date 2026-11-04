// Shared gameplay and immutable primitive profile. This package owns no
// Timeline, Lane, Session, transport, presentation or rollback mechanism.
package box3d_common

import b "godot:box3d"
import bd "godot:box3d/diagnostics"

PROFILE :: u64(0x534c494345503031)
ASSET_DECLARATION :: u64(0x534c494345413031)
SEATS :: 2
MAX_DYNAMIC :: 33
FLOOR_ASSET :: u32(1)
SENSOR_ASSET :: u32(2)
CRATE_ASSET :: u32(3)
PLAYER_ASSET :: u32(4)
SPAWN_ASSET :: u32(5)
// Default Box3D density is 1000 kg/m³: a radius .25 player is about65 kg.
// Full input applies10 N·s per60 Hz tick; the same scale is used by both adapters.
CONTROL_IMPULSE_SCALE :: f32(0.1)

Control :: struct {x,z:i16}
Action_Kind :: enum u8 {None,Spawn,Remove,Motor,Sleep,Wake,Query}
Action :: struct {kind:Action_Kind}
Event_Kind :: enum u8 {Sensor_Begin,Sensor_End,Spawn,Remove,Motor,Sleep,Wake,Query}
Event :: struct {serial,lifetime:u64,seat:u16,kind:Event_Kind}
Observation :: struct {sensor,visitor:b.Shape_Key,began:bool}
Retired :: struct {shape:b.Shape_Key,lifetime,tick:u64}
Game :: struct {
	tick,next_lifetime,next_event,births,deaths,begins,ends,sleeps,wakes,motor_changes,queries:u64,
	rng,initial:u32,
	bodies:[MAX_DYNAMIC]b.Body_Key,
	shapes:[MAX_DYNAMIC]b.Shape_Key,
	lifetimes:[MAX_DYNAMIC]u64,
	alive:[MAX_DYNAMIC]bool,
	floor,sensor:b.Body_Key,
	sensor_shape:b.Shape_Key,
	joint:b.Joint_Key,
	retired:[8]Retired,
	retired_count:u32,
}

// Borrowed only for the current staged callback. Adapters use their existing
// execution capability and must poison that candidate on native/resource error.
// None of these callbacks may retain user or step the world.
Operations :: struct {
	user:rawptr,
	impulse:proc(rawptr,b.Body_Key,b.Vec3)->bool,
	spawn:proc(rawptr,u32,b.Body_Def)->(b.Body_Key,b.Shape_Key,bool),
	remove:proc(rawptr,b.Body_Key)->bool,
	motor:proc(rawptr,b.Joint_Key,f32)->bool,
	awake:proc(rawptr,b.Body_Key,bool)->bool,
	query:proc(rawptr,b.Body_Key)->(u32,bool),
}

assets :: proc()->[5]b.Recovery_Asset {return {
	b.recovery_asset_box(FLOOR_ASSET,{7,1,7}),
	b.recovery_asset_box(SENSOR_ASSET,{1.5,1,1.5}),
	b.recovery_asset_box(CRATE_ASSET,{0.25,0.25,0.25}),
	b.recovery_asset_sphere(PLAYER_ASSET,{},0.25),
	b.recovery_asset_capsule(SPAWN_ASSET,{0,-0.2,0},{0,0.2,0},0.2),
}}

// The model source includes every immutable gameplay/geometry parameter above.
// Adapters also bind their actual schemas, native target and provider config.
game_rules :: proc()->bd.Digest {return bd.hash_bytes(transmute([]u8)#load("rules.odin"))}
control_valid :: proc(value:Control)->bool{return value.x>=-100 && value.x<=100 && value.z>=-100 && value.z<=100}
action_valid :: proc(value:Action)->bool{return value.kind<=.Query}

// Pure structural/safety contract for the fixed arrays consumed below. Keys
// remain opaque typed values: Native existence/content is a separate boundary.
// Counter totals are observations, not arbitrary new gameplay/admission caps.
game_valid :: proc(value:Game)->bool {
	if (value.initial!=4 && value.initial!=32) || value.retired_count>u32(len(value.retired)) {return false}
	if value.rng==0 || value.next_event==0 || value.next_lifetime<=u64(value.initial) {return false}
	if value.floor==0 || value.sensor==0 || value.floor==value.sensor || value.sensor_shape==0 || value.joint==0 {return false}
	slot:=int(value.initial)
	for i in 0..<MAX_DYNAMIC {
		body,shape,life,alive:=value.bodies[i],value.shapes[i],value.lifetimes[i],value.alive[i]
		if i<slot {
			if !alive || life!=u64(i)+1 {return false}
		} else if i==slot {
			// Remove clears both keys, but intentionally keeps the last lifetime
			// even after its retirement entry expires on a later post_step.
			if life!=0 && (life<=u64(value.initial) || life>=value.next_lifetime) {return false}
			if alive && life==0 {return false}
		} else if alive || body!=0 || shape!=0 || life!=0 {return false}
		if alive {
			if body==0 || shape==0 || life==0 || life>=value.next_lifetime ||
			   body==value.floor || body==value.sensor || shape==value.sensor_shape {return false}
			for j in 0..<i {
				if value.alive[j] && (body==value.bodies[j] || shape==value.shapes[j] || life==value.lifetimes[j]) {return false}
			}
		} else if body!=0 || shape!=0 {return false}
	}
	for i in 0..<int(value.retired_count) {
		retired:=value.retired[i]
		if retired.shape==0 || retired.shape==value.sensor_shape || retired.lifetime<=u64(value.initial) ||
		   retired.lifetime>=value.next_lifetime || retired.lifetime>value.lifetimes[slot] || retired.tick>value.tick {return false}
		for shape,j in value.shapes {
			if value.alive[j] && (retired.shape==shape || retired.lifetime==value.lifetimes[j]) {return false}
		}
		for j in 0..<i {
			prior:=value.retired[j]
			if retired.shape==prior.shape || retired.lifetime==prior.lifetime {return false}
		}
	}
	return true
}

world :: proc(initial:u32=4,seed:u32=1)->(world:b.World,game:Game,status:b.Status) {
	if (initial!=4 && initial!=32) || seed==0{return 0,{},.Invalid_Argument}
	world,status=b.world_create(b.world_def_default());if status!=.Ok{return}
	created:=world;committed:=false;defer if !committed{b.world_destroy(&created);world=0;game={}}
	game={initial=initial,rng=seed,next_lifetime=u64(initial)+1,next_event=1,births=u64(initial)}
	def:=b.body_def_default();def.pose.position={0,-1,0}
	floor,fs:=b.body_create(world,def);if fs!=.Ok{return 0,{},fs}
	_,floor_status:=b.shape_box(floor,b.shape_def_default(),{7,1,7});if floor_status!=.Ok{return 0,{},floor_status}
	game.floor,status=b.body_key(floor);if status!=.Ok{return}
	def.pose.position={0,1,0}
	sensor,ss:=b.body_create(world,def);if ss!=.Ok{return 0,{},ss}
	shape:=b.shape_def_default();shape.is_sensor=1;shape.enable_sensor_events=1
	sensor_shape,sensor_status:=b.shape_box(sensor,shape,{1.5,1,1.5});if sensor_status!=.Ok{return 0,{},sensor_status}
	game.sensor,status=b.body_key(sensor);if status!=.Ok{return}
	game.sensor_shape,status=b.shape_key(sensor_shape);if status!=.Ok{return}
	for i in 0..<int(initial) {
		body_def:=b.body_def_default();body_def.type=.Dynamic;body_def.linear_damping=0.5
		switch i {
		case 0:body_def.pose.position={-0.6,0.45,0}
		case 1:body_def.pose.position={0.6,0.45,0}
		case 2:body_def.pose.position={0,0.45,0}
		case 3:body_def.pose.position={-1.2,0.45,-1.2}
		case:j:=i-4;body_def.pose.position={2+f32(j%5)*0.6,0.45+f32(j/25)*0.55,f32(j/5%5-2)*0.6}
		}
		body,bs:=b.body_create(world,body_def);if bs!=.Ok{return 0,{},bs}
		shape_def:=b.shape_def_default();shape_def.enable_sensor_events=1
		body_shape:b.Shape
		if i<2 {body_shape,status=b.shape_sphere(body,shape_def,0.25)} else {body_shape,status=b.shape_box(body,shape_def,{0.25,0.25,0.25})}
		if status!=.Ok{return}
		game.bodies[i],status=b.body_key(body);if status!=.Ok{return}
		game.shapes[i],status=b.shape_key(body_shape);if status!=.Ok{return}
		game.lifetimes[i]=u64(i)+1;game.alive[i]=true
	}
	hinge:=b.hinge_def_default();hinge.body_a=floor
	hinge.body_b,status=b.body_resolve(world,game.bodies[3]);if status!=.Ok{return}
	hinge.local_frame_a.position={-1.2,1.45,-1.2};hinge.enable_limit=1;hinge.lower_angle=-0.5;hinge.upper_angle=0.5
	hinge.enable_motor=1;hinge.max_motor_torque=2
	joint,js:=b.joint_hinge_create(world,hinge);if js!=.Ok{return 0,{},js}
	game.joint,status=b.joint_key(joint);if status!=.Ok{return}
	committed=true;return
}

// Model.step phase, before the one existing framework fixed step. Network
// actions run AFTER post_step, matching Replay's existing Model.action order.
pre_step :: proc(game:^Game,controls:[SEATS]Control,ops:Operations)->bool {
	for control in controls {if !control_valid(control){return false}}
	if game.tick==max(u64){return false}
	game.tick+=1;x:=game.rng;x~=x<<13;x~=x>>17;x~=x<<5;game.rng=x
	for control,seat in controls {
		if control.x!=0 || control.z!=0 {
			if ops.impulse==nil || !ops.impulse(ops.user,game.bodies[seat],{f32(control.x)*CONTROL_IMPULSE_SCALE,0,f32(control.z)*CONTROL_IMPULSE_SCALE}){return false}
		}
	}
	return true
}

event_make :: proc(game:^Game,kind:Event_Kind,lifetime:u64,seat:u16=0)->Event {
	result:=Event{serial=game.next_event,lifetime=lifetime,seat=seat,kind=kind};game.next_event+=1;return result
}
lifetime_for_shape :: proc(game:^Game,key:b.Shape_Key)->u64 {
	for shape,i in game.shapes {if game.alive[i] && shape==key{return game.lifetimes[i]}}
	for retired in game.retired[:game.retired_count] {if retired.shape==key{return retired.lifetime}}
	return 0
}
post_step :: proc(game:^Game,observations:[]Observation,out:[]Event)->(count:int,ok:bool) {
	if len(observations)>len(out) || u64(len(observations))>max(u64)-game.next_event{return 0,false}
	for observation in observations {
		if observation.sensor!=game.sensor_shape{return 0,false}
		life:=lifetime_for_shape(game,observation.visitor);if life==0{return 0,false}
		if observation.began{game.begins+=1}else{game.ends+=1}
		out[count]=event_make(game,observation.began?.Sensor_Begin:.Sensor_End,life);count+=1
	}
	kept:=u32(0)
	for retired in game.retired[:game.retired_count] {if retired.tick>=game.tick{game.retired[kept]=retired;kept+=1}}
	for i in int(kept)..<len(game.retired){game.retired[i]={}}
	game.retired_count=kept
	return count,true
}

// Called after the fixed step/sensor outputs, in semantic seat order. A false
// gameplay predicate performs no native operation or Game mutation. Native
// callback failure requires the adapter's existing candidate-abort path.
apply_action :: proc(game:^Game,seat:u16,action:Action,ops:Operations)->(event:Event,applied:bool) {
	if seat<1 || seat>SEATS || !action_valid(action) || game.next_event==max(u64){return {},false}
	slot:=int(game.initial)
	#partial switch action.kind {
	case .None:return {},true
	case .Spawn:
		if game.alive[slot] || ops.spawn==nil || game.next_lifetime==max(u64){return {},false}
		def:=b.body_def_default();def.type=.Dynamic;def.pose.position={0.1,1.2,0.1}
		body,shape,ok:=ops.spawn(ops.user,SPAWN_ASSET,def);if !ok{return {},false}
		game.bodies[slot]=body;game.shapes[slot]=shape;game.alive[slot]=true;game.lifetimes[slot]=game.next_lifetime;game.next_lifetime+=1;game.births+=1
		event=event_make(game,.Spawn,game.lifetimes[slot],seat)
	case .Remove:
		if !game.alive[slot] || game.retired_count==u32(len(game.retired)) || ops.remove==nil{return {},false}
		if !ops.remove(ops.user,game.bodies[slot]){return {},false}
		game.retired[game.retired_count]={game.shapes[slot],game.lifetimes[slot],game.tick};game.retired_count+=1
		game.alive[slot]=false;game.bodies[slot]=0;game.shapes[slot]=0;game.deaths+=1
		event=event_make(game,.Remove,game.lifetimes[slot],seat)
	case .Motor:
		if ops.motor==nil || !ops.motor(ops.user,game.joint,seat==1?0.5:-0.5){return {},false};game.motor_changes+=1;event=event_make(game,.Motor,game.lifetimes[3],seat)
	case .Sleep,.Wake:
		awake:=action.kind==.Wake
		if ops.awake==nil || !ops.awake(ops.user,game.bodies[2],awake){return {},false}
		if awake{game.wakes+=1}else{game.sleeps+=1};event=event_make(game,awake?.Wake:.Sleep,game.lifetimes[2],seat)
	case .Query:
		if ops.query==nil{return {},false};hits,ok:=ops.query(ops.user,game.bodies[seat-1]);if !ok{return {},false};game.queries+=u64(hits);event=event_make(game,.Query,game.lifetimes[seat-1],seat)
	}
	return event,true
}

// Reproducible intent, sampled outside simulation in the headless examples.
scripted_control :: proc(tick:u64,seat:u16)->Control {
	phase:=tick%240;direction:=i16(1);if seat==2{direction=-1}
	if phase<80{return {25*direction,0}};if phase<160{return {-25*direction,0}};return {}
}
scripted_action :: proc(tick:u64,seat:u16)->Action {
	switch tick%240 {
	case 40:return {.Spawn} // simultaneous Spawn proves one accepted/one rejected predicate
	case 56:if seat==1{return {.Remove}}
	case 80:if seat==1{return {.Motor}}
	case 120:if seat==1{return {.Sleep}}
	case 136:if seat==1{return {.Wake}}
	case 160:if seat==2{return {.Query}}
	}
	return {}
}
