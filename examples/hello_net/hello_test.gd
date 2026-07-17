extends SceneTree

# The hello-multiplayer acid driver: host walks right, guest WATCHES the walk
# arrive through the wire — read entirely through GENERATED probes
# (probe_player_count / probe_my_player / probe_player_x); the game ships no
# queries file at all. ROLE=host|guest; run.sh asserts the printed receipts.

var game: Node = null
var role := ""
var phase := "boot"
var t0 := 0
var start_x := -1.0

const TIMEOUT_MS := 30000

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
			# Both squares up on this screen (the guest's spawns on join).
			if game.probe_player_count() == 2:
				print("HELLO_TWO_UP me=", game.probe_my_player())
				phase = "watch"; t0 = now
				if role == "host":
					Input.action_press("ui_right") # walk right; the guest watches
		"watch":
			if role == "host":
				if now - t0 > 3000:
					Input.action_release("ui_right")
					print("HELLO_WALKED x=%.0f" % game.probe_player_x(0))
					phase = "done"
			else:
				# The OTHER square: two players seat as net ids 1 and 2.
				var other: int = 2 if game.probe_my_player() == 1 else 1
				if start_x < 0.0:
					start_x = game.probe_player_x(other)
				elif game.probe_player_x(other) - start_x > 60.0:
					print("HELLO_SAW_WALK d=%.0f" % (game.probe_player_x(other) - start_x))
					phase = "done"
		"done":
			print(role.to_upper(), "_DONE")
			quit(0); return true
	return false
