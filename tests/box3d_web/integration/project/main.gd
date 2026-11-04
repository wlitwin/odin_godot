extends Node3D

func require_test(condition: bool, message: String) -> bool:
	if not condition:
		push_error("WEBBOX_FAIL "+message)
		get_tree().quit(1)
		return false
	return true

func getter_batch(probe: Node, count: int) -> bool:
	for _index in range(count):
		var value: String = probe.call("text")
		if value!="actual web callback 1":
			return false
	return true

func _ready() -> void:
	var probe: Node = $Probe
	var world: Node = probe.get_node("AuthoredWorld")
	var source_ref: WeakRef = weakref(world)
	var proxies: Dictionary = {}
	for body in world.get_children():
		if body is Box3DBody3D:
			var proxy := MeshInstance3D.new()
			var shape: Resource = body.shapes[0]
			var mesh: PrimitiveMesh
			if shape is Box3DBoxShape3D:
				var box := BoxMesh.new()
				box.size=shape.half_extents*2
				mesh=box
			else:
				if not require_test(shape is Box3DSphereShape3D,"fixture geometry"):
					return
				var sphere := SphereMesh.new()
				sphere.radius=shape.radius
				sphere.height=shape.radius*2
				mesh=sphere
			proxy.mesh=mesh
			var material := StandardMaterial3D.new()
			material.albedo_color=Color("4bd5cf") if body.stable_key=="player" else Color("d8b264")
			proxy.material_override=material
			proxy.transform=body.transform
			add_child(proxy)
			proxies[body.stable_key]=proxy
	var camera := Camera3D.new()
	camera.position=Vector3(8,6,9)
	add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.current=true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-45,-30,0)
	add_child(sun)
	await get_tree().process_frame
	await get_tree().process_frame
	var source_freed := source_ref.get_ref()==null
	if not require_test(source_freed,"actual authoring source destruction"):
		return
	for _frame in range(60):
		var poses: Variant=JSON.parse_string(probe.call("step"))
		if not require_test(poses is Array and poses.size()==4,"actual copied native poses"):
			return
		for row in poses:
			var part: Node3D=proxies[row.key]
			var p: Array=row.position
			var q: Array=row.rotation
			part.position=Vector3(p[0],p[1],p[2])
			part.quaternion=Quaternion(q[0],q[1],q[2],q[3])
		await get_tree().process_frame
	var weak_was_live: bool = probe.call("weak_live")
	if not require_test(weak_was_live,"real weak owner before source death"):
		return
	if not require_test(getter_batch(probe,128),"warmup callback return ownership"):
		return
	var before := [int(probe.call("temp_used")),int(probe.call("temp_capacity")),int(probe.call("temp_count"))]
	if not require_test(getter_batch(probe,10000),"first callback batch"):
		return
	var middle := [int(probe.call("temp_used")),int(probe.call("temp_capacity")),int(probe.call("temp_count"))]
	if not require_test(getter_batch(probe,10000),"second callback batch"):
		return
	var after := [int(probe.call("temp_used")),int(probe.call("temp_capacity")),int(probe.call("temp_count"))]
	if OS.has_feature("web"):
		if not require_test(before[0]>=0 and before==middle and middle==after,"actual callback arena restoration"):
			return
	var churn_count: int = probe.call("churn")
	if not require_test(churn_count==70000,"real owner cycles across pointer-tag retirement"):
		return
	var origins_rejected: bool = probe.call("origin_rejected")
	if not require_test(origins_rejected,"out-of-image callbacks rejected before invocation"):
		return
	var value: Variant = JSON.parse_string(probe.call("exercise"))
	if not require_test(value is Dictionary and value.get("ok")==true,"actual source-free native exercise"):
		return
	var probe_ref: WeakRef = weakref(probe)
	probe.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	if not require_test(probe_ref.get_ref()==null,"actual Odin creator destruction"):
		return
	var weak_rejected: bool = $Keeper.call("weak_rejected")
	if not require_test(weak_rejected,"stale owner denied and explicitly dropped"):
		return
	print("WEBBOX_PASS ",JSON.stringify({"native":value,"temp_before":before,"temp_middle":middle,"temp_after":after,"owner_churn":churn_count,"origins_rejected":origins_rejected,"weak_source_freed":weak_rejected,"actual_source_free":source_freed}))
	if OS.has_feature("web"):
		await RenderingServer.frame_post_draw
	get_tree().quit()
