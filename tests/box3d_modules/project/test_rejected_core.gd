extends SceneTree

func _init() -> void:
	process_frame.connect(run_test, CONNECT_ONE_SHOT)

func run_test() -> void:
	for path in ["res://scripts/producer.odin", "res://modules/consumer/consumer.odin", "res://modules/vocabulary/pure.odin"]:
		var script = load(path)
		if script == null or not script.get_script_method_list().is_empty():
			push_error("BOX3D_GODOT_CORE_REJECTION_FAIL published_module=" + path)
			quit(1)
			return
	print("BOX3D_GODOT_CORE_REJECTION_OK no_module_descriptors=true")
	quit(0)
