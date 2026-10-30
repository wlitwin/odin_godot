extends "res://shop_test.gd"

func button(name: String) -> Button: return game.get_node("UI/Menu/Scroll/Column/" + name)
func click_button(name: String):
	var target := button(name)
	game.get_node("UI/Menu/Scroll").ensure_control_visible(target)
	await process_frame; await process_frame
	await move_mouse(target.get_global_rect().get_center())
	var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT
	event.position = target.get_global_rect().get_center(); event.global_position = event.position; event.pressed = true
	mouse_event(event); await process_frame
	event = event.duplicate(); event.pressed = false; mouse_event(event)
	await process_frame; await process_frame
func panels_fit() -> bool:
	var bounds := root.get_visible_rect()
	var menu: Rect2 = game.get_node("UI/Menu").get_global_rect()
	var tally: Rect2 = game.get_node("UI/Tally").get_global_rect()
	var veil: Rect2 = game.get_node("UI/MenuVeil").get_global_rect()
	return bounds.encloses(menu) and bounds.encloses(tally) and veil.is_equal_approx(bounds) and abs(menu.get_center().x - bounds.get_center().x) < 1 and tally.get_center().distance_to(bounds.get_center()) < 1
func picture(name: String):
	var directory := OS.get_environment("RSY_MENU_CAPTURE")
	if directory == "" or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.save_png(directory + "/" + name + ".png") != OK: await finish(1, "menu capture"); return
	image = null
func run():
	root.size = Vector2i(1280, 704)
	bench = load("res://dev/workbench.tscn").instantiate(); bench.open_shop = true
	root.add_child(bench); current_scene = bench; game = bench.game_node()
	if not await until(func(): return bench.is_staged() and p("stage") == 2): await finish(1, "menu staging"); return
	bench.open_shop = false
	await press(KEY_ESCAPE)
	if not p("menu_open") or not game.get_node("UI/MenuVeil").visible or not button("Resume").has_focus(): await finish(1, "menu veil/focus"); return
	var x := p("x"); var shots := p("shots"); var casts := p("casts"); var dashes := p("dashes"); var head := p("head"); var iron := p("iron")
	for code in [KEY_D, KEY_SHIFT, KEY_Q, KEY_E, KEY_9]: key(code, true)
	await move_mouse(Vector2(80, 100))
	var mouse := InputEventMouseButton.new(); mouse.button_index = MOUSE_BUTTON_LEFT; mouse.position = Vector2(80,100); mouse.global_position = mouse.position; mouse.pressed = true; mouse_event(mouse)
	await create_timer(0.25).timeout
	for code in [KEY_D, KEY_SHIFT, KEY_Q, KEY_E, KEY_9]: key(code, false)
	mouse = mouse.duplicate(); mouse.pressed = false; mouse_event(mouse)
	if p("x") != x or p("shots") != shots or p("casts") != casts or p("dashes") != dashes or p("iron") != iron or p("head") <= head + 5: await finish(1, "menu input or simulation"); return
	button("Resume").grab_focus(); await press(KEY_ENTER)
	if p("menu_open") or game.chat_probe("typing") or game.get_node("UI/MenuVeil").visible: await finish(1, "resume entered chat"); return
	await press(KEY_ESCAPE); key(KEY_SHIFT, true); await process_frame
	await click_button("Resume"); await create_timer(0.15).timeout
	if p("menu_open") or p("dashes") != dashes: await finish(1, "held menu key became a fresh dash"); return
	key(KEY_SHIFT, false)
	key(KEY_TAB, true); await process_frame; await process_frame
	if not game.get_node("UI/Tally").visible: await finish(1, "tally key"); return
	if game.get_node("UI/Tally/Column/Grid").columns != 8 or game.get_node("UI/Tally/Column/Grid/Row0_6").text != "0" or game.get_node("UI/Tally/Column/Grid/Row0_7").text != "0": await finish(1, "tally deaths and offline ping"); return
	await picture("tally")
	await press(KEY_ENTER)
	if not game.chat_probe("typing"): await finish(1, "chat focus while holding tally"); return
	key(KEY_TAB, false); await process_frame; await process_frame
	if game.get_node("UI/Tally").visible: await finish(1, "tally release lost to chat"); return
	await press(KEY_ESCAPE); await press(KEY_ESCAPE)
	if not p("menu_open"): await finish(1, "menu return"); return
	for size in [Vector2i(960,540), Vector2i(1600,900), Vector2i(1280,704)]:
		root.size = size; await process_frame; await process_frame; await process_frame
		if not panels_fit(): await finish(1, "anchored panel bounds"); return
		game.get_node("UI/Menu/Scroll").ensure_control_visible(button("Quit")); await process_frame; await process_frame
		if not game.get_node("UI/Menu").get_global_rect().encloses(button("Quit").get_global_rect()): await finish(1, "quit scroll access"); return
	await picture("menu")
	await click_button("Resume")
	if p("menu_open") or p("shots") != shots: await finish(1, "resume click leaked fire"); return
	await press(KEY_ESCAPE)
	print("REPLAY_MENU_VIEW_OK veil=true input_isolated=true ticking=true resume=true held_key=true tally_release=true resize=true scroll=true")
	if OS.get_environment("RSY_MENU_QUIT") == "1":
		await click_button("Quit")
		await create_timer(2).timeout
		await finish(1, "quit did not stop the game")
	else: await finish(0)
