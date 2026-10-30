extends "res://combat_test.gd"

var resumed := false

func _initialize() -> void:
	super._initialize()
	resumed = OS.get_environment("RSY_RESUME") == "1"
	timeout_ms = 45000

func _process(_dt: float) -> bool:
	if closing:return false
	if Time.get_ticks_msec() - started > timeout_ms: return fail("save timeout")
	if not p("ready"): return false
	match phase:
		"join":
			game.dev_drive(0, 0, false)
			if resumed:
				var saved := read("saved")
				if saved.is_empty() or p("restored_tick") != int(saved.tick) or p("restored_hash") != int(saved.hash): return fail("installed save differs")
				if p("epoch") != 2 or p("seat") != 1 or p("casts") != 2 or p("lobs") != 1 or p("zones") != 1: return fail("restored combat state")
				phase = "land"
			else:
				game.dev_abilities(5, 1); phase = "loadout"
		"loadout":
			if p("ability0") == 5 and p("ability1") == 1:
				game.on_ready(); phase = "ready"
		"ready":
			if p("marked_ready"): game.on_start(); phase = "world"
		"world":
			if p("in_yard"):
				if not game.dev_cast(0, 500.0, 1040.0, true) or not game.dev_cast(1, 800.0, 1040.0, true): return fail("save combat setup")
				phase = "save"
		"save":
			if p("casts") == 2 and p("lobs") == 1 and p("zones") == 1:
				if not game.save_run(): return fail("write run")
				# Decimal strings preserve all 63 digest bits through JSON parsers.
				write("saved", {"tick": str(p("saved_tick")), "hash": str(p("saved_hash"))})
				if game.probe_hash(p("saved_tick")) != p("saved_hash"): return fail("captured frame")
				game.set_process(false)
				print("RSY_SAVE_READY tick=", p("saved_tick"), " hash=", p("saved_hash"))
				phase = "kill"
		"land":
			if p("landed") == 1:
				if p("casts") != 2 or p("zones") != 1: return fail("saved action repeated")
				game.dev_aim(1.0, 0.0, true); phase = "continued"
		"continued":
			if p("shots") > 0 and p("damage") > 0:
				print("RSY_SAVE_RESUME_OK tick=", p("head"), " restored=", p("restored_tick"), " casts=", p("casts"), " landed=", p("landed"), " zones=", p("zones"), " shots=", p("shots"))
				finish_game(0); return false
	return false
