@tool
class_name Box3DJoint3D
extends Node3D

@export_storage var stable_key: String=Box3DIdentityKey.initial("joint")
@export var body_a: String=""
@export var body_b: String=""
enum FrameMode { VIEWPORT, BODY_LOCAL }
@export_storage var frame_mode: FrameMode = FrameMode.VIEWPORT
## Anchor B relative to this joint node. Identity uses the same anchor as A.
@export var anchor_b_offset: Transform3D = Transform3D.IDENTITY
@export var local_frame_a: Transform3D=Transform3D.IDENTITY
@export var local_frame_b: Transform3D=Transform3D.IDENTITY
@export var force_threshold: float=3.4028234663852886e38
@export var torque_threshold: float=3.4028234663852886e38
@export var constraint_hertz: float=60.0
@export var constraint_damping_ratio: float=1.0
@export var collide_connected: bool=false
@export var settings: Box3DJointSettings3D

func _joint_kind() -> String:return ""

func _validate_property(property: Dictionary) -> void:
	if property.name in ["local_frame_a", "local_frame_b"] and frame_mode != FrameMode.BODY_LOCAL:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	if property.name == "anchor_b_offset" and frame_mode != FrameMode.VIEWPORT:
		property.usage &= ~PROPERTY_USAGE_EDITOR

func _body(world: Node, key: String, path: String, errors: Array) -> Box3DBody3D:
	var key_errors: Array = []
	Box3DAuthoringData.key(key, path, key_errors)
	if not key_errors.is_empty():
		errors.append_array(key_errors)
		return null
	var found: Box3DBody3D
	var pending: Array[Node] = [world]
	var visited := 0
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		visited += 1
		if visited > 4096:
			Box3DAuthoringData.issue(errors, path, "Capacity", "Body lookup exceeds 4096 nodes.")
			return null
		if node != world and node is Box3DWorld3D: continue
		if node is Box3DBody3D and node.stable_key == key:
			if found != null:
				Box3DAuthoringData.issue(errors, path, "Reference", "Body ID is ambiguous: " + key)
				return null
			found = node
		for child in node.get_children(): pending.append(child)
	if found == null: Box3DAuthoringData.issue(errors, path, "Reference", "Body is missing from this World: " + key)
	return found

func _transform(value: Dictionary) -> Transform3D:
	var p: Array = value.position
	var q: Array = value.rotation
	return Transform3D(Basis(Quaternion(q[0], q[1], q[2], q[3])), Vector3(p[0], p[1], p[2]))

# One resolver for detached extraction, viewport drawing and editor conversion.
# It reads local ancestry, so a detached PackedScene has the same result.
func resolved_frames(world: Node3D, path: String, errors: Array) -> Dictionary:
	var d := Box3DAuthoringData
	var a := _body(world, body_a, path + ".body_a", errors)
	var b := _body(world, body_b, path + ".body_b", errors)
	if a == null or b == null: return {}
	if a == b:
		d.issue(errors, path + ".body_b", "Reference", "A joint needs two distinct bodies.")
		return {}
	var placement_errors: Array = []
	var marker := _transform(d.relative_pose(self, world, path + ".marker", placement_errors))
	var wa := _transform(d.relative_pose(a, world, path + ".body_a", placement_errors))
	var wb := _transform(d.relative_pose(b, world, path + ".body_b", placement_errors))
	if not placement_errors.is_empty():
		errors.append_array(placement_errors)
		return {}
	var fa: Transform3D
	var fb: Transform3D
	match frame_mode:
		FrameMode.VIEWPORT:
			if not d.rigid(anchor_b_offset):
				d.issue(errors, path + ".anchor_b_offset", "Pose", "Anchor B must be a finite rigid transform.")
				return {}
			fa = wa.affine_inverse() * marker
			fb = wb.affine_inverse() * marker * anchor_b_offset
		FrameMode.BODY_LOCAL:
			fa = local_frame_a
			fb = local_frame_b
		_:
			d.issue(errors, path + ".frame_mode", "Unsupported", "Choose viewport anchors or explicit body-local frames.")
			return {}
	if not d.rigid(fa) or not d.rigid(fb):
		d.issue(errors, path + ".local_frames", "Pose", "Joint frames must be finite and rigid.")
		return {}
	return {"a": fa, "b": fb, "world_a": wa * fa, "world_b": wb * fb, "body_a": a, "body_b": b}

func box3d_joint_definition(world: Node3D,path: String,errors: Array) -> Dictionary:
	var d:=Box3DAuthoringData
	d.key(stable_key,path+".stable_key",errors)
	var frames := resolved_frames(world, path, errors)
	var fa: Transform3D = frames.get("a", Transform3D.IDENTITY)
	var fb: Transform3D = frames.get("b", Transform3D.IDENTITY)
	for field in ["force_threshold","torque_threshold","constraint_hertz","constraint_damping_ratio"]:d.scalar(get(field),path+"."+field,errors,true)
	var kind:=_joint_kind()
	var result: Dictionary={"stable_key":stable_key,"kind":kind,"body_a":body_a,"body_b":body_b,"local_frame_a":d.pose(fa,path+".local_frame_a",errors),"local_frame_b":d.pose(fb,path+".local_frame_b",errors),"force_threshold":force_threshold,"torque_threshold":torque_threshold,"constraint_hertz":constraint_hertz,"constraint_damping_ratio":constraint_damping_ratio,"collide_connected":collide_connected}
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
