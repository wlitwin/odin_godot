extends SceneTree

# Collision phase of the multi-module spike (run AFTER run.sh built modules/rogue,
# whose class name collides with the main module's Player). The core must have
# REJECTED the rogue module at load (an error naming both modules — run.sh greps the
# combined log for it) while the MAIN module's Player keeps working untouched.

var done := false

func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _fail(reason: String) -> void:
	if done:
		return
	done = true
	print("COLLISION_PHASE_FAIL: ", reason)
	quit(1)

func _run() -> void:
	if done:
		return
	var player_script = load("res://scripts/player.odin")
	if player_script == null:
		_fail("player.odin failed to load")
		return
	var player := Node.new()
	player.set_script(player_script)
	root.add_child(player)
	await process_frame
	# Main's Player must win: brand 1007, and the rogue module's method must NOT exist.
	if int(player.call("get_brand")) != 1007:
		_fail("Player did not resolve to the MAIN module (brand=%s)" % str(player.call("get_brand")))
		return
	if player.has_method("rogue_brand"):
		_fail("rogue module's method leaked onto Player — collision was not rejected")
		return
	print("COLLISION_PHASE_OK")
	done = true
	quit(0)
