extends SceneTree

func _initialize() -> void:
	call_deferred("exercise")

func exercise() -> void:
	var scene: Node=load("res://main.tscn").instantiate()
	root.add_child(scene)
	for _frame in range(150):
		await process_frame
	await RenderingServer.frame_post_draw
	var status: Variant=JSON.parse_string(scene.call("status"))
	var frame: Variant=JSON.parse_string(scene.call("presentation"))
	var view: Node=scene.get_node("View")
	var proxies: Dictionary=view.get("proxies")
	var spheres := 0
	for name in ["robot_a","robot_b"]:
		for mesh in proxies[name].get_children():
			if mesh is MeshInstance3D and mesh.mesh is SphereMesh:
				spheres+=1
	var valid: bool=status is Dictionary and frame is Dictionary and frame.get("bodies",[]).size()==19 and spheres==2 and view.get("bay_materials").size()==3 and view.get("cargo_clamps").size()==3
	if not valid:
		push_error("ROUND_VISUAL_FAIL actual presentation/robot/bay/clamp surfaces")
		quit(1)
		return
	var image := root.get_texture().get_image()
	var saved := image.save_png(OS.get_environment("DOCKYARD_SCREENSHOT"))
	var closed: bool=scene.call("close")
	scene.free()
	print("ROUND_VISUAL ",JSON.stringify({"screenshot_error":saved,"checked_close":closed,"status":status,"presentation":frame,"actual_sphere_meshes":spheres}))
	quit(0 if saved==OK and closed else 1)
