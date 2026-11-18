extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene: Node = load("res://game.tscn").instantiate()
	root.add_child(scene)
	scene.get_node("Button").pressed.emit()
	scene.get_node("Value").value_changed.emit(12.5)
	scene.get_node("Emitter").emit_signal("payload", {"entry": [1, 2, 3]})
	var body := Node2D.new()
	scene.add_child(body)
	scene.get_node("Emitter").emit_signal("body_seen", body)
	scene.get_node("Emitter").emit_signal("helper")
	assert(scene.get("hits") == 111)
	assert(is_equal_approx(float(scene.get("amount")), 12.5))
	assert(scene.get("kind") == TYPE_DICTIONARY)
	var item := Resource.new()
	item.set_script(load("res://scripts/Item_Definition.odin"))
	assert(item.get_script() != null)
	scene.queue_free()
	await process_frame
	print("EDITOR_AUTHORING_RUNTIME_OK")
	quit()
