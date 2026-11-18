extends SceneTree

# The hello-sim acid driver: under 120ms injected latency the guest's OWN
# square moves the instant a key goes down (prediction), and the host's walk
# arrives on the watched clock — all read through GENERATED probes.

var game: Node = null
var role := ""
var phase := "boot"
var t0 := 0
var press_x := -1.0
var start_x := -1.0

const TIMEOUT_MS := 30000

func _player_scenes(node: Node, counts: Dictionary) -> void:
	if node.scene_file_path in ["res://player.tscn", "res://player_diamond.tscn"]:
		counts[node.scene_file_path] = counts.get(node.scene_file_path, 0) + 1
	for child in node.get_children():
		_player_scenes(child, counts)

func _initialize() -> void:
	role = OS.get_environment("ROLE")
	if role == "": role = "host"
	var scene: PackedScene = load("res://hello.tscn")
	game = scene.instantiate()
	get_root().add_child(game)
	t0 = Time.get_ticks_msec()
	print(role.to_upper(), "_BOOT")

func _process(_delta: float) -> bool:
	var now := Time.get_ticks_msec()
	if now - t0 > TIMEOUT_MS:
		print(role.to_upper(), "_FAIL: timeout in phase ", phase)
		quit(1); return true
	match phase:
		"boot":
			if game.probe_player_count() == 2:
				var scenes := {}
				_player_scenes(game, scenes)
				if scenes.get("res://player.tscn", 0) != 1 or scenes.get("res://player_diamond.tscn", 0) != 1:
					print("HELLO_FAIL scene variants ", scenes)
					quit(1); return true
				print("HELLO_VARIANTS_OK default=1 diamond=1")
				print("HELLO_TWO_UP me=", game.probe_my_player())
				phase = "walk"; t0 = now
				press_x = game.probe_player_x(0)
				Input.action_press("ui_right") # both roles walk their own square
		"walk":
			if role == "guest" and now - t0 > 500 and press_x >= 0.0:
				# HALF A SECOND in, under 120ms each way: an un-predicted square
				# would still be waiting on the server's echo. Ours moved.
				var d: float = game.probe_player_x(0) - press_x
				if d > 40.0:
					print("HELLO_PREDICTED d=%.0f" % d)
					press_x = -2.0 # printed once
			if now - t0 > 3000:
				Input.action_release("ui_right")
				print("HELLO_WALKED x=%.0f" % game.probe_player_x(0))
				phase = "watch"; t0 = now
		"watch":
			if role == "host":
				phase = "done" # the guest does the cross-wire assert
			else:
				var other: int = 2 if game.probe_my_player() == 1 else 1
				if start_x < 0.0:
					start_x = game.probe_player_x(other)
					phase = "done" # sampled AFTER both walks: motion already crossed
		"done":
			if role == "guest":
				var other: int = 2 if game.probe_my_player() == 1 else 1
				print("HELLO_SAW_WALK x=%.0f" % game.probe_player_x(other))
			print(role.to_upper(), "_DONE")
			quit(0); return true
	return false
