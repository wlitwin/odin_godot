extends "res://workbench_test.gd"

func picture(name: String):
	var directory := OS.get_environment("RSY_SCREEN_CAPTURE")
	if directory == "": return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.save_png(directory + "/" + name + ".png") != OK: await finish(1, "screen capture"); return
	image = null

func run():
	root.size = Vector2i(1280, 704)
	bench = load("res://dev/workbench.tscn").instantiate(); bench.open_shop = true
	root.add_child(bench); game = bench.game_node()
	if not await until(func(): return bench.is_staged() and p("stage") == 2): await finish(1, "screen staging"); return
	bench.open_shop = false
	var vignette := game.get_node("ScreenFx/Vignette") as TextureRect
	var veil := game.get_node("ScreenFx/FloorVeil") as ColorRect
	var camera := game.get_node("Camera") as Camera2D
	if vignette.visible or veil.visible or camera.zoom != Vector2(2, 2): await finish(1, "initial screen effect"); return
	if game.get_node("ScreenFx").layer >= game.get_node("UI").layer: await finish(1, "screen effects cover HUD"); return
	if game.dev_hurt(1, 8) <= 0: await finish(1, "low health setup"); return
	if not await until(func(): return p("hp") == 2 and vignette.visible and vignette.modulate.a > 0.3): await finish(1, "low HP vignette"); return
	if vignette.get_global_rect() != root.get_visible_rect(): await finish(1, "vignette not full viewport"); return
	await picture("low-health")
	root.size = Vector2i(1600, 900); await process_frame; await process_frame
	if vignette.get_global_rect() != root.get_visible_rect() or veil.get_global_rect() != root.get_visible_rect(): await finish(1, "resized overlays"); return
	root.size = Vector2i(1280, 704); await process_frame; await process_frame
	game.on_shop_card(3)
	if not await until(func(): return p("hp") == 10 and not vignette.visible): await finish(1, "healed vignette"); return
	if game.dev_spawn(4, 1, 260.0, -40.0) <= 0: await finish(1, "boss setup"); return
	if not await until(func(): return camera.zoom.x > 2.02): await finish(1, "boss lens kick"); return
	game.on_shake()
	if p("shake_off") != 1 or camera.zoom != Vector2(2, 2) or camera.offset != Vector2.ZERO: await finish(1, "disable motion mid-kick"); return
	game.dev_combat(true)
	var deadline := Time.get_ticks_msec() + 25000
	while p("mobs") > 0 and Time.get_ticks_msec() < deadline:
		if camera.zoom != Vector2(2, 2) or camera.offset != Vector2.ZERO: await finish(1, "motion while disabled"); return
		await process_frame
	if p("mobs") != 0: await finish(1, "boss combat"); return
	game.dev_combat(false); game.on_shake()
	if p("shake_off") != 0: await finish(1, "motion setting restore"); return
	game.dev_gate(true)
	if not await until(func(): return p("floor") == 2 and veil.visible, 25000): await finish(1, "floor veil"); return
	game.dev_gate(false)
	await picture("floor-veil")
	if not await until(func(): return not veil.visible, 2000): await finish(1, "veil did not clear"); return
	print("REPLAY_SCREEN_FX_OK vignette=true healing=true resize=true lens=true motion_off=true floor_veil=true")
	await finish(0)
