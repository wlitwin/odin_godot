extends SceneTree

func _initialize() -> void:
	call_deferred("exercise")

func exercise() -> void:
	var packed: PackedScene = load("res://main.tscn")
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	for _frame in range(150):
		await process_frame
	await RenderingServer.frame_post_draw
	var status: Variant = JSON.parse_string(scene.call("status"))
	var frame: Variant = JSON.parse_string(scene.call("presentation"))
	if not status is Dictionary or not frame is Dictionary or frame.get("bodies",[]).size()!=14:
		push_error("Dockyard actual copied presentation unavailable")
		quit(1)
		return
	var image := root.get_texture().get_image()
	var saved := image.save_png(OS.get_environment("DOCKYARD_SCREENSHOT"))
	var closed: bool = scene.call("close")
	scene.free()
	print("DOCKYARD_VISUAL ",JSON.stringify({"screenshot_error":saved,"checked_close":closed,"status":status,"presentation":frame}))
	quit(0 if saved==OK and closed else 1)
