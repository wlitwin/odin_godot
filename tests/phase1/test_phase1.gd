extends SceneTree

# Headless milestone test for Phase 1 of odin_godot.
# Run: $GODOT --headless --path tests/phase1 --script test_phase1.gd
# Prints PHASE1_OK on success, or PHASE1_FAIL: <reason>.

func _init() -> void:
	var fail := func(reason: String) -> void:
		print("PHASE1_FAIL: ", reason)
		quit(1)

	var path := "res://hello.odin"

	# 1. The Odin language registered its extension classes with the engine.
	if not ClassDB.class_exists("OdinLanguage"):
		fail.call("OdinLanguage class not registered")
		return
	if not ClassDB.class_exists("OdinScript"):
		fail.call("OdinScript class not registered")
		return

	# 2. load() of a .odin file returns an OdinScript with the file's source code.
	if not ResourceLoader.exists(path):
		fail.call("ResourceLoader does not recognize %s" % path)
		return

	var script = load(path)
	if script == null:
		fail.call("load(%s) returned null" % path)
		return
	if script.get_class() != "OdinScript":
		fail.call("loaded resource is %s, expected OdinScript" % script.get_class())
		return
	if not (script is Script):
		fail.call("loaded resource is not a Script")
		return

	var expected_source := FileAccess.get_file_as_string(path)
	var actual_source: String = script.get_source_code()
	if actual_source != expected_source:
		fail.call("source code mismatch (got %d chars, expected %d)" % [actual_source.length(), expected_source.length()])
		return
	if not actual_source.contains("package phase1_sample"):
		fail.call("source code does not contain expected text")
		return

	# 3. The base type reflects the //gd:extends marker.
	var base = script.get_instance_base_type()
	if base != "Node2D":
		fail.call("get_instance_base_type() == %s, expected Node2D" % str(base))
		return

	# 4. set_script on a compatible Node does not crash; get_script round-trips.
	var node := Node2D.new()
	node.set_script(script)
	var got_script = node.get_script()
	if got_script != script:
		fail.call("get_script() did not return the assigned script")
		return
	node.free()

	print("PHASE1_OK")
	quit(0)
