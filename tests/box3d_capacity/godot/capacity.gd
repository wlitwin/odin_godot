extends SceneTree

var probe: Node

func fail(message: String) -> void:
	push_error("CAPACITY_GODOT_FAIL " + message)
	if probe != null:
		probe.call("close")
		probe.free()
	quit(1)

func _initialize() -> void:
	if Box3DAuthoringData.MAX_BODIES < 1000 or Box3DAuthoringData.MAX_JOINTS < 100:
		fail("authoring profile is too small")
		return
	var script = load("res://modules/authoring_probe/probe.odin")
	probe = Node.new()
	probe.set_script(script)
	root.add_child(probe)
	var world := Box3DWorld3D.new()
	world.stable_key = "capacity.godot.1000.100"
	world.gravity = Vector3.ZERO
	root.add_child(world)
	var cube := Box3DBoxShape3D.new()
	cube.stable_key = "cube"
	cube.half_extents = Vector3(.1,.1,.1)
	for i in range(1000):
		var body := Box3DBody3D.new()
		body.stable_key = "body-%04d" % i
		body.body_type = 0 if i == 0 else 2
		body.position = Vector3((i % 32)*.5,(i/32)*.5,0)
		body.shapes.append(cube)
		world.add_child(body)
	for i in range(100):
		var joint := Box3DHingeJoint3D.new()
		joint.stable_key = "hinge-%03d" % i
		joint.body_a = "body-0000"
		joint.body_b = "body-%04d" % (i+1)
		joint.local_frame_a.origin = Vector3(((i+1) % 32)*.5,((i+1)/32)*.5,0)
		world.add_child(joint)
	var errors := world.box3d_diagnostics()
	var definition := world.box3d_definition()
	var encoded := world.box3d_definition_json()
	if not errors.is_empty() or definition.get("bodies",[]).size() != 1000 or definition.get("joints",[]).size() != 100:
		world.free()
		fail("frontend: " + JSON.stringify(errors))
		return
	var extracted: Dictionary = JSON.parse_string(String(probe.call("extract", world)))
	world.free()
	if not extracted.get("ok",false) or extracted.get("bodies",0) != 1000:
		fail("extract: " + JSON.stringify(extracted))
		return
	var built: Dictionary = JSON.parse_string(String(probe.call("build")))
	if not built.get("ok",false) or built.get("body_count",0) != 1000 or built.get("shape_count",0) != 1000:
		fail("build: " + JSON.stringify(built))
		return
	if int(probe.call("native_images")) != 1 or not probe.call("close") or not probe.call("clean"):
		fail("native domain or cleanup")
		return
	probe.free()
	probe = null
	print("CAPACITY_GODOT_OK bodies=1000 joints=100 source_free=true native_images=1 cleanup=zero json_bytes=", encoded.to_utf8_buffer().size())
	quit(0)
