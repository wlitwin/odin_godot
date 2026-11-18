@tool
class_name Box3DEditorPreview
extends RefCounted

const D = preload("res://addons/box3d_authoring/data.gd")
const RED := Color(1.0, 0.25, 0.2)
const AMBER := Color(1.0, 0.7, 0.15)
const SCOPE := "EDITOR_PARTIAL_SHAPES_NO_IDS_NO_FRAME"

static func world_of(node: Node) -> Box3DWorld3D:
	while node != null:
		if node is Box3DWorld3D: return node
		node = node.get_parent()
	return null

static func transform_from(value: Dictionary) -> Transform3D:
	var q: Array = value.rotation
	var p: Array = value.position
	return Transform3D(Basis(Quaternion(q[0], q[1], q[2], q[3])), Vector3(p[0], p[1], p[2]))

static func issue(context: Dictionary, node: Node, path: String, code: String, message: String, category := "authoring", slot := -1) -> void:
	if category == "authoring": context.validation_status = "invalid"
	var id := node.get_instance_id()
	if not context.problems.has(id): context.problems[id] = []
	for previous in context.problems[id]:
		if previous.path == path and previous.code == code and previous.category == category:
			if slot >= 0: previous.slot = slot
			return
	if context.diagnostics.size() >= D.MAX_ERRORS:
		context.diagnostics_omitted = true
		return
	var problem := {"node_path": D.relative_name(node, context.world), "path": path, "code": code, "message": message, "category": category, "slot": slot}
	context.problems[id].append(problem)
	context.diagnostics.append(problem)

static func add_errors(context: Dictionary, node: Node, errors: Array, slot := -1) -> void:
	for error in errors: issue(context, node, error.path, error.code, error.message, "authoring", slot)

static func context_for(world: Box3DWorld3D, services: Box3DEditorServices) -> Dictionary:
	var context := {"world": world, "nodes": [], "bodies": {}, "poses": {}, "problems": {}, "diagnostics": [], "diagnostics_omitted": false, "validation_status": "unavailable", "frame_valid": true}
	var frame_errors: Array = []
	D.validate_world_frame(world, frame_errors)
	add_errors(context, world, frame_errors)
	context.frame_valid = frame_errors.is_empty()
	var pending: Array[Node] = [world]
	var object_keys := {"body": {}, "joint": {}, "character": {}}
	var body_count := 0
	var shape_count := 0
	while not pending.is_empty() and context.nodes.size() < 4096:
		var node: Node = pending.pop_back()
		if node != world and node is Box3DWorld3D: continue
		context.nodes.append(node)
		var kind := Box3DEditorIdentity.kind(node)
		if object_keys.has(kind):
			if not object_keys[kind].has(node.stable_key): object_keys[kind][node.stable_key] = []
			object_keys[kind][node.stable_key].append(node)
		if node is Box3DBody3D:
			body_count += 1
			shape_count += node.shapes.size()
			context.bodies[node.stable_key] = object_keys.body[node.stable_key]
			var errors: Array = []
			node.box3d_body_header(world, "bodies[" + D.relative_name(node, world) + "]", errors)
			add_errors(context, node, errors)
			var placement_errors: Array = []
			var placement := D.relative_pose(node, world, "body", placement_errors)
			if placement_errors.is_empty() and node.body_type >= 0 and node.body_type <= 2: context.poses[node.get_instance_id()] = placement
		var children := node.get_children()
		for index in range(children.size() - 1, -1, -1): pending.append(children[index])
	for kind in object_keys:
		for key in object_keys[kind]:
			if object_keys[kind][key].size() > 1:
				for node in object_keys[kind][key]: issue(context, node, kind + ".stable_key", "Duplicate", "This ID belongs to more than one " + kind + ".")
	if not pending.is_empty() or body_count > D.MAX_BODIES or shape_count > D.MAX_SHAPES:
		issue(context, world, "world", "Capacity", "The authoring traversal/body/shape capacity is exceeded; preview is bounded.")
	else:
		var snapshot: Dictionary = world._snapshot()
		for error in snapshot.errors:
			var target: Node = world
			for node in context.nodes:
				var prefix := ""
				if node is Box3DBody3D: prefix = "bodies"
				elif node is Box3DJoint3D: prefix = "joints"
				elif node is Box3DCharacterMover3D: prefix = "characters"
				if not prefix.is_empty() and (String(error.path).begins_with(prefix + "[" + D.relative_name(node, world) + "]") or String(error.path).begins_with(prefix + "[" + node.stable_key + "]")):
					target = node
					break
			issue(context, target, error.path, error.code, error.message)
		if snapshot.errors.is_empty() and services != null:
			var checked := services.validate_definition(snapshot.definition)
			if checked.get("ok", false): context.validation_status = "valid"
			else:
				var diagnostic: Dictionary = checked.get("diagnostic", {})
				if diagnostic.get("error", "") == "ToolsUnavailable": issue(context, world, "preview", "ToolsUnavailable", "Build the shared authoring tools to preview shapes.", "preview")
				else:
					var target: Node = world
					var detail: Dictionary = diagnostic.get("definition", {})
					var field: String = String(detail.get("field", "definition"))
					var slot := -1
					var body_index: int = int(detail.get("body", -1))
					if body_index >= 0 and body_index < snapshot.definition.bodies.size():
						var key: String = snapshot.definition.bodies[body_index].stable_key
						if context.bodies.get(key, []).size() == 1:
							target = context.bodies[key][0]
							var shape_index: int = int(detail.get("shape", -1))
							if shape_index >= 0 and shape_index < snapshot.definition.bodies[body_index].shapes.size():
								var shape_key: String = snapshot.definition.bodies[body_index].shapes[shape_index].stable_key
								for i in range(target.shapes.size()):
									if target.shapes[i] != null and target.shapes[i].stable_key == shape_key: slot = i; break
								if field == "conflicting_resource_geometry":
									for body in context.nodes:
										if not body is Box3DBody3D: continue
										for i in range(body.shapes.size()):
											if body.shapes[i] != null and body.shapes[i].stable_key == shape_key:
												issue(context, body, "shapes[%d].stable_key" % i, "Duplicate", "This shape ID names conflicting geometry.", "authoring", i)
					else:
						var element: int = int(detail.get("element", -1))
						for kind in ["joint", "character"]:
							var records: Array = snapshot.definition[kind + "s"]
							if field.begins_with(kind + ".") and element >= 0 and element < records.size():
								var matches: Array = object_keys[kind].get(records[element].stable_key, [])
								if matches.size() == 1: target = matches[0]
					issue(context, target, field, String(diagnostic.get("error", "Invalid")), "Shared validation: " + JSON.stringify(diagnostic), "authoring", slot)
	return context

static func finite_values(value: Variant) -> bool:
	if value is float: return is_finite(value) and absf(value) <= 3.4028234663852886e38
	if value is Array:
		for item in value:
			if not finite_values(item): return false
	if value is Dictionary:
		for item in value.values():
			if not finite_values(item): return false
	return true

static func reference_key_valid(key: String) -> bool:
	var errors: Array = []
	D.key(key, "reference", errors)
	return errors.is_empty()

static func raw_transform(node: Node, world: Node) -> Dictionary:
	var transform := Transform3D.IDENTITY
	var current := node
	var gap := false
	var chain: Array[Node3D] = []
	while current != null and current != world:
		if current is Node3D:
			if current.top_level: gap = true
			chain.append(current)
		else: gap = true
		current = current.get_parent()
	if current != world: return {}
	if gap:
		var source := raw_effective_transform(node)
		var target := raw_effective_transform(world)
		if source.is_empty() or target.is_empty(): return {}
		var determinant: float = target.transform.basis.determinant()
		if not is_finite(determinant) or absf(determinant) <= D.EPS: return {}
		transform = target.transform.affine_inverse() * source.transform
	else:
		for item in chain:
			if not item.transform.is_finite(): return {}
			transform = item.transform * transform
	return {"transform": transform} if transform.is_finite() else {}

static func raw_effective_transform(node: Node) -> Dictionary:
	var value := Transform3D.IDENTITY
	while node is Node3D:
		if not node.transform.is_finite(): return {}
		value = node.transform * value
		if node.top_level: break
		node = node.get_parent()
	return {"transform": value} if value.is_finite() else {}

static func marker_position(node: Node, world: Node, slot: int) -> Vector3:
	var placement := raw_transform(node, world)
	if not placement.is_empty():
		var transform: Transform3D = placement.transform
		if node is Box3DBody3D and slot >= 0 and slot < node.shapes.size() and node.shapes[slot] != null:
			var local: Transform3D = node.shapes[slot].local_pose
			if local.origin.is_finite() and (transform * local.origin).is_finite(): return transform * local.origin
		return transform.origin
	var parent := node.get_parent()
	while parent != null and parent != world:
		placement = raw_transform(parent, world)
		if not placement.is_empty(): return placement.transform.origin
		parent = parent.get_parent()
	return Vector3.ZERO # diagnostic at a valid ancestor, never replacement geometry

static func line(points: PackedVector3Array, colors: PackedColorArray, a: Vector3, b: Vector3, color: Color) -> void:
	points.append(a); points.append(b); colors.append(color)

static func append_fragment(result: Dictionary, points: PackedVector3Array, colors: PackedColorArray, limit: int) -> bool:
	for point in points:
		if not point.is_finite(): return false
	if points.size() != colors.size() * 2 or result.colors.size() + colors.size() > limit: return false
	result.points.append_array(points)
	result.colors.append_array(colors)
	return true

static func markers(context: Dictionary, selected: Node, result: Dictionary, limit: int) -> void:
	for node in context.nodes:
		if selected != context.world and selected != node: continue
		for problem in context.problems.get(node.get_instance_id(), []):
			var marker_key: String = str(node.get_instance_id()) + ":" + str(problem.slot) + ":" + problem.category
			if result.marked.has(marker_key): continue
			var position := marker_position(node, context.world, problem.slot)
			var color := RED if problem.category == "authoring" else AMBER
			var points := PackedVector3Array()
			var colors := PackedColorArray()
			for axis in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]: line(points, colors, position - axis * 0.15, position + axis * 0.15, color)
			if append_fragment(result, points, colors, limit): result.marked[marker_key] = true
			else:
				result.complete = false
				result.capacity_exceeded = true

static func geometry(context: Dictionary, selected: Node3D, services: Box3DEditorServices, limit: int) -> Dictionary:
	var world: Box3DWorld3D = context.world
	var result := {"ok": true, "complete": true, "capacity_exceeded": false, "omitted_shapes": 0, "points": PackedVector3Array(), "colors": PackedColorArray(), "marked": {}, "scope": "authored_only_no_frame_no_native"}
	if not context.frame_valid: return {"ok": false, "complete": false, "error": "WorldFrameInvalid", "diagnostics": context.diagnostics, "validation_status": "invalid"}
	var items: Array = []
	var sources: Array = []
	var bytes := 128
	for node in context.nodes:
		if selected != world and selected != node: continue
		if not node is Box3DBody3D: continue
		if not context.poses.has(node.get_instance_id()):
			result.omitted_shapes += node.shapes.size()
			result.complete = false
			continue
		if items.size() >= D.MAX_SHAPES:
			issue(context, node, "preview.shapes", "Capacity", "Preview shape capacity exceeded.", "preview")
			result.omitted_shapes += node.shapes.size()
			result.capacity_exceeded = true
			continue
		if node.shapes.size() > D.MAX_SHAPES:
			result.omitted_shapes += node.shapes.size() - D.MAX_SHAPES
			result.capacity_exceeded = true
		var shape_keys: Dictionary = {}
		for slot in range(mini(node.shapes.size(), D.MAX_SHAPES)):
			if items.size() >= D.MAX_SHAPES:
				result.omitted_shapes += mini(node.shapes.size(), D.MAX_SHAPES) - slot
				result.capacity_exceeded = true
				issue(context, node, "preview.shapes", "Capacity", "Preview shape capacity exceeded.", "preview")
				break
			var path := "bodies[" + D.relative_name(node, world) + "].shapes[%d]" % slot
			var shape: Box3DShape3D = node.shapes[slot]
			if shape == null:
				issue(context, node, path, "Reference", "Shape Resource is missing.", "authoring", slot)
				result.omitted_shapes += 1
				continue
			if shape_keys.has(shape.stable_key):
				issue(context, node, path + ".stable_key", "Duplicate", "Duplicate shape ID on this body.", "authoring", slot)
				var previous: int = int(shape_keys[shape.stable_key])
				issue(context, node, "bodies[" + D.relative_name(node, world) + "].shapes[%d].stable_key" % previous, "Duplicate", "Duplicate shape ID on this body.", "authoring", previous)
			shape_keys[shape.stable_key] = slot
			var errors: Array = []
			var input: Dictionary = shape.box3d_shape_definition(path, errors, ["static", "kinematic", "dynamic"][node.body_type], node._sensor_body())
			add_errors(context, node, errors, slot)
			if not finite_values(input):
				issue(context, node, path, "Nonfinite", "Shape values must fit finite float32 values.", "authoring", slot)
				result.omitted_shapes += 1
				continue
			if not D.rigid(shape.local_pose) or errors.any(func(error): return error.code != "Key"):
				result.omitted_shapes += 1
				continue
			var item := {"pose": context.poses[node.get_instance_id()], "body_type": ["static", "kinematic", "dynamic"][node.body_type], "sensor": node._sensor_body(), "shape": input}
			var size := JSON.stringify(item, "", true, true).to_utf8_buffer().size() + 1
			if items.size() >= D.MAX_SHAPES or bytes + size > D.MAX_BYTES:
				issue(context, node, path, "Capacity", "Preview input capacity exceeded.", "preview", slot)
				result.omitted_shapes += 1
				result.capacity_exceeded = true
				continue
			bytes += size
			items.append(item)
			sources.append({"node": node, "slot": slot, "path": path})
	markers(context, selected, result, limit)
	if not items.is_empty():
		var preview: Dictionary = services.preview_shapes(items, maxi(0, limit - result.colors.size())) if services != null else {"ok": false, "error": "ToolsUnavailable"}
		if not preview.get("ok", false) or preview.get("scope", "") != SCOPE:
			issue(context, selected, "preview", "Unavailable", "Shared shape preview unavailable: " + JSON.stringify(preview.get("diagnostic", preview.get("error", "ToolVersion"))), "preview")
			result.omitted_shapes += items.size()
			result.complete = false
		else:
			for record in preview.items:
				if record.available: continue
				var source: Dictionary = sources[int(record.index)]
				issue(context, source.node, source.path + "." + String(record.field), String(record.error), "Shared preview: " + String(record.error), "preview" if record.error in ["Capacity", "Allocation"] else "authoring", source.slot)
				result.omitted_shapes += 1
			result.capacity_exceeded = result.capacity_exceeded or preview.capacity_exceeded
			markers(context, selected, result, limit)
			for record in preview.items:
				if not record.available: continue
				var source: Dictionary = sources[int(record.index)]
				var points := PackedVector3Array()
				var colors := PackedColorArray()
				var invalid: bool = context.problems.get(source.node.get_instance_id(), []).any(func(problem): return problem.category == "authoring")
				for i in range(int(record.start), int(record.start + record.count)):
					var segment: Dictionary = preview.lines[i]
					line(points, colors, Vector3(segment.a[0], segment.a[1], segment.a[2]), Vector3(segment.b[0], segment.b[1], segment.b[2]), RED if invalid else Color(segment.color[0], segment.color[1], segment.color[2], segment.color[3]))
				if not append_fragment(result, points, colors, limit):
					issue(context, source.node, source.path, "Capacity", "Complete outline omitted at the preview line budget.", "preview", source.slot)
					result.capacity_exceeded = true
					result.omitted_shapes += 1
	_overlays(context, selected, result, limit)
	markers(context, selected, result, limit)
	var local := raw_transform(selected, world)
	var determinant: float = local.transform.basis.determinant() if not local.is_empty() else 0.0
	if local.is_empty() or not is_finite(determinant) or absf(determinant) <= D.EPS: return {"ok": false, "complete": false, "error": "GizmoFrameInvalid", "diagnostics": context.diagnostics, "validation_status": context.validation_status}
	var inverse: Transform3D = local.transform.affine_inverse()
	if not inverse.is_finite(): return {"ok": false, "complete": false, "error": "GizmoFrameInvalid", "diagnostics": context.diagnostics, "validation_status": context.validation_status}
	for i in range(result.points.size()):
		var point: Vector3 = inverse * result.points[i]
		if not point.is_finite(): return {"ok": false, "complete": false, "error": "GizmoFrameInvalid", "diagnostics": context.diagnostics, "validation_status": context.validation_status}
		result.points[i] = point
	result.lines = result.colors.size()
	result.complete = result.complete and result.omitted_shapes == 0 and not result.capacity_exceeded and not context.diagnostics_omitted
	result.validation_status = context.validation_status
	result.diagnostics = context.diagnostics.duplicate(true)
	result.markers = result.marked.size()
	result.erase("marked")
	return result

static func _overlays(context: Dictionary, selected: Node, result: Dictionary, limit: int) -> void:
	for node in context.nodes:
		if selected != context.world and selected != node: continue
		var points := PackedVector3Array()
		var colors := PackedColorArray()
		var errors: Array = []
		if node is Box3DJoint3D:
			node.box3d_joint_definition(context.world, "joints[" + D.relative_name(node, context.world) + "]", errors)
			add_errors(context, node, errors)
			var a: Array = context.bodies.get(node.body_a, [])
			var b: Array = context.bodies.get(node.body_b, [])
			if not reference_key_valid(node.body_a) or not reference_key_valid(node.body_b) or a.size() != 1 or b.size() != 1:
				issue(context, node, "joint.body_a/body_b", "Reference", "Joint endpoints must each resolve to exactly one body.")
				result.complete = false
				continue
			if errors.any(func(error): return error.code != "Key") or not context.poses.has(a[0].get_instance_id()) or not context.poses.has(b[0].get_instance_id()):
				result.complete = false
				continue
			if a[0].body_type == 0 and b[0].body_type == 0:
				issue(context, node, "joint.body_a/body_b", "Unsupported", "A joint cannot join two Static bodies.")
				result.complete = false
				continue
			var resolved: Dictionary = node.resolved_frames(context.world, "joint", errors)
			if resolved.is_empty():
				add_errors(context, node, errors)
				result.complete = false
				continue
			var pa: Transform3D = resolved.world_a
			var pb: Transform3D = resolved.world_b
			line(points, colors, pa.origin, pb.origin, Color.MAGENTA)
			for frame in [pa, pb]:
				line(points, colors, frame.origin, frame.origin + frame.basis.x * 0.3, Color.RED)
				line(points, colors, frame.origin, frame.origin + frame.basis.y * 0.3, Color.GREEN)
				line(points, colors, frame.origin, frame.origin + frame.basis.z * 0.3, Color.BLUE)
		elif node is Box3DCharacterMover3D:
			var character: Dictionary = node.box3d_character_definition(context.world, "characters[" + D.relative_name(node, context.world) + "]", errors)
			add_errors(context, node, errors)
			if not node.exclude_body.is_empty() and (not reference_key_valid(node.exclude_body) or context.bodies.get(node.exclude_body, []).size() != 1): issue(context, node, "character.exclude_body", "Reference", "Exclusion must resolve to one body in this World.")
			if errors.any(func(error): return error.code != "Key"):
				result.complete = false
				continue
			var p: Array = character.initial.position
			var position := Vector3(p[0], p[1], p[2])
			var capsule: Dictionary = character.config.capsule
			_capsule(points, colors, position + Vector3(capsule.center1[0], capsule.center1[1], capsule.center1[2]), position + Vector3(capsule.center2[0], capsule.center2[1], capsule.center2[2]), capsule.radius)
		if context.problems.get(node.get_instance_id(), []).any(func(problem): return problem.category == "authoring"):
			colors.fill(RED)
		if not points.is_empty() and not append_fragment(result, points, colors, limit):
			issue(context, node, "preview.overlay", "Capacity", "Complete overlay omitted at the preview budget.", "preview")
			result.complete = false
			result.capacity_exceeded = true

static func _capsule(points: PackedVector3Array, colors: PackedColorArray, a: Vector3, b: Vector3, radius: float) -> void:
	var axis := (b - a).normalized()
	var right := axis.cross(Vector3.RIGHT if absf(axis.x) < 0.8 else Vector3.UP).normalized()
	var forward := axis.cross(right)
	for i in range(16):
		var angle := TAU * float(i) / 16.0
		var next := TAU * float(i + 1) / 16.0
		var edge := radius * (right * cos(angle) + forward * sin(angle))
		var following := radius * (right * cos(next) + forward * sin(next))
		line(points, colors, a + edge, a + following, Color.ORANGE)
		line(points, colors, b + edge, b + following, Color.ORANGE)
		if i % 4 == 0: line(points, colors, a + edge, b + edge, Color.ORANGE)
	for radial in [right, forward]:
		for i in range(16):
			var angle := PI * float(i) / 16.0
			var next := PI * float(i + 1) / 16.0
			line(points, colors, a + radius * (radial * cos(angle) - axis * sin(angle)), a + radius * (radial * cos(next) - axis * sin(next)), Color.ORANGE)
			line(points, colors, b + radius * (radial * cos(angle) + axis * sin(angle)), b + radius * (radial * cos(next) + axis * sin(next)), Color.ORANGE)
