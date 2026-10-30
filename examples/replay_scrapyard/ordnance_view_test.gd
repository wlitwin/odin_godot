extends "res://workbench_test.gd"
const ViewProbe = preload("res://view_probe.gd")

func nodes(prefix: String, visible_only := false) -> Array:
	var found := []
	for child in game.get_node("World").get_children():
		if ViewProbe.polygon(child) and str(child.name).begins_with(prefix) and (not visible_only or child.visible): found.append(child)
	return found
func equip(iron: int) -> bool:
	for _step in range(7):
		if p("iron") == iron: return true
		var old := p("iron"); game.on_shop_card(8)
		if not await until(func(): return p("iron") != old): return false
	return p("iron") == iron
func picture(name: String):
	var directory := OS.get_environment("RSY_ORDNANCE_CAPTURE")
	if directory == "": return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.save_png(directory + "/" + name + ".png") != OK: await finish(1, "ordnance capture"); return
	image = null
func run():
	root.size = Vector2i(1280, 704)
	bench = load("res://dev/workbench.tscn").instantiate(); bench.open_shop = true
	root.add_child(bench); game = bench.game_node()
	if not await until(func(): return bench.is_staged() and p("stage") == 2): await finish(1, "ordnance staging"); return
	bench.open_shop = false
	for iron in [5, 6]:
		if not await equip(iron): await finish(1, "rail equip"); return
		if not await until(func(): return nodes("WallSpark").is_empty()): await finish(1, "old rail effect"); return
		game.dev_aim(-1.0, 0.0, true)
		if not await until(func(): return nodes("WallSpark").size() == 3): await finish(1, "rail wall event"); return
		game.dev_aim(-1.0, 0.0, false)
		for spark in nodes("WallSpark"):
			if spark.position.x < 649 or spark.position.x > 675 or abs(spark.position.y - 544) > 20 or abs(spark.rotation) > 0.56:
				await finish(1, "rail endpoint/normal"); return
		await picture("rail-" + str(iron))
	if not await equip(4): await finish(1, "grenade equip"); return
	if not await until(func(): return nodes("WallSpark").is_empty()): await finish(1, "rail expiry"); return
	var shots := p("shots"); var blasts := p("blasts")
	game.dev_aim(-1.0, 0.0, true)
	if not await until(func(): return p("shots") > shots and nodes("Grenade", true).size() == 1): await finish(1, "shell view"); return
	game.dev_aim(-1.0, 0.0, false)
	var shell: Node2D = nodes("Grenade", true)[0]
	if ViewProbe.vertices(shell) != PackedVector2Array([Vector2(5,0),Vector2(2,4),Vector2(-3,3),Vector2(-5,0),Vector2(-3,-3),Vector2(2,-4)]) or not ViewProbe.tint(shell).is_equal_approx(Color(0.62,0.64,0.46,1)) or shell.z_index != 12:
		await finish(1, "original grenade glyph"); return
	if not await until(func(): return nodes("Ember").size() > 0): await finish(1, "ember trail"); return
	var ember: Node2D = nodes("Ember")[0]; var ember_id := ember.get_instance_id(); var anchor: Vector2 = ember.position
	await picture("grenade-trail")
	await create_timer(0.06).timeout
	if not is_instance_id_valid(ember_id) or ember.position != anchor or ember.modulate.a >= 1:
		await finish(1, "ember stationary fade"); return
	var minimum: float = shell.position.x; var bounced := false
	var deadline := Time.get_ticks_msec() + 1800
	while shell.visible and Time.get_ticks_msec() < deadline:
		minimum = minf(minimum, shell.position.x)
		if minimum < 665 and shell.position.x > minimum + 8: bounced = true
		if not nodes("WallSpark").is_empty(): await finish(1, "grenade invented terminal sparks"); return
		await process_frame
	if not bounced or shell.visible or p("blasts") != blasts + 1: await finish(1, "bounce/fuse"); return
	if not await until(func(): return nodes("Ember").is_empty(), 700): await finish(1, "ember expiry"); return
	await process_frame
	if is_instance_id_valid(ember_id) or game.feedback_probe("dropped") or game.feedback_probe("trail_dropped"):
		await finish(1, "ember retention/capacity"); return
	print("REPLAY_ORDNANCE_VIEW_OK lance=true mend=true shell=true bounce=true trail=true stationary=true expiry=true")
	await finish(0)
