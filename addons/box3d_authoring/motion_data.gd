@tool
class_name Box3DMotionAuthoringData
extends RefCounted

static func native_vector(value: Vector3,path: String,errors: Array) -> Dictionary:
	Box3DAuthoringData.vector(value,path,errors)
	return {"x":value.x,"y":value.y,"z":value.z}

static func native_quaternion(value: Quaternion,path: String,errors: Array) -> Dictionary:
	if not value.is_finite() or absf(value.length_squared()-1.0)>Box3DAuthoringData.EPS:
		Box3DAuthoringData.issue(errors,path,"Pose","Quaternion must be finite and unit; it is not silently normalized.")
	return {"x":value.x,"y":value.y,"z":value.z,"w":value.w}

static func zero_settings() -> Dictionary:
	var axis: Dictionary={"flags":0,"hertz":0.0,"damping_ratio":0.0,"target":0.0,"lower":0.0,"upper":0.0,"motor_speed":0.0,"max_motor":0.0}
	var zero: Dictionary={"x":0.0,"y":0.0,"z":0.0}
	return {"axis":axis,"distance":{"axis":axis.duplicate(true),"length":0.0,"lower_spring_force":0.0,"upper_spring_force":0.0},
		"spherical":{"flags":0,"hertz":0.0,"damping_ratio":0.0,"cone_angle":0.0,"lower_twist":0.0,"upper_twist":0.0,"max_motor_torque":0.0,"target_rotation":{"x":0.0,"y":0.0,"z":0.0,"w":0.0},"motor_velocity":zero.duplicate(true)},
		"motor":{"linear_velocity":zero.duplicate(true),"angular_velocity":zero.duplicate(true),"max_velocity_force":0.0,"max_velocity_torque":0.0,"linear_hertz":0.0,"linear_damping_ratio":0.0,"angular_hertz":0.0,"angular_damping_ratio":0.0,"max_spring_force":0.0,"max_spring_torque":0.0},
		"weld":{"linear_hertz":0.0,"angular_hertz":0.0,"linear_damping_ratio":0.0,"angular_damping_ratio":0.0},
		"wheel":{"flags":0,"suspension_hertz":0.0,"suspension_damping_ratio":0.0,"lower_suspension":0.0,"upper_suspension":0.0,"max_spin_torque":0.0,"spin_speed":0.0,"steering_hertz":0.0,"steering_damping_ratio":0.0,"target_steering_angle":0.0,"max_steering_torque":0.0,"lower_steering":0.0,"upper_steering":0.0}}

static func scalar_fields(value: Resource,names: Array,path: String,errors: Array) -> void:
	for field in names:Box3DAuthoringData.scalar(value.get(field),path+"."+field,errors)

static func flags(value: int,allowed: int,path: String,errors: Array) -> void:
	if value<0 or value>4294967295 or (value&~allowed)!=0:
		Box3DAuthoringData.issue(errors,path,"Unsupported","Unknown joint flag bits.")
