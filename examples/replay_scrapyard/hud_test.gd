extends "res://workbench_test.gd"

var hud: Control

func node(path: String) -> Node: return hud.get_node(path)

func capture(name: String):
	var directory := OS.get_environment("RSY_HUD_CAPTURE")
	if directory == "": return
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	if picture.save_png(directory + "/" + name + ".png") != OK: await finish(1, "HUD capture"); return
	print("RSY_HUD_CAPTURE ", name)
	picture = null

func run():
	root.size = Vector2i(1280, 704)
	bench = load("res://dev/workbench.tscn").instantiate(); bench.open_shop = true
	if case == "boss": bench.boss = true
	else: bench.hurt = true; bench.jam = true; bench.statuses = true
	root.add_child(bench); game = bench.game_node(); hud = game.get_node("UI/CombatHUD")
	if not await until(func(): return bench.is_staged() and hud.visible): await finish(1, "HUD staging"); return
	if case == "boss":
		if not await until(func(): return node("BossPlate").visible): await finish(1, "boss absent"); return
		if not "36/36" in node("BossPlate/Name").text or abs(node("BossPlate/Fill").size.x - 386) > 1:
			await finish(1, "boss initial bar"); return
		if abs(node("Ammo").offset_bottom + 12) > 1: await finish(1, "combat magazine anchor"); return
		await capture("boss")
		game.dev_combat(true)
		if not await until(func(): return node("BossPlate").visible and node("BossPlate/Fill").size.x < 385, 25000): await finish(1, "boss damage bar"); return
		if not await until(func(): return p("stage") == 2 and not node("BossPlate").visible, 35000): await finish(1, "boss death bar"); return
		game.dev_combat(false)
		await process_frame
		if node("Ammo").get_global_rect().intersects(game.get_node("UI/Shop").get_global_rect()): await finish(1, "magazine overlaps counter"); return
		print("REPLAY_COMBAT_HUD_OK case=boss full=true damage=true death=true counter_climb=true")
		await finish(0); return
	if not await until(func(): return p("stage") == 2 and node("Vitals/Text").text == "5/10" and "JAMMED" in node("Ammo/State").text): await finish(1, "hurt/jam display"); return
	bench.statuses = false
	if abs(node("Vitals/Fill").size.x - 78) > 1 or node("Vitals/Fill").color.g >= 0.8: await finish(1, "half health bar"); return
	if not node("Vitals/St0").visible or not node("Vitals/St1").visible or node("Vitals/St0").color == node("Vitals/St1").color: await finish(1, "status colors"); return
	var height: float = node("Vitals/St0").size.y
	await create_timer(0.4).timeout
	if node("Vitals/St0").size.y >= height: await finish(1, "status lifetime bar"); return
	if node("Ammo").get_global_rect().intersects(game.get_node("UI/Shop").get_global_rect()): await finish(1, "shop overlap"); return
	await capture("hurt-jammed")
	game.dev_aim(1.0, 0.0, true)
	if not await until(func(): return node("Ammo/State").text == "low", 20000): await finish(1, "low magazine state"); return
	game.dev_aim(1.0, 0.0, false)
	if node("Ammo/Count").text != "2 / 8": await finish(1, "low bolter magazine count"); return
	await capture("low-ammo")
	game.dev_aim(1.0, 0.0, true)
	if not await until(func(): return "RELOADING" in node("Ammo/State").text, 20000): await finish(1, "reload display"); return
	game.dev_aim(1.0, 0.0, false)
	if node("Ammo/Count").text != "-- / 8": await finish(1, "reload count"); return
	await capture("reloading")
	if not await until(func(): return node("Ammo/Count").text == "8 / 8" and node("Ammo/State").text == "", 10000): await finish(1, "refilled display"); return
	if not game.dev_cast(0, p("x") + 100.0, p("y"), true) or not game.dev_cast(1, 1.0, 0.0, false): await finish(1, "cooldown setup"); return
	game.dev_drive(1, 0, true)
	if not await until(func(): return node("Vitals/Pip0/Fill").size.x < 12 and node("Vitals/Pip1/Fill").size.x < 12 and node("Vitals/Pip2/Fill").size.x < 12): await finish(1, "cooldown pip consumption"); return
	game.dev_drive(0, 0, false)
	var width: float = node("Vitals/Pip0/Fill").size.x
	await create_timer(0.25).timeout
	if node("Vitals/Pip0/Fill").size.x <= width: await finish(1, "cooldown refill"); return
	await capture("cooldowns")
	game.on_shop_card(3); game.on_shop_card(5)
	if not await until(func(): return node("Vitals/Text").text == "14/14" and abs(node("Vitals/Fill").size.x - 156) < 1): await finish(1, "plate health maximum"); return
	if not await until(func(): return p("fx_mask") == 0 and not node("Vitals/St0").visible and not node("Vitals/St1").visible, 10000): await finish(1, "expired status squares"); return
	if not await until(func(): return abs(node("Vitals/Pip0/Fill").size.x - 48) < 0.1 and abs(node("Vitals/Pip1/Fill").size.x - 48) < 0.1 and abs(node("Vitals/Pip2/Fill").size.x - 48) < 0.1): await finish(1, "ready cooldown pips"); return
	root.size = Vector2i(1600, 900); await process_frame; await process_frame
	if node("Ammo").get_global_rect().intersects(game.get_node("UI/Shop").get_global_rect()): await finish(1, "resized shop overlap"); return
	print("REPLAY_COMBAT_HUD_OK case=player health=true statuses=true jam=true low=true reload=true cooldowns=true plate=true resize=true")
	await finish(0)
