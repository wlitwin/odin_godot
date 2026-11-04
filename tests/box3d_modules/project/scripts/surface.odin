package box3d_module_producer

import b "godot:box3d"
import gd "godot:godot"

// Exercise the runtime surface in an actual SDK producer, under its Core scope.
@(gd_method)
producer_surface :: proc(self:^Producer)->gd.Int {
	def:=b.world_def_default();def.gravity={0,0,0}
	world,status:=b.world_create(def);if status!=.Ok{return 1};defer b.world_destroy(&world)
	body_def:=b.body_def_default()
	sensor,bs:=b.body_create(world,body_def);if bs!=.Ok{return 2}
	shape_def:=b.shape_def_default();shape_def.is_sensor=1;shape_def.enable_sensor_events=1
	_,ss:=b.shape_box(sensor,shape_def,{1,1,1});if ss!=.Ok{return 3}
	anchor,as:=b.body_create(world,body_def);if as!=.Ok{return 4}
	body_def.type=.Dynamic
	visitor,vs:=b.body_create(world,body_def);if vs!=.Ok{return 5}
	shape_def.is_sensor=0
	_,sphere_status:=b.shape_sphere(visitor,shape_def,0.25);if sphere_status!=.Ok{return 6}
	body_def.pose.position={4,0,0}
	capsule,cs:=b.body_create(world,body_def);if cs!=.Ok{return 7}
	_,capsule_status:=b.shape_capsule(capsule,shape_def,{0,-0.25,0},{0,0.25,0},0.2);if capsule_status!=.Ok{return 8}
	hinge_def:=b.hinge_def_default();hinge_def.body_a=anchor;hinge_def.body_b=visitor
	hinge,hs:=b.joint_hinge_create(world,hinge_def);if hs!=.Ok{return 9}
	if b.joint_hinge_set_motor(hinge,true,1,4)!=.Ok{return 10}
	shapes:[8]b.Shape
	count,overlap_status:=b.query_overlap_aabb(world,{-2,-2,-2},{2,2,2},b.QUERY_FILTER_ALL,shapes[:])
	if overlap_status!=.Ok || count<2{return 11}
	hits:[8]b.Ray_Hit
	ray_count,ray_status:=b.query_ray(world,{0,0,3},{0,0,-6},b.QUERY_FILTER_ALL,hits[:])
	if ray_status!=.Ok || ray_count==0{return 12}
	if b.world_step_fixed(world)!=.Ok{return 13}
	events:[8]b.Sensor_Event
	begin_count,begin_status:=b.world_sensor_events(world,events[:])
	if begin_status!=.Ok || begin_count!=1 || events[0].began!=1{return 14}
	if b.body_destroy(&sensor)!=.Ok{return 15}
	snapshot,capture_status:=b.snapshot_capture(world);if capture_status!=.Ok{return 16};defer b.snapshot_destroy(&snapshot)
	restored,restored_status:=b.world_create(def);if restored_status!=.Ok{return 17};defer b.world_destroy(&restored)
	if b.snapshot_restore(restored,&snapshot)!=.Ok || b.world_step_fixed(restored)!=.Ok{return 18}
	end_count,end_status:=b.world_sensor_events(restored,events[:])
	if end_status!=.Ok || end_count!=1 || events[0].began!=0{return 19}
	if b.world_step_fixed(restored)!=.Ok{return 20}
	next_count,next_status:=b.world_sensor_events(restored,events[:])
	if next_status!=.Ok || next_count!=0{return 21}
	return 0
}
