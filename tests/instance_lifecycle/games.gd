extends SceneTree

func _initialize():
	call_deferred("run")

func require(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok

func run():
	var scene = load(ProjectSettings.get_setting("application/run/main_scene"))
	for cycle in 2:
		var game = scene.instantiate()
		var authored_children: Array = game.get_children()
		root.add_child(game)
		await process_frame
		if OS.get_environment("LIFECYCLE_CAVE") == "1":
			if cycle == 0:
				game.on_host()
				game.on_start()
			else:
				game.on_resume()
		for frame in 25:
			await physics_frame
		var world: int = game.lifecycle_probe()
		if not require(world != 0, "gameplay did not start"):
			return
		var parking = Node.new()
		root.add_child(parking)
		game.reparent(parking)
		game.reparent(root)
		parking.free()
		if not require(game.lifecycle_probe() == world, "reparent retired or replaced the live stack"):
			return
		if OS.get_environment("LIFECYCLE_CAVE") == "1" and cycle == 0:
			game.save_run()
		if cycle == 1:
			game.set_script(null)
			await process_frame
			for child in game.get_children():
				if not require(child in authored_children, "script removal retained an owned child: " + str(child.name)):
					return
		game.free()
		await process_frame
		await process_frame
		if OS.get_environment("LIFECYCLE_CAVE") == "1":
			var peer = ENetMultiplayerPeer.new()
			if not require(peer.create_server(int(OS.get_environment("CAVE_PORT"))) == OK, "cleanup retained the listening socket"):
				return
			peer.close()
		print("GAME_LIFECYCLE_CYCLE ", cycle)
	scene = null
	await process_frame
	print("GAME_LIFECYCLE_OK")
	quit()
