@tool
extends EditorPlugin

var failed := false

func _enter_tree() -> void:
	if OS.get_environment("BOX3D_IDENTITY_CHECK") == "1": call_deferred("run")

func need(ok: bool, message: String) -> bool:
	if not ok:
		failed = true
		push_error("BOX3D_IDENTITY_FAIL: " + message)
		get_tree().quit(1)
	return ok

func own(root: Node, node: Node) -> void:
	for child in node.get_children():
		child.owner = root
		own(root, child)

func body(parent: Node, name_: String, shape: Box3DShape3D) -> Box3DBody3D:
	var result := Box3DBody3D.new()
	result.name = name_
	result.body_type = 2
	result.shapes = [shape]
	parent.add_child(result)
	return result

func fixture() -> Node3D:
	var scene := Node3D.new()
	scene.name = "IdentityScene"
	var world := Box3DWorld3D.new()
	world.name = "World"
	scene.add_child(world)
	var shape := Box3DSphereShape3D.new()
	var a := body(world, "A", shape)
	var b := body(world, "B", shape)
	var external := body(world, "External", shape)
	var joint := Box3DPinJoint3D.new(); joint.frame_mode = Box3DJoint3D.FrameMode.BODY_LOCAL
	joint.name = "Inside"
	joint.body_a = a.stable_key
	joint.body_b = b.stable_key
	world.add_child(joint)
	var outside := Box3DPinJoint3D.new(); outside.frame_mode = Box3DJoint3D.FrameMode.BODY_LOCAL
	outside.name = "Outside"
	outside.body_a = a.stable_key
	outside.body_b = external.stable_key
	world.add_child(outside)
	var character := Box3DCharacterMover3D.new()
	character.name = "Character"
	character.exclude_body = b.stable_key
	world.add_child(character)
	var nested := Box3DWorld3D.new()
	nested.name = "Nested"
	world.add_child(nested)
	var nested_body := body(nested, "A", shape)
	nested_body.stable_key = a.stable_key
	var other := body(nested, "Other", shape)
	var nested_joint := Box3DPinJoint3D.new(); nested_joint.frame_mode = Box3DJoint3D.FrameMode.BODY_LOCAL
	nested_joint.name = "Joint"
	nested_joint.body_a = a.stable_key
	nested_joint.body_b = other.stable_key
	nested.add_child(nested_joint)
	own(scene, scene)
	return scene

func save_prefab(node: Node, path: String) -> bool:
	if String(node.name).is_empty(): node.name = "Prefab"
	own(node, node)
	var packed := PackedScene.new()
	var ok := packed.pack(node) == OK and ResourceSaver.save(packed, path) == OK
	node.free()
	return need(ok, "save prefab " + path)

func prefab_graph(as_world: bool) -> Node3D:
	var node: Node3D = Box3DWorld3D.new() if as_world else Node3D.new()
	var shape := Box3DSphereShape3D.new()
	shape.resource_local_to_scene = true
	var p := body(node, "P", shape)
	var q := body(node, "Q", shape)
	var joint := Box3DPinJoint3D.new(); joint.frame_mode = Box3DJoint3D.FrameMode.BODY_LOCAL
	joint.name = "Link"
	joint.body_a = p.stable_key
	joint.body_b = q.stable_key
	node.add_child(joint)
	return node

func instantiate_prefab(path: String, parent: Node, owner: Node, name_: String) -> Node:
	var packed: PackedScene = load(path)
	var node := packed.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	node.name = name_
	parent.add_child(node)
	node.owner = owner
	return node

func check_instances(addon: EditorPlugin, scene: Node, world: Box3DWorld3D) -> bool:
	var local := Box3DSphereShape3D.new()
	local.resource_local_to_scene = true
	var body_source := Box3DBody3D.new()
	body_source.body_type = 2
	body_source.shapes = [local]
	if not save_prefab(body_source, "res://body-prefab.tscn"): return false
	var instance: Box3DBody3D = instantiate_prefab("res://body-prefab.tscn", world, scene, "BodyInstance")
	var result: Dictionary = addon.duplicate_nodes([instance])
	if not need(result.get("ok", false), "duplicate body instance: " + str(result)): return false
	var copy: Box3DBody3D = result.nodes[0]
	if not need(copy.scene_file_path == instance.scene_file_path and copy.stable_key != instance.stable_key, "body instance keeps source with distinct ID"): return false
	if not need(copy.shapes[0] != instance.shapes[0] and copy.shapes[0].resource_local_to_scene, "local-to-scene shape stays private"): return false
	copy.shapes[0].friction = 0.75
	if not need(instance.shapes[0].friction == 0.5, "private shape edits do not mutate source"): return false
	if not save_prefab(prefab_graph(true), "res://world-prefab.tscn"): return false
	var wi: Box3DWorld3D = instantiate_prefab("res://world-prefab.tscn", scene, scene, "WorldInstance")
	result = addon.duplicate_nodes([wi])
	if not need(result.get("ok", false), "duplicate closed World instance: " + str(result)): return false
	var wc: Box3DWorld3D = result.nodes[0]
	if not need(wi.stable_key != wc.stable_key and wi.get_node("P").stable_key == wc.get_node("P").stable_key, "whole-World duplicate changes only namespace"): return false
	if not need(wc.get_node("Link").body_a == wc.get_node("P").stable_key, "whole-World references retain local keys"): return false
	if not need(wc.get_node("P").shapes[0] != wi.get_node("P").shapes[0] and wc.get_node("P").shapes[0] == wc.get_node("Q").shapes[0], "private World geometry isolation and internal sharing"): return false
	var old_key: String = wi.get_node("P").stable_key
	result = addon.rekey_object(wi.get_node("P"), "instance.body")
	if not need(not result.get("ok", true) and wi.get_node("P").stable_key == old_key, "closed instance child edit refused without mutation"): return false
	scene.set_editable_instance(wi, true)
	result = addon.rekey_object(wi.get_node("P"), "instance.body")
	if not need(result.get("ok", false) and wi.get_node("Link").body_a == "instance.body", "editable child key and incoming override"): return false
	if not save_prefab(prefab_graph(false), "res://group-prefab.tscn"): return false
	var group := instantiate_prefab("res://group-prefab.tscn", world, scene, "GroupInstance")
	scene.set_editable_instance(group, true)
	result = addon.duplicate_nodes([group])
	if not need(result.get("ok", false), "duplicate editable non-World instance: " + str(result)): return false
	var group_copy: Node = result.nodes[0]
	if not need(group_copy.get_node("P").stable_key != group.get_node("P").stable_key and group_copy.get_node("Link").body_a == group_copy.get_node("P").stable_key, "editable instance child IDs and references"): return false
	print("BOX3D_IDENTITY_INSTANCES_OK")
	return true

func check_inherited(addon: EditorPlugin) -> bool:
	var file := FileAccess.open("res://identity-derived.tscn", FileAccess.WRITE)
	file.store_string('[gd_scene load_steps=2 format=3]\n[ext_resource type="PackedScene" path="res://identity-seed.tscn" id="1"]\n[node name="Derived" instance=ExtResource("1")]\n')
	file.close()
	get_editor_interface().open_scene_from_path("res://identity-derived.tscn")
	for _frame in 6: await get_tree().process_frame
	var scene := get_editor_interface().get_edited_scene_root()
	var b: Box3DBody3D = scene.get_node("World/B")
	var result: Dictionary = addon.rekey_object(b, "inherited.body")
	if not need(result.get("ok", false) and scene.get_node("World/Inside").body_b == "inherited.body" and scene.get_node("World/Character").exclude_body == "inherited.body", "inherited scene reference overrides"): return false
	result = addon.duplicate_nodes([scene.get_node("World/A")])
	if not need(result.get("ok", false), "duplicate inherited body"): return false
	get_editor_interface().save_scene_as("res://identity-inherited-final.tscn", false)
	var text := FileAccess.get_file_as_string("res://identity-inherited-final.tscn")
	if not need('identity-seed.tscn' in text and 'instance=ExtResource' in text, "saved scene keeps its inheritance link"): return false
	file = FileAccess.open("res://expected-inherited.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(load("res://snapshot.gd").read(scene)))
	file.close()
	print("BOX3D_IDENTITY_INHERITED_OK")
	return true

func check_external_resource(addon: EditorPlugin) -> bool:
	var shape := Box3DSphereShape3D.new()
	if not need(ResourceSaver.save(shape, "res://external-shape.tres") == OK, "save external shape"): return false
	shape = load("res://external-shape.tres")
	var old_key := shape.stable_key
	get_editor_interface().edit_resource(shape)
	var result: Dictionary = addon.rekey_object(shape, "external.shape")
	if not need(result.get("ok", false), "rekey external Resource"): return false
	# An explicit editor scene save flushes edited external resources. The
	# save_all_scenes API only visits dirty scenes, which are already saved here.
	var path: String = get_editor_interface().get_edited_scene_root().scene_file_path
	get_editor_interface().save_scene_as(path, false)
	if not need('stable_key = "external.shape"' in FileAccess.get_file_as_string("res://external-shape.tres"), "editor save persists external Resource ID"): return false
	var history := get_undo_redo().get_history_undo_redo(get_undo_redo().get_object_history_id(shape))
	history.undo()
	get_editor_interface().save_scene_as(path, false)
	if not need(old_key in FileAccess.get_file_as_string("res://external-shape.tres"), "editor save persists external ID undo"): return false
	history.redo()
	get_editor_interface().save_scene_as(path, false)
	print("BOX3D_IDENTITY_EXTERNAL_RESOURCE_OK")
	return true

func check_standalone(addon: EditorPlugin) -> bool:
	var source := Box3DBody3D.new()
	source.shapes = [Box3DSphereShape3D.new()]
	if not save_prefab(source, "res://identity-standalone.tscn"): return false
	get_editor_interface().open_scene_from_path("res://identity-standalone.tscn")
	for _frame in 5: await get_tree().process_frame
	var scene := get_editor_interface().get_edited_scene_root()
	var result: Dictionary = addon.rekey_object(scene, "standalone.body")
	if not need(result.get("ok", false), "standalone component source ID editing"): return false
	get_editor_interface().save_scene_as("res://identity-standalone-final.tscn", false)
	var file := FileAccess.open("res://expected-standalone.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(load("res://snapshot.gd").read(scene)))
	file.close()
	return true

func run() -> void:
	for _frame in 4: await get_tree().process_frame
	var plugins := get_tree().get_nodes_in_group("box3d_authoring_editor_plugin")
	if not need(plugins.size() == 1, "real editor plugin registration"): return
	var addon: EditorPlugin = plugins[0]
	if not need(not addon.services.available(), "identity gate must not require native tooling"): return
	for script in [Box3DPinJoint3D, Box3DHingeJoint3D, Box3DSliderJoint3D, Box3DSphericalJoint3D, Box3DDistanceJoint3D, Box3DMotorJoint3D, Box3DWeldJoint3D, Box3DWheelJoint3D, Box3DMeshShape3D, Box3DHeightfieldShape3D]:
		var instance: Object = script.new()
		var assigned: bool = not instance.stable_key.is_empty()
		if instance is Node: instance.free()
		if not need(assigned, "derived constructors retain automatic ID assignment"): return
	var source := fixture()
	var before: Dictionary = load("res://snapshot.gd").read(source)
	for path in before:
		var entry: Dictionary = before[path]
		if not need(not entry.key.is_empty(), "creation key missing: " + path + " " + entry.kind):
			source.free()
			return
	if not need(not source.get_node("World/A").shapes[0].stable_key.is_empty(), "creation assigns resource key"): return
	var packed := PackedScene.new()
	if not need(packed.pack(source) == OK and ResourceSaver.save(packed, "res://identity-seed.tscn") == OK, "save new identities"): return
	source.free()
	packed = null
	get_editor_interface().open_scene_from_path("res://identity-seed.tscn")
	for _frame in 6: await get_tree().process_frame
	var scene := get_editor_interface().get_edited_scene_root()
	if not need(load("res://snapshot.gd").read(scene) == before, "first reload preserves generated keys"): return
	var world: Box3DWorld3D = scene.get_node("World")
	var a: Box3DBody3D = world.get_node("A")
	var b: Box3DBody3D = world.get_node("B")
	var external: Box3DBody3D = world.get_node("External")
	var inside: Box3DPinJoint3D = world.get_node("Inside")
	var outside: Box3DPinJoint3D = world.get_node("Outside")
	var character: Box3DCharacterMover3D = world.get_node("Character")
	var shared: Box3DShape3D = a.shapes[0]
	for object in [world, a, shared, inside, character]:
		var found_identity := false
		for property in object.get_property_list():
			if property.name == "stable_key":
				found_identity = true
				if not need((property.usage & PROPERTY_USAGE_STORAGE) != 0 and (property.usage & PROPERTY_USAGE_EDITOR) == 0, "identity is stored but excluded from native parameter reset/copy"): return
		if not need(found_identity, "identity remains a stored script property"): return
	var baseline_file := FileAccess.open("res://definition-before.json", FileAccess.WRITE)
	baseline_file.store_string(world.box3d_definition_json())
	baseline_file.close()
	if not need(b.shapes[0] == shared, "loaded geometry is intentionally shared"): return
	var original_key := a.stable_key
	a.name = "Renamed"
	world.move_child(a, world.get_child_count() - 1)
	var group := Node3D.new()
	world.add_child(group)
	group.owner = scene
	a.reparent(group)
	if not need(a.stable_key == original_key, "rename, reorder and reparent preserve identity"): return
	a.reparent(world)
	a.name = "A"
	group.free()
	var selection := get_editor_interface().get_selection()
	selection.clear()
	for node in [a, b, inside, outside, character]: selection.add_node(node)
	var result: Dictionary = addon.duplicate_selection()
	if not need(result.get("ok", false) and result.nodes.size() == 5, "duplicate selection: " + str(result)): return
	var ac: Box3DBody3D = world.get_node("ACopy")
	var bc: Box3DBody3D = world.get_node("BCopy")
	var ic: Box3DPinJoint3D = world.get_node("InsideCopy")
	var oc: Box3DPinJoint3D = world.get_node("OutsideCopy")
	var cc: Box3DCharacterMover3D = world.get_node("CharacterCopy")
	if not need(ac.stable_key != a.stable_key and bc.stable_key != b.stable_key, "distinct cloned bodies"): return
	if not need(ic.body_a == ac.stable_key and ic.body_b == bc.stable_key and cc.exclude_body == bc.stable_key, "internal cloned references"): return
	if not need(oc.body_a == ac.stable_key and oc.body_b == external.stable_key, "external cloned reference stays external"): return
	if not need(ac.shapes[0] == shared and bc.shapes[0] == shared and outside.body_a == original_key, "original graph and shared resources untouched"): return
	var cloned_key := ac.stable_key
	var history := get_undo_redo().get_history_undo_redo(get_undo_redo().get_object_history_id(scene))
	for _cycle in 2:
		history.undo()
		if not need(ac.get_parent() == null and world.get_node_or_null("InsideCopy") == null, "duplicate undo removes exact graph"): return
		history.redo()
		if not need(ac.get_parent() == world and ac.stable_key == cloned_key and ac.shapes[0] == shared, "redo reuses objects, keys and shared resources"): return
	result = addon.rekey_object(a, "renamed.body")
	if not need(result.get("ok", false), "rekey body"): return
	if not need(inside.body_a == "renamed.body" and outside.body_a == "renamed.body", "all incoming references rekeyed"): return
	if not need(world.get_node("Nested/Joint").body_a == original_key and oc.body_a == cloned_key, "nested and cloned namespaces remain unchanged"): return
	history.undo()
	if not need(a.stable_key == original_key and inside.body_a == original_key, "atomic rekey undo"): return
	history.redo()
	var b_key := b.stable_key
	result = addon.rekey_object(b, "temporary.body.b")
	if not need(result.get("ok", false) and inside.body_b == "temporary.body.b" and character.exclude_body == "temporary.body.b", "second joint endpoint and character reference rekey"): return
	for _cycle in 2:
		history.undo()
		if not need(b.stable_key == b_key and inside.body_b == b_key and character.exclude_body == b_key, "reference undo restores exact old values"): return
		history.redo()
		if not need(inside.body_b == "temporary.body.b" and character.exclude_body == "temporary.body.b", "reference redo restores exact new values"): return
	history.undo()
	result = addon.duplicate_shape(a, 0)
	if not need(result.get("ok", false) and a.shapes.size() == 2, "duplicate shape slot"): return
	var copied_shape: Box3DShape3D = a.shapes[1]
	if not need(copied_shape != shared and copied_shape.stable_key != shared.stable_key and b.shapes[0] == shared, "shape slot has its own resource and ID"): return
	var shape_key := copied_shape.stable_key
	history.undo()
	if not need(a.shapes.size() == 1 and a.shapes[0] == shared, "shape undo"): return
	history.redo()
	if not need(a.shapes[1] == copied_shape and copied_shape.stable_key == shape_key, "shape redo"): return
	var unchanged: Dictionary = load("res://snapshot.gd").read(scene)
	result = addon.rekey_object(copied_shape, shared.stable_key)
	if not need(not result.get("ok", true) and load("res://snapshot.gd").read(scene) == unchanged, "shape key collision refused"): return
	result = addon.rekey_object(a, b.stable_key)
	if not need(not result.get("ok", true) and load("res://snapshot.gd").read(scene) == unchanged, "collision fails without partial edits"): return
	var transient := Box3DBody3D.new()
	world.add_child(transient) # intentionally unowned, so it cannot survive saving
	result = addon.duplicate_nodes([world])
	transient.free()
	if not need(not result.get("ok", true) and load("res://snapshot.gd").read(scene) == unchanged, "unowned authoring subtree refused atomically"): return
	var ambiguous := Box3DBody3D.new()
	ambiguous.stable_key = a.stable_key
	world.add_child(ambiguous)
	ambiguous.owner = scene
	var conflict_snapshot: Dictionary = load("res://snapshot.gd").read(scene)
	result = addon.rekey_object(a, "ambiguous.body")
	if not need(not result.get("ok", true) and load("res://snapshot.gd").read(scene) == conflict_snapshot, "ambiguous reference repair does not guess"): return
	result = addon.duplicate_nodes([a])
	if not need(not result.get("ok", true) and load("res://snapshot.gd").read(scene) == conflict_snapshot, "ambiguous duplicate refused atomically"): return
	ambiguous.free()
	# Undo and redo the last identity action while the plugin is disabled.
	get_editor_interface().set_plugin_enabled("box3d_authoring", false)
	for _frame in 3: await get_tree().process_frame
	history.undo()
	history.redo()
	if not need(load("res://snapshot.gd").read(scene) == unchanged, "history survives plugin disable"): return
	get_editor_interface().set_plugin_enabled("box3d_authoring", true)
	for _frame in 3: await get_tree().process_frame
	if not need(load("res://snapshot.gd").read(scene) == unchanged, "reenable does not rekey"): return
	addon = get_tree().get_nodes_in_group("box3d_authoring_editor_plugin")[0]
	if not check_instances(addon, scene, world): return
	# Exercise the actual replacement Inspector property editor.
	get_editor_interface().edit_node(a)
	for _frame in 4: await get_tree().process_frame
	var key_editor: Box3DIdentityControl
	for control in get_editor_interface().get_inspector().find_children("*", "", true, false):
		if control is Box3DIdentityControl and control.get_edited_object() == a: key_editor = control
		if control is EditorProperty and control.get_edited_object() == a and control.get_edited_property() == &"stable_key":
			if not need(false, "native reset/paste must not bypass reference updates"): return
	if not need(key_editor != null, "real stable-ID Inspector control"): return
	key_editor.field.text = "inspector.body"
	key_editor.field.text_submitted.emit("inspector.body")
	if not need(a.stable_key == "inspector.body" and inside.body_a == "inspector.body" and outside.body_a == "inspector.body", "Inspector edit updates references atomically"): return
	history.undo()
	if not need(a.stable_key == "renamed.body" and inside.body_a == "renamed.body", "Inspector edit undo"): return
	history.redo()
	unchanged = load("res://snapshot.gd").read(scene)
	if not need(world.box3d_diagnostics().is_empty(), "final reference graph validates: " + str(world.box3d_diagnostics())): return
	get_editor_interface().save_scene_as("res://identity-final.tscn", false)
	if not need(FileAccess.file_exists("res://identity-final.tscn"), "save editor changes"): return
	var file := FileAccess.open("res://expected.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(unchanged))
	file.close()
	file = FileAccess.open("res://definition.json", FileAccess.WRITE)
	file.store_string(world.box3d_definition_json())
	file.close()
	if not await check_inherited(addon): return
	if not check_external_resource(addon): return
	if not await check_standalone(addon): return
	print("BOX3D_IDENTITY_EDITOR_OK")
	get_tree().quit()
