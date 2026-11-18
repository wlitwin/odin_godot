@tool
extends EditorPlugin

var addon: EditorPlugin
var probe: Node
var world: Box3DWorld3D

func _enter_tree() -> void:
	if OS.get_environment("BOX3D_PREVIEW_CHECK") == "1": call_deferred("run")

func need(ok: bool, message: String) -> bool:
	if not ok:
		push_error("BOX3D_PREVIEW_FAIL: " + message)
		if is_instance_valid(probe): probe.free()
		get_tree().quit(1)
	return ok

func frozen(value: Variant, seen: Dictionary = {}) -> Variant:
	if value is Resource:
		var id := str(value.get_instance_id())
		if seen.has(id): return {"ref": id}
		seen[id] = true
		var fields: Dictionary = {"instance": id}
		for property in value.get_property_list():
			if (property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0 and (property.usage & PROPERTY_USAGE_STORAGE) != 0:
				fields[property.name] = frozen(value.get(property.name), seen)
		return fields
	if value is Array:
		var output: Array = []
		for item in value: output.append(frozen(item, seen))
		return output
	if value is Dictionary:
		var output: Dictionary = {}
		for key in value: output[key] = frozen(value[key], seen)
		return output
	return var_to_str(value)

func state() -> Dictionary:
	var output: Dictionary = {}
	var seen: Dictionary = {}
	for node in Box3DEditorIdentity._nodes(world):
		var fields: Dictionary = {"transform": var_to_str(node.transform) if node is Node3D else "", "name": String(node.name)}
		for property in node.get_property_list():
			if (property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0 and (property.usage & PROPERTY_USAGE_STORAGE) != 0:
				fields[property.name] = frozen(node.get(property.name), seen)
		output[String(world.get_path_to(node))] = fields
	return output

func draw(node: Node3D, label: String, budget := Box3DAuthoringData.MAX_LINES) -> Dictionary:
	var before := state()
	var native_before: Dictionary = JSON.parse_string(probe.stats())
	var result: Dictionary = addon.gizmos.geometry_for(node, budget)
	var native_after: Dictionary = JSON.parse_string(probe.stats())
	if not need(native_before.get("ok", false) and native_after == native_before, label + ": native allocations changed"): return {}
	if not need(state() == before, label + ": preview mutated authoring properties or Resources"): return {}
	if result.get("ok", false):
		if not need(result.points.size() == result.lines * 2 and result.colors.size() == result.lines and result.lines <= budget, label + ": bounded line result"): return {}
		for point in result.points:
			if not need(point.is_finite(), label + ": nonfinite draw point"): return {}
	return result

func strict_rejects(label: String) -> bool:
	return need(not addon.inspect_object(world).get("ok", true), label + ": strict validation accepted invalid world")

func contains_near(result: Dictionary, position: Vector3) -> bool:
	if not result.get("ok", false): return false
	for point in result.points:
		if point.distance_to(position) < 2: return true
	return false

func make_body(parent: Node, name_: String, position: Vector3, shapes: Array[Box3DShape3D]) -> Box3DBody3D:
	var body := Box3DBody3D.new()
	body.name = name_; body.stable_key = name_; body.position = position; body.body_type = 2; body.shapes = shapes
	parent.add_child(body); body.owner = parent
	return body

func make_world() -> Box3DWorld3D:
	var value := Box3DWorld3D.new(); value.name = "World"; value.stable_key = "preview.world"
	var box := Box3DBoxShape3D.new(); box.stable_key = "box"
	var sphere := Box3DSphereShape3D.new(); sphere.stable_key = "sphere"
	make_body(value, "A", Vector3.ZERO, [box])
	make_body(value, "B", Vector3(5, 0, 0), [sphere])
	var first := Box3DBoxShape3D.new(); first.stable_key = "first"
	var second := Box3DBoxShape3D.new(); second.stable_key = "second"; second.local_pose.origin = Vector3(1.5, 0, 0)
	var third := Box3DSphereShape3D.new(); third.stable_key = "third"
	make_body(value, "C", Vector3(10, 0, 0), [first, second, third])
	var joint := Box3DPinJoint3D.new(); joint.frame_mode = Box3DJoint3D.FrameMode.BODY_LOCAL; joint.name = "Joint"; joint.stable_key = "joint"; joint.body_a = "A"; joint.body_b = "B"
	value.add_child(joint); joint.owner = value
	var character := Box3DCharacterMover3D.new(); character.name = "Character"; character.stable_key = "character"; character.position = Vector3(15, 0, 0); character.exclude_body = "A"
	value.add_child(character); character.owner = value
	return value

func run() -> void:
	for _frame in 5: await get_tree().process_frame
	var plugins := get_tree().get_nodes_in_group("box3d_authoring_editor_plugin")
	if not need(plugins.size() == 1, "real plugin registration"): return
	addon = plugins[0]
	if not need(addon.services.available(), "ordinary compiled tool module"): return
	probe = Node.new(); probe.set_script(load("res://modules/probe/probe.odin")); add_child(probe)
	var source := make_world()
	var packed := PackedScene.new()
	if not need(packed.pack(source) == OK and ResourceSaver.save(packed, "res://preview.tscn") == OK, "save fixture"): return
	source.free(); packed = null
	get_editor_interface().open_scene_from_path("res://preview.tscn")
	for _frame in 6: await get_tree().process_frame
	world = get_editor_interface().get_edited_scene_root()
	get_editor_interface().set_main_screen_editor("3D")
	get_editor_interface().edit_node(world)
	world.update_gizmos()
	for _frame in 3: await get_tree().process_frame
	var a: Box3DBody3D = world.get_node("A")
	var b: Box3DBody3D = world.get_node("B")
	var c: Box3DBody3D = world.get_node("C")
	var joint: Box3DJoint3D = world.get_node("Joint")
	var character: Box3DCharacterMover3D = world.get_node("Character")
	var baseline := draw(world, "valid")
	if not need(baseline.get("ok", false) and baseline.complete and baseline.validation_status == "valid" and baseline.markers == 0, "complete valid preview"): return
	if not need(addon.gizmos.redraw_count > 0, "actual gizmo callback"): return
	var actual_gizmo: EditorNode3DGizmo
	for gizmo in c.get_gizmos():
		if gizmo.get_plugin() == addon.gizmos: actual_gizmo = gizmo; break
	if not need(actual_gizmo != null, "actual body gizmo instance"): return
	addon.gizmos._redraw(actual_gizmo)
	var manager := get_undo_redo()
	manager.create_action("Edit preview radius", UndoRedo.MERGE_DISABLE, world)
	manager.add_do_property(c.shapes[2], &"radius", -1.0)
	manager.add_undo_property(c.shapes[2], &"radius", 0.5)
	manager.commit_action()
	addon.gizmos._redraw(actual_gizmo)
	if not need(addon.gizmos.last_status.omitted_shapes == 1 and addon.gizmos.last_status.validation_status == "invalid", "editor edit invalidates cached validation in the same frame"): return
	manager.get_history_undo_redo(manager.get_object_history_id(world)).undo()
	addon.gizmos._redraw(actual_gizmo)
	if not need(addon.gizmos.last_status.complete and addon.gizmos.last_status.validation_status == "valid", "editor undo restores cached preview"): return
	b.stable_key = "A"
	var partial := draw(world, "duplicate body ID")
	if not need(contains_near(partial, Vector3(10, 0, 0)) and partial.markers >= 3 and partial.validation_status == "invalid" and not partial.complete, "duplicate does not blank geometry or choose a joint endpoint"): return
	if not strict_rejects("duplicate ID"): return
	b.stable_key = "B"
	a.stable_key = ""
	partial = draw(world, "missing body ID")
	if not need(contains_near(partial, Vector3.ZERO) and contains_near(partial, Vector3(10, 0, 0)) and partial.markers > 0, "missing ID retains authored outlines"): return
	if not strict_rejects("missing ID"): return
	a.stable_key = "A"
	var old_keys := [c.shapes[0].stable_key, c.shapes[1].stable_key, c.shapes[2].stable_key]
	c.shapes[1].stable_key = old_keys[0]; c.shapes[2].stable_key = old_keys[0]
	var slots := draw(c, "duplicate shape slots")
	if not need(slots.markers >= 3 and slots.complete and slots.validation_status == "invalid", "each duplicate slot is marked without hiding its outline"): return
	for i in range(3): c.shapes[i].stable_key = old_keys[i]
	a.stable_key = ""; joint.body_a = ""
	var missing_endpoint := draw(joint, "empty endpoint with empty body ID")
	if not need(missing_endpoint.markers > 0 and not missing_endpoint.complete and missing_endpoint.lines == 3, "empty references never resolve to an unkeyed body"): return
	a.stable_key = "A"; joint.body_a = "A"
	a.shapes[0].density = 1.0e100
	var overflow := draw(world, "float32 overflow in one shape")
	if not need(contains_near(overflow, Vector3(5, 0, 0)) and overflow.omitted_shapes == 1, "scalar overflow cannot poison the whole preview request"): return
	a.shapes[0].density = 1.0
	var box_key: String = a.shapes[0].stable_key
	var sphere_key: String = b.shapes[0].stable_key
	a.shapes[0].stable_key = "conflict"; b.shapes[0].stable_key = "conflict"
	var conflict := draw(world, "conflicting shared geometry")
	if not need(conflict.validation_status == "invalid" and conflict.markers >= 2 and contains_near(conflict, Vector3(10, 0, 0)), "all conflicting resource users are marked"): return
	a.shapes[0].stable_key = box_key; b.shapes[0].stable_key = sphere_key
	var hinge := Box3DHingeJoint3D.new(); hinge.frame_mode = Box3DJoint3D.FrameMode.BODY_LOCAL; hinge.name = "Hinge"; hinge.stable_key = "hinge"; hinge.body_a = "A"; hinge.body_b = "B"
	hinge.settings.flags = 2; hinge.settings.lower = -4; hinge.settings.upper = 4
	world.add_child(hinge); hinge.owner = world
	var shared_joint := draw(hinge, "shared-only hinge diagnostic")
	if not need(shared_joint.markers > 0 and shared_joint.validation_status == "invalid" and shared_joint.diagnostics.any(func(problem): return problem.node_path == "Hinge" and problem.path == "joint.hinge_angles"), "shared joint failure belongs to its actual node"): return
	hinge.free()
	c.shapes[2].radius = -1
	partial = draw(world, "one invalid sibling shape")
	var local := draw(c, "selected body with bad shape")
	if not need(contains_near(partial, Vector3(5, 0, 0)) and local.lines >= 24 and local.omitted_shapes == 1 and local.markers > 0, "valid siblings and unrelated bodies survive bad shape"): return
	if not strict_rejects("invalid radius"): return
	c.shapes[2].radius = 0.5
	c.scale = Vector3(2, 1, 1)
	partial = draw(world, "invalid transform")
	if not need(contains_near(partial, Vector3(5, 0, 0)) and partial.omitted_shapes == 3 and partial.markers > 0, "bad transform omits only its body geometry"): return
	c.scale = Vector3.ONE
	c.scale = Vector3(1.0e30, 1.0e30, 1.0e30)
	local = draw(c, "overflowing gizmo inverse")
	if not need(not local.get("ok", true) and local.error == "GizmoFrameInvalid", "overflowing inverse is never published"): return
	partial = draw(world, "huge invalid body with valid neighbors")
	if not need(contains_near(partial, Vector3(5, 0, 0)), "World preview retains neighbors of huge invalid transform"): return
	c.scale = Vector3.ONE
	world.stable_key = ""
	partial = draw(world, "invalid namespace")
	if not need(contains_near(partial, Vector3(10, 0, 0)) and partial.validation_status == "invalid", "namespace error does not prevent geometry collection"): return
	world.stable_key = "preview.world"
	world.contact_hertz = -1
	partial = draw(world, "invalid solver setting")
	if not need(contains_near(partial, Vector3(5, 0, 0)), "solver setting does not blank geometry"): return
	world.contact_hertz = 0
	joint.body_b = "missing"
	partial = draw(world, "missing joint endpoint")
	if not need(contains_near(partial, Vector3(10, 0, 0)) and partial.markers > 0 and not partial.complete, "bad joint preserves shapes"): return
	joint.body_b = "B"
	character.exclude_body = "missing"
	local = draw(character, "invalid exclusion")
	if not need(local.lines >= 100 and local.markers > 0 and local.validation_status == "invalid", "valid capsule survives bad exclusion"): return
	character.exclude_body = "A"
	character.config.radius = -1
	partial = draw(world, "invalid character")
	if not need(contains_near(partial, Vector3(5, 0, 0)) and not partial.complete, "invalid character does not erase shapes"): return
	character.config.radius = 0.5
	local = draw(c, "small budget", 20)
	if not need(local.lines >= 12 and local.lines <= 20 and local.capacity_exceeded and not local.complete, "capacity preserves complete small outlines"): return
	var restored := draw(world, "fixed scene")
	if not need(restored.complete and restored.validation_status == "valid" and restored.points == baseline.points and restored.colors == baseline.colors, "fix restores exact valid preview"): return
	var unavailable := Box3DAuthoringGizmoPlugin.new()
	local = unavailable.geometry_for(a)
	if not need(local.get("ok", false) and not local.complete and local.markers > 0 and local.validation_status == "unavailable", "unavailable tools produce honest markers"): return
	world.scale = Vector3(2, 1, 1)
	local = draw(world, "invalid World frame")
	if not need(not local.get("ok", true) and local.error == "WorldFrameInvalid", "invalid World frame never becomes an identity fallback"): return
	world.scale = Vector3.ONE
	probe.free(); probe = null
	get_editor_interface().save_scene_as("res://preview.tscn", false)
	if not need(get_editor_interface().close_scene() == OK, "close watched scene"): return
	world = null
	for _frame in 3: await get_tree().process_frame
	get_editor_interface().open_scene_from_path("res://preview.tscn")
	for _frame in 5: await get_tree().process_frame
	get_editor_interface().set_plugin_enabled("box3d_authoring", false)
	for _frame in 3: await get_tree().process_frame
	print("BOX3D_PREVIEW_LIFECYCLE_OK")
	print("BOX3D_PARTIAL_PREVIEW_OK")
	get_tree().quit()
