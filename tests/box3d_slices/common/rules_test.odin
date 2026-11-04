package common_rules_test

import "core:testing"
import "core:mem"
import b "godot:box3d"
import f "godot:examples/box3d_common"

Context :: struct {world:b.World,verified_sleep,verified_wake:u32}
operations :: proc(c:^Context)->f.Operations {
	return {user=c,
		impulse=proc(raw:rawptr,key:b.Body_Key,value:b.Vec3)->bool {c:=cast(^Context)raw;body,s:=b.body_resolve(c.world,key);return s==.Ok && b.body_apply_impulse(body,value)==.Ok},
		spawn=proc(raw:rawptr,asset:u32,def:b.Body_Def)->(b.Body_Key,b.Shape_Key,bool) {
			c:=cast(^Context)raw;if asset!=f.SPAWN_ASSET{return 0,0,false}
			body,s:=b.body_create(c.world,def);if s!=.Ok{return 0,0,false}
			shape_def:=b.shape_def_default();shape_def.enable_sensor_events=1
			shape,ss:=b.shape_capsule(body,shape_def,{0,-0.2,0},{0,0.2,0},0.2);if ss!=.Ok{return 0,0,false}
			key,ks:=b.body_key(body);shape_key,sks:=b.shape_key(shape);return key,shape_key,ks==.Ok && sks==.Ok
		},
		remove=proc(raw:rawptr,key:b.Body_Key)->bool {c:=cast(^Context)raw;body,s:=b.body_resolve(c.world,key);return s==.Ok && b.body_destroy(&body)==.Ok},
		motor=proc(raw:rawptr,key:b.Joint_Key,speed:f32)->bool {c:=cast(^Context)raw;joint,s:=b.joint_resolve(c.world,key);return s==.Ok && b.joint_hinge_set_motor(joint,true,speed,2)==.Ok},
		awake=proc(raw:rawptr,key:b.Body_Key,value:bool)->bool {
			c:=cast(^Context)raw;body,s:=b.body_resolve(c.world,key);if s!=.Ok || b.body_set_awake(body,value)!=.Ok{return false}
			actual,gs:=b.body_get_awake(body);if gs!=.Ok || actual!=value{return false};if value{c.verified_wake+=1}else{c.verified_sleep+=1};return true
		},
		query=proc(raw:rawptr,key:b.Body_Key)->(u32,bool) {
			c:=cast(^Context)raw;body,s:=b.body_resolve(c.world,key);if s!=.Ok{return 0,false};pose,ps:=b.body_get_pose(body);if ps!=.Ok{return 0,false}
			origin:=pose.position;origin.y+=0.5
			hits:[35]b.Ray_Hit;count,qs:=b.query_ray(c.world,origin,{0,-2,0},b.QUERY_FILTER_ALL,hits[:]);return count,qs==.Ok
		},
	}
}
tick :: proc(t:^testing.T,c:^Context,game:^f.Game)->(events:[32]f.Event,count:int) {
	controls:=[2]f.Control{f.scripted_control(game.tick+1,1),f.scripted_control(game.tick+1,2)}
	testing.expect(t,f.pre_step(game,controls,operations(c)))
	testing.expect_value(t,b.world_step_fixed(c.world),b.Status.Ok)
	raw:[70]b.Sensor_Event;available,s:=b.world_sensor_events(c.world,raw[:]);testing.expect_value(t,s,b.Status.Ok)
	observations:[70]f.Observation
	for item,i in raw[:available] {sensor,ss:=b.shape_key_from_handle(item.sensor);visitor,vs:=b.shape_key_from_handle(item.visitor);testing.expect_value(t,ss,b.Status.Ok);testing.expect_value(t,vs,b.Status.Ok);observations[i]={sensor,visitor,item.began!=0}}
	ok:bool;count,ok=f.post_step(game,observations[:available],events[:]);testing.expect(t,ok)
	for seat:=u16(1);seat<=2;seat+=1 {
		action:=f.scripted_action(game.tick,seat);if action.kind==.None{continue}
		event,applied:=f.apply_action(game,seat,action,operations(c))
		if game.tick%240==40 && seat==2 {testing.expect(t,!applied)} else {testing.expect(t,applied)}
		if applied && event.serial!=0{events[count]=event;count+=1}
	}
	return
}
dump :: proc(t:^testing.T,world:b.World)->[]u8 {
	snap,s:=b.snapshot_capture(world);testing.expect_value(t,s,b.Status.Ok);defer b.snapshot_destroy(&snap)
	required,qs:=b.snapshot_dump(&snap,nil);testing.expect_value(t,qs,b.Status.Ok);testing.expect(t,required>0)
	bytes:=make([]u8,int(required));_,ds:=b.snapshot_dump(&snap,bytes);testing.expect_value(t,ds,b.Status.Ok);return bytes
}

@(test)
shared_rules_lifecycle_and_canonical_pending_end :: proc(t:^testing.T) {
	cases:=[2]u32{4,32}
	for initial in cases {
		world,game,s:=f.world(initial,1);testing.expect_value(t,s,b.Status.Ok);source:=Context{world=world}
		catalog_config:=b.recovery_config_default();catalog_config.profile=f.PROFILE
		assets:=f.assets();catalog,cats:=b.recovery_catalog_create(catalog_config,assets[:]);testing.expect_value(t,cats,b.Status.Ok)
		for _ in 0..<56 {tick(t,&source,&game)}
		testing.expect_value(t,game.births,u64(initial)+1);testing.expect_value(t,game.deaths,u64(1))
		// Removal occurred after tick56's completed sensor output. Its end is
		// future native input plus a retained shape->game-lifetime tombstone.
		testing.expect_value(t,game.retired_count,u32(1))
		snapshot,ss:=b.snapshot_capture(source.world);testing.expect_value(t,ss,b.Status.Ok)
		required,qs:=b.recovery_write(&catalog,&snapshot,nil);testing.expect_value(t,qs,b.Status.Ok);testing.expect(t,required>0)
		wire:=make([]u8,int(required));_,ws:=b.recovery_write(&catalog,&snapshot,wire);testing.expect_value(t,ws,b.Status.Ok)
		decoded,rs:=b.recovery_read(&catalog,wire);testing.expect_value(t,rs,b.Status.Ok);delete(wire)
		branch_world,bs:=b.world_create(b.world_def_default());testing.expect_value(t,bs,b.Status.Ok)
		testing.expect_value(t,b.snapshot_restore(branch_world,&decoded),b.Status.Ok)
		b.snapshot_destroy(&decoded);b.snapshot_destroy(&snapshot);b.recovery_catalog_destroy(&catalog)
		branch:=Context{world=branch_world};branch_game:=game
		before_ends:=game.ends
		for i in 0..<184 {
			a,ac:=tick(t,&source,&game);v,vc:=tick(t,&branch,&branch_game)
			testing.expect_value(t,game,branch_game);testing.expect_value(t,ac,vc);for event,j in a[:ac]{testing.expect_value(t,event,v[j])}
			if i==0{testing.expect_value(t,game.ends,before_ends+1)}
			counts,counts_status:=b.world_counters(source.world);testing.expect_value(t,counts_status,b.Status.Ok)
			testing.expect(t,counts.body_count<=35 && counts.shape_count<=35 && counts.contact_count<=147 && counts.joint_count==1)
			left:=dump(t,source.world);right:=dump(t,branch.world);testing.expect(t,mem.compare(left,right)==0);delete(left);delete(right)
		}
		testing.expect(t,source.verified_sleep>0 && source.verified_wake>0 && game.queries>0 && game.motor_changes>0)
		b.world_destroy(&source.world);b.world_destroy(&branch.world)
	}
	engine,es:=b.engine_allocation_stats();owned,os:=b.snapshot_allocation_stats();testing.expect_value(t,es,b.Status.Ok);testing.expect_value(t,os,b.Status.Ok)
	testing.expect_value(t,engine.live_bytes,u64(0));testing.expect_value(t,owned.live_bytes,u64(0))
}
