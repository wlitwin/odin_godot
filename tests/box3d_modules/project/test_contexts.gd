extends SceneTree

func fail(message: String) -> void:
	push_error("BOX3D_GODOT_CONTEXT_FAIL: " + message)
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
	if int(a.call("reject_borrowed_self")) != 5:
		fail("borrowed self was not rejected before retention callbacks")
		return
	if not bool(b.call("foreign_owner_rejected", a.call("owner_packet"))):
		fail("typed foreign realm was accepted")
		return
	if int(a.call("capture_weak")) != 0 or not bool(b.call("accept_capsule", a.call("take_capsule"))):
		fail("weak-context capsule construction")
		return
	if int(b.call("weak_read")) != 0 or int(b.call("weak_execute")) != 0:
		fail("live weak context")
		return
	a.free()
	await process_frame
	if int(b.call("weak_read")) != 0 or int(b.call("weak_execute")) != 2:
		fail("source death did not separate cached access from execution")
		return
	if int(b.call("release_capsules")) != 0:
		fail("weak-context whole destruction")
		return
	b.free()
	print("BOX3D_GODOT_CONTEXT_OK borrowed_self_rejected=true foreign_typed_rejected=true weak_execute_denied_after_actual_free=true")
	quit(0)
