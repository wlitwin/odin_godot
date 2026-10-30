extends SceneTree

# Run against either Hello example: the same host port must be reusable after
# scene removal, and an engine peer installed by someone else must survive.
func _initialize() -> void:
	check_scenes.call_deferred()

func check_scenes() -> void:
	var multiplayer_api := get_root().get_multiplayer()
	var scene: PackedScene = load("res://hello.tscn")
	for iteration in range(4):
		var game := scene.instantiate()
		get_root().add_child(game)
		await process_frame
		if iteration == 0:
			if not game.test_code_lifecycle():
				push_error("SCENE_EXIT_FAIL: code rendezvous retained its socket")
				quit(1)
				return
			print("KIT_CODE_SOCKET_LIFETIME_OK")
		if game.probe_player_count() != 1:
			push_error("SCENE_EXIT_FAIL: host could not reuse its port")
			quit(1)
			return
		if not game.test_raw_detach():
			push_error("SCENE_EXIT_FAIL: detached a borrowed raw peer")
			quit(1)
			return
		if iteration == 1:
			if not game.test_detach_rehost():
				push_error("SCENE_EXIT_FAIL: detach/rehost was not idempotent")
				quit(1)
				return
			await process_frame
			if game.probe_player_count() != 1:
				push_error("SCENE_EXIT_FAIL: rehost did not rebuild its entity")
				quit(1)
				return
		var installed_id := multiplayer_api.multiplayer_peer.get_instance_id()
		var replacement: MultiplayerPeer = null
		var reassigned_api: SceneMultiplayer = null
		var reassigned_peer: MultiplayerPeer = null
		var branch_path: NodePath
		if iteration == 2:
			replacement = OfflineMultiplayerPeer.new()
			multiplayer_api.multiplayer_peer = replacement
		if iteration == 3:
			reassigned_api = SceneMultiplayer.new()
			reassigned_peer = OfflineMultiplayerPeer.new()
			reassigned_api.multiplayer_peer = reassigned_peer
			branch_path = game.get_path()
			set_multiplayer(reassigned_api, branch_path)
		game.queue_free()
		await process_frame
		await process_frame
		var current := multiplayer_api.multiplayer_peer
		if replacement != null:
			if current != replacement:
				push_error("SCENE_EXIT_FAIL: detached an externally installed peer")
				quit(1)
				return
			print("KIT_REPLACEMENT_PEER_OK")
		elif current != null and current.get_instance_id() == installed_id:
			push_error("SCENE_EXIT_FAIL: owned peer survived scene removal")
			quit(1)
			return
		if reassigned_api != null:
			if reassigned_api.multiplayer_peer != reassigned_peer:
				push_error("SCENE_EXIT_FAIL: touched a replacement MultiplayerAPI")
				quit(1)
				return
			set_multiplayer(null, branch_path)
			reassigned_api.multiplayer_peer = null
			print("KIT_MULTIPLAYER_API_REASSIGN_OK")
	multiplayer_api.multiplayer_peer = null
	print("KIT_RAW_PEER_BORROWED_OK")
	print("KIT_DETACH_REHOST_OK")
	print("KIT_SCENE_EXIT_OK")
	quit(0)
