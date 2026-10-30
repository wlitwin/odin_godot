extends "res://shop_test.gd"

func button(path: String) -> Button: return game.get_node("UI/Lobby/Scroll/Layout/" + path)
func row(index: int) -> Control: return game.get_node("UI/Lobby/Scroll/Layout/Roster/Row" + str(index))
func click_pick(path: String):
	var target := button(path)
	game.get_node("UI/Lobby/Scroll").ensure_control_visible(target)
	await process_frame; await process_frame
	await move_mouse(target.get_global_rect().get_center())
	var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT
	event.position = target.get_global_rect().get_center(); event.global_position = event.position; event.pressed = true
	mouse_event(event); await process_frame
	event = event.duplicate(); event.pressed = false; mouse_event(event)
	await process_frame; await process_frame
func picture():
	var path := OS.get_environment("RSY_MUSTER_CAPTURE")
	if path == "" or DisplayServer.get_name() == "headless": return
	game.get_node("UI/Lobby/Scroll").scroll_vertical = 0
	await process_frame; await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image(); image.save_png(path); image = null
func run():
	root.size = Vector2i(1280,704)
	bench = load("res://main.tscn").instantiate(); root.add_child(bench); game = bench
	if not await until(func(): return p("ready") and p("meta_claimed") and row(0).get_node("Body").texture != null): await finish(1,"muster staging"); return
	if not game.get_node("UI/Lobby").visible or game.get_node("World").visible or not "(you)" in row(0).get_node("Name").text: await finish(1,"staging layout"); return
	for i in range(1,4):
		if row(i).visible: await finish(1,"vacant row"); return
	if button("Actions/Start").disabled or not button("Actions/Start").visible: await finish(1,"solo start shortcut"); return
	button("Actions/Ready").pressed.emit(); button("Actions/Ready").pressed.emit()
	await create_timer(0.3).timeout
	if p("marked_ready") != 0: await finish(1,"rapid ready toggle used stale authority state"); return
	for pair in [["look","Picks/Look","Picks/LookPrev"],["iron","Picks/Iron","Picks/IronPrev"],["ability0","Abilities/Left","Abilities/LeftPrev"],["ability1","Abilities/Right","Abilities/RightPrev"]]:
		var before := p(pair[0]); var before_mask := p("automatic"); await click_pick("Actions/Ready")
		if not await until(func(): return p("marked_ready") == 1 and row(0).get_node("Lamp").text == "READY"): await finish(1,"ready lamp"); return
		await click_pick(pair[1])
		if not await until(func(): return p("automatic") != before_mask and p("marked_ready") == 0 and row(0).get_node("Lamp").text == "..."): await finish(1,"pick must unready"); return
		await click_pick(pair[2])
		if not await until(func(): return p(pair[0]) == before and p("automatic") == before_mask): await finish(1,"reverse pick"); return
	var body := row(0).get_node("Body") as Sprite2D
	var names := ["becca","joe","unknow"]
	if not body.texture.resource_path.ends_with("runner_" + names[p("look")] + "_idle.png") or body.frame != 0 or body.hframes != 6 or body.scale != Vector2(2,2): await finish(1,"original idle preview"); return
	await create_timer(0.15).timeout
	if body.frame != 0: await finish(1,"preview should use original fixed frame"); return
	for size in [Vector2i(960,540),Vector2i(1600,900),Vector2i(1280,704)]:
		root.size = size; await process_frame; await process_frame
		var bounds: Rect2 = game.get_node("UI/Lobby").get_global_rect()
		if not root.get_visible_rect().encloses(bounds) or abs(bounds.get_center().x - root.get_visible_rect().get_center().x) > 1: await finish(1,"muster resizing"); return
	if game.get_node("UI/Chat").get_global_rect().end.x > game.get_node("UI/Lobby").get_global_rect().position.x - 4: await finish(1,"chat overlaps muster"); return
	await picture()
	if p("marked_ready") != 0: await finish(1,"host must start from unready"); return
	await click_pick("Actions/Start")
	if not await until(func(): return p("in_yard") and p("marked_ready") and not game.get_node("UI/Lobby").visible and game.get_node("World").visible): await finish(1,"ready then start"); return
	var look := p("look"); game.on_look_prev(); await create_timer(0.15).timeout
	if p("look") != look: await finish(1,"in-yard pick changed"); return
	print("REPLAY_MUSTER_VIEW_OK preview=true reverse=true unready=true rapid_ready=true start_shortcut=true resize=true in_yard_guard=true")
	await finish(0)
