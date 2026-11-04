@tool
class_name Box3DJoint3D
extends Node3D

@export var stable_key: String=""
@export var body_a: String=""
@export var body_b: String=""
@export var local_frame_a: Transform3D=Transform3D.IDENTITY
@export var local_frame_b: Transform3D=Transform3D.IDENTITY
@export var force_threshold: float=3.4028234663852886e38
@export var torque_threshold: float=3.4028234663852886e38
@export var constraint_hertz: float=60.0
@export var constraint_damping_ratio: float=1.0
@export var collide_connected: bool=false
@export var settings: Box3DJointSettings3D

func _joint_kind() -> String:return ""
func box3d_joint_definition(world: Node3D,path: String,errors: Array) -> Dictionary:
	var d:=Box3DAuthoringData
	d.key(stable_key,path+".stable_key",errors);d.key(body_a,path+".body_a",errors);d.key(body_b,path+".body_b",errors)
	if body_a==body_b:d.issue(errors,path+".body_b","Reference","A joint needs two distinct explicit body keys.")
	var marker_pose: Dictionary=d.relative_pose(self,world,path,errors)
	if marker_pose.position!=[0.0,0.0,0.0] or absf(marker_pose.rotation[0])+absf(marker_pose.rotation[1])+absf(marker_pose.rotation[2])>d.EPS:
		d.issue(errors,path+".transform","Pose","Joint marker transform must be identity; author actual body-local local_frame_a/b explicitly.")
	for field in ["force_threshold","torque_threshold","constraint_hertz","constraint_damping_ratio"]:d.scalar(get(field),path+"."+field,errors,true)
	var kind:=_joint_kind()
	var result: Dictionary={"stable_key":stable_key,"kind":kind,"body_a":body_a,"body_b":body_b,"local_frame_a":d.pose(local_frame_a,path+".local_frame_a",errors),"local_frame_b":d.pose(local_frame_b,path+".local_frame_b",errors),"force_threshold":force_threshold,"torque_threshold":torque_threshold,"constraint_hertz":constraint_hertz,"constraint_damping_ratio":constraint_damping_ratio,"collide_connected":collide_connected}
	result.merge(Box3DMotionAuthoringData.zero_settings())
	if settings==null or not settings.accepts_kind(kind):d.issue(errors,path+".settings","Reference","Settings Resource must match the named joint family.")
	else:result[settings.settings_key()]=settings.definition(kind,path+"."+settings.settings_key(),errors)
	return result
func _get_configuration_warnings() -> PackedStringArray:
	var current:=get_parent()
	while current!=null:
		if current.has_method("box3d_diagnostics"):return Box3DAuthoringData.warnings(current.call("box3d_diagnostics"))
		current=current.get_parent()
	return PackedStringArray(["Place the joint below its Box3DWorld3D; references are body stable keys."])
