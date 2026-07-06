extends SceneTree

# ----------------------------------------------------------------------------
# Acid-test driver skeleton. One process = one player; the ROLE env decides
# which script it follows. It instantiates your REAL main scene and presses
# the same @(gd_method)s your buttons fire — no test doubles, no mock net.
#
# Pair this with a queries.odin in your game: small @(gd_method)s returning
# ints/bools the phases below can poll (see the examples' queries.odin).
# Print an UPPERCASE tag for every fact worth asserting; run.sh greps them.
# ----------------------------------------------------------------------------

var game: Node = null
var role := ""
var phase := "init"
var t_acted := 0

const TIMEOUT_MS := 30000
const MAIN_SCENE := "res://main.tscn"

func _initialize() -> void:
	role = OS.get_environment("ROLE")
	if role == "": role = "host"
	var scene: PackedScene = load(MAIN_SCENE)
	if scene == null:
		print(role.to_upper(), "_FAIL: could not load ", MAIN_SCENE)
		quit(1); return
	game = scene.instantiate()
	get_root().add_child(game)
	t_acted = Time.get_ticks_msec()
	print(role.to_upper(), "_BOOT")

func enter(next: String, now: int) -> void:
	phase = next
	t_acted = now

func _process(_delta: float) -> bool:
	var now := Time.get_ticks_msec()
	if now - t_acted > TIMEOUT_MS:
		print(role.to_upper(), "_FAIL: timeout in phase ", phase)
		quit(1); return true

	if role == "host":
		match phase:
			"init":
				if game.is_inside_tree():
					game.call("on_host")
					enter("gather", now)
			"gather":
				if int(game.call("get_players")) >= 2:
					game.call("on_start")
					enter("play", now)
			"play":
				# your asserts here: poll queries, act, print facts
				print("HOST_DONE")
				quit(0); return true

	elif role == "guest":
		match phase:
			"init":
				if game.is_inside_tree():
					game.call("on_join")
					enter("seat", now)
			"seat":
				if bool(game.call("is_seated")):
					enter("play", now)
			"play":
				print("GUEST_DONE")
				quit(0); return true

	return false
