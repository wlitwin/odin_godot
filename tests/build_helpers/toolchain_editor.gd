extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func missing_badge(node: Node) -> bool:
	if node is Label and node.text == "Odin: compiler not found" and node.visible:
		return true
	for child in node.get_children():
		if missing_badge(child):
			return true
	return false

func has_field(node: Node, field: String) -> bool:
	for property in node.get_property_list():
		if property.name == field:
			return true
	return false

func run() -> void:
	assert(Engine.is_editor_hint())
	await create_timer(0.1).timeout
	var script: Script = load("res://scripts/widget.odin")
	var node := Node.new()
	node.set_script(script)
	root.add_child(node)
	assert(has_field(node, "speed"))
	var extra_script: Script = load("res://modules/extras/extra.odin")
	var extra := Node.new()
	extra.set_script(extra_script)
	root.add_child(extra)
	assert(has_field(extra, "speed"))
	var cache_path := "res://.godot/odin_godot/toolchain/"
	var cache: Dictionary = {}
	for key in DirAccess.get_files_at(cache_path):
		cache[key] = FileAccess.get_file_as_string(cache_path + key)
	assert(not cache.is_empty())
	assert(not OS.has_environment("ODIN"))
	# Remove the remembered tools to exercise a failed save, then restore them
	# in this same editor process and prove the pending edit gets compiled.
	for key in cache:
		DirAccess.remove_absolute(cache_path + str(key))
	var original_path := OS.get_environment("PATH")
	OS.set_environment("PATH", "/nonexistent")
	script.source_code = script.source_code.replace("//NEW_FIELD_HERE", "new_field: gd.Int `gd:\"export\"`,")
	assert(ResourceSaver.save(script) == OK)
	extra_script.source_code = extra_script.source_code.replace("//NEW_FIELD_HERE", "other_field: gd.Int `gd:\"export\"`,")
	assert(ResourceSaver.save(extra_script) == OK)
	await create_timer(0.1).timeout
	assert(missing_badge(root), "Missing compiler must remain visible")
	# _build is an engine virtual, not a callable script method. Exercise its
	# real invocation through Play; the runner checks the rejection diagnostic.
	EditorInterface.play_custom_scene("res://main.tscn")
	await create_timer(0.1).timeout
	assert(not EditorInterface.is_playing_scene(), "Play must reject the unbuilt saved edit")
	assert(not has_field(node, "new_field"))
	assert(not has_field(extra, "other_field"))
	for key in cache:
		var file := FileAccess.open(cache_path + str(key), FileAccess.WRITE)
		file.store_string(str(cache[key]))
		file.close()
	OS.set_environment("PATH", original_path)
	# Repair is triggered only through the root script. Its recovery must also
	# compile the other module saved while the compiler was missing.
	script.reload(true)
	var deadline := Time.get_ticks_msec() + 30000
	while not has_field(node, "new_field") or not has_field(extra, "other_field"):
		assert(Time.get_ticks_msec() < deadline, "Remembered tools did not rebuild the pending edit")
		await process_frame
	assert(not missing_badge(root))
	node.queue_free()
	extra.queue_free()
	await process_frame
	print("TOOLCHAIN_EDITOR_RECOVERY_OK")
	quit()
