extends Node

var probe: Node
var failure := false
func fail(message: String) -> void:
	failure = true
	push_error("BOX3D_STARTER_FAIL: " + message)
	get_tree().quit(1)
func check(value: bool, message: String) -> bool:
	if not value: fail(message)
	return value
func _ready() -> void:
	probe = Node.new()
	probe.set_script(load("res://scripts/probe.odin"))
	add_child(probe)
	call_deferred("run")
func frames(count: int) -> void:
	for _i in range(count): await get_tree().physics_frame
func press(action: String) -> void:
	Input.action_press(action)
	await frames(2)
	Input.action_release(action)
func equivalent(a: Transform3D, b: Transform3D) -> bool:
	if a.origin.distance_to(b.origin) > 0.0005: return false
	for i in range(3):
		if a.basis[i].distance_to(b.basis[i]) > 0.0005: return false
	return true
func bound_pose(world: Node3D, body: Node3D) -> Transform3D:
	return world.global_transform * Transform3D(Basis(probe.rotation(body)), probe.position(body))
func run() -> void:
	await frames(2)
	var game := get_tree().current_scene
	if not check(game != null and probe.live_bytes() > 0, "ordinary starter creates physics"): return
	var world: Node3D = game.get_node("World")
	var crate: Node3D = world.get_node("Crate")
	await frames(100)
	if not check(crate.position.y < 1.2 and crate.position.y > 0.35, "crate falls and rests on floor"): return
	var capture := OS.get_environment("BOX3D_STARTER_CAPTURE")
	if not capture.is_empty():
		await RenderingServer.frame_post_draw
		if not check(get_viewport().get_texture().get_image().save_png(capture) == OK, "rendered starter capture"): return
	var resting := crate.position.y
	await press("jump")
	await frames(15)
	if not check(crate.position.y > resting + 0.5, "Space action applies impulse"): return
	for _i in range(3):
		await press("reset")
		if not check(abs(crate.position.y - 3.0) < 0.04, "reset uses immutable authored position"): return
		await frames(20)
	var live_before: int = probe.live_bytes()
	get_tree().root.remove_child(game)
	await frames(3)
	if not check(probe.live_bytes() == live_before, "temporary exit preserves physics owner"): return
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await press("reset")
	if not check(abs(crate.position.y - 3.0) < 0.04, "reentry retains original reset baseline"): return
	get_tree().root.remove_child(game)
	game.set_script(null)
	if not check(probe.live_bytes() == 0, "script removal outside tree finalizes native owner"): return
	game.free()
	var packed: PackedScene = load("res://main.tscn")
	game = packed.instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(3)
	if not check(probe.live_bytes() > 0, "fresh scene starts after prior cleanup"): return
	game.queue_free()
	await frames(3)
	if not check(probe.live_bytes() == 0, "node deletion cleanup"): return
	print("BOX3D_STARTER_GAMEPLAY_OK")
	if not helper_cases(): return
	probe.free();probe = null
	print("BOX3D_STARTER_OK")
	get_tree().quit(0)

func helper_cases() -> bool:
	var packed: PackedScene = load("res://content/world.tscn")
	var host := Node3D.new()
	host.transform = Transform3D(Basis.from_euler(Vector3(0.15,0.4,-0.2)),Vector3(5,2,-3))
	add_child(host)
	var world: Box3DWorld3D = packed.instantiate()
	world.transform = Transform3D(Basis.from_euler(Vector3(0.1,-0.2,0.05)),Vector3(-1,0.5,2))
	host.add_child(world)
	var parent: Box3DBody3D = world.get_node("Floor")
	var child: Box3DBody3D = world.get_node("Crate")
	parent.stable_key = "z.parent"
	parent.body_type = 2
	parent.gravity_scale = 0.5
	child.stable_key = "a.child"
	child.reparent(parent, true)
	var group := Node.new();world.add_child(group);parent.reparent(group, true)
	var visual: MeshInstance3D = child.get_node("Visual")
	visual.position = Vector3(0.15,0.2,-0.1);visual.scale = Vector3(0.8,1.1,0.9)
	var visual_local := visual.transform
	var nested: Box3DWorld3D = packed.instantiate()
	world.add_child(nested)
	var nested_pose: Transform3D = nested.get_node("Crate").global_transform
	var initial_parent := parent.global_transform
	var initial_child := child.global_transform
	if not check(probe.open_world(world) == "None" and probe.body_count() == 2, "transformed/plain-node capture and nested World scope"): return false
	print("BOX3D_STARTER_HELPER_CAPTURE_OK")
	for _i in range(30):
		if not check(probe.step_world() == "None", "manual fixed step"): return false
		if not check(equivalent(parent.global_transform,bound_pose(world,parent)) and equivalent(child.global_transform,bound_pose(world,child)), "parent-before-child pose publication with reversed key order"): return false
	if not check(visual.transform == visual_local and nested.get_node("Crate").global_transform == nested_pose, "visual local transforms and nested World remain untouched"): return false
	if not check(probe.reset_world() == "None" and equivalent(parent.global_transform,initial_parent) and equivalent(child.global_transform,initial_child), "reset from captured transforms"): return false
	world.position += Vector3(2,0,1)
	if not check(probe.step_world() == "None" and equivalent(child.global_transform,bound_pose(world,child)), "moving World presentation frame"): return false
	var before: Vector3 = probe.first_position()
	Engine.physics_ticks_per_second = 30
	var timing: String = probe.step_world()
	Engine.physics_ticks_per_second = 60
	if not check(timing == "Timing" and probe.first_position() == before, "timing mismatch refuses step"): return false
	child.reparent(world, true)
	if not check(probe.step_world() == "Binding" and probe.first_position() == before, "changed body ancestry refuses step"): return false
	if not check(probe.close() and probe.live_bytes() == 0, "tracked helper cleanup after invalid binding"): return false
	host.free()
	world = packed.instantiate();add_child(world)
	world.get_node("Crate").scale = Vector3(2,1,1)
	if not check(probe.open_world(world) == "Authoring" and probe.close() and probe.live_bytes() == 0, "invalid authoring cleanup"): return false
	world.free()
	world = packed.instantiate();add_child(world)
	if not check(probe.open_world(world) == "None", "weak binding fixture"): return false
	probe.remember(world.get_node("Crate"))
	world.get_node("Crate").free()
	if not check(not probe.lookup_saved(), "stale onready pointer lookup is safe"): return false
	world.free()
	if not check(probe.step_world() == "Binding" and probe.close() and probe.live_bytes() == 0, "freed source detected and cleaned"): return false
	world = packed.instantiate();add_child(world)
	var trapped: Node3D = world.get_node("Crate")
	var shapes: Array = trapped.shapes
	trapped.set_script(load("res://body_trap.gd"))
	trapped.stable_key = "crate";trapped.body_type = 2;trapped.shapes.assign(shapes)
	trapped.set_notify_local_transform(true)
	var victim := Node.new();victim.set_script(load("res://scripts/probe.odin"));add_child(victim)
	if not check(victim.open_world(world) == "None", "reentrant fixture capture"): return false
	trapped.target = victim;trapped.armed = true
	var interrupted: String = victim.step_world()
	if not check(interrupted == "Interrupted" and victim.get_script() == null and probe.live_bytes() == 0, "synchronous script removal during pose publication"): return false
	victim.free();world.free()
	print("BOX3D_STARTER_HELPER_OK")
	return true
