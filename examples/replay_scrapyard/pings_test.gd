extends "res://chat_test.gd"

var before_sent := false
var second_sent := false
var second_seen := false
var ping_node_id := 0

func ping_node() -> Node2D: return game.get_node("World/Pings").get_child(0) as Node2D

func history_ready() -> bool:
	if seat == 0:
		if game.chat_probe("pings") != 0 or game.chat_probe("active_pings") != 0: return not fail("late join replayed a ping")
		if game.ping(1000.0, 500.0): return not fail("observer could submit ping")
		return true
	if seat == 1 and not before_sent:
		before_sent = true
		if game.ping(-1.0, 500.0) or not game.ping(1050.0, 544.0): return not fail("ping coordinate admission")
	if game.chat_probe("pings") < 1: return false
	if game.chat_probe("active_pings") != 1 or ping_node().position != Vector2(1050, 544) or ping_node().get_node("Name").text != "host": return not fail("initial ping presentation")
	write("ping-before-" + mode, {"ready": true})
	return seat != 1 or not read("ping-before-client").is_empty()

func send_middle():
	var point: Vector2 = game.get_node("World").get_global_transform_with_canvas() * Vector2(1100, 500)
	if DisplayServer.get_name() != "headless": Input.warp_mouse(point)
	var motion := InputEventMouseMotion.new(); motion.position = point; motion.global_position = point
	Input.parse_input_event(motion)
	var button := InputEventMouseButton.new(); button.button_index = MOUSE_BUTTON_MIDDLE; button.position = point; button.global_position = point; button.pressed = true
	Input.parse_input_event(button)
	await process_frame; await process_frame
	button = button.duplicate(); button.pressed = false; Input.parse_input_event(button)

func observer_ready() -> bool:
	if not second_sent:
		if game.chat_probe("active_pings") != 0: return false
		write("ping-expired-" + mode, {"ready": true})
		for role in participants:
			if read("ping-expired-" + role).is_empty(): return false
		second_sent = true
		if seat == 2:
			game.get_node("UI/Chat/Input").grab_focus()
			if game.ping(1100.0, 500.0): return not fail("typing allowed ping")
			game.get_node("UI/Chat/Input").release_focus()
			game.on_menu()
			if game.ping(1100.0, 500.0): return not fail("menu allowed ping")
			game.on_menu(); send_middle()
	var expected := 1 if seat == 0 else 2
	if game.chat_probe("pings") < expected: return false
	if game.chat_probe("pings") != expected: return not fail("ping duplicated")
	if not second_seen:
		if game.chat_probe("active_pings") != 1: return not fail("live ping absent")
		var marker := ping_node()
		if marker.position.distance_to(Vector2(1100, 500)) > 1 or marker.get_node("Name").text != "client": return not fail("middle click position/name")
		ping_node_id = marker.get_instance_id(); second_seen = true
		if OS.get_environment("RSY_SCREENSHOT") != "": captured = true; capture_scene(OS.get_environment("RSY_SCREENSHOT"))
	if game.chat_probe("active_pings") != 0: return false
	if is_instance_id_valid(ping_node_id): return not fail("expired ping node retained")
	print("RSY_PINGS_OK role=", mode, " middle_mouse=true stamped=true expired=true late_history_excludes_markers=true")
	return true
