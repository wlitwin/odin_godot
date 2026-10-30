extends SceneTree

var game: Node
var phase := "boot"
var started := 0
var restored := false
var save_path := ""
var expected: Dictionary

func _initialize() -> void:
	save_path = OS.get_environment("REPLAY_CAVE_SAVE")
	restored = OS.get_environment("REPLAY_CAVE_RESUME") == "1"
	if restored:
		expected = JSON.parse_string(FileAccess.get_file_as_string(save_path + ".json"))
	game = load("res://cave.tscn").instantiate()
	root.add_child(game)
	started = Time.get_ticks_msec()

func fail(message: String) -> bool:
	print("REPLAY_CAVE_FAIL save " + message)
	quit(1)
	return true

func _process(_dt: float) -> bool:
	if Time.get_ticks_msec() - started > 18000: return fail("timeout " + phase)
	match phase:
		"boot":
			if not game.probe_ready(): return false
			if restored:
				if str(game.probe_restored_hash()) != expected.hash: return fail("complete frame hash")
				if game.probe_restored_tick() != int(expected.tick): return fail("restore tick")
				if game.probe_epoch() != 2: return fail("authority epoch")
				if game.probe_bag() != 3 or game.probe_chest(0) != 0 or game.probe_gems() != 3: return fail("inventory")
				if not game.probe_door() or game.probe_accepted() != 0: return fail("door or repeated outcome")
				game.door()
				phase = "continue"
			else:
				game.walk_to(300.0, 180.0)
				phase = "chest"
		"chest":
			if game.probe_x() > 280:
				game.loot(0)
				phase = "loot"
		"loot":
			if game.probe_bag() == 3:
				if not game.save(): return fail("first archive")
				game.walk_to(560.0, 180.0)
				phase = "door"
		"door":
			if game.probe_x() > 535:
				game.door()
				phase = "open"
		"open":
			if game.probe_door():
				game.throw(1.0, 0.0)
				phase = "rock"
		"rock":
			if game.probe_accepted() >= 3:
				if not game.save(): return fail("replacement archive")
				var metadata := FileAccess.open(save_path + ".json", FileAccess.WRITE)
				metadata.store_string(JSON.stringify({"hash": str(game.probe_saved_hash()), "tick": game.probe_saved_tick()}))
				metadata.close()
				# Simulate an interrupted next write. The committed archive must win.
				var staged := FileAccess.open(save_path + ".pending", FileAccess.WRITE)
				staged.store_string("interrupted checkpoint")
				staged.close()
				print("REPLAY_CAVE_SAVE_READY tick=", game.probe_saved_tick())
				phase = "saved" # The harness now kills this process without shutdown.
		"continue":
			if not game.probe_door() and game.probe_accepted() == 1:
				if not game.save(): return fail("save after recovery")
				print("REPLAY_CAVE_SAVE_RESUME_OK tick=", game.probe_restored_tick(), " epoch=", game.probe_epoch())
				quit(0)
				return true
	return false
