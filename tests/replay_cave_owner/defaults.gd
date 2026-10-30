extends SceneTree
var game: Node
func _initialize() -> void:
	game=load("res://cave.tscn").instantiate();root.add_child(game)
	call_deferred("run")
func run() -> void:
	await process_frame
	if game.motion_probe("profile",0)!=1 or game.get_node("Lobby/Panel/Column/Port").value!=49585:
		print("CAVE_OWNER_DEFAULTS_FAIL profile/port");quit(1);return
	if ProjectSettings.get_setting("application/config/custom_user_dir_name")!="ReplayCavecrawlOwned":
		print("CAVE_OWNER_DEFAULTS_FAIL storage");quit(1);return
	game.queue_free();await process_frame;await process_frame
	print("REPLAY_CAVE_OWNER_DEFAULTS_OK");quit(0)
