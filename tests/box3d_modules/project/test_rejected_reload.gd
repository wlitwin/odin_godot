extends SceneTree

func fail(message: String) -> void:
	push_error("BOX3D_GODOT_REJECTED_RELOAD_FAIL: " + message)
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
	if int(a.call("brand")) != 1 or int(a.call("create")) != 0 or int(a.call("capture")) != 0:
		fail("initial live generation")
		return
	var world := int(a.call("world"))
	var key := int(a.call("body_key"))
	var expected := float(a.call("y"))
	if not bool(b.call("accept_capsule", a.call("take_capsule"))):
		fail("retained original checkpoint")
		return
	var output := []
	if OS.execute("bash", [ProjectSettings.globalize_path("res://install_rejected_candidate.sh")], output, true) != 0:
		fail("candidate installation: " + "\n".join(output))
		return
	if source.reload(true) == OK:
		fail("invalid replacement was accepted")
		return
	if int(a.call("brand")) != 1 or int(a.call("world")) != world or float(a.call("y")) != expected:
		fail("rejected replacement changed live publication")
		return
	if int(b.call("native_images")) != 1 or float(b.call("capsule_y", key)) != expected or int(b.call("clone_capsule")) != 0:
		fail("rejected replacement damaged native domain or retained checkpoint")
		return
	if int(b.call("step", world)) != 0 or float(a.call("y")) >= expected:
		fail("old generation cannot continue after rejected reload")
		return
	if int(b.call("release_capsules")) != 0 or int(a.call("clear")) != 0:
		fail("original generation cleanup")
		return
	a.free()
	b.free()
	print("BOX3D_GODOT_REJECTED_RELOAD_OK publication_preserved=true native_images=1")
	quit(0)
