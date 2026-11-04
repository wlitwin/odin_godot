extends SceneTree

func fail(message: String) -> void:
	push_error("BOX3D_GODOT_REJECTION_FAIL: " + message)
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
	if int(a.call("cookie")) == 0 or int(a.call("cookie")) != int(b.call("cookie")):
		fail("valid modules lost their shared native domain")
		return
	if int(b.call("native_images")) != 1:
		fail("rejected static/duplicate backend remained loaded")
		return
	# Query the SDK script resource itself: script classes are not ClassDB classes.
	var rejected = load("res://modules/bad/bad.odin")
	if rejected == null or rejected.has_script_method("attempt") or not rejected.get_script_method_list().is_empty():
		fail("rejected producer descriptors were published")
		return
	if int(a.call("create")) != 0:
		fail("valid producer was poisoned by rejected peer module")
		return
	var world := int(a.call("world"))
	if int(b.call("step", world)) != 0 or int(a.call("clear")) != 0:
		fail("valid world lifecycle after rejection")
		return
	a.free()
	b.free()
	print("BOX3D_GODOT_REJECTION_OK valid_modules_usable=true native_images=1")
	quit(0)
