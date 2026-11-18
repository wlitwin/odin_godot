@tool
class_name Box3DEditorJoints
extends RefCounted

static func scope(node: Node, root: Node) -> Node3D:
	var world := Box3DEditorIdentity.world_of(node)
	return world if world != null else root as Node3D

static func bodies(node: Node, root: Node) -> Array[Box3DBody3D]:
	var domain := scope(node, root)
	var result: Array[Box3DBody3D] = []
	if domain == null: return result
	for item in Box3DEditorIdentity._nodes(domain, true):
		if item is Box3DBody3D: result.append(item)
	result.sort_custom(func(a, b): return Box3DAuthoringData.relative_name(a, domain).naturalnocasecmp_to(Box3DAuthoringData.relative_name(b, domain)) < 0)
	return result

static func parent_frame(joint: Box3DJoint3D, world: Node3D, errors: Array) -> Dictionary:
	var parent := joint.get_parent()
	if parent is Node3D:
		var count := errors.size()
		var value := joint._transform(Box3DAuthoringData.relative_pose(parent, world, "joint.parent", errors))
		return {"transform": value} if errors.size() == count else {}
	var effective := Box3DAuthoringData.effective_transform(world, "world", errors)
	if effective.is_empty(): return {}
	var inverse: Transform3D = effective.transform.affine_inverse()
	return {"transform": inverse} if Box3DAuthoringData.rigid(inverse) else {}

static func body_inherits_marker(body: Box3DBody3D, joint: Box3DJoint3D) -> bool:
	var current: Node = body
	while current is Node3D:
		if current == joint: return true
		if current.top_level: return false
		current = current.get_parent()
	return false

static func moves_referenced_body(joint: Box3DJoint3D, frames: Dictionary, marker: Transform3D) -> bool:
	return not joint.transform.is_equal_approx(marker) and (body_inherits_marker(frames.body_a, joint) or body_inherits_marker(frames.body_b, joint))

static func plan_mode(joint: Box3DJoint3D, mode: int, root: Node) -> Dictionary:
	if not Box3DEditorIdentity.editable(joint, root): return {"ok": false, "error": "Enable Editable Children or edit the joint's source scene."}
	if mode not in [Box3DJoint3D.FrameMode.VIEWPORT, Box3DJoint3D.FrameMode.BODY_LOCAL]: return {"ok": false, "error": "Unknown anchor mode."}
	var plan := Box3DEditorIdentity._plan("Change Box3D anchor mode", root)
	if joint.frame_mode == mode: return plan
	var world := scope(joint, root)
	if world == null: return {"ok": false, "error": "Place the joint in a 3D authoring scene first."}
	var errors: Array = []
	Box3DAuthoringData.validate_world_frame(world, errors)
	var frames := joint.resolved_frames(world, "joint", errors)
	if frames.is_empty() or not errors.is_empty(): return {"ok": false, "error": "Choose valid bodies and rigid frames before switching modes.", "diagnostics": errors}
	if mode == Box3DJoint3D.FrameMode.BODY_LOCAL:
		Box3DEditorIdentity._change(plan, joint, &"local_frame_a", frames.a)
		Box3DEditorIdentity._change(plan, joint, &"local_frame_b", frames.b)
	else:
		var parent := parent_frame(joint, world, errors)
		if parent.is_empty() or not errors.is_empty(): return {"ok": false, "error": "The joint's parent transform is invalid.", "diagnostics": errors}
		var marker: Transform3D = parent.transform.affine_inverse() * frames.world_a
		var offset: Transform3D = frames.world_a.affine_inverse() * frames.world_b
		if not Box3DAuthoringData.rigid(marker) or not Box3DAuthoringData.rigid(offset): return {"ok": false, "error": "Anchor conversion did not produce finite rigid transforms."}
		if moves_referenced_body(joint, frames, marker): return {"ok": false, "error": "Moving this marker would also move a referenced child body. Keep body-local mode or place the joint outside that body's transform ancestry first."}
		Box3DEditorIdentity._change(plan, joint, &"transform", marker)
		Box3DEditorIdentity._change(plan, joint, &"anchor_b_offset", offset)
	Box3DEditorIdentity._change(plan, joint, &"frame_mode", mode)
	return plan

static func handle_property(joint: Box3DJoint3D, id: int) -> StringName:
	if joint.frame_mode == Box3DJoint3D.FrameMode.VIEWPORT: return &"anchor_b_offset" if id == 1 else &""
	return &"local_frame_a" if id == 0 else &"local_frame_b" if id == 1 else &""

static func plan_body_origins(joint: Box3DJoint3D, root: Node) -> Dictionary:
	if joint.frame_mode != Box3DJoint3D.FrameMode.VIEWPORT or not Box3DEditorIdentity.editable(joint, root):
		return {"ok": false, "error": "Use viewport mode on an editable joint first."}
	var world := scope(joint, root)
	if world == null: return {"ok": false, "error": "Place the joint in a 3D scene first."}
	var errors: Array = []
	Box3DAuthoringData.validate_world_frame(world, errors)
	var frames := joint.resolved_frames(world, "joint", errors)
	if frames.is_empty() or not errors.is_empty(): return {"ok": false, "error": "Choose valid bodies first.", "diagnostics": errors}
	var a := joint._transform(Box3DAuthoringData.relative_pose(frames.body_a, world, "body.a", errors))
	var b := joint._transform(Box3DAuthoringData.relative_pose(frames.body_b, world, "body.b", errors))
	var parent := parent_frame(joint, world, errors)
	if parent.is_empty() or not errors.is_empty(): return {"ok": false, "error": "Parent placement is invalid.", "diagnostics": errors}
	var marker: Transform3D = parent.transform.affine_inverse() * a
	var offset := a.affine_inverse() * b
	if not Box3DAuthoringData.rigid(marker) or not Box3DAuthoringData.rigid(offset): return {"ok": false, "error": "Body origins do not produce finite rigid anchor transforms."}
	if moves_referenced_body(joint, frames, marker): return {"ok": false, "error": "Placing this marker would also move a referenced child body. Place the joint outside that body's transform ancestry first."}
	var plan := Box3DEditorIdentity._plan("Place Box3D anchors at body origins", root)
	Box3DEditorIdentity._change(plan, joint, &"transform", marker)
	Box3DEditorIdentity._change(plan, joint, &"anchor_b_offset", offset)
	return plan

static func handle_positions(joint: Box3DJoint3D, root: Node) -> Dictionary:
	var world := scope(joint, root)
	if world == null: return {}
	var errors: Array = []
	Box3DAuthoringData.validate_world_frame(world, errors)
	var frames := joint.resolved_frames(world, "joint", errors)
	var marker := joint._transform(Box3DAuthoringData.relative_pose(joint, world, "joint.marker", errors))
	if frames.is_empty() or not errors.is_empty(): return {}
	var inverse := marker.affine_inverse()
	return {"a": inverse * frames.world_a.origin, "b": inverse * frames.world_b.origin, "frames": frames, "world": world}

static func drag_value(joint: Box3DJoint3D, id: int, camera: Camera3D, screen: Vector2, root: Node) -> Dictionary:
	var property := handle_property(joint, id)
	if property.is_empty() or not screen.is_finite() or not is_instance_valid(camera): return {}
	var positions := handle_positions(joint, root)
	if positions.is_empty() or not joint.is_inside_tree(): return {}
	var world: Node3D = positions.world
	var anchor: Transform3D = positions.frames.world_a if id == 0 else positions.frames.world_b
	var point: Vector3 = world.global_transform * anchor.origin
	var normal := camera.global_transform.basis.z.normalized()
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	if not point.is_finite() or not normal.is_finite() or not origin.is_finite() or not direction.is_finite(): return {}
	var intersection: Variant = Plane(normal, point).intersects_ray(origin, direction)
	if intersection == null or not intersection.is_finite(): return {}
	var frame: Transform3D = joint.get(property)
	if joint.frame_mode == Box3DJoint3D.FrameMode.VIEWPORT:
		frame.origin = joint.global_transform.affine_inverse() * intersection
	else:
		var body: Box3DBody3D = positions.frames.body_a if id == 0 else positions.frames.body_b
		frame.origin = body.global_transform.affine_inverse() * intersection
	if not Box3DAuthoringData.rigid(frame): return {}
	return {"property": property, "value": frame}
