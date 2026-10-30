extends "res://workbench_test.gd"

func fx(key: String) -> int: return int(game.feedback_probe(key))
func number(text: String) -> bool:
	for node in game.get_node("World").get_children():
		if node is Label and node.text == text: return true
	return false
func picture(name: String):
	var directory := OS.get_environment("RSY_FEEDBACK_CAPTURE")
	if directory == "": return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.save_png(directory + "/" + name + ".png") != OK: await finish(1, "feedback capture"); return
	image = null

func run():
	root.size = Vector2i(1280, 704)
	bench = load("res://dev/workbench.tscn").instantiate(); bench.open_shop = true
	root.add_child(bench); game = bench.game_node()
	if not await until(func(): return bench.is_staged() and p("stage") == 2): await finish(1, "feedback staging"); return
	bench.open_shop = false
	if not await until(func(): return fx("active") == 0): await finish(1, "initial cleanup"); return
	if game.dev_hurt(1, 2) <= 0: await finish(1, "hurt setup"); return
	if not await until(func(): return p("hp") == 8 and fx("bursts") > 0): await finish(1, "hurt burst"); return
	await picture("hurt-burst")
	if not await until(func(): return fx("active") == 0): await finish(1, "hurt expiry"); return
	if game.dev_spawn(1, 1, 120.0, 0.0) <= 0: await finish(1, "target setup"); return
	if not await until(func(): return p("mobs") > 0): await finish(1, "target spawn"); return
	game.dev_aim(1.0, 0.0, true)
	if not await until(func(): return number("2")): await finish(1, "per-target damage number"); return
	game.dev_aim(1.0, 0.0, false)
	await picture("damage")
	if game.dev_smite(1) <= 0: await finish(1, "kill setup"); return
	if not await until(func(): return fx("bursts") >= 3 and fx("debris") >= 6): await finish(1, "death burst/debris"); return
	await picture("death-feedback")
	game.dev_combat(true)
	if not await until(func(): return p("scrap") > 500 and (number("+3") or number("+6"))): await finish(1, "pickup feedback"); return
	game.dev_combat(false)
	await picture("pickup")
	if not await until(func(): return fx("active") == 0): await finish(1, "feedback expiry"); return
	game.dev_gate(true)
	if not await until(func(): return p("depart") > 0 and p("depart") <= 12, 25000): await finish(1, "departure setup"); return
	if game.dev_hurt(1, 1) <= 0: await finish(1, "transition effect"); return
	if not await until(func(): return fx("bursts") > 0): await finish(1, "recent transition burst"); return
	if not await until(func(): return p("floor") == 2): await finish(1, "descent"); return
	game.dev_gate(false)
	if fx("active") != 0 or fx("dropped") != 0: await finish(1, "scope cleanup or capacity loss"); return
	print("REPLAY_FEEDBACK_OK hurt=true per_target_numbers=true death=true pickup=true expiry=true floor_cleanup=true spawned=", fx("spawned"))
	await finish(0)
