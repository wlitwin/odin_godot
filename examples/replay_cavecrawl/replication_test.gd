extends SceneTree

var game: Node
var role := ""
var phase := "join"
var started := 0
var acted := 0
var first_sequence := 0

func _initialize() -> void:
	role = OS.get_environment("REPLAY_CAVE_ROLE")
	game = load("res://cave.tscn").instantiate()
	root.add_child(game)
	started = Time.get_ticks_msec()

func fail(message: String) -> bool:
	print("REPLAY_CAVE_NETWORK_FAIL replication ", role, " ", message)
	quit(1)
	return true

func _process(_dt: float) -> bool:
	var now := Time.get_ticks_msec()
	if now - started > 22000: return fail("timeout " + phase)
	match phase:
		"join":
			if game.probe_ready() and game.probe_players() == 2:
				if role == "host" and not game.backup_to(2): return fail("authorize successor")
				game.walk_to(300.0, 180.0)
				phase = "walk"
		"walk":
			if game.probe_x() > 280:
				if role == "client": game.loot(0)
				first_sequence = game.probe_backup_sequence()
				phase = "loot"
		"loot":
			if game.probe_chest(0) == 0:
				if game.probe_gems() != 3: return fail("loot conservation")
				if role == "client" and game.probe_bag() != 3: return false
				game.walk_to(560.0, 180.0)
				phase = "door"
		"door":
			if game.probe_x() > 535:
				if role == "client": game.door()
				phase = "backup"
		"backup":
			if game.probe_door() and game.probe_backup_play() and game.probe_backup_sequence() > first_sequence:
				if game.probe_protocol_rejections() != 0: return fail("checkpoint packets reached the game protocol")
				print("REPLAY_CAVE_BACKUP_", role.to_upper(), " tick=", game.probe_backup_tick(), " sequence=", game.probe_backup_sequence())
				acted = now
				phase = "linger"
		"linger":
			if now - acted > (1500 if role == "host" else 700):
				if game.probe_gems() != 3: return fail("continued conservation")
				print("REPLAY_CAVE_NETWORK_", role.to_upper(), "_OK")
				quit(0)
				return true
	return false
