extends SceneTree

var game: Node
var started := 0

func _initialize() -> void:
	game = load("res://loot.tscn").instantiate()
	root.add_child(game)
	started = Time.get_ticks_msec()

func _process(_dt: float) -> bool:
	if game.probe_begins() == 0:
		if Time.get_ticks_msec() - started > 10000:
			print("REPLAY_LOOT_VIEW_FAIL: ready timeout")
			quit(1)
			return true
		return false
	if game.probe_blue() != 5 or game.probe_orange() != 0:
		print("REPLAY_LOOT_VIEW_FAIL: initial prediction")
		quit(1)
		return true
	var began: int = game.probe_begins()
	game.correct()
	if game.probe_blue() != 0 or game.probe_orange() != 5:
		print("REPLAY_LOOT_VIEW_FAIL: corrected inventories")
		quit(1)
		return true
	if game.probe_begins() != began + 1 or game.probe_cancels() != 1:
		print("REPLAY_LOOT_VIEW_FAIL: event reconciliation")
		quit(1)
		return true
	game.correct()
	if game.probe_begins() != began + 1 or game.probe_cancels() != 1:
		print("REPLAY_LOOT_VIEW_FAIL: duplicate correction")
		quit(1)
		return true
	print("REPLAY_LOOT_VIEW_OK")
	quit(0)
	return true
