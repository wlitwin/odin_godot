extends SceneTree

# ----------------------------------------------------------------------------
# Cavecrawl lobby test driver (examples/cavecrawl). TWO processes — host and
# guest — instantiate the REAL cave.tscn and press the same code paths the
# lobby buttons fire. Verified: seating over the wire, the live player list
# (actual Label texts read back out of the kit/ui tree on both peers), and
# the host's Start button appearing once enough spelunkers are in.
# ----------------------------------------------------------------------------

var cave: Node = null
var role := ""
var phase := "init"
var t_acted := 0

const TIMEOUT_MS := 20000

func _initialize() -> void:
	role = OS.get_environment("ROLE")
	if role == "":
		role = "host"
	var scene: PackedScene = load("res://cave.tscn")
	if scene == null:
		print(role.to_upper(), "_FAIL: could not load cave.tscn")
		quit(1); return
	cave = scene.instantiate()
	get_root().add_child(cave)
	t_acted = Time.get_ticks_msec()
	print(role.to_upper(), "_BOOT")

func label_texts() -> String:
	var texts := []
	for l in cave.find_children("*", "Label", true, false):
		if l.visible and l.text != "":
			texts.append(l.text)
	return " | ".join(texts)

func timed_out(now: int, msg: String) -> bool:
	if now - t_acted > TIMEOUT_MS:
		print(role.to_upper(), "_TIMEOUT: ", msg, "  UI=[", label_texts(), "]")
		return true
	return false

func _process(_delta: float) -> bool:
	var now := Time.get_ticks_msec()

	if phase == "init":
		if not cave.is_inside_tree():
			return false
		# Press the same method the lobby button fires.
		cave.call("on_host" if role == "host" else "on_join")
		phase = "lobby"
		t_acted = now
		return false

	if phase == "lobby":
		var seated := role == "host" or bool(cave.call("is_seated"))
		if seated and int(cave.call("get_players")) >= 2:
			phase = "verify"
			t_acted = now
		elif timed_out(now, "players=" + str(cave.call("get_players"))):
			quit(1); return true
		return false

	if phase == "verify":
		# Give the stats a beat so ping can appear, then read the REAL UI.
		if now - t_acted > 1500:
			print("CAVE_UI [", label_texts(), "]")
			var starts := 0
			for b in cave.find_children("*", "Button", true, false):
				if b.text == "Start" and b.visible:
					starts += 1
			print("CAVE_START_VISIBLE n=", starts)
			print(role.to_upper(), "_DONE")
			quit(0); return true
		return false

	return false
