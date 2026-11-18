extends SceneTree

func _initialize() -> void:
	var packed: PackedScene = load("res://joint-final.tscn")
	var scene := packed.instantiate()
	var world: Box3DWorld3D = scene.get_node("World")
	var expected := FileAccess.get_file_as_string("res://joint-expected.json")
	var actual := world.box3d_definition_json()
	if actual != expected:
		push_error("JOINT_RELOAD_FAIL: canonical detached extraction differs after reload " + actual)
		scene.free(); quit(1); return
	scene.free(); packed = null
	print("BOX3D_JOINT_RELOAD_OK")
	quit()
