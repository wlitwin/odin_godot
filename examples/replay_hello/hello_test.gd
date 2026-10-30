extends SceneTree

var game: Node
var phase := "boot"
var start_ms := 0
var shot_tick := 0
var begins := 0

func _initialize() -> void:
	game = load("res://hello.tscn").instantiate()
	root.add_child(game)
	start_ms = Time.get_ticks_msec()

func fail(message: String) -> bool:
	print("REPLAY_HELLO_FAIL: ", message)
	quit(1)
	return true

func _process(_dt: float) -> bool:
	if Time.get_ticks_msec() - start_ms > 15000:
		return fail("timeout in " + phase)
	match phase:
		"boot":
			if game.probe_tick() >= 1:
				if game.probe_views() != 2: return fail("initial entity views")
				Input.action_press("ui_right")
				Input.action_press("ui_accept")
				phase = "shot"
		"shot":
			if game.probe_shots() >= 1:
				Input.action_release("ui_accept")
				shot_tick = game.probe_tick()
				if game.probe_views() != 3: return fail("projectile view did not spawn")
				phase = "walk"
		"walk":
			if game.probe_tick() >= shot_tick + 8:
				Input.action_release("ui_right")
				if game.probe_x() <= 130: return fail("device input did not move simulation")
				if game.probe_begins() != game.probe_shots(): return fail("duplicate/missing shot effect")
				print("REPLAY_HELLO_WALK x=", game.probe_x())
				phase = "expire"
		"expire":
			if game.probe_tick() >= shot_tick + 65:
				if game.probe_views() != 2: return fail("expired projectile view remained")
				if not game.probe_audit(): return fail("presentation contaminated simulation")
				begins = game.probe_begins()
				game.pause(true)
				if not game.rewind_to(shot_tick): return fail("rewind checkpoint was unavailable")
				phase = "restored"
		"restored":
			if game.probe_views() != 3: return fail("rewind failed to recreate projectile")
			if game.probe_begins() != begins: return fail("rewind replayed historical one-shots")
			print("REPLAY_HELLO_RESTORE tick=", game.probe_tick(), " views=", game.probe_views())
			print("REPLAY_HELLO_OK")
			quit(0)
			return true
	return false
