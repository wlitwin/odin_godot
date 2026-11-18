extends SceneTree
func _initialize() -> void: call_deferred("run")
func probe() -> Node:
	var node := Node.new();node.set_script(load("res://modules/owner_probe/probe.odin"));root.add_child(node);return node
func fail(message: String) -> void: push_error("COMPLETE_OWNER_FAIL: " + message);quit(1)
func run() -> void:
	var observer := probe()
	var world: Node3D = load("res://content/world.tscn").instantiate();root.add_child(world)
	if not observer.zero():fail("baseline");return
	if not observer.replay_cases(world):fail("Replay failure/epoch/checkpoint/parallel lifecycle");return
	print("COMPLETE_OWNER_REPLAY_OK")
	if not observer.kit_cases(world):fail("Kit busy-close/checkpoint lifecycle");return
	print("COMPLETE_OWNER_KIT_OK")
	var closing := probe()
	var trap: Box3DWorld3D = load("res://world_trap.gd").new()
	trap.stable_key = "trap"
	var packed: Node3D = load("res://content/world.tscn").instantiate()
	for child in packed.get_children():
		packed.remove_child(child);trap.add_child(child)
	packed.free();root.add_child(trap)
	trap.target = closing
	if closing.open_replay(trap) != "Wrong_Phase" or closing.get_script() != null:fail("opening cancellation on script removal");return
	closing.free();trap.free();world.free()
	if not observer.zero():fail("final allocation/owner cleanup");return
	observer.free()
	print("COMPLETE_PHYSICS_OWNER_OK");quit()
