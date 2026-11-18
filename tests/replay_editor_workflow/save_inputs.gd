@tool
extends EditorPlugin

var plugin: EditorPlugin

func _enter_tree() -> void:
	if OS.get_environment("REPLAY_SAVE_CHECK") == "1":run.call_deferred()

func find_plugin(node: Node) -> EditorPlugin:
	if node.get_script() != null and node.get_script().resource_path == "res://addons/replay_authoring/plugin.gd":return node
	for child in node.get_children():
		var found := find_plugin(child)
		if found != null:return found
	return null

func settle() -> void:
	for frame in 3:await get_tree().process_frame

func wait_job() -> Dictionary:
	var deadline := Time.get_ticks_msec() + 30000
	await settle()
	while (plugin.pid > 0 or not plugin.pending_request.is_empty()) and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(.05).timeout
	assert(plugin.pid < 0 and plugin.pending_request.is_empty(), "editor job deadline")
	while EditorInterface.get_resource_filesystem().is_scanning() and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(.05).timeout
	assert(not EditorInterface.get_resource_filesystem().is_scanning(), "filesystem deadline")
	plugin.status_clock = -100000
	return plugin.last_report

func edit(object: Object, property: StringName, value: Variant) -> void:
	var history := get_undo_redo()
	history.create_action("Edit " + property, UndoRedo.MERGE_DISABLE, object)
	history.add_do_property(object, property, value)
	history.add_undo_property(object, property, object.get(property))
	history.commit_action()
	if object is Resource:assert(EditorInterface.is_object_edited(object), "native editor edits flag Resources")

func run() -> void:
	assert(EditorInterface.get_editor_paths().is_self_contained())
	await get_tree().create_timer(.5).timeout
	plugin = find_plugin(get_tree().root)
	assert(plugin != null)
	await wait_job()
	EditorInterface.open_scene_from_path("res://other.tscn")
	await settle()
	var other_scene := EditorInterface.get_edited_scene_root()
	edit(other_scene, "number", 5678)
	EditorInterface.open_scene_from_path("res://main.tscn")
	await settle()
	var scene := EditorInterface.get_edited_scene_root()
	var first: Resource = load("res://first.tres")
	var second: Resource = load("res://second.tres")
	var child: Resource = first.mapping.nested[0]
	var payload: Resource = scene.payload
	EditorInterface.edit_resource(first)
	await settle()
	edit(first, "amount", 11)
	edit(child, "amount", 33)
	EditorInterface.edit_resource(second)
	await settle()
	edit(second, "amount", 22)
	edit(scene, "number", 1234)
	edit(payload, "amount", 44)
	plugin._start("bake")
	var baked := await wait_job()
	assert(baked.get("ok", false), str(baked))
	assert("amount = 11" in baked.snapshot["first.tres"] and "amount = 33" in baked.snapshot["first.tres"])
	assert("amount = 22" in baked.snapshot["second.tres"])
	assert("amount = 44" in baked.snapshot["main.tscn"] and "number = 1234" in baked.snapshot["main.tscn"])
	assert("number = 5678" in baked.snapshot["other.tscn"])
	assert(EditorInterface.get_edited_scene_root() == scene, "saving preserves the selected scene tab")
	assert(EditorInterface.get_unsaved_scenes().is_empty())
	assert(not plugin.saved_data.has_pending(EditorInterface))
	print("SAVE_MULTIPLE_RESOURCES_AND_SCENE_OK")

	# Shared containers can belong to more than one external Resource. Persist
	# both owners, even when one is visited as the other's external dependency.
	edit(second, "mapping", first.mapping)
	edit(first, "children", [second] as Array[Resource])
	edit(child, "amount", 34)
	plugin._start("bake")
	var shared := await wait_job()
	assert(shared.ok, str(shared))
	assert("amount = 34" in shared.snapshot["first.tres"] and "amount = 34" in shared.snapshot["second.tres"])
	assert(not EditorInterface.is_object_edited(child))
	print("SAVE_SHARED_CONTAINER_OWNERS_OK")
	# Once both containers are saved, an edit to only their shared resource
	# still has to persist into every proven owner and clear that resource.
	edit(child, "amount", 35)
	plugin._start("bake")
	var shared_only := await wait_job()
	assert(shared_only.ok and "amount = 35" in shared_only.snapshot["first.tres"] and "amount = 35" in shared_only.snapshot["second.tres"])
	assert(not EditorInterface.is_object_edited(child))
	EditorInterface.open_scene_from_path("res://parent.tscn")
	await settle()
	var inherited: Resource = EditorInterface.get_edited_scene_root().get_node("Child").payload
	edit(inherited, "amount", 66)
	plugin._start("bake")
	var instanced := await wait_job()
	assert(instanced.ok and "amount = 66" in instanced.snapshot["child.tscn"], str(instanced))
	assert(not "amount = 66" in instanced.snapshot["parent.tscn"], "inherited data stays in its actual owner")
	assert(not EditorInterface.is_object_edited(inherited))
	EditorInterface.open_scene_from_path("res://main.tscn")
	await settle()
	print("SAVE_PROVEN_INSTANCE_OWNERS_OK")

	# Include live Script editor buffers, not only Script Resource.source_code.
	var logic: Script = load("res://logic.gd")
	EditorInterface.edit_script(logic)
	await settle()
	var code := EditorInterface.get_script_editor().get_current_editor().get_base_editor() as CodeEdit
	code.text = code.text.replace("VALUE = 1", "VALUE = 2")
	assert("res://logic.gd" in EditorInterface.get_script_editor().get_unsaved_files())
	plugin._start("validate")
	var scripted := await wait_job()
	assert(scripted.ok and "VALUE = 2" in scripted.snapshot["logic.gd"], str(scripted))
	assert(EditorInterface.get_script_editor().get_unsaved_files().is_empty())
	print("SAVE_SCRIPT_BUFFER_OK")

	# Closed cached scenes still own editable embedded Resources. Save their
	# PackedScene data without requiring unrelated scene tabs to be opened.
	var closed: PackedScene = load("res://closed.tscn")
	var state := closed.get_state()
	var closed_payload: Resource
	for index in state.get_node_property_count(0):
		if state.get_node_property_name(0, index) == &"payload":
			closed_payload = state.get_node_property_value(0, index)
	assert(closed_payload != null)
	edit(closed_payload, "amount", 77)
	plugin._start("bake")
	var closed_result := await wait_job()
	assert(closed_result.ok and "amount = 77" in closed_result.snapshot["closed.tscn"], str(closed_result))
	assert(not "res://closed.tscn" in EditorInterface.get_open_scenes())
	assert(EditorInterface.get_edited_scene_root() == scene)
	print("SAVE_CLOSED_SCENE_RESOURCE_OK")
	var closed_artifact := FileAccess.get_file_as_string("res://.godot/artifact.json")
	edit(closed_payload, "amount", 78)
	assert(DirAccess.rename_absolute("res://closed.tscn", "res://closed.tscn.saved") == OK)
	assert(DirAccess.make_dir_absolute("res://closed.tscn") == OK)
	print("EXPECTED_CLOSED_SCENE_SAVE_FAILURE_BEGIN")
	plugin._start("bake")
	assert(plugin.pid < 0 and plugin.pending_request.is_empty())
	var closed_failure: Dictionary = plugin.last_report
	assert(DirAccess.remove_absolute("res://closed.tscn") == OK)
	assert(DirAccess.rename_absolute("res://closed.tscn.saved", "res://closed.tscn") == OK)
	print("EXPECTED_CLOSED_SCENE_SAVE_FAILURE_END")
	await wait_job()
	assert(not closed_failure.ok and closed_failure.kind == "save", str(closed_failure))
	assert(EditorInterface.is_object_edited(closed_payload))
	assert(FileAccess.get_file_as_string("res://.godot/artifact.json") == closed_artifact)
	plugin._start("bake")
	var closed_retry := await wait_job()
	assert(closed_retry.ok and "amount = 78" in closed_retry.snapshot["closed.tscn"], str(closed_retry))
	print("SAVE_CLOSED_SCENE_FAILURE_RECOVERY_OK")

	# Saving an open scene replaces its cached SceneState. Retaining an older
	# Resource with that scene's path must not fool the save ownership check.
	EditorInterface.open_scene_from_path("res://closed.tscn")
	await settle()
	var closed_root := EditorInterface.get_edited_scene_root()
	edit(closed_root, "payload", closed_root.payload.duplicate())
	assert(EditorInterface.save_scene() == OK)
	assert(EditorInterface.get_unsaved_scenes().is_empty())
	EditorInterface.edit_resource(closed_payload)
	await settle()
	edit(closed_payload, "amount", 79)
	plugin._start("bake")
	var open_stale := await wait_job()
	assert(not open_stale.ok and "no longer embedded in the open scene" in open_stale.issues[0].message, str(open_stale))
	assert(EditorInterface.is_object_edited(closed_payload))
	# Clear this deliberately disconnected edit's native history to close the
	# scene, then exercise the same ownership guard with the scene closed.
	assert(EditorInterface.save_scene() == OK)
	assert(EditorInterface.close_scene() == OK)
	await settle()
	EditorInterface.edit_resource(closed_payload)
	await settle()
	edit(closed_payload, "amount", 79)
	plugin._start("bake")
	var stale := await wait_job()
	assert(not stale.ok and stale.kind == "save", str(stale))
	assert("no longer embedded" in stale.issues[0].message)
	assert(EditorInterface.is_object_edited(closed_payload))
	assert(ResourceSaver.save(closed_payload, "res://recovered.tres", ResourceSaver.FLAG_CHANGE_PATH) == OK)
	plugin._start("bake")
	var recovered := await wait_job()
	assert(recovered.ok, str(recovered))
	assert("amount = 78" in recovered.snapshot["closed.tscn"])
	assert("amount = 79" in FileAccess.get_file_as_string("res://recovered.tres"))
	print("SAVE_STALE_SCENE_RESOURCE_RECOVERY_OK")

	# Inspector/preview caches can retain an embedded Resource after releasing
	# its PackedScene. Recover the owner without replacing this edited object.
	var released: PackedScene = load("res://released.tscn")
	var released_state := released.get_state()
	var released_payload: Resource
	for index in released_state.get_node_property_count(0):
		if released_state.get_node_property_name(0, index) == &"payload":
			released_payload = released_state.get_node_property_value(0, index)
	assert(released_payload != null)
	EditorInterface.edit_resource(released_payload)
	await settle()
	released = null
	released_state = null
	assert(ResourceLoader.get_cached_ref("res://released.tscn") == null)
	edit(released_payload, "amount", 88)
	plugin._start("bake")
	var retained := await wait_job()
	assert(retained.ok and "amount = 88" in retained.snapshot["released.tscn"], str(retained))
	assert(released_payload.amount == 88 and not EditorInterface.is_object_edited(released_payload))
	assert(not "res://released.tscn" in EditorInterface.get_open_scenes())
	print("SAVE_RELEASED_SCENE_OWNER_OK")

	# A real write failure must block the worker and retain edited state.
	var artifact := FileAccess.get_file_as_string("res://.godot/artifact.json")
	var original := FileAccess.get_file_as_string("res://second.tres")
	assert(DirAccess.rename_absolute(second.resource_path, second.resource_path + ".saved") == OK)
	assert(DirAccess.make_dir_absolute(second.resource_path) == OK)
	edit(second, "amount", 23)
	print("EXPECTED_RESOURCE_SAVE_FAILURE_BEGIN")
	plugin._start("bake")
	assert(plugin.pid < 0 and plugin.pending_request.is_empty())
	var failed: Dictionary = plugin.last_report
	assert(DirAccess.remove_absolute(second.resource_path) == OK)
	assert(DirAccess.rename_absolute(second.resource_path + ".saved", second.resource_path) == OK)
	print("EXPECTED_RESOURCE_SAVE_FAILURE_END")
	await wait_job()
	assert(not failed.ok and failed.kind == "save", str(failed))
	assert(failed.issues[0].source == second.resource_path)
	assert("Could not save Resource" in failed.issues[0].message)
	assert(EditorInterface.is_object_edited(second))
	assert(FileAccess.get_file_as_string("res://second.tres") == original)
	assert(FileAccess.get_file_as_string("res://.godot/artifact.json") == artifact)
	plugin._open_issue(0)
	assert(EditorInterface.get_inspector().get_edited_object() == second)
	plugin._start("bake")
	var retry := await wait_job()
	assert(retry.ok and "amount = 23" in retry.snapshot["second.tres"])
	print("SAVE_FAILURE_RECOVERY_OK")

	# The engine emits scene_saved even on write failure, and clears Resource
	# flags. A Resource-only scene edit must survive that path and block baking.
	assert(EditorInterface.get_unsaved_scenes().is_empty())
	payload.amount = 45
	EditorInterface.set_object_edited(payload, true)
	assert(EditorInterface.get_unsaved_scenes().is_empty(), "this edit has no scene UndoRedo action")
	artifact = FileAccess.get_file_as_string("res://.godot/artifact.json")
	original = FileAccess.get_file_as_string("res://main.tscn")
	assert(DirAccess.rename_absolute("res://main.tscn", "res://main.tscn.saved") == OK)
	assert(DirAccess.make_dir_absolute("res://main.tscn") == OK)
	print("EXPECTED_SCENE_SAVE_FAILURE_BEGIN")
	plugin._start("bake")
	assert(plugin.pid < 0 and plugin.pending_request.is_empty())
	var scene_failed: Dictionary = plugin.last_report
	assert(DirAccess.remove_absolute("res://main.tscn") == OK)
	assert(DirAccess.rename_absolute("res://main.tscn.saved", "res://main.tscn") == OK)
	print("EXPECTED_SCENE_SAVE_FAILURE_END")
	await wait_job()
	assert(not scene_failed.ok and scene_failed.kind == "save", str(scene_failed))
	assert(scene_failed.issues[0].source == "res://main.tscn")
	assert(EditorInterface.is_object_edited(payload))
	assert("res://main.tscn" in EditorInterface.get_unsaved_scenes())
	assert(FileAccess.get_file_as_string("res://main.tscn") == original)
	assert(FileAccess.get_file_as_string("res://.godot/artifact.json") == artifact)
	plugin._start("bake")
	var scene_retry := await wait_job()
	assert(scene_retry.ok and "amount = 45" in scene_retry.snapshot["main.tscn"], str(scene_retry))
	print("SAVE_SCENE_FAILURE_RECOVERY_OK")

	# Unnamed drafts have nowhere to persist; do not silently ignore them.
	var draft: Resource = load("res://value.gd").new()
	EditorInterface.edit_resource(draft)
	await settle()
	edit(draft, "amount", 55)
	artifact = FileAccess.get_file_as_string("res://.godot/artifact.json")
	plugin._start("validate")
	var orphan := await wait_job()
	assert(not orphan.ok and orphan.kind == "save", str(orphan))
	assert("no saved owner" in orphan.issues[0].message)
	assert(FileAccess.get_file_as_string("res://.godot/artifact.json") == artifact)
	EditorInterface.edit_resource(second)
	plugin._open_issue(0)
	assert(EditorInterface.get_inspector().get_edited_object() == draft)
	edit(first, "children", [draft] as Array[Resource])
	plugin._start("validate")
	var assigned := await wait_job()
	assert(assigned.ok and "amount = 55" in assigned.snapshot["first.tres"], str(assigned))
	print("SAVE_UNNAMED_RESOURCE_RECOVERY_OK")

	# A visible tool-created child is not saved unless it has a scene owner.
	# Inspecting its embedded draft must not turn reachability into persistence.
	var transient := Node.new()
	transient.name = "ToolPreview"
	transient.set_script(load("res://scene.gd"))
	var transient_data: Resource = load("res://value.gd").new()
	transient.payload = transient_data
	scene.add_child(transient)
	assert(transient.owner == null)
	EditorInterface.edit_resource(transient_data)
	await settle()
	edit(transient_data, "amount", 91)
	plugin._start("bake")
	var unowned := await wait_job()
	assert(not unowned.ok and unowned.kind == "save", str(unowned))
	assert(EditorInterface.is_object_edited(transient_data))
	assert(not "amount = 91" in FileAccess.get_file_as_string("res://main.tscn"))
	transient.owner = scene
	plugin._start("bake")
	var owned := await wait_job()
	assert(owned.ok and "amount = 91" in owned.snapshot["main.tscn"], str(owned))
	assert(not EditorInterface.is_object_edited(transient_data))
	print("SAVE_TRANSIENT_NODE_OWNERSHIP_OK")

	# A successful saved snapshot must not claim newer edits were validated.
	FileAccess.open("res://.godot/hold_worker", FileAccess.WRITE).store_string("hold")
	plugin._start("bake")
	var deadline := Time.get_ticks_msec() + 10000
	while not plugin._json(plugin.result_path).get("running", false) and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(.05).timeout
	assert(plugin._json(plugin.result_path).get("running", false), "worker read snapshot")
	assert(plugin.status.text != "Content: current", "running work is labelled as checking saved inputs")
	edit(second, "amount", 24)
	DirAccess.remove_absolute("res://.godot/hold_worker")
	var changed := await wait_job()
	assert(changed.ok and changed.editor_unsaved)
	assert("amount = 23" in changed.snapshot["second.tres"])
	assert("unsaved" in plugin.status.text and "not included" in plugin.detail.text)
	plugin._start("bake")
	var final := await wait_job()
	assert(final.ok and not final.editor_unsaved and "amount = 24" in final.snapshot["second.tres"])
	assert(plugin.status.text == "Content: current")
	print("SAVE_EDITS_DURING_JOB_OK")

	# Wait for discovery before saving, and retain the queued action until the
	# deferred start so callers cannot mistake it for a completed job.
	edit(second, "amount", 25)
	EditorInterface.get_resource_filesystem().scan()
	assert(EditorInterface.get_resource_filesystem().is_scanning())
	plugin._start("bake")
	assert(plugin.pending_request.get("action") == "bake")
	var queued := await wait_job()
	assert(queued.ok and "amount = 25" in queued.snapshot["second.tres"], str(queued))
	edit(second, "amount", 26)
	EditorInterface.get_resource_filesystem().scan()
	plugin._start("bake")
	assert(plugin.pending_request.get("action") == "bake")
	plugin._cancel()
	await wait_job()
	assert(plugin.pending_request.is_empty() and plugin.pid < 0)
	assert("amount = 25" in FileAccess.get_file_as_string("res://second.tres"))
	assert(EditorInterface.is_object_edited(second))
	plugin._start("bake")
	var resumed := await wait_job()
	assert(resumed.ok and "amount = 26" in resumed.snapshot["second.tres"], str(resumed))
	print("SAVE_IMPORT_QUEUE_CANCEL_OK")

	# UI values belong to the click, even when import or status delays saving.
	plugin.controls["definition"].text = "res://first.tres"
	plugin.controls["latency"].select(0) # value 80, not the selected index
	plugin.controls["name"].text = "first draft"
	EditorInterface.get_resource_filesystem().scan()
	plugin._start("validate")
	assert(plugin.pending_request.get("action") == "validate")
	plugin.controls["definition"].text = "res://second.tres"
	plugin.controls["latency"].select(1)
	plugin.controls["name"].text = "later edit"
	var captured := await wait_job()
	# Godot's JSON reader represents numbers as floats; the request writer and
	# Python worker still validate the declared integer choice value (80, not 0).
	var expected := {"definition": "res://first.tres", "latency": 80.0, "name": "first draft"}
	assert(captured.ok and captured.request.inputs == expected, str(captured))
	assert(plugin._json(plugin.result_path.get_base_dir() + "/request.json").inputs == expected)
	var calls: Array = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/invocations.json"))
	var before_calls := calls.size()
	FileAccess.open("res://.godot/hold_status", FileAccess.WRITE).store_string("hold")
	plugin._start("status")
	plugin.controls["definition"].text = "res://first.tres"
	plugin.controls["latency"].select(0)
	plugin.controls["name"].text = "first draft"
	plugin._start("validate")
	assert(plugin.pending_request.get("action") == "validate")
	plugin.controls["definition"].text = "res://second.tres"
	plugin.controls["latency"].select(1)
	plugin.controls["name"].text = "later edit"
	DirAccess.remove_absolute("res://.godot/hold_status")
	var after_status := await wait_job()
	assert(after_status.ok and after_status.request.inputs == expected, str(after_status))
	calls = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/invocations.json"))
	assert(calls.size() == before_calls + 2, "one status and one queued action")
	edit(second, "amount", 27)
	before_calls = calls.size()
	FileAccess.open("res://.godot/hold_status", FileAccess.WRITE).store_string("hold")
	plugin._start("status")
	plugin._start("bake")
	plugin._cancel()
	await wait_job()
	DirAccess.remove_absolute("res://.godot/hold_status")
	calls = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/invocations.json"))
	assert(calls.size() == before_calls + 1, "canceling a queued action never invokes it")
	assert(plugin.pending_request.is_empty() and EditorInterface.is_object_edited(second))
	assert("amount = 26" in FileAccess.get_file_as_string("res://second.tres"))
	plugin._start("bake")
	assert((await wait_job()).ok)
	print("SAVE_REQUEST_SNAPSHOT_OK")
	FileAccess.open("res://.godot/fail_status", FileAccess.WRITE).store_string("fail")
	plugin._start("status")
	var failed_status := await wait_job()
	assert(not failed_status.ok and plugin.status.text == "Status check failed")
	assert("Status cannot read" in plugin.detail.text and plugin.issues.item_count > 0)
	DirAccess.remove_absolute("res://.godot/fail_status")
	plugin._start("status")
	var recovered_status := await wait_job()
	assert(recovered_status.ok and plugin.status.text == "Content: current" and plugin.issues.item_count == 0)
	print("SAVE_STATUS_FAILURE_RECOVERY_OK")
	print("REPLAY_SAVE_INPUTS_OK")
	get_tree().quit()
