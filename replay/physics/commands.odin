package replay_physics

import b "godot:box3d"
import r "godot:replay"

// Bind mutating helpers to the producer image that owns Working/accounting.
// A consumer module can contain another copy of this facade without charging
// its unrelated globals or dropping the producer's lifetime requirement.
@(private)
Command_Dispatch :: struct {
 step: proc(r.Execution)->r.Error,
 observe:proc(r.Execution)->(b.Alpha_Observation,r.Error),
 spawn: proc(r.Execution,u32,b.Body_Def)->(Body_Key,r.Error),
 body_destroy: proc(r.Execution,Body_Key)->r.Error,
 body_impulse,body_angular_impulse: proc(r.Execution,Body_Key,b.Vec3,bool)->r.Error,
 body_awake: proc(r.Execution,Body_Key,bool)->r.Error,
 body_velocity: proc(r.Execution,Body_Key,b.Vec3,b.Vec3)->r.Error,
 hinge_motor: proc(r.Execution,Joint_Key,bool,f32,f32)->r.Error,
 gravity: proc(r.Execution,b.Vec3)->r.Error,
 spawn_with_shape:proc(r.Execution,u32,b.Body_Def)->(Body_Key,Shape_Key,r.Error),
 motion_joint_create:proc(r.Execution,b.Motion_Joint_Def)->(Joint_Key,r.Error),
 motion_joint_destroy:proc(r.Execution,Joint_Key)->r.Error,
 // ABI2 extensions trail the original entries. The provider identity is
 // checked before any table access, including across retained producer code.
 body_pose_set: proc(r.Execution,Body_Key,b.Pose)->r.Error,
 body_type:proc(r.Execution,Body_Key,b.Body_Type)->r.Error,
 body_impulse_at:proc(r.Execution,Body_Key,b.Vec3,b.Vec3,bool)->r.Error,
}
@(private)
command_dispatch := Command_Dispatch{
 step=step,observe=observe,spawn=spawn,body_destroy=body_destroy,body_impulse=body_impulse,body_impulse_at=body_impulse_at,
 body_angular_impulse=body_angular_impulse,body_awake=body_awake,
 body_velocity=body_velocity,body_pose_set=body_pose_set,body_type=body_type,hinge_motor=hinge_motor,gravity=gravity,spawn_with_shape=spawn_with_shape,
 motion_joint_create=motion_joint_create,motion_joint_destroy=motion_joint_destroy,
}

@(private)
working :: proc(capability: r.Execution) -> (^Working, r.Error) {
	pointer, error := r.execution_pointer(capability, IDENTITY)
	if error!=.None{return nil,error}
	work:=cast(^Working)pointer
	if owner_error:=r.owner_access(work.ownership.owner,.Execute);owner_error!=.None{return nil,owner_error}
	return work,error
}
@(private)
command_begin :: proc(capability: r.Execution) -> (^Working, Operation, r.Error) {
	work, error := working(capability); if error != .None {return nil, {}, error}
	if error := world_check(work.stage.world, work.config); error != .None {return nil, {}, r.execution_fail(capability, error)}
	operation, begin_error := begin()
	if begin_error != .None {return nil, {}, r.execution_fail(capability, begin_error)}
	return work, operation, .None
}
@(private)
command_finish :: proc(capability: r.Execution, work: ^Working, operation: Operation, status: b.Status) -> r.Error {
	work.revision+=1
	request_error := finish(operation)
	if status != .Ok {return r.execution_fail(capability, status_error(status))}
	if request_error != .None {return r.execution_fail(capability, request_error)}
	return r.execution_fail(capability, world_check(work.stage.world, work.config))
}

// Exactly one fixed 60Hz/four-substep operation is required in each managed tick.
// Savepoints preserve this claim; restoring a rejected action cannot permit a
// second step in that tick. Returned failures poison the unpublished callback.
step :: proc(capability: r.Execution) -> r.Error {
	owner, owner_error := working(capability)
	if owner_error != .None {return owner_error}
	if owner.commands.step != step {return owner.commands.step(capability)}
	work, operation, error := command_begin(capability); if error != .None {return error}
	defer operation_end(&operation)
	if error := r.execution_claim_step(capability); error != .None {return error}
	status := b.world_step_fixed(work.stage.world)
	if status == .Ok {
		count, sensor_error := read_sensor_events(work.stage.world, work.sensors[:])
		if sensor_error != .None {return r.execution_fail(capability, sensor_error)}
		work.sensor_count = count
	}
	return command_finish(capability, work, operation, status)
}

spawn :: proc(capability: r.Execution, asset_id: u32, body_def: b.Body_Def) -> (Body_Key, r.Error) {
 owner,error:=working(capability);if error!=.None{return 0,error}
 if owner.commands.spawn!=spawn{return owner.commands.spawn(capability,asset_id,body_def)}
 body,_,result:=spawn_keys(capability,asset_id,body_def);return body,result
}

// Returns the identity of the shape already created by the ordinary spawn path.
// No extra geometry or world capability is exposed. Both variants poison/abort
// the same unpublished transaction on any allocation/admission/identity failure.
spawn_with_shape :: proc(capability:r.Execution,asset_id:u32,body_def:b.Body_Def)->(Body_Key,Shape_Key,r.Error){
 owner,error:=working(capability);if error!=.None{return 0,0,error}
 if owner.commands.spawn_with_shape!=spawn_with_shape{return owner.commands.spawn_with_shape(capability,asset_id,body_def)}
 return spawn_keys(capability,asset_id,body_def)
}
@(private)
spawn_keys :: proc(capability:r.Execution,asset_id:u32,body_def:b.Body_Def)->(Body_Key,Shape_Key,r.Error){
	work, operation, error := command_begin(capability); if error != .None {return 0,0, error}
	defer operation_end(&operation)
	if body_def.type != .Dynamic {return 0,0, r.execution_fail(capability, .Invalid_Config)}
	asset: ^Asset
	for &candidate in work.config.assets[:work.config.asset_count] {if candidate.id == asset_id {asset = &candidate; break}}
	if asset == nil {return 0,0, r.execution_fail(capability, .Invalid_Config)}
	// Triangle meshes remain static-only; this existing spawn door is Dynamic.
	if asset.kind==.Mesh{return 0,0,r.execution_fail(capability,.Invalid_Config)}
	counts, count_status := b.world_counters(work.stage.world)
	if count_status != .Ok {return 0,0, r.execution_fail(capability, status_error(count_status))}
	if counts.body_count >= b.ALPHA_TOTAL_BODIES || counts.shape_count >= b.ALPHA_SHAPES {return 0,0, r.execution_fail(capability, .Resource_Limit)}
	body, status := b.body_create(work.stage.world, body_def)
	if status != .Ok {return 0,0, command_finish(capability, work, operation, status)}
	shape: b.Shape
	#partial switch asset.kind {
	case .Box: shape, status = b.shape_box(body, asset.shape, asset.half_extents)
	case .Sphere: shape, status = b.shape_sphere(body, asset.shape, asset.radius, asset.center_a)
	case .Capsule: shape, status = b.shape_capsule(body, asset.shape, asset.center_a, asset.center_b, asset.radius)
	case .Hull: shape,status=b.recovery_catalog_shape(&work.catalog,asset.id,body,asset.shape)
	}
	if status != .Ok {return 0,0, command_finish(capability, work, operation, status)}
	key, key_status := b.body_key(body)
	shape_key:Shape_Key
 if key_status==.Ok {shape_key,key_status=b.shape_key(shape)}
 if error := command_finish(capability, work, operation, key_status); error != .None {return 0,0, error}
 return key,shape_key,.None
}

body_destroy :: proc(capability: r.Execution, key: Body_Key) -> r.Error {
	owner, owner_error := working(capability)
	if owner_error != .None {return owner_error}
	if owner.commands.body_destroy != body_destroy {return owner.commands.body_destroy(capability, key)}
	work, operation, error := command_begin(capability); if error != .None {return error}
	defer operation_end(&operation)
	body, status := b.body_resolve(work.stage.world, key)
	if status == .Ok {status = b.body_destroy(&body)}
	return command_finish(capability, work, operation, status)
}

body_impulse :: proc(capability: r.Execution, key: Body_Key, impulse: b.Vec3, wake := true) -> r.Error {
	owner, owner_error := working(capability)
	if owner_error != .None {return owner_error}
	if owner.commands.body_impulse != body_impulse {return owner.commands.body_impulse(capability, key, impulse, wake)}
	work, operation, error := command_begin(capability); if error != .None {return error}
	defer operation_end(&operation)
	body, status := b.body_resolve(work.stage.world, key)
	if status == .Ok {status = b.body_apply_impulse(body, impulse, wake = wake)}
	return command_finish(capability, work, operation, status)
}

body_angular_impulse :: proc(capability: r.Execution, key: Body_Key, impulse: b.Vec3, wake := true) -> r.Error {
	owner, owner_error := working(capability)
	if owner_error != .None {return owner_error}
	if owner.commands.body_angular_impulse != body_angular_impulse {return owner.commands.body_angular_impulse(capability, key, impulse, wake)}
	work, operation, error := command_begin(capability); if error != .None {return error}
	defer operation_end(&operation)
	body, status := b.body_resolve(work.stage.world, key)
	if status == .Ok {status = b.body_apply_angular_impulse(body, impulse, wake)}
	return command_finish(capability, work, operation, status)
}

// World-space application point uses the existing Native impulse API and the
// same producer/transaction/accounting guards as the centre-of-mass helper.
body_impulse_at :: proc(capability:r.Execution,key:Body_Key,impulse,point:b.Vec3,wake:=true)->r.Error{
 owner,owner_error:=working(capability);if owner_error!=.None{return owner_error}
 if owner.commands.body_impulse_at!=body_impulse_at{return owner.commands.body_impulse_at(capability,key,impulse,point,wake)}
 work,operation,error:=command_begin(capability);if error!=.None{return error}
 defer operation_end(&operation)
 body,status:=b.body_resolve(work.stage.world,key);point:=point
 if status==.Ok{status=b.body_apply_impulse(body,impulse,&point,wake)}
 return command_finish(capability,work,operation,status)
}

body_awake :: proc(capability: r.Execution, key: Body_Key, awake: bool) -> r.Error {
	owner, owner_error := working(capability)
	if owner_error != .None {return owner_error}
	if owner.commands.body_awake != body_awake {return owner.commands.body_awake(capability, key, awake)}
	work, operation, error := command_begin(capability); if error != .None {return error}
	defer operation_end(&operation)
	body, status := b.body_resolve(work.stage.world, key)
	if status == .Ok {status = b.body_set_awake(body, awake)}
	return command_finish(capability, work, operation, status)
}

body_pose :: proc(capability: r.Execution, key: Body_Key) -> (b.Pose, r.Error) {
	work, error := working(capability); if error != .None {return {}, error}
	body, status := b.body_resolve(work.stage.world, key); if status != .Ok {return {}, status_error(status)}
	pose, pose_status := b.body_get_pose(body)
	return pose, status_error(pose_status)
}

body_velocities :: proc(capability:r.Execution,key:Body_Key)->(linear,angular:b.Vec3,error:r.Error){
 work,working_error:=working(capability);if working_error!=.None{return {},{},working_error}
 body,status:=b.body_resolve(work.stage.world,key);if status!=.Ok{return {},{},status_error(status)}
 linear,angular,status=b.body_get_velocity(body);return linear,angular,status_error(status)
}

// Teleport only the unpublished managed world. Native validation, operation
// accounting and the complete transaction's publication gate remain in force.
body_pose_set :: proc(capability:r.Execution,key:Body_Key,pose:b.Pose)->r.Error {
 owner,owner_error:=working(capability);if owner_error!=.None{return owner_error}
 if owner.commands.body_pose_set!=body_pose_set{return owner.commands.body_pose_set(capability,key,pose)}
 work,operation,error:=command_begin(capability);if error!=.None{return error}
 defer operation_end(&operation)
 body,status:=b.body_resolve(work.stage.world,key)
 if status==.Ok{status=b.body_set_pose(body,pose)}
 return command_finish(capability,work,operation,status)
}

body_type :: proc(capability:r.Execution,key:Body_Key,kind:b.Body_Type)->r.Error {
 owner,owner_error:=working(capability);if owner_error!=.None{return owner_error}
 if owner.commands.body_type!=body_type{return owner.commands.body_type(capability,key,kind)}
 work,operation,error:=command_begin(capability);if error!=.None{return error}
 defer operation_end(&operation)
 body,status:=b.body_resolve(work.stage.world,key)
 if status==.Ok{status=b.body_set_type(body,kind)}
 return command_finish(capability,work,operation,status)
}

body_velocity :: proc(capability: r.Execution, key: Body_Key, linear, angular: b.Vec3) -> r.Error {
	owner, owner_error := working(capability)
	if owner_error != .None {return owner_error}
	if owner.commands.body_velocity != body_velocity {return owner.commands.body_velocity(capability, key, linear, angular)}
	work, operation, error := command_begin(capability); if error != .None {return error}
	defer operation_end(&operation)
	body, status := b.body_resolve(work.stage.world, key)
	if status == .Ok {status = b.body_set_velocity(body, linear, angular)}
	return command_finish(capability, work, operation, status)
}

hinge_motor :: proc(capability: r.Execution, key: Joint_Key, enabled: bool, speed, torque: f32) -> r.Error {
	owner, owner_error := working(capability)
	if owner_error != .None {return owner_error}
	if owner.commands.hinge_motor != hinge_motor {return owner.commands.hinge_motor(capability, key, enabled, speed, torque)}
	work, operation, error := command_begin(capability); if error != .None {return error}
	defer operation_end(&operation)
	joint, status := b.joint_resolve(work.stage.world, key)
	if status == .Ok {status = b.joint_hinge_set_motor(joint, enabled, speed, torque)}
	return command_finish(capability, work, operation, status)
}

gravity :: proc(capability: r.Execution, value: b.Vec3) -> r.Error {
	owner, owner_error := working(capability)
	if owner_error != .None {return owner_error}
	if owner.commands.gravity != gravity {return owner.commands.gravity(capability, value)}
	work, operation, error := command_begin(capability); if error != .None {return error}
	defer operation_end(&operation)
	return command_finish(capability, work, operation, b.world_set_gravity(work.stage.world, value))
}

Sensor_Event :: struct {sensor, visitor: Shape_Key, began: bool}

// Event keys can refer to objects destroyed this tick. Native structural decode
// makes no liveness claim; resolving a retired key still fails explicitly.
sensor_events :: proc(capability: r.Execution, out: []Sensor_Event) -> (u32, r.Error) {
 work, error := working(capability); if error != .None {return 0, error}
 if u64(len(out)) < u64(work.sensor_count) {return work.sensor_count, .Output_Too_Small}
 copy(out, work.sensors[:work.sensor_count])
 return work.sensor_count, .None
}

@(private)
read_sensor_events :: proc(world: b.World, out: []Sensor_Event) -> (u32, r.Error) {
 events: [70]b.Sensor_Event
 count, status := b.world_sensor_events(world, events[:])
 if status != .Ok {return count, status_error(status)}
 if u64(len(out)) < u64(count) {return count, .Output_Too_Small}
 for event, i in events[:count] {
  sensor, sensor_status := b.shape_key_from_handle(event.sensor)
  visitor, visitor_status := b.shape_key_from_handle(event.visitor)
  if sensor_status != .Ok || visitor_status != .Ok {return 0, .External_State}
  out[i] = {sensor, visitor, event.began != 0}
 }
 return count, .None
}

overlap :: proc(capability: r.Execution, lower, upper: b.Vec3, out: []Shape_Key) -> (u32, r.Error) {
	work, error := working(capability); if error != .None {return 0, error}
	shapes: [35]b.Shape
	count, status := b.query_overlap_aabb(work.stage.world, lower, upper, b.QUERY_FILTER_ALL, shapes[:])
	if status != .Ok {return count, status_error(status)}
	if u64(len(out)) < u64(count) {return count, .Output_Too_Small}
	for shape, i in shapes[:count] {
		key, key_status := b.shape_key(shape); if key_status != .Ok {return 0, status_error(key_status)}
		out[i] = key
	}
	return count, .None
}

Ray_Hit :: struct {shape: Shape_Key, point, normal: b.Vec3, fraction: f32}
ray :: proc(capability: r.Execution, origin, translation: b.Vec3, out: []Ray_Hit) -> (u32, r.Error) {
	work, error := working(capability); if error != .None {return 0, error}
	hits: [35]b.Ray_Hit
	count, status := b.query_ray(work.stage.world, origin, translation, b.QUERY_FILTER_ALL, hits[:])
	if status != .Ok {return count, status_error(status)}
	if u64(len(out)) < u64(count) {return count, .Output_Too_Small}
	for hit, i in hits[:count] {
		key, key_status := b.shape_key(hit.shape); if key_status != .Ok {return 0, status_error(key_status)}
		out[i] = {key, hit.point, hit.normal, hit.fraction}
	}
	return count, .None
}

// Read-only resource/count observations for profiling and external presentation.
// They do not enter Game State and never gate on wall time.
observe :: proc(capability:r.Execution)->(b.Alpha_Observation,r.Error){
	work,error:=working(capability);if error!=.None{return {},error}
	if work.commands.observe!=observe{return work.commands.observe(capability)}
	observation,status:=b.alpha_observe(work.stage.world,memory.live_bytes)
	return observation,status_error(status)
}
