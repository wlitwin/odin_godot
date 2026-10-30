extends SceneTree

var game: Node
var phase := "boot"
var started := 0
var since := 0

func _initialize() -> void:
	game = load("res://cave.tscn").instantiate()
	root.add_child(game)
	started = Time.get_ticks_msec()

func fail(message: String) -> bool:
	print("REPLAY_CAVE_FAIL ", message)
	quit(1)
	return true

func _process(_dt: float) -> bool:
	var now := Time.get_ticks_msec()
	if now - started > 18000: return fail("timeout " + phase)
	match phase:
		"boot":
			if game.probe_ready():
				if game.probe_gems() != 3: return fail("authored chest stock")
				game.walk_to(300.0, 180.0)
				phase = "chest"
		"chest":
			if game.probe_x() > 280:
				game.loot(0)
				since = now
				phase = "loot"
		"loot":
			if game.probe_bag() == 3 and game.probe_accepted() > 0:
				if game.probe_gems() != 3: return fail("loot conservation")
				print("REPLAY_CAVE_LOOT_OK")
				game.walk_to(560.0, 180.0)
				phase = "door"
		"door":
			if game.probe_x() > 535:
				game.door()
				phase = "open"
		"open":
			if game.probe_door():
				print("REPLAY_CAVE_DOOR_OK")
				print("REPLAY_CAVE_SOLO_OK")
				quit(0)
				return true
	return false
