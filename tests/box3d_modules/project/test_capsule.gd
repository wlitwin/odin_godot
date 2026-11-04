extends SceneTree

func fail(message: String) -> void:
	push_error("BOX3D_GODOT_CAPSULE_FAIL: " + message)
	quit(1)

func _init() -> void:
	process_frame.connect(run_test, CONNECT_ONE_SHOT)

func run_test() -> void:
	var a := Node.new()
	var b := Node.new()
	a.set_script(load("res://scripts/producer.odin"))
	b.set_script(load("res://modules/consumer/consumer.odin"))
	root.add_child(a)
	root.add_child(b)
	if int(a.call("create")) != 0:
		fail("producer world creation")
		return
	var key := int(a.call("body_key"))
	if int(a.call("capture")) != 0:
		fail("complete checkpoint/capsule capture")
		return
	var packet: PackedByteArray = a.call("take_capsule")
	if not bool(b.call("accept_capsule", packet)):
		fail("fixed C-shaped process-local capsule transfer")
		return
	# Free the actual source instance and native world before reading/cloning.
	a.free()
	await process_frame
	if abs(float(b.call("capsule_y", key)) - 2.0) > 0.001:
		fail("detached cached body read after source free")
		return
	if int(b.call("clone_capsule")) != 0:
		fail("origin clone through stable Core after source free")
		return
	if int(b.call("release_capsules")) != 0:
		fail("whole origin cleanup")
		return
	b.free()
	print("BOX3D_GODOT_CAPSULE_OK actual_source_freed=true clone_and_cached_read=true")
	quit(0)
