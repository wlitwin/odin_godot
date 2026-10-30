extends "res://combat_test.gd"

var operation := ""
var entered_floor := 1

func _initialize() -> void:
	super._initialize()
	operation = OS.get_environment("RSY_PROFILE_PHASE")
	timeout_ms = 90000

func _process(_dt: float) -> bool:
	if closing:return false
	var now := Time.get_ticks_msec()
	if now - started > timeout_ms: return fail("profile timeout")
	if phase != "join" and not p("ready"): return false
	if p("profile_error"):
		if operation == "write_failure":
			print("RSY_PROFILE_WRITE_FAILURE_OBSERVED")
			finish_game(0); return false
		return fail("profile write")
	match phase:
		"join":
			if p("ready"):
				seat = p("seat")
				if operation == "earn": game.dev_loadout(2, 1); game.dev_abilities(5, 6)
				if operation == "write_failure":
					game.dev_loadout(1, 2); phase = "write_failure"
				else: phase = "loadout"
		"loadout":
			if p("look") == 2 and p("iron") == 1 and p("ability0") == 5 and p("ability1") == 6:
				if operation == "load" and (p("parts") != 2 or p("cores") != 0 or not p("profile_loaded")): return fail("restored profile")
				game.on_ready(); phase = "ready"
		"ready":
			if p("marked_ready"): game.on_start(); phase = "world"
		"world":
			if p("stage") == 1 and p("in_yard"):
				if operation == "load":
					if p("hp") != 14 or p("parts") != 2: return fail("plate not restored at entry")
					print("RSY_PROFILE_RELOAD_OK parts=", p("parts"), " hp=", p("hp"), " iron=", p("iron"), " writes=", p("profile_writes"))
					finish_game(0); return false
				game.dev_combat(true); phase = "fight"
		"fight":
			if p("stage") == 2 and p("drops") == 0:
				game.dev_combat(false)
				if entered_floor == 1: game.dev_gate(true); phase = "gate"
				else:
					if p("cores") != 2: return fail("earned cores")
					if not game.dev_buy(1, true): return fail("queue permanent part")
					phase = "saved"
		"gate":
			if p("floor") == 2:
				entered_floor = 2; game.dev_combat(true); phase = "fight"
		"saved":
			if p("parts") == 2 and p("cores") == 0 and p("profile_writes") >= 3:
				print("RSY_PROFILE_EARN_OK parts=", p("parts"), " cores=", p("cores"), " writes=", p("profile_writes"))
				finish_game(0); return false
	return false
