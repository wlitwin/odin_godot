extends SceneTree

var game: Node
var host := false
var recovering := false
var phase := "join"
var started := 0
var since := 0
var save_path := ""
var expected: Dictionary

func _initialize() -> void:
	host = OS.get_environment("REPLAY_CAVE_ROLE") == "host"
	recovering = OS.get_environment("REPLAY_CAVE_RECOVERY_STAGE") == "resume"
	save_path = OS.get_environment("REPLAY_CAVE_SAVE")
	if host and recovering:
		expected = JSON.parse_string(FileAccess.get_file_as_string(save_path + ".json"))
	game = load("res://cave.tscn").instantiate()
	root.add_child(game)
	started = Time.get_ticks_msec()

func fail(message: String) -> bool:
	print("REPLAY_CAVE_FAIL recovery ", "host " if host else "client ", message)
	quit(1)
	return true

func _process(_dt: float) -> bool:
	var now := Time.get_ticks_msec()
	if now - started > 22000: return fail("timeout " + phase)
	match phase:
		"join":
			if not game.probe_ready() or game.probe_players() != 2: return false
			if recovering:
				if game.probe_gems() != 3 or game.probe_chest(0) != 0: return fail("saved inventory")
				if not game.probe_door(): return fail("saved door")
				if host:
					if str(game.probe_restored_hash()) != expected.hash: return fail("complete authority frame")
					if game.probe_restored_tick() != int(expected.tick) or game.probe_epoch() != 2: return fail("tick/epoch")
					phase = "closed"
				else:
					if game.probe_bag() != 3: return fail("stable guest seat")
					game.walk_to(560.0, 180.0)
					phase = "resume_door"
			elif host:
				phase = "open"
			else:
				game.walk_to(300.0, 180.0)
				phase = "chest"
		"chest":
			if game.probe_x() > 280:
				game.loot(0)
				phase = "loot"
		"loot":
			if game.probe_bag() == 3:
				game.walk_to(560.0, 180.0)
				phase = "door"
		"door":
			if game.probe_x() > 535:
				game.door()
				phase = "waiting"
		"open":
			if game.probe_door():
				if not game.save(): return fail("archive")
				var metadata := FileAccess.open(save_path + ".json", FileAccess.WRITE)
				metadata.store_string(JSON.stringify({"hash": str(game.probe_saved_hash()), "tick": game.probe_saved_tick()}))
				metadata.close()
				print("REPLAY_CAVE_RECOVERY_SAVED")
				phase = "waiting"
		"resume_door":
			if game.probe_x() > 535:
				game.door()
				phase = "closed"
		"closed":
			if not game.probe_door() and (host or game.probe_accepted() == 1):
				since = now
				phase = "linger"
				if not host:
					var stall := int(OS.get_environment("REPLAY_CAVE_RECOVERY_STALL_MS"))
					if stall > 0 and stall <= 5000: OS.delay_msec(stall)
		"linger":
			if now - since > (1500 if host else 500):
				# The host must remain available until the guest has checked its
				# resumed state. Independent wall-clock quit timers can race when a
				# guest stalls/resyncs, making unavailable state look like zero loot.
				if host and not FileAccess.file_exists(save_path + ".client.done"): return false
				if not game.probe_ready(): return false
				if game.probe_gems() != 3 or (not host and game.probe_bag() != 3):
					return fail("continued conservation total=%d bag=%d players=%d" % [game.probe_gems(), game.probe_bag(), game.probe_players()])
				if not host:
					var completed := FileAccess.open(save_path + ".client.done", FileAccess.WRITE)
					completed.store_string("verified")
					completed.close()
				print("REPLAY_CAVE_RECOVERY_", "HOST_OK" if host else "CLIENT_OK")
				quit(0)
				return true
	return false
