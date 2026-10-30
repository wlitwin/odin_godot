extends SceneTree

var game: Node
var role := ""
var phase := "join"
var start := 0
var since := 0
var x := 0.0

func _initialize() -> void:
	role = OS.get_environment("REPLAY_ROLE")
	game = load("res://network.tscn").instantiate()
	root.add_child(game)
	start = Time.get_ticks_msec()

func fail(message: String) -> bool:
	print("REPLAY_NETWORK_TEST_FAIL ", role, " ", message)
	quit(1)
	return true

func _process(_dt: float) -> bool:
	var now := Time.get_ticks_msec()
	if now - start > 20000: return fail("timeout " + phase)
	match phase:
		"join":
			if game.probe_running() and game.probe_players() == 2:
				since = now
				if role == "client":
					x = game.probe_x()
					Input.action_press("ui_right")
					Input.action_press("ui_accept")
					phase = "press"
				else: phase = "observe"
		"press":
			if now - since > 60:
				Input.action_release("ui_accept")
				phase = "move"
		"move":
			if now - since > 400:
				Input.action_release("ui_right")
				var moved: float = game.probe_x() - x
				if moved < 35: return fail("local prediction moved only " + str(moved))
				print("REPLAY_NETWORK_PREDICTED delta=", moved)
				phase = "settle"
		"settle":
			if now - since > 3000:
				if game.probe_shots() != 2: return fail("shots=" + str(game.probe_shots()))
				if game.probe_applied() != 1: return fail("action did not settle once")
				if game.probe_rejected() != 0: return fail("action rejected")
				if game.probe_begins() != 2: return fail("effect count=" + str(game.probe_begins()))
				if game.probe_corrections() < 1: return fail("no authority correction")
				if game.probe_deltas() < 1: return fail("no acknowledged delta snapshots")
				print("REPLAY_NETWORK_CLIENT_OK")
				quit(0)
				return true
		"observe":
			if now - since > 4500:
				if game.probe_shots() != 2: return fail("observer/authority state")
				if game.probe_begins() != 2: return fail("observer/authority effects")
				if game.probe_deltas() < 1: return fail("observer/authority delta stream")
				print("REPLAY_NETWORK_", role.to_upper(), "_OK")
				quit(0)
				return true
	return false
