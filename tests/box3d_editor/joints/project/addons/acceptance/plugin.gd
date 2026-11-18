@tool
extends EditorPlugin

func _enter_tree() -> void:
	if OS.get_environment("BOX3D_JOINT_CHECK") == "1": call_deferred("run")

func need(ok: bool, message: String) -> bool:
	if not ok:
		push_error("BOX3D_JOINT_FAIL: " + message)
		get_tree().quit(1)
	return ok

func own(root: Node, node: Node) -> void:
	for child in node.get_children(): child.owner = root; own(root, child)

func fixture() -> Node3D:
	var scene := Node3D.new(); scene.name = "Scene"
	scene.transform = Transform3D(Basis(Vector3.UP, 0.3), Vector3(3, 4, 5))
	var world := Box3DWorld3D.new(); world.name = "World"; world.stable_key = "joint.world"
	world.transform = Transform3D(Basis(Vector3.RIGHT, 0.2), Vector3(5, -1, 2)); scene.add_child(world)
	var shape := Box3DBoxShape3D.new(); shape.stable_key = "shared"
	for spec in [["GroupA", "A", "a", Transform3D(Basis(Vector3.BACK, 0.4), Vector3(1, 2, 3)), Transform3D(Basis(Vector3.UP, -0.2), Vector3(-2, 1, 0.5))], ["GroupB", "B", "b", Transform3D(Basis(Vector3.RIGHT, -0.3), Vector3(-3, 2, 0)), Transform3D(Basis(Vector3.BACK, 0.8), Vector3(6, 1, 2))]]:
		var group := Node3D.new(); group.name = spec[0]; group.transform = spec[3]; world.add_child(group)
		var body := Box3DBody3D.new(); body.name = spec[1]; body.stable_key = spec[2]; body.transform = spec[4]; body.body_type = 2; body.shapes = [shape]; group.add_child(body)
	var choice := Box3DBody3D.new(); choice.name = "Choice"; choice.stable_key = "choice"; choice.body_type = 2; choice.shapes = [shape]; world.add_child(choice)
	var group := Node3D.new(); group.name = "JointParent"; group.transform = Transform3D(Basis(Vector3.UP, 0.6), Vector3(0, 3, -2)); world.add_child(group)
	var joint := Box3DHingeJoint3D.new(); joint.name = "Hinge"; joint.stable_key = "hinge"; joint.body_a = "a"; joint.body_b = "b"
	joint.transform = Transform3D(Basis(Vector3.BACK, 0.7), Vector3(2, -1, 3))
	joint.anchor_b_offset = Transform3D(Basis(Vector3.RIGHT, 0.45), Vector3(3, 0, -1)); group.add_child(joint)
	var nested := Box3DWorld3D.new(); nested.name = "Nested"; nested.stable_key = "nested"; world.add_child(nested)
	var hidden := Box3DBody3D.new(); hidden.name = "Hidden"; hidden.stable_key = "a"; hidden.shapes = [shape]; nested.add_child(hidden)
	own(scene, scene)
	return scene

func picker_for(joint: Box3DJoint3D, property: StringName) -> Box3DBodyPicker:
	for control in get_editor_interface().get_inspector().find_children("*", "", true, false):
		if control is Box3DBodyPicker and control.get_edited_object() == joint and control.get_edited_property() == property: return control
	return null

func mode_control(joint: Box3DJoint3D) -> Box3DJointControl:
	for control in get_editor_interface().get_inspector().find_children("*", "", true, false):
		if control is Box3DJointControl and control.target.get_ref() == joint: return control
	return null

func frames(joint: Box3DJoint3D, world: Node3D) -> Dictionary:
	var errors: Array = []
	var result := joint.resolved_frames(world, "test", errors)
	if not need(errors.is_empty() and not result.is_empty(), "valid frame resolution: " + str(errors)): return {}
	return result

func check_plain_groups(addon: EditorPlugin, scene: Node3D, world: Box3DWorld3D, camera: Camera3D) -> bool:
	var ignored := Node3D.new(); ignored.name = "IgnoredTransform"; ignored.scale = Vector3(2, 1, 1); world.add_child(ignored); ignored.owner = scene
	var group := Node.new(); group.name = "PlainGroup"; ignored.add_child(group); group.owner = scene
	var body := Box3DBody3D.new(); body.name = "GapBody"; body.stable_key = "gap.body"; body.body_type = 2; body.transform = Transform3D(Basis(Vector3.UP, 0.4), Vector3(1, 2, 3)); body.shapes = [Box3DSphereShape3D.new()]
	group.add_child(body); body.owner = scene
	var joint := Box3DPinJoint3D.new(); joint.name = "GapJoint"; joint.stable_key = "gap.joint"; joint.body_a = "a.rekeyed"; joint.body_b = "gap.body"
	joint.transform = Transform3D(Basis(Vector3.RIGHT, 0.2), Vector3(2, 3, 4)); joint.anchor_b_offset.origin = Vector3(1, 0, 0)
	group.add_child(joint); joint.owner = scene
	var expected: Transform3D = world.global_transform.affine_inverse() * joint.global_transform
	var resolved := frames(joint, world)
	if not need(joint.global_transform == joint.transform and resolved.world_a.is_equal_approx(expected), "plain Node stops native transform inheritance"): return false
	var errors: Array = []
	var body_pose := joint._transform(Box3DAuthoringData.relative_pose(body, world, "gap.body", errors))
	if not need(errors.is_empty() and body_pose.is_equal_approx(world.global_transform.affine_inverse() * body.global_transform), "body extraction follows native plain-Node grouping"): return false
	var before := frames(joint, world)
	for mode in [Box3DJoint3D.FrameMode.BODY_LOCAL, Box3DJoint3D.FrameMode.VIEWPORT]:
		var result := Box3DEditorIdentity.apply_plan(Box3DEditorJoints.plan_mode(joint, mode, scene), get_undo_redo())
		if not need(result.get("ok", false) and frames(joint, world).world_a.is_equal_approx(before.world_a) and frames(joint, world).world_b.is_equal_approx(before.world_b), "mode conversion across plain Node parent"): return false
	joint.update_gizmos()
	for _frame in 3: await get_tree().process_frame
	var gizmo: EditorNode3DGizmo
	for item in joint.get_gizmos():
		if item.get_plugin() == addon.gizmos: gizmo = item; break
	if not need(gizmo != null, "plain-group joint has a viewport handle"): return false
	var anchor: Vector3 = world.global_transform * frames(joint, world).world_b.origin
	camera.global_position = anchor + Vector3(0, 0, 15); camera.look_at(anchor, Vector3.UP)
	var target := anchor + Vector3(0.75, 0.25, 0)
	var restore: Dictionary = addon.gizmos._get_handle_value(gizmo, 1, false)
	addon.gizmos._set_handle(gizmo, 1, false, camera, camera.unproject_position(target))
	addon.gizmos._commit_handle(gizmo, 1, false, restore, false)
	if not need((world.global_transform * frames(joint, world).world_b.origin).distance_to(target) < 0.001, "plain-group dragging agrees with extracted anchors"): return false
	print("BOX3D_JOINT_PLAIN_GROUP_OK")
	return true

func check_refused_placement(scene: Node3D, world: Box3DWorld3D) -> bool:
	var parent_joint := Box3DPinJoint3D.new(); parent_joint.name = "AncestorJoint"; parent_joint.stable_key = "ancestor.joint"; parent_joint.frame_mode = Box3DJoint3D.FrameMode.BODY_LOCAL
	world.add_child(parent_joint); parent_joint.owner = scene
	var child := Box3DBody3D.new(); child.name = "ChildBody"; child.stable_key = "child.body"; child.body_type = 2; child.position = Vector3(2, 0, 0); child.shapes = [Box3DSphereShape3D.new()]
	parent_joint.add_child(child); child.owner = scene
	parent_joint.body_a = "child.body"; parent_joint.body_b = "b"; parent_joint.local_frame_a.origin = Vector3(1, 0, 0)
	var before := world.box3d_definition_json()
	var plan := Box3DEditorJoints.plan_mode(parent_joint, Box3DJoint3D.FrameMode.VIEWPORT, scene)
	var refused: bool = not plan.get("ok", true) and world.box3d_definition_json() == before
	parent_joint.free()
	if not need(refused, "conversion cannot silently move a referenced child body"): return false
	var isolated := Box3DWorld3D.new(); isolated.stable_key = "extreme"
	var a := Box3DBody3D.new(); a.stable_key = "a"; a.position = Vector3(-3e38, 0, 0); isolated.add_child(a); a.owner = isolated
	var b := Box3DBody3D.new(); b.stable_key = "b"; b.position = Vector3(3e38, 0, 0); isolated.add_child(b); b.owner = isolated
	var joint := Box3DPinJoint3D.new(); joint.body_a = "a"; joint.body_b = "b"; isolated.add_child(joint); joint.owner = isolated
	plan = Box3DEditorJoints.plan_body_origins(joint, isolated)
	refused = not plan.get("ok", true) and joint.transform == Transform3D.IDENTITY and joint.anchor_b_offset == Transform3D.IDENTITY
	isolated.free()
	return need(refused, "overflowing body-origin placement is refused atomically")

func run() -> void:
	for _frame in 4: await get_tree().process_frame
	var plugins := get_tree().get_nodes_in_group("box3d_authoring_editor_plugin")
	if not need(plugins.size() == 1, "registered plugin"): return
	var addon: EditorPlugin = plugins[0]
	var source := fixture()
	var source_world: Box3DWorld3D = source.get_node("World")
	var detached := source_world.box3d_definition()
	if not need(not detached.is_empty(), "detached viewport extraction"): return
	var packed := PackedScene.new()
	if not need(packed.pack(source) == OK and ResourceSaver.save(packed, "res://joint.tscn") == OK, "save fixture"): return
	source.free(); packed = null
	get_editor_interface().open_scene_from_path("res://joint.tscn")
	for _frame in 6: await get_tree().process_frame
	var scene := get_editor_interface().get_edited_scene_root()
	var world: Box3DWorld3D = scene.get_node("World")
	var a: Box3DBody3D = world.get_node("GroupA/A")
	var b: Box3DBody3D = world.get_node("GroupB/B")
	var choice: Box3DBody3D = world.get_node("Choice")
	var joint: Box3DJoint3D = world.get_node("JointParent/Hinge")
	var history := get_undo_redo().get_history_undo_redo(get_undo_redo().get_object_history_id(scene))
	if not need(world.box3d_definition() == detached and joint.frame_mode == Box3DJoint3D.FrameMode.VIEWPORT, "saved default viewport mode"): return
	var wa: Transform3D = a.get_parent().transform * a.transform
	var wb: Transform3D = b.get_parent().transform * b.transform
	var j: Transform3D = joint.get_parent().transform * joint.transform
	var resolved := frames(joint, world)
	if not need(resolved.a.is_equal_approx(wa.affine_inverse() * j) and resolved.b.is_equal_approx(wb.affine_inverse() * j * joint.anchor_b_offset), "independent transformed-parent derivation"): return
	get_editor_interface().set_main_screen_editor("3D")
	get_editor_interface().edit_node(joint)
	joint.update_gizmos()
	for _frame in 4: await get_tree().process_frame
	var picker := picker_for(joint, &"body_a")
	if not need(picker != null and mode_control(joint) != null, "actual body picker and mode controls"): return
	var choice_index := -1
	for i in range(picker.choices.item_count):
		if not need(not "Hidden" in picker.choices.get_item_text(i), "picker excludes nested World"): return
		if picker.choices.get_item_metadata(i) == "choice": choice_index = i
	if not need(choice_index >= 0, "named choice exists"): return
	picker.choices.item_selected.emit(choice_index)
	if not need(joint.body_a == "choice" and frames(joint, world).world_a.is_equal_approx(j), "picker retarget keeps viewport anchor"): return
	history.undo()
	if not need(joint.body_a == "a", "picker undo"): return
	a.name = "RenamedA"
	picker._update_property()
	if not need("RenamedA" in picker.choices.get_item_text(picker.choices.selected), "picker refreshes renamed body label"): return
	var rekeyed: Dictionary = addon.rekey_object(a, "a.rekeyed")
	if not need(rekeyed.get("ok", false) and joint.body_a == "a.rekeyed", "picker uses remapped stable ID"): return
	for _frame in 3: await get_tree().process_frame
	picker = picker_for(joint, &"body_a")
	choice.stable_key = "a.rekeyed"; picker._update_property()
	if not need(picker.choices.get_item_text(picker.choices.selected).begins_with("Ambiguous body:"), "duplicate IDs never choose an arbitrary body"): return
	choice.stable_key = "choice"
	joint.body_a = "missing"; picker._update_property()
	if not need(joint.body_a == "missing" and picker.choices.get_item_text(picker.choices.selected).begins_with("Missing body:"), "missing reference remains visible"): return
	joint.body_a = "a.rekeyed"; picker._update_property()
	var original := frames(joint, world)
	mode_control(joint).modes.item_selected.emit(1)
	if not need(joint.frame_mode == Box3DJoint3D.FrameMode.BODY_LOCAL and frames(joint, world).world_a.is_equal_approx(original.world_a) and frames(joint, world).world_b.is_equal_approx(original.world_b), "viewport to explicit preserves both frames"): return
	var explicit_a := joint.local_frame_a
	var explicit_b := joint.local_frame_b
	joint.position += Vector3(1, 2, 3)
	if not need(frames(joint, world).a == explicit_a and frames(joint, world).b == explicit_b, "explicit frames are independent of the editor marker"): return
	joint.local_frame_b.basis = Basis(Vector3.UP, 0.25) * joint.local_frame_b.basis
	var advanced := frames(joint, world)
	for _frame in 3: await get_tree().process_frame
	mode_control(joint).modes.item_selected.emit(0)
	if not need(joint.frame_mode == Box3DJoint3D.FrameMode.VIEWPORT and frames(joint, world).world_a.is_equal_approx(advanced.world_a) and frames(joint, world).world_b.is_equal_approx(advanced.world_b), "explicit to viewport preserves independent endpoint orientation"): return
	history.undo(); history.redo()
	if not need(frames(joint, world).world_b.is_equal_approx(advanced.world_b), "mode conversion undo/redo"): return
	var gizmo: EditorNode3DGizmo
	for item in joint.get_gizmos():
		if item.get_plugin() == addon.gizmos: gizmo = item; break
	if not need(gizmo != null, "actual registered joint gizmo"): return
	var camera := get_editor_interface().get_editor_viewport_3d(0).get_camera_3d()
	var global_anchor: Vector3 = world.global_transform * frames(joint, world).world_b.origin
	camera.global_position = global_anchor + Vector3(0, 0, 20)
	camera.look_at(global_anchor, Vector3.UP)
	var target := global_anchor + camera.global_transform.basis.x * 1.2 + camera.global_transform.basis.y * 0.6
	var screen := camera.unproject_position(target)
	var restore: Dictionary = addon.gizmos._get_handle_value(gizmo, 1, false)
	var version := history.get_version()
	addon.gizmos._set_handle(gizmo, 1, false, camera, screen)
	if not need(not joint.anchor_b_offset.is_equal_approx(restore.value), "viewport B handle moves"): return
	addon.gizmos._commit_handle(gizmo, 1, false, restore, true)
	if not need(joint.anchor_b_offset == restore.value and history.get_version() == version, "handle cancel restores exact value without history"): return
	addon.gizmos._set_handle(gizmo, 1, false, camera, screen)
	var moved := joint.anchor_b_offset
	addon.gizmos._commit_handle(gizmo, 1, false, restore, false)
	if not need((world.global_transform * frames(joint, world).world_b.origin).distance_to(target) < 0.001, "projected handle reaches expected world point"): return
	history.undo()
	if not need(joint.anchor_b_offset == restore.value, "handle undo"): return
	history.redo()
	if not need(joint.anchor_b_offset == moved, "handle redo"): return
	var invalid_parent: Node3D = joint.get_parent()
	invalid_parent.scale = Vector3(2, 1, 1)
	if not need(world.box3d_definition().is_empty() and not Box3DEditorJoints.plan_mode(joint, 1, scene).get("ok", true), "invalid ancestry rejected without conversion"): return
	invalid_parent.scale = Vector3.ONE
	if not await check_plain_groups(addon, scene, world, camera): return
	if not check_refused_placement(scene, world): return
	get_editor_interface().save_scene_as("res://joint-final.tscn", false)
	var file := FileAccess.open("res://joint-expected.json", FileAccess.WRITE)
	file.store_string(world.box3d_definition_json()); file.close()
	print("BOX3D_JOINT_EDITOR_OK")
	get_tree().quit()
