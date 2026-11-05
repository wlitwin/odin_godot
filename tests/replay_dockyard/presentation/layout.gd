extends SceneTree

var failures: Array[String] = []
var observations: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("exercise")

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func rect(data: Dictionary) -> Rect2:
	var r: Array = data.rect
	return Rect2(r[0],r[1],r[2],r[3])

func exercise() -> void:
	var scene: Node = load("res://main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for _frame in range(5):
		await process_frame
	var view: Node = scene.get_node("View")
	# Geometry-only fixture: keep the actual controls, layout and resize signals,
	# without having the presentation poll overwrite forced modal visibility.
	view.set_process(false)
	var crew_panel: Control = view.party_box.get_parent()
	var settings_panel: Control = view.settings_box.get_parent()
	var results_panel: Control = view.result_box.get_parent()
	for dimensions in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(1024,768),Vector2i(800,600),Vector2i(3440,1440),Vector2i(720,1280)]:
		root.size = dimensions
		crew_panel.show()
		for _frame in range(4):
			await process_frame
		var layout: Dictionary = view.ui_layout()
		var size: Vector2 = Vector2(layout.viewport[0],layout.viewport[1])
		var bounds := Rect2(Vector2.ZERO,size).grow(0.5)
		for name in ["status","help","crew"]:
			check(bounds.encloses(rect(layout.panels[name])),"%s outside %s" % [name,dimensions])
		var status := rect(layout.panels.status)
		var help := rect(layout.panels.help)
		var crew := rect(layout.panels.crew)
		check(absf(status.position.x-24)<0.5 and absf(status.position.y-22)<0.5,"status anchor %s" % dimensions)
		check(absf(crew.end.x-(size.x-24))<0.5 and absf(crew.position.y-22)<0.5,"crew anchor %s" % dimensions)
		check(absf(help.position.x-24)<0.5 and absf(help.end.y-(size.y-22))<0.5,"help anchor %s" % dimensions)
		check(not status.intersects(crew) and not help.intersects(crew),"HUD overlap %s" % dimensions)
		var camera: Camera3D = view.camera
		var aspect: float = size.x/size.y
		check(camera.size+0.001>=view.camera_zoom,"camera vertical crop %s" % dimensions)
		check(camera.size*aspect+0.001>=view.camera_zoom*(1280.0/720.0),"camera horizontal crop %s" % dimensions)
		var target := Vector3.ZERO
		var mouse := camera.unproject_position(target)
		var hit: Variant = Plane(Vector3.UP,0).intersects_ray(camera.project_ray_origin(mouse),camera.project_ray_normal(mouse))
		check(hit is Vector3 and hit.distance_to(target)<0.001,"camera pointer projection %s" % dimensions)
		layout["modal_rects"] = []
		for panel in [settings_panel,results_panel]:
			panel.show()
			for _frame in range(3):
				await process_frame
			var r: Rect2 = panel.get_global_rect()
			layout.modal_rects.append([r.position.x,r.position.y,r.size.x,r.size.y])
			check(bounds.encloses(r),"modal outside %s" % dimensions)
			# Integer-pixel placement can put an odd-sized panel half a pixel off.
			check(r.get_center().distance_to(size*0.5)<=0.75,"modal center %s" % dimensions)
			panel.hide()
		observations.append(layout)
	var output := {"result":"PASS" if failures.is_empty() else "FAIL","scope":"Actual SDK controls, container anchors, camera fit and pointer projection at seven window sizes; geometry only.","failures":failures,"observations":observations}
	var file := FileAccess.open(OS.get_environment("DOCKYARD_LAYOUT_OUTPUT"),FileAccess.WRITE)
	file.store_string(JSON.stringify(output,"\t"))
	file.close()
	print("DOCKYARD_LAYOUT_TEST ",JSON.stringify({"result":output.result,"failures":failures}))
	view.request_exit(0 if failures.is_empty() else 1)
