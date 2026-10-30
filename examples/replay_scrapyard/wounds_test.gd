extends "res://workbench_test.gd"
const ViewProbe = preload("res://view_probe.gd")

func wound() -> Node2D:
	for child in game.get_node("World").get_children():
		if ViewProbe.polygon(child) and str(child.name).begins_with("Wound"): return child
	return null

func run():
	root.size = Vector2i(1280, 704)
	bench = load("res://dev/workbench.tscn").instantiate(); bench.open_shop = true
	root.add_child(bench); game = bench.game_node()
	if not await until(func(): return bench.is_staged() and p("stage") == 2): await finish(1, "wound staging"); return
	bench.open_shop = false
	if game.dev_hurt(1, 1) <= 0: await finish(1, "ambient hurt"); return
	if not await until(func(): return p("hp") == 9): await finish(1, "ambient application"); return
	if game.feedback_probe("wounds") != 0: await finish(1, "self-origin invented direction"); return
	game.on_shop_card(3)
	if not await until(func(): return p("hp") == 10): await finish(1, "heal setup"); return
	var origin := Vector2(p("x"), p("y"))
	if game.dev_spawn(1, 1, 30.0, 0.0) <= 0: await finish(1, "attacker setup"); return
	if not await until(func(): return wound() != null): await finish(1, "wound indicator"); return
	var marker := wound(); var id := marker.get_instance_id(); var position := marker.position
	if position.distance_to(origin + Vector2(30, 0)) > 1 or abs(marker.rotation) > 0.02: await finish(1, "wound bearing/anchor"); return
	var capture := OS.get_environment("RSY_WOUND_CAPTURE")
	if capture != "":
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		if image.save_png(capture) != OK: await finish(1, "wound capture"); return
		image = null
	game.dev_drive(-1, 0, false); await create_timer(0.2).timeout; game.dev_drive(0, 0, false)
	if not is_instance_id_valid(id) or marker.position != position: await finish(1, "wound moved with victim"); return
	if game.dev_smite(1) <= 0: await finish(1, "stop attacker"); return
	if not await until(func(): return game.feedback_probe("wounds") == 0): await finish(1, "wound expiry"); return
	await process_frame
	if is_instance_id_valid(id) or game.feedback_probe("wound_missing") != 0: await finish(1, "wound lifetime/history"); return
	print("REPLAY_WOUND_VIEW_OK source=true historical_anchor=true stationary=true ambient_silent=true expired=true")
	await finish(0)
