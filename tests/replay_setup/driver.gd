extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene: Node = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var message: String = scene.get_node("Status").text
	assert(message.contains("model.control_valid"), message)
	assert(message.contains("required control validation callback"), message)
	assert(scene.get_node("Status").get_rect().end.x <= root.get_visible_rect().size.x, "Setup message extends past the viewport")
	scene.queue_free()
	await process_frame
	print("REPLAY_SETUP_UI_OK")
	quit()
