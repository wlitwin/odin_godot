extends SceneTree

var game: Node
var mode := ""
var phase := "join"
var started := 0
var acted := 0
var seat := 0
var initial_x := 0
var their_x := 0
var directory := ""
var captured := false

func _initialize() -> void:
	mode = OS.get_environment("RSY_ROLE")
	directory = OS.get_environment("RSY_RESULT_DIR")
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	started = Time.get_ticks_msec()

func p(field: String, player: int = 1) -> int:
	return game.probe(field, player)

func fail(message: String) -> bool:
	print("RSY_ARENA_FAIL role=", mode, " phase=", phase, " ", message)
	quit(1)
	return true

func capture_scene(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.save_png(path) == OK: print("RSY_SCREENSHOT_OK ", path)

func _process(_dt: float) -> bool:
	var now := Time.get_ticks_msec()
	if now - started > 25000: return fail("timeout")
	match phase:
		"join":
			if p("ready"):
				seat = p("seat")
				if p("hz") != 60: return fail("tick rate")
				if seat == 0: phase = "world"
				else:
					game.dev_loadout(2 if seat == 1 else 1, 1 if seat == 1 else 2)
					phase = "loadout"
		"loadout":
			if p("look", seat) == (2 if seat == 1 else 1) and p("iron", seat) == (1 if seat == 1 else 2):
				game.on_ready()
				phase = "ready"
		"ready":
			var count := 1 if mode == "solo" else 2
			if p("players") == count and p("marked_ready", 1) and (count == 1 or p("marked_ready", 2)):
				if mode == "host" or mode == "solo": game.on_start()
				phase = "world"
		"world":
			if p("stage") == 1 and p("in_yard", 1) and (mode == "solo" or p("in_yard", 2)):
				if not captured and OS.get_environment("RSY_SCREENSHOT") != "":
					captured = true
					capture_scene(OS.get_environment("RSY_SCREENSHOT"))
				if p("look", 1) != 2 or p("iron", 1) != 1: return fail("remote loadout")
				initial_x = p("shown_x", maxi(seat, 1))
				their_x = p("shown_x", 2 if seat == 1 else 1)
				if seat > 0: game.dev_drive(1 if seat == 1 else -1, 0, true)
				acted = now
				phase = "walk"
		"walk":
			if now - acted >= 1800:
				if seat > 0:
					if absi(p("shown_x", seat) - initial_x) < 60 or p("dashes", seat) != 1: return fail("own movement/dash")
					game.dev_drive(0, 0, false)
				acted = now
				phase = "settle"
		"settle":
			if now - acted >= 1600:
				if not p("ready"): return false
				if mode != "solo" and absi(p("shown_x", 2 if seat == 1 else 1) - their_x) < 60: return fail("remote movement")
				print("RSY_ARENA_RESULT role=", mode, " seat=", seat, " seed=", p("seed"), " floor=", p("floor"), " players=", p("players"),
					" x1=", p("x", 1), " x2=", p("x", 2), " d1=", p("dashes", 1), " d2=", p("dashes", 2), " effects=", p("dash_effects"))
				if directory != "":
					var path := directory + "/measured-" + mode
					var file := FileAccess.open(path + ".pending", FileAccess.WRITE)
					file.store_string("ready")
					file.close()
					assert(DirAccess.rename_absolute(path + ".pending", path) == OK)
				phase = "finish"
		"finish":
			if directory != "":
				for role in ["host", "client", "observer"]:
					if not FileAccess.file_exists(directory + "/measured-" + role): return false
			print("REPLAY_SCRAPYARD_ARENA_PEER_OK")
			quit(0)
			return true
	return false
