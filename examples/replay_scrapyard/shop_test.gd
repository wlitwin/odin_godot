extends "res://workbench_test.gd"

func card(index: int) -> Button: return game.get_node("UI/Shop/Card" + str(index))

func mouse_event(event: InputEvent):
	Input.parse_input_event(event)
	# Dummy windows have no focused OS window to route GUI events through.
	if DisplayServer.get_name() == "headless": root.push_input(event, true)

func move_mouse(point: Vector2):
	# A visible window polls the physical pointer between synthetic events.
	if DisplayServer.get_name() != "headless": Input.warp_mouse(point)
	var event := InputEventMouseMotion.new(); event.position = point; event.global_position = point
	mouse_event(event)
	await process_frame

func click(index: int):
	var point := card(index).get_global_rect().get_center()
	await move_mouse(point)
	var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT
	event.position = point; event.global_position = point; event.pressed = true
	mouse_event(event)
	await create_timer(0.12).timeout
	event = event.duplicate(); event.pressed = false; mouse_event(event)
	await process_frame

func press(code: Key):
	key(code, true); await create_timer(0.06).timeout; key(code, false)
	await process_frame

func layout_ok() -> bool:
	var bounds: Rect2 = game.get_node("UI/Shop").get_global_rect()
	var viewport := root.get_visible_rect().size
	if abs(bounds.end.y - (viewport.y - 20)) > 1 or abs(bounds.get_center().x - viewport.x / 2.0) > 1: return false
	for i in range(9):
		if not bounds.encloses(card(i).get_global_rect()): return false
		if i > 0 and card(i - 1).get_global_rect().intersects(card(i).get_global_rect()): return false
	return true

func run():
	root.size = Vector2i(1280, 704)
	bench = load("res://dev/workbench.tscn").instantiate(); bench.open_shop = true
	root.add_child(bench); game = bench.game_node()
	if not await until(func(): return bench.is_staged() and p("stage") == 2 and game.get_node("UI/Shop").visible):
		await finish(1, "shop staging"); return
	# Let the confirmed world reach presentation before checking disabled states.
	await process_frame; await process_frame
	if not card(3).disabled: await finish(1, "full-health heal enabled"); return
	var money := p("scrap"); var cores := p("cores"); var shots := p("shots")
	print("RSY_SHOP_INPUT display=", DisplayServer.get_name(), " viewport=", root.size, " panel=", game.get_node("UI/Shop").get_global_rect())
	await click(0)
	if not await until(func(): return p("boost_damage") == 1): await finish(1, "real card click did not buy"); return
	if p("scrap") != money - 5 or p("shots") != shots:
		await finish(1, "click accounting: scrap %d -> %d; shots %d -> %d; mouse %s; panel %s" % [money, p("scrap"), shots, p("shots"), game.get_node("UI/Shop").get_local_mouse_position(), game.get_node("UI/Shop").get_global_rect()]); return
	if game.dev_hurt(1, 4) <= 0: await finish(1, "hurt setup"); return
	if not await until(func(): return p("hp") == 6 and not card(3).disabled): await finish(1, "heal did not enable"); return
	await click(3)
	if not await until(func(): return p("hp") == 10 and card(3).disabled): await finish(1, "heal card"); return
	await press(KEY_2); await press(KEY_3)
	if not await until(func(): return p("boost_rate") == 1 and p("boost_speed") == 1): await finish(1, "upgrade shortcuts"); return
	await press(KEY_5); await click(5); await press(KEY_7); await press(KEY_8)
	if not await until(func(): return p("parts") == 15 and p("hp") == 14): await finish(1, "part shortcuts/cards"); return
	if p("cores") != cores - 9: await finish(1, "part prices"); return
	for i in range(4, 8):
		if not card(i).disabled or not "OWNED" in card(i).text: await finish(1, "owned part still buyable"); return
	# A stale/synthetic pressed signal still goes through the same guard.
	card(5).pressed.emit(); await create_timer(0.12).timeout
	if p("cores") != cores - 9: await finish(1, "owned part charged twice"); return
	var iron := p("iron"); await press(KEY_9)
	if not await until(func(): return p("iron") != iron): await finish(1, "rack shortcut"); return
	if p("scrap") != money - 15 or p("shots") != shots: await finish(1, "purchase accounting or mouse isolation"); return
	card(8).grab_focus()
	await move_mouse(card(5).get_global_rect().get_center())
	if not await until(func(): return "+4 max hp" in game.get_node("UI/Shop/CardHint").text): await finish(1, "hover hint"); return
	if not layout_ok(): await finish(1, "shop bounds or card overlap"); return
	var capture := OS.get_environment("RSY_SHOP_CAPTURE")
	if capture != "":
		await RenderingServer.frame_post_draw
		var picture := root.get_texture().get_image()
		if picture.save_png(capture) != OK: await finish(1, "shop capture"); return
		picture = null
	root.size = Vector2i(1600, 900); await process_frame; await process_frame
	if not layout_ok(): await finish(1, "resized shop bounds or card overlap"); return
	root.size = Vector2i(1280, 704); await process_frame; await process_frame
	# Spend through the public UI path until the first card becomes unaffordable.
	while p("scrap") >= 5:
		var level := p("boost_damage"); game.on_shop_card(0)
		if not await until(func(): return p("boost_damage") == level + 1): await finish(1, "repeated card purchase"); return
	if not await until(func(): return card(0).disabled): await finish(1, "unaffordable card enabled"); return
	money = p("scrap"); game.on_shop_card(0); await create_timer(0.12).timeout
	if p("scrap") != money: await finish(1, "unaffordable action spent money"); return
	game.on_menu(); iron = p("iron"); await press(KEY_9); game.on_shop_card(8)
	await create_timer(0.12).timeout
	if p("iron") != iron or not card(8).disabled: await finish(1, "menu allowed purchase"); return
	print("REPLAY_SHOP_UI_OK click=true shortcuts=true prices=true owned=true unaffordable=true mouse_isolated=true layout=true")
	await finish(0)
