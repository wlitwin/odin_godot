extends SceneTree

func fail(message: String) -> void:
	push_error("BOX3D_GODOT_RELOAD_FAIL: " + message)
	quit(1)

func _init() -> void:
	process_frame.connect(run_test, CONNECT_ONE_SHOT)

func run_test() -> void:
	var kit_mode := "--kit" in OS.get_cmdline_user_args()
	var source = load("res://scripts/producer.odin")
	var a := Node.new()
	var b := Node.new()
	a.set_script(source)
	b.set_script(load("res://modules/consumer/consumer.odin"))
	root.add_child(a)
	root.add_child(b)
	if int(a.call("brand")) != 1 or (not kit_mode and int(a.call("create")) != 0):
		fail("initial generation")
		return
	if int(a.call("capture_kit" if kit_mode else "capture")) != 0:
		fail("initial complete checkpoint")
		return
	var key := int(a.call("kit_key" if kit_mode else "body_key"))
	if not bool(b.call("accept_kit_capsule" if kit_mode else "accept_capsule", a.call("take_capsule"))):
		fail("move C-shaped capsule to consumer")
		return
	var expected_y := float(b.call("capsule_y", key))
	if expected_y < -1000.0:
		fail("initial capsule cache")
		return
	a.free()
	await process_frame
	var output := []
	var rc := OS.execute("bash", [ProjectSettings.globalize_path("res://rebuild_producer.sh")], output, true)
	if rc != 0:
		fail("producer-only rebuild: " + "\n".join(output))
		return
	if source.reload(true) != OK:
		fail("producer reload rejected")
		return
	var replacement := Node.new()
	replacement.set_script(source)
	root.add_child(replacement)
	if int(replacement.call("brand")) != 2:
		fail("new generation was not installed")
		return
	if float(b.call("capsule_y", key)) != expected_y or int(b.call("clone_capsule")) != 0:
		fail("old generation checkpoint read/clone after source free and reload")
		return
	if not kit_mode:
		if int(b.call("restore_target")) != 0:
			fail("origin native-only restore into consumer world")
			return
		if float(b.call("target_y", key)) != expected_y:
			fail("retargeted destination body")
			return
		if int(b.call("target_step")) != 0 or float(b.call("target_y", key)) >= expected_y:
			fail("consumer step after old-origin native-only restore")
			return
		if int(b.call("clear_target")) != 0:
			fail("consumer world release")
			return
	print("BOX3D_GODOT_RELEASE_OLD_CAPSULES_BEGIN")
	if int(b.call("release_capsules")) != 0:
		fail("old generation whole cleanup")
		return
	print("BOX3D_GODOT_RELEASE_OLD_CAPSULES_RETURNED")
	await process_frame
	await process_frame
	if int(replacement.call("brand")) != 2:
		fail("new generation damaged by old owner collection")
		return
	replacement.free()
	b.free()
	print("BOX3D_GODOT_RELOAD_OK framework=", "Kit" if kit_mode else "Replay", " old_checkpoint_survived=true native_only_restore=", not kit_mode)
	quit(0)
