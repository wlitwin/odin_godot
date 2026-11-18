@tool
extends EditorPlugin

func _enter_tree() -> void:
	if OS.get_environment("STARTER_AUTHORING_EDITOR") == "1": run.call_deferred()

func find_plugin(node: Node) -> Node:
	if node.get_script() != null and node.get_script().resource_path == "res://addons/replay_authoring/plugin.gd": return node
	for child in node.get_children():
		var found := find_plugin(child)
		if found != null: return found
	return null

func wait_job(plugin: Node) -> Dictionary:
	await get_tree().process_frame
	var deadline := Time.get_ticks_msec() + 180000
	while (plugin.pid > 0 or not plugin.pending_request.is_empty()) and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(.05).timeout
	assert(plugin.pid < 0 and plugin.pending_request.is_empty())
	return plugin.last_report

func run() -> void:
	await get_tree().create_timer(1).timeout
	var plugin := find_plugin(get_tree().root)
	assert(plugin != null)
	await wait_job(plugin)
	assert(plugin.buttons.keys() == ["validate", "preview"] and plugin.controls.is_empty())
	assert(not plugin.config.has("worker") and not plugin.config.has("status_action"))
	var definition: Resource = load("res://data/pickup.tres")
	get_editor_interface().edit_resource(definition)
	definition.reach = 0
	get_editor_interface().set_object_edited(definition, true)
	plugin._start("validate")
	var invalid := await wait_job(plugin)
	assert(not invalid.ok and invalid.issues[0].source == "res://data/pickup.tres" and invalid.issues[0].path == "reach", str(invalid))
	plugin._open_issue(0)
	assert(get_editor_interface().get_inspector().get_edited_object() == definition)
	definition.reach = 40
	get_editor_interface().set_object_edited(definition, true)
	plugin._start("validate")
	assert((await wait_job(plugin)).ok)
	plugin._start("preview")
	for _frame in 5: await get_tree().process_frame
	assert(get_editor_interface().get_edited_scene_root().scene_file_path == "res://dev/pickup_preview.tscn")
	definition.reach = 24
	get_editor_interface().set_object_edited(definition, true)
	plugin._start("validate")
	assert((await wait_job(plugin)).ok)
	print("REPLAY_STARTER_EDITOR_OK declared=true invalid=true clickable=true recovery=true preview=true")
	get_tree().quit()
