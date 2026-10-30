extends "res://combat_test.gd"

var resumed := false

func _initialize() -> void:
	super._initialize()
	resumed = OS.get_environment("RSY_SAVE_PHASE") == "resume"
	timeout_ms = 55000

func _process(dt: float) -> bool:
	if phase == "hash" or phase == "finish": return super._process(dt)
	if Time.get_ticks_msec() - started > timeout_ms: return fail("co-op save timeout")
	if not p("ready"): return false
	match phase:
		"join":
			seat = p("seat")
			if seat != (1 if mode == "host" else 2 if mode == "client" else 0): return fail("saved seat identity")
			game.dev_drive(0, 0, false)
			if resumed:
				if mode == "host":
					var saved := read("saved")
					if saved.is_empty() or p("restored_tick") != int(saved.tick) or p("restored_hash") != int(saved.hash): return fail("co-op installed world")
					if p("epoch") != 2: return fail("co-op epoch")
				phase = "rejoined"
			elif seat == 0: phase = "active"
			else:
				game.dev_abilities(5 if seat == 1 else 4, 1 if seat == 1 else 6); phase = "loadout"
		"loadout":
			if p("ability0", seat) == (5 if seat == 1 else 4) and p("ability1", seat) == (1 if seat == 1 else 6):
				game.on_ready(); phase = "ready"
		"ready":
			if p("players") == 2 and p("marked_ready", 1) and p("marked_ready", 2):
				if seat == 1: game.on_start()
				phase = "world"
		"world":
			if p("in_yard", 1) and p("in_yard", 2):
				if seat == 1:
					if not game.dev_cast(0, 500.0, 1040.0, true) or not game.dev_cast(1, 800.0, 1040.0, true): return fail("co-op save setup")
				elif not game.dev_cast(0, 0.0, 0.0, false): return fail("old client cast")
				phase = "active"
		"active":
			if p("casts", 1) == 2 and p("casts", 2) == 1 and p("lobs") == 1 and p("zones") == 1:
				write("active-" + mode, {"ready": true})
				if mode == "host" and not read("active-client").is_empty() and not read("active-observer").is_empty():
					if not game.save_run(): return fail("co-op write")
					write("saved", {"tick": str(p("saved_tick")), "hash": str(p("saved_hash"))})
					game.set_process(false)
					print("RSY_COOP_SAVE_READY tick=", p("saved_tick"), " hash=", p("saved_hash"))
					phase = "kill"
		"rejoined":
			if p("players") == 2 and p("in_yard", 1) and p("in_yard", 2):
				if p("ability0", 1) != 5 or p("ability0", 2) != 4 or p("casts", 1) != 2 or p("casts", 2) != 1: return fail("saved profiles/action counts")
				write("rejoined-" + mode, {"ready": true})
				phase = "land"
		"land":
			if p("landed") == 1 and not read("rejoined-host").is_empty() and not read("rejoined-client").is_empty() and not read("rejoined-observer").is_empty():
				if seat == 2 and not game.dev_cast(1, 800.0, 1040.0, true): return fail("new client action")
				phase = "continued"
		"continued":
			if p("casts", 2) == 2 and p("landed") == 2 and p("reactions") >= 2 and p("zones") == 1:
				print("RSY_COOP_SAVE_RESULT role=", mode, " epoch=", p("epoch"), " seat=", seat, " casts2=", p("casts", 2), " landed=", p("landed"), " reactions=", p("reactions"))
				write("stopped-" + mode, {"ready": true}); phase = "hash"
	return false
