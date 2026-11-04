extends SceneTree

func fail(message: String) -> void:
	push_error("BOX3D_GODOT_DOMAIN_FAIL: " + message)
	quit(1)

func _init() -> void:
	process_frame.connect(run_test, CONNECT_ONE_SHOT)

func run_test() -> void:
	var a_script = load("res://scripts/producer.odin")
	var b_script = load("res://modules/consumer/consumer.odin")
	if a_script == null or b_script == null:
		fail("separate producer/consumer modules did not load")
		return
	var a := Node.new()
	var b := Node.new()
	var pure := Node.new()
	a.set_script(a_script)
	b.set_script(b_script)
	pure.set_script(load("res://modules/vocabulary/pure.odin"))
	root.add_child(a)
	root.add_child(b)
	root.add_child(pure)
	if not bool(pure.call("check")):
		fail("native-free module rejected by opted-in Core")
		return
	var cookie := int(a.call("cookie"))
	if int(b.call("native_images")) != 1:
		fail("process loaded more than one Box3D image")
		return
	if cookie == 0 or int(b.call("cookie")) != cookie:
		fail("actual loaded native domains differ")
		return
	if int(a.call("create")) != 0:
		fail("world creation in producer was rejected")
		return
	var world := int(a.call("world"))
	var key := int(a.call("body_key"))
	if world == 0 or key == 0:
		fail("producer did not return checked native world/key")
		return
	var y_before := float(b.call("y", world, key))
	if y_before != float(a.call("y")) or abs(y_before - 2.0) > 0.001:
		fail("consumer cannot read producer body through the shared domain")
		return
	for _tick in range(8):
		if int(b.call("step", world)) != 0:
			fail("consumer cannot step producer world")
			return
	var y_after := float(b.call("y", world, key))
	if y_after >= y_before or y_after != float(a.call("y")):
		fail("modules did not observe the same stepped world")
		return
	if int(a.call("clear")) != 0:
		fail("producer world cleanup failed")
		return
	a.free()
	b.free()
	pure.free()
	print("BOX3D_GODOT_DOMAIN_OK shared_cookie=", cookie, " eight_cross_module_steps=8")
	quit(0)
