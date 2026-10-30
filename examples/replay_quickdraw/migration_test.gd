extends SceneTree

var game: Node
var member := 0
var mode := ""
var directory := ""
var phase := "join"
var started := 0
var armed := false
var trigger_to_ready_ms := 0
var checkpoint_age_ticks := 0
var next_trace_ms := 0
var early_claim_sent := false
var early_backup := 0
var early_refreshed := false

func _initialize() -> void:
	member = int(OS.get_environment("RQ_MEMBER"))
	mode = OS.get_environment("REPLAY_MIGRATION_MODE")
	directory = OS.get_environment("REPLAY_MIGRATION_DIR")
	game = load("res://quickdraw.tscn").instantiate()
	root.add_child(game)
	game.drive(0, 0, 0, 0, 0)
	started = Time.get_ticks_msec()

func p(field: String, seat: int = 1) -> int:
	return game.probe(field, seat)

func exists(name: String) -> bool:
	return FileAccess.file_exists(directory + "/" + name)

func put(name: String, value: Dictionary = {}) -> void:
	var file := FileAccess.open(directory + "/" + name, FileAccess.WRITE)
	file.store_string(JSON.stringify(value))
	file.close()

func get_record(name: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(directory + "/" + name))

func fail(message: String) -> bool:
	print("RQ_MIGRATION_FAIL member=", member, " phase=", phase, " ", message)
	print("RQ_MIGRATION_DIAG backup_tick=", p("backup_tick"), " control=", p("control_error"), " reply=", p("reply_error"),
		" link=", p("link_error"), " model=", p("link_model_error"), " transfer=", p("transfer_phase"), " failure=", p("transfer_failure"))
	quit(1)
	return true

func _process(_dt: float) -> bool:
	if OS.get_environment("REPLAY_MIGRATION_TRACE") == "1" and Time.get_ticks_msec() >= next_trace_ms:
		next_trace_ms = Time.get_ticks_msec() + 500
		print("RQ_MIGRATION_TRACE member=", member, " phase=", p("room_phase"), " tick=", p("head"), " backup=", p("backup_sequence"),
			" backup_tick=", p("backup_tick"), " control=", p("control_error"), " reply=", p("reply_error"),
			" link=", p("link_error"), " model=", p("link_model_error"), " transfer=", p("transfer_phase"), " failure=", p("transfer_failure"))
	if Time.get_ticks_msec() - started > 38000:
		return fail("timeout epoch=%d room=%d hits=%d hp=%d backup=%d" % [p("epoch"), p("room_phase"), p("hits"), p("hp", 2), p("backup_sequence")])
	match phase:
		"join":
			if p("steady") and p("players") == 3:
				if p("seat") != member: return fail("seat assignment")
				if member == 2: game.drive(0, 1, 0, 0, 1)
				if member == 3:
					if not game.purchase(): return fail("initial purchase")
					game.drive(0, 0, 5, 2, -1) # held hitscan + lobs aimed at the observed opponent
				phase = "combat"
		"combat":
			if member == 2 and OS.get_environment("RQ_EARLY_CLAIM") == "1" and not early_claim_sent and p("backup_sequence") >= 2:
				if game.early_claim():
					early_claim_sent = true
					early_backup = p("backup_sequence")
					print("RQ_EARLY_CLAIM tick=", p("head"), " backup=", p("backup_sequence"))
			if member == 2 and early_claim_sent and not early_refreshed and p("busy_claims") > 0 and p("backup_sequence") > early_backup:
				early_refreshed = true
				put("early_refreshed")
				print("RQ_EARLY_CLAIM_RECOVERED backup=", p("backup_sequence"), " busy=", p("busy_claims"), " rejected=", p("claim_rejections"))
			if member == 2 and p("combat_backup") and not armed:
				armed = true
				put("combat_backup", {"tick": p("head"), "sequence": p("backup_sequence")})
			if member == 1 and p("steady") and p("boots", 3) and p("hp", 2) == 0 and p("bullets") > 0 and p("backup_sequence") >= 2:
				if mode == "planned":
					put("trigger", {"tick": p("head"), "at_ms": int(Time.get_unix_time_from_system() * 1000.0)})
					if not game.handoff(): return fail("handoff request")
					print("RQ_COMBAT_TRIGGER mode=planned tick=", p("head"), " bullets=", p("bullets"))
					phase = "migrating"
				elif exists("combat_backup") and p("head") >= int(OS.get_environment("RQ_CRASH_AFTER")):
					if OS.get_environment("RQ_EARLY_CLAIM") == "1" and not exists("early_refreshed"): return false
					put("trigger", {"tick": p("head"), "at_ms": int(Time.get_unix_time_from_system() * 1000.0)})
					print("RQ_COMBAT_TRIGGER mode=crash tick=", p("head"), " bullets=", p("bullets"))
					put("kill_owner")
					phase = "migrating"
			if p("epoch") == 2: phase = "migrating"
		"migrating":
			if p("epoch") == 2 and p("steady") and p("recovery_ready"):
				var trigger := get_record("trigger")
				trigger_to_ready_ms = int(Time.get_unix_time_from_system() * 1000.0) - int(trigger.at_ms)
				checkpoint_age_ticks = maxi(int(trigger.tick) - p("recovery_tick"), 0)
				if p("recovery_kind") != (1 if mode == "planned" else 2): return fail("recovery policy")
				if p("seat") != member or not p("mixed"): return fail("seat / mixed presentation after role change")
				if member == 2:
					if not p("authority") or not p("restored_exact") or not p("restored_combat"): return fail("complete combat checkpoint was not restored")
					if not p("boots", 3): return fail("lost equipment")
					game.drive(0, 0, 0, 0, 0)
					if not game.purchase(): return fail("new authority purchase")
					put("resumed", {"hits": p("restored_hits"), "lobs": p("restored_lobs"), "life": p("restored_life"), "checkpoint": p("recovery_tick")})
					phase = "settle"
				elif member == 3:
					game.drive(0, 0, 5, 2, 1)
					phase = "continued_combat"
				else:
					if p("authority"): return fail("old host remained authority")
					phase = "final"
		"continued_combat":
			if exists("resumed") and p("steady"):
				var resumed := get_record("resumed")
				if p("hits") >= int(resumed.hits) + 3 and p("lobs") >= int(resumed.lobs) + 2 and p("life", 2) > int(resumed.life) and p("buys") == 2:
					game.drive(0, 0, 0, 0, 0)
					put("continued_combat", {"hits": p("hits"), "lobs": p("lobs")})
					phase = "final"
		"settle":
			if exists("continued_combat") and p("bullets") == 0 and p("steady") and p("players") == (3 if mode == "planned" else 2):
				var tick := p("head")
				if tick % 3 != 0: return false
				var digest: int = game.probe_hash(tick)
				if digest < 0: return fail("authority history missing")
				# Strings preserve all 63 hash bits across JSON's floating-point numbers.
				put("final", {"tick": tick, "hash": str(digest), "hits": p("hits"), "lobs": p("lobs"), "lands": p("lands"), "buys": p("buys")})
				phase = "wait_clients"
		"final":
			if exists("final"):
				var expected := get_record("final")
				var digest: int = game.probe_hash(int(expected.tick))
				if digest < 0: return false
				if str(digest) != expected.hash: return fail("canonical world mismatch at common tick")
				if p("buys") != 2 or not p("boots", 2) or not p("boots", 3): return fail("purchase convergence")
				put("done_%d" % member)
				print("RQ_MIGRATION_CLIENT_OK member=", member, " epoch=", p("epoch"), " tick=", expected.tick, " hash=", expected.hash,
					" checkpoint=", p("recovery_tick"), " lost=", p("lost_ticks"), " interruption_ms=", p("interruption"),
					" trigger_to_ready_ms=", trigger_to_ready_ms, " checkpoint_age_ticks=", checkpoint_age_ticks)
				quit(0)
				return true
		"wait_clients":
			if exists("done_3") and (mode == "crash" or exists("done_1")):
				print("RQ_MIGRATION_AUTHORITY_OK epoch=", p("epoch"), " checkpoint=", p("recovery_tick"), " lost=", p("lost_ticks"),
					" interruption_ms=", p("interruption"), " archive_bytes=", p("archive_bytes"), " install_us=", p("install_us"),
					" trigger_to_ready_ms=", trigger_to_ready_ms, " checkpoint_age_ticks=", checkpoint_age_ticks)
				quit(0)
				return true
	return false
