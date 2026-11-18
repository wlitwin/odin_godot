extends SceneTree

func _initialize() -> void:
	for files in [["identity-final.tscn", "expected.json"], ["identity-inherited-final.tscn", "expected-inherited.json"], ["identity-standalone-final.tscn", "expected-standalone.json"]]:
		var scene: PackedScene = load("res://" + files[0])
		var authored := scene.instantiate()
		root.add_child(authored)
		var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://" + files[1]))
		var actual: Dictionary = load("res://snapshot.gd").read(authored)
		if actual != expected:
			push_error("IDENTITY_RELOAD_FAIL " + files[0] + " " + JSON.stringify(actual))
			authored.free()
			quit(1)
			return
		if authored.has_node("World") and not authored.get_node("World").box3d_diagnostics().is_empty():
			push_error("Saved identity graph is invalid")
			authored.free()
			quit(1)
			return
		authored.free()
		scene = null
	var external: Box3DShape3D = load("res://external-shape.tres")
	if external.stable_key != "external.shape":
		push_error("External shape ID did not survive editor saving")
		quit(1)
		return
	print("BOX3D_IDENTITY_RELOAD_OK")
	quit()
