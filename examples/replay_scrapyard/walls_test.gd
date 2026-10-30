extends "res://workbench_test.gd"
const ViewProbe = preload("res://view_probe.gd")

func sparks() -> Array:
	var found := []
	for child in game.get_node("World").get_children():
		if ViewProbe.polygon(child) and str(child.name).begins_with("WallSpark"): found.append(child)
	return found

func run():
	root.size = Vector2i(1280, 704)
	bench = load("res://dev/workbench.tscn").instantiate(); bench.open_shop = true
	root.add_child(bench); game = bench.game_node()
	if not await until(func(): return bench.is_staged() and p("stage") == 2): await finish(1, "wall staging"); return
	bench.open_shop = false
	if not await until(func(): return game.feedback_probe("active") == 0): await finish(1, "initial cleanup"); return
	# Seed 1337/floor 1 has a cover [583,517,66,46], west of spawn [840,544].
	# Fire through the ordinary input/reducer path, then inspect actual scene nodes.
	game.dev_aim(-1.0, 0.0, true)
	if not await until(func(): return sparks().size() >= 3): await finish(1, "wall sparks"); return
	game.dev_aim(-1.0, 0.0, false)
	var observed_at := Time.get_ticks_msec()
	var fan := sparks(); var ids := []; var positions := []; var angles := []; var alphas := []
	for spark in fan:
		ids.append(spark.get_instance_id()); positions.append(spark.position); angles.append(spark.rotation); alphas.append(spark.modulate.a)
		if spark.position.x < 649 or spark.position.x > 675 or abs(spark.position.y - 544) > 20:
			await finish(1, "wall endpoint"); return
		if not ViewProbe.tint(spark).is_equal_approx(Color(1, 0.88, 0.55, 1)) or spark.z_index != 24:
			await finish(1, "wall color/depth"); return
	angles.sort()
	if fan.size() != 3 or abs(angles[0] + 0.55) > 0.01 or abs(angles[1]) > 0.01 or abs(angles[2] - 0.55) > 0.01:
		await finish(1, "outward three-spark fan"); return
	var capture := OS.get_environment("RSY_WALL_CAPTURE")
	if capture != "":
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		if image.save_png(capture) != OK: await finish(1, "wall capture"); return
		image = null
	await create_timer(0.06).timeout
	for i in fan.size():
		var moved: Vector2 = fan[i].position - positions[i]
		var age_delta: float = (alphas[i] - fan[i].modulate.a) * 0.3
		if moved.x <= 0 or age_delta <= 0 or abs(moved.length() / age_delta - 170) > 1:
			await finish(1, "spark velocity/fade"); return
	if not await until(func(): return sparks().is_empty()): await finish(1, "spark expiry"); return
	if Time.get_ticks_msec() - observed_at > 450: await finish(1, "spark lifetime exceeded"); return
	await process_frame
	for id in ids:
		if is_instance_id_valid(id): await finish(1, "spark retained"); return
	if game.feedback_probe("dropped") != 0: await finish(1, "spark pool capacity"); return
	print("REPLAY_WALL_VIEW_OK contact=true normal=true fan=3 warm=true velocity=170 lifetime=0.3 expired=true")
	await finish(0)
