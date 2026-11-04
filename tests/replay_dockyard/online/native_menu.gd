extends SceneTree

func _initialize() -> void:
	call_deferred("exercise")

func write_private(file: String, text: String) -> bool:
	var stream:=FileAccess.open(file,FileAccess.WRITE)
	if stream==null:
		return false
	var stored:=stream.store_string(text)
	stream.flush()
	var good:=stored and stream.get_error()==OK
	stream.close()
	return good

func exercise() -> void:
	var scene: Node=load("res://main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	var role:=OS.get_environment("N1_ROLE")
	var work:=OS.get_environment("N1_PRIVATE")
	var sent:=false
	var shared:=false
	for _frame in range(12000):
		await process_frame
		if not is_instance_valid(scene):
			return
		var info: Variant=JSON.parse_string(scene.call("online_status"))
		if not info is Dictionary:
			continue
		if _frame%120==0:
			var safe: Dictionary=info.duplicate()
			safe.erase("invite")
			safe.erase("watch_invite")
			print("SAMPLE_MENU ",JSON.stringify(safe))
		if info.get("enabled",false) and not info.get("configured",false):
			push_error("N1 actual configuration failed: "+str(info.get("message","")))
			quit(1)
			return
		if role=="host" and not FileAccess.file_exists(work+"/cohort.txt"):
			if not write_private(work+"/cohort.txt",str(info.get("cohort",""))):
				push_error("N1 private cohort write failed")
				quit(1)
				return
		if info.get("ended",false):
			push_error("N1 actual menu ended: "+str(info.get("message","")))
			quit(1)
			return
		if not sent and info.get("can_start",false) and FileAccess.file_exists(work+"/service.ready"):
			var view: Node=scene.get_node("View")
			var name_field: LineEdit=view.get("party_name")
			name_field.text="Mint" if role=="host" else "Coral"
			if role=="client":
				if not FileAccess.file_exists(work+"/invite.txt"):
					continue
				var code_field: LineEdit=view.get("party_code")
				code_field.text=FileAccess.get_file_as_string(work+"/invite.txt")
			var button: Button=view.get("party_host" if role=="host" else "party_join")
			if not button.disabled and button.is_visible_in_tree():
				button.emit_signal("pressed")
				sent=true
		if role=="host" and not shared and info.get("connected",false) and not str(info.get("invite","")).is_empty():
			if not write_private(work+"/invite.txt",str(info.invite)):
				push_error("N1 private invite write failed")
				quit(1)
				return
			shared=true
	push_error("N1 menu fixture bounded frame limit")
	quit(1)
