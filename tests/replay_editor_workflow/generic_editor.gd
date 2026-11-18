@tool
extends EditorPlugin

func _enter_tree() -> void:
	if OS.get_environment("GENERIC_AUTHORING_CHECK") == "1": run.call_deferred()

func find_plugin(node: Node) -> Node:
	if node.get_script() != null and node.get_script().resource_path == "res://addons/replay_authoring/plugin.gd": return node
	for child in node.get_children():
		var found := find_plugin(child)
		if found != null: return found
	return null

func wait_job(plugin: Node) -> Dictionary:
	await get_tree().process_frame
	var deadline := Time.get_ticks_msec() + 120000
	while (plugin.pid > 0 or not plugin.pending_request.is_empty()) and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(.05).timeout
	assert(plugin.pid < 0 and plugin.pending_request.is_empty(), "generic authoring deadline")
	return plugin.last_report

func job_count() -> int:
	return DirAccess.get_directories_at("res://.godot/replay_authoring/jobs").size()

func run() -> void:
	await get_tree().create_timer(1).timeout
	var plugin := find_plugin(get_tree().root)
	assert(plugin != null)
	await wait_job(plugin)
	assert(plugin.buttons.keys() == ["check-orbit", "preview-orbit"])
	assert(plugin.controls.is_empty() and not plugin.config.has("status_action"))
	var before := job_count()
	await get_tree().create_timer(6).timeout
	assert(plugin.pid < 0 and job_count() == before, "no undeclared status polling")
	plugin._start("validate")
	assert(not plugin.last_report.ok and job_count() == before, "undeclared action never launches")
	var resource: Resource = load("res://orbit.tres")
	get_editor_interface().edit_resource(resource)
	resource.radius = -1
	get_editor_interface().set_object_edited(resource, true)
	plugin._start("check-orbit")
	var invalid := await wait_job(plugin)
	assert(not invalid.ok and invalid.issues[0].source == "res://orbit.tres" and invalid.issues[0].path == "radius", str(invalid))
	plugin._open_issue(0)
	assert(get_editor_interface().get_inspector().get_edited_object() == resource)
	resource.radius = 7
	get_editor_interface().set_object_edited(resource, true)
	plugin._start("check-orbit")
	var valid := await wait_job(plugin)
	assert(valid.ok and not valid.has("stale"), str(valid))
	assert(plugin.status.text == "Validation passed", "validation alone does not claim baked content is current")
	before = job_count()
	plugin._start("preview-orbit")
	for _frame in 5: await get_tree().process_frame
	assert(get_editor_interface().get_edited_scene_root().scene_file_path == "res://preview.tscn")
	assert(plugin.pid < 0 and job_count() == before, "opening a preview runs no worker")
	resource.radius = 8
	get_editor_interface().set_object_edited(resource, true)
	await get_tree().create_timer(1.2).timeout
	assert("unsaved" in plugin.status.text)
	assert(job_count() == before)
	plugin._start("check-orbit")
	assert((await wait_job(plugin)).ok)
	print("REPLAY_GENERIC_AUTHORING_OK actions=true no_status=true default_worker=true saved_toolchain=true preview=true")
	get_tree().quit()
