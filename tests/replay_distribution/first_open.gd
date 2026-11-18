@tool
extends EditorPlugin

func _enter_tree() -> void: run.call_deferred()

func find_dock(node: Node) -> Node:
	if node.get_script() != null and node.get_script().resource_path == "res://addons/replay_authoring/plugin.gd": return node
	for child in node.get_children():
		var found := find_dock(child)
		if found != null: return found
	return null

func run() -> void:
	await get_tree().create_timer(1).timeout
	var plugin := find_dock(get_tree().root)
	assert(plugin != null, "The copied starter must include its enabled dock before any build")
	assert(get_editor_interface().is_plugin_enabled("replay_authoring"))
	assert(plugin.config.is_empty() and "Build the project once" in plugin.detail.text)
	var marker := FileAccess.open("res://.godot/first-open-ready", FileAccess.WRITE)
	marker.store_string("dock loaded before compilation\n")
	marker.close()
	# The external harness builds once while this initial editor stays open.
	var deadline := Time.get_ticks_msec() + 180000
	while plugin.config.is_empty() and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(.1).timeout
	assert(not plugin.config.is_empty(), "First build must make the dock usable without a toggle/restart")
	assert(plugin.buttons.keys() == ["validate", "preview"])
	while plugin.pid > 0: await get_tree().process_frame
	assert(plugin.last_report.ok)
	assert(plugin.issues.item_count == 0, "First-build setup recovery must clear its old issue")
	print("REPLAY_FIRST_OPEN_OK dock=true toolchain_discovered=true")
	get_tree().quit()
