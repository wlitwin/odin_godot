extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func frames(count: int) -> void:
	for _frame in count: await process_frame

func new_game() -> Node:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	for _frame in 120:
		if game.probe("ready") == 1: return game
		await process_frame
	assert(false, "starter did not become ready")
	return game

func move_near(game: Node) -> void:
	game.move(1)
	for _frame in 120:
		if game.probe("x") >= 250: break
		await process_frame
	game.move(0)
	assert(game.probe("x") >= 250 and game.probe("x") < 280)

func run() -> void:
	var preview = load("res://dev/pickup_preview.tscn").instantiate()
	root.add_child(preview)
	await frames(2)
	var view = preview.get_node("Pickup")
	assert(view.preview_reach() == 24)
	var definition: Resource = view.definition
	definition.reach = -1
	assert(not view.refresh() and view.validation_path() == "reach")
	assert(view.validation_source() == "res://data/pickup.tres")
	assert(view.preview_reach() == 24, "invalid edits preserve the last valid preview")
	definition.reach = 80
	assert(view.refresh() and view.preview_reach() == 80)
	definition.reach = 24
	preview.queue_free()
	await frames(2)
	var game := await new_game()
	assert(game.authoring_reach() == 24)
	definition = game.get_node("Coin").definition
	definition.reach = 80
	assert(game.get_node("Coin").refresh())
	assert(game.authoring_reach() == 24, "live World owns a copied value")
	await move_near(game)
	game.take()
	await frames(6)
	assert(game.probe("bag1") == 0, "the live run still uses its admitted reach")
	game.queue_free()
	await frames(3)
	game = await new_game()
	assert(game.authoring_reach() == 80, "a new run admits the changed definition")
	await move_near(game)
	game.take()
	await frames(6)
	assert(game.probe("bag1") == 1, "the authored reach changes gameplay")
	definition.reach = 24
	game.queue_free()
	await frames(4)
	print("REPLAY_STARTER_AUTHORING_OK preview=true invalid=true copied=true gameplay=true")
	quit()
