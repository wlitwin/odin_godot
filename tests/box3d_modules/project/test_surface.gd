extends SceneTree

func _init() -> void:
	process_frame.connect(run_test, CONNECT_ONE_SHOT)

func run_test() -> void:
	var a := Node.new()
	a.set_script(load("res://scripts/producer.odin"))
	root.add_child(a)
	var result := int(a.call("surface"))
	if result != 0:
		push_error("BOX3D_GODOT_SURFACE_FAIL stage=" + str(result))
		a.free()
		quit(1)
		return
	a.free()
	print("BOX3D_GODOT_SURFACE_OK primitives=box,sphere,capsule sensor_pending_end_once=true query=aabb,ray joint=hinge")
	quit(0)
