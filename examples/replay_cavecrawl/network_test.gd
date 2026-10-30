extends SceneTree

var game: Node
var role := ""
var phase := "join"
var started := 0
var acted := 0

func _initialize() -> void:
	role = OS.get_environment("REPLAY_CAVE_ROLE")
	game = load("res://cave.tscn").instantiate()
	root.add_child(game)
	started = Time.get_ticks_msec()

func fail(message: String) -> bool:
	print("REPLAY_CAVE_NETWORK_FAIL ", role, " ", message)
	quit(1)
	return true

func _process(_dt: float) -> bool:
	var now := Time.get_ticks_msec()
	if now - started > 22000: return fail("timeout " + phase)
	match phase:
		"join":
			if game.probe_ready() and game.probe_players() == 2:
				game.walk_to(300.0, 180.0)
				phase = "walk"
		"walk":
			if game.probe_x() > 280:
				if role == "client": game.loot(0)
				phase = "loot"
		"loot":
			if game.probe_chest(0) == 0:
				if game.probe_gems() != 3: return fail("gems were not conserved")
				if role == "client" and game.probe_bag() != 3: return false
				print("REPLAY_CAVE_NETWORK_LOOT ", role)
				game.walk_to(560.0, 180.0)
				phase = "door"
		"door":
			if game.probe_x() > 535:
				if role == "client": game.door()
				phase = "open"
		"open":
			if game.probe_door():
				acted = now
				phase = "linger"
		"linger":
			if now - acted > (1500 if role == "host" else 700):
				if game.probe_gems() != 3: return fail("late conservation")
				print("REPLAY_CAVE_NETWORK_", role.to_upper(), "_OK")
				quit(0)
				return true
	return false
