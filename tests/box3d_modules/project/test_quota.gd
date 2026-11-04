extends SceneTree

func fail(message: String) -> void:
	push_error("BOX3D_GODOT_QUOTA_FAIL: " + message)
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
	if int(a.call("create")) != 0 or int(a.call("quota_init")) != 0 or int(b.call("quota_init")) != 0:
		fail("two producer worlds and managed contexts")
		return
	if int(a.call("quota_allocate", 32 * 1024 * 1024)) != 0:
		fail("first producer allocation")
		return
	var before := int(b.call("admitted"))
	var available := 64 * 1024 * 1024 - before
	if available < 1024 or int(b.call("quota_allocate", available)) != 0:
		fail("second producer exact remaining quota")
		return
	if int(b.call("admitted")) != 64 * 1024 * 1024:
		fail("ledger did not sum both producer allocations exactly")
		return
	if int(b.call("quota_extra")) != 4 or int(a.call("capture")) != 4:
		fail("one-byte and managed capture admission must reject at full quota")
		return
	if not bool(a.call("quota_probe")) or not bool(b.call("quota_probe")):
		fail("rejected admission changed native world, caller marker, or old buffers")
		return
	if int(b.call("admitted")) != 64 * 1024 * 1024:
		fail("rejected admission changed shared ledger")
		return
	if int(b.call("quota_clear")) != 0:
		fail("second producer release")
		return
	if int(a.call("capture")) != 0:
		fail("release did not unblock first producer capture")
		return
	if int(a.call("quota_clear")) != 0:
		fail("first producer release")
		return
	a.free()
	b.free()
	print("BOX3D_GODOT_QUOTA_OK exact_bytes=67108864 over_one_rejected=true both_world_dumps_unchanged=true")
	quit(0)
