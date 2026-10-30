extends "res://workbench_test.gd"
const ViewProbe = preload("res://view_probe.gd")

func globs(prefix: String) -> Array:
	var result := []
	for child in game.get_node("World").get_children():
		if ViewProbe.polygon(child) and str(child.name).begins_with(prefix) and child.visible: result.append(child)
	return result
func shape(node: Node2D, radius: float, color: Color) -> bool:
	if ViewProbe.vertices(node).size() != 10 or node.z_index != 6 or not ViewProbe.tint(node).is_equal_approx(color): return false
	for i in range(10):
		var angle := float(i) / 10 * TAU
		if not ViewProbe.vertices(node)[i].is_equal_approx(Vector2(cos(angle),sin(angle)) * radius): return false
	return node.scale.x >= 0.819 and node.scale.x <= 1.181 and node.scale.x == node.scale.y
func picture(name: String):
	var directory := OS.get_environment("RSY_GLOB_CAPTURE")
	if directory == "" or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.save_png(directory + "/" + name + ".png") != OK: await finish(1, "glob capture"); return
	image = null
func run():
	root.size = Vector2i(1280,704)
	bench = load("res://dev/workbench.tscn").instantiate(); bench.open_shop = true; bench.set_process(false)
	root.add_child(bench); game = bench.game_node()
	if not await until(func(): return p("ready")): await finish(1,"glob admission"); return
	game.dev_abilities(1,6)
	if not await until(func(): return p("ability0") == 1 and p("ability1") == 6): await finish(1,"lob loadout"); return
	bench.set_process(true)
	if not await until(func(): return bench.is_staged() and p("stage") == 2): await finish(1,"glob staging"); return
	bench.open_shop = false
	var colors := [Color(0.45,0.9,0.5,1), Color(0.75,0.85,1,1)]
	for slot in range(2):
		var landed := p("landed")
		if not game.dev_cast(slot, float(p("x") + 300), float(p("y")), true): await finish(1,"lob cast"); return
		if not await until(func(): return globs("Lob").size() == 1): await finish(1,"lob not visible"); return
		var node: Node2D = globs("Lob")[0]
		if not shape(node,7,colors[slot]): print("GLOB_COLOR ",ViewProbe.tint(node)); await finish(1,"lob shape/color"); return
		var before: Vector2 = node.position; var scale_before: Vector2 = node.scale
		await picture("lob-" + str(slot))
		await process_frame; await process_frame
		if not node.visible or node.position.x <= before.x or node.position.y != before.y or node.scale == scale_before: await finish(1,"straight flight/pulse"); return
		if not await until(func(): return p("landed") == landed + 1 and globs("Lob").is_empty()): await finish(1,"lob expiry"); return
	if game.dev_spawn(2,1,210.0,0.0) <= 0: await finish(1,"spitter setup"); return
	if not await until(func(): return globs("Spit").size() > 0): await finish(1,"spit not visible"); return
	var spit: Node2D = globs("Spit")[0]
	if not shape(spit,5,Color(0.45,0.9,0.5,1)): await finish(1,"spit shape/color"); return
	var first: Vector2 = spit.position
	await picture("spit")
	await process_frame; await process_frame
	if not spit.visible or spit.position.x >= first.x: await finish(1,"spit flight"); return
	if not await until(func(): return not spit.visible,1500): await finish(1,"spit terminal"); return
	print("REPLAY_GLOB_VIEW_OK slime=true spark=true spit=true discs=true colors=true pulse=true straight=true expiry=true")
	await finish(0)
