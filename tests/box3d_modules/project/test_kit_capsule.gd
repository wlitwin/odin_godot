extends SceneTree

func fail(message: String) -> void:
	push_error("BOX3D_GODOT_KIT_CAPSULE_FAIL: " + message)
	quit(1)

func _init() -> void:
	process_frame.connect(run_test, CONNECT_ONE_SHOT)

func run_test() -> void:
	var source = load("res://scripts/producer.odin")
	var a := Node.new()
	var b := Node.new()
	a.set_script(source)
	b.set_script(load("res://modules/consumer/consumer.odin"))
	root.add_child(a)
	root.add_child(b)
	var capture := int(a.call("capture_kit"))
	if capture != 0 or int(a.call("kit_sources")) != 0:
		fail("complete Kit factory/source cleanup: " + str(capture))
		return
	var key := int(a.call("kit_key"))
	if not bool(b.call("accept_kit_capsule", a.call("take_capsule"))):
		fail("C-shaped capsule transfer")
		return
	var expected := float(b.call("capsule_y", key))
	if expected < -1000.0:
		fail("initial cached pose")
		return
	a.free()
	await process_frame
	if float(b.call("capsule_y", key)) != expected or int(b.call("clone_capsule")) != 0:
		fail("cached pose/clone after actual source free")
		return
	if int(b.call("release_capsules")) != 0:
		fail("Kit full checkpoint/allocator destruction")
		return
	b.free()
	print("BOX3D_GODOT_KIT_CAPSULE_OK source_lane_session_provider_proxy_freed=true")
	quit(0)
