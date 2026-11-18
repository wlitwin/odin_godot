extends SceneTree
func make() -> Node:
	var node := Node.new()
	node.set_script(load("res://scripts/probe.odin"))
	return node
func _initialize(): call_deferred("run")
func run():
	var negative := OS.get_environment("LIFETIME_NEGATIVE")=="1"
	var observer := make()
	var source := make()
	if not source.open():
		push_error("PHYSICS_LIFETIME_FAIL: open")
		quit(1)
		return
	if negative:
		print("EXPECTED_PHYSICS_QUARANTINE_BEGIN")
		var worker := Thread.new()
		worker.start(func(): source.set_script(null))
		worker.wait_to_finish()
		print("EXPECTED_PHYSICS_QUARANTINE_END")
	source.free()
	if not observer.verify(negative) or not observer.close_globals():
		push_error("PHYSICS_LIFETIME_FAIL: context/retention/cleanup")
		quit(1)
		return
	observer.free()
	print("PHYSICS_QUARANTINE_OK" if negative else "PHYSICS_LIFETIME_OK")
	quit()
