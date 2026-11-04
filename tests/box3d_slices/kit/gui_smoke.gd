extends SceneTree

# Real GUI/control smoke. Only normal Input intents are injected. State is read
# from committed visual proxies; this script never sets physics or confirmation.
var game: Node
var role := ""
var phase := "wait"
var started := 0
var phase_started := 0
var start_z := 0.0
var moved := false
var spawned := false
var done_file := ""

func _initialize() -> void:
	role = OS.get_environment("B3_ROLE")
	done_file = OS.get_environment("B3_GUI_DONE")
	game = load("res://kit_box3d.tscn").instantiate()
	root.add_child(game)
	started = Time.get_ticks_msec()

func _process(_delta: float) -> bool:
	var now := Time.get_ticks_msec()
	if now - started > 20000:
		print(JSON.stringify({"event":"GUI_SMOKE", "role":role, "ok":false, "phase":phase}))
		quit(1)
		return true
	var player: Node3D = game.get_node("Bodies/B0")
	var extra: Node3D = game.get_node("Bodies/B4")
	match phase:
		"wait":
			if player.visible and "Physics epoch " in game.get_node("HUD/Status").text and "head " in game.get_node("HUD/Status").text:
				start_z = player.position.z
				phase_started = now
				phase = "move" if role == "host" else "watch"
				if role == "host": Input.action_press("b3_up")
		"move":
			if now-phase_started > 700:
				Input.action_release("b3_up")
				moved = player.position.z < start_z - 0.05
				Input.action_press("b3_spawn")
				phase_started = now
				phase = "spawn"
		"spawn":
			if now-phase_started > 100: Input.action_release("b3_spawn")
			if extra.visible and extra.get_node("Capsule").visible:
				spawned = true
				phase = "capture"
				_capture()
		"watch":
			moved = moved or player.position.z < start_z - 0.05
			spawned = spawned or (extra.visible and extra.get_node("Capsule").visible)
			if FileAccess.file_exists(done_file):
				print(JSON.stringify({"event":"GUI_SMOKE", "role":role, "ok":moved and spawned, "moved":moved, "start_z":start_z, "end_z":player.position.z, "spawned":spawned}))
				quit(0 if moved and spawned else 1)
				return true
		"exit":
			if now-phase_started > 500:
				quit(0 if moved and spawned else 1)
				return true
	return false

func _capture() -> void:
	await RenderingServer.frame_post_draw
	var path := OS.get_environment("B3_OUTPUT") + "/gui.png"
	var image := root.get_texture().get_image()
	var error := image.save_png(path)
	print(JSON.stringify({"event":"GUI_SMOKE", "role":role, "ok":moved and spawned and error == OK, "moved":moved, "spawned":spawned, "start_z":start_z, "end_z":game.get_node("Bodies/B0").position.z, "screenshot":path, "width":image.get_width(), "height":image.get_height()}))
	var flag := FileAccess.open(done_file, FileAccess.WRITE)
	flag.store_string("GUI control test complete")
	flag.close()
	phase_started = Time.get_ticks_msec()
	phase = "exit"
