extends SceneTree

func _initialize() -> void:
	call_deferred("exercise")

func exercise() -> void:
	var scene: Node=load("res://main.tscn").instantiate()
	root.add_child(scene)
	var requested := false
	var observed := false
	var role := OS.get_environment("BOX3D_SAMPLE_ROLE")
	while is_instance_valid(scene):
		await process_frame
		var value: Variant=JSON.parse_string(scene.call("presentation"))
		if not value is Dictionary:
			continue
		if role=="host" and not requested and value.get("phase")=="Results" and value.get("round")==1:
			var view: Node=scene.get_node("View")
			var button: Button=view.get("next_button")
			if not button.visible or not button.is_visible_in_tree():
				continue
			requested=true
			button.emit_signal("pressed")
			print("SAMPLE_RETRY_REQUEST ",JSON.stringify({"role":role,"actual_button_pressed":true,"round":value.round}))
		if not observed and value.get("round")==2:
			observed=true
			print("SAMPLE_RETRY_OBSERVED ",JSON.stringify({"role":role,"round":value.round,"layout":value.layout,"phase":value.phase}))
