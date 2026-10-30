extends SceneTree

var game: Node
var member := 0
var mode := ""
var directory := ""
var phase := "join"
var started := 0
var kicks_before := 0
var final_round := 0
var proposed_at := 0
var verified_round := 0

func _initialize() -> void:
	member = int(OS.get_environment("RSL_MEMBER"))
	mode = OS.get_environment("REPLAY_MIGRATION_MODE")
	directory = OS.get_environment("REPLAY_MIGRATION_DIR")
	game = load("res://slopball.tscn").instantiate()
	root.add_child(game)
	started = Time.get_ticks_msec()

func p(field: String) -> int:
	return game.probe(field)

func exists(name: String) -> bool:
	return FileAccess.file_exists(directory + "/" + name)

func put(name: String, value: Dictionary = {}) -> void:
	var destination := directory + "/" + name
	var staged := destination + ".pending"
	var file := FileAccess.open(staged, FileAccess.WRITE)
	file.store_string(JSON.stringify(value))
	file.close()
	assert(DirAccess.rename_absolute(staged, destination) == OK)

func get_record(name: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(directory + "/" + name))

func fail(message: String) -> bool:
	print("RSL_MIGRATION_FAIL member=", member, " phase=", phase, " ", message,
		" epoch=", p("epoch"), " room=", p("room_phase"), " tick=", p("head"),
		" backup=", p("backup_tick"), " prepared=", p("prepared_tick"), " control=", p("control_error"), " link=", p("link_error"))
	quit(1)
	return true

func _process(_dt: float) -> bool:
	if Time.get_ticks_msec() - started > 50000: return fail("timeout")
	match phase:
		"join":
			if p("steady") and p("players") == 3:
				if p("seat") != member: return fail("stable seat")
				game.set_bot("striker" if member == 1 else "idle")
				phase = "moving"
		"moving":
			if member == 2 and p("moving_backup"):
				put("moving_backup", {"tick": p("backup_tick")})
			if member == 1 and p("moving") and exists("moving_backup"):
				var saved := get_record("moving_backup")
				if p("backup_tick") < int(saved.tick) or p("prepared_tick") < int(saved.tick): return false
				put("trigger", {"tick": p("head"), "backup": p("backup_tick"), "at_ms": int(Time.get_unix_time_from_system() * 1000)})
				game.set_bot("idle")
				if mode == "planned":
					if not game.handoff(): return fail("handoff")
				else: put("kill_owner")
				print("RSL_MIGRATION_TRIGGER mode=", mode, " tick=", p("head"), " backup=", p("backup_tick"))
				phase = "migrating"
			if p("epoch") == 2: phase = "migrating"
		"migrating":
			if p("epoch") == 2 and p("steady") and p("recovery_ready"):
				if p("recovery_kind") != (1 if mode == "planned" else 2): return fail("recovery policy")
				if p("seat") != member: return fail("reseating")
				if member == 2:
					if not p("authority") or not p("restored_exact") or not p("restored_moving"): return fail("checkpoint restoration")
					kicks_before = p("kicks")
					game.set_bot("striker")
					phase = "continued"
				else:
					if p("authority"): return fail("old authority unfenced")
					phase = "verify"
		"continued":
			if p("body_epoch") == 2 and p("body_sequence") > 0 and p("seeded") and p("kicks") > kicks_before and p("right") > p("restored_right"):
				game.set_bot("idle")
				phase = "propose"
		"propose":
			if p("players") != (3 if mode == "planned" else 2): return false
			if final_round == 0 or Time.get_ticks_msec() - proposed_at > 600:
				final_round += 1
				var tick := p("head")
				var digest: int = game.probe_hash(tick)
				if digest < 0: return fail("authority history")
				put("final", {"round": final_round, "tick": tick, "hash": str(digest)})
				proposed_at = Time.get_ticks_msec()
			var all_verified := true
			for peer in ([1, 3] if mode == "planned" else [3]):
				if not exists("verified_%d" % peer) or int(get_record("verified_%d" % peer).round) != final_round: all_verified = false
			if all_verified:
				put("done")
				phase = "finish"
		"verify":
			if exists("final"):
				var expected := get_record("final")
				if int(expected.round) != verified_round:
					var digest: int = game.probe_hash(int(expected.tick))
					if digest >= 0:
						if str(digest) != expected.hash: return fail("common-tick world mismatch")
						verified_round = int(expected.round)
						put("verified_%d" % member, {"round": verified_round})
				if exists("done"):
					print("RSL_MIGRATION_CLIENT_OK member=", member, " epoch=", p("epoch"), " tick=", expected.tick, " hash=", expected.hash)
					put("finished_%d" % member)
					quit(0)
					return true
		"finish":
			if exists("finished_3") and (mode == "crash" or exists("finished_1")):
				print("RSL_MIGRATION_AUTHORITY_OK epoch=", p("epoch"), " tick=", p("head"), " recovery_tick=", p("recovery_tick"),
					" lost=", p("lost_ticks"), " interruption_ms=", p("interruption"), " goals=", p("goals"), " kicks=", p("kicks"))
				quit(0)
				return true
	return false
