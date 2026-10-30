extends "res://combat_test.gd"

var input_started := 0
var baseline: Dictionary = {}

func chat() -> RichTextLabel: return game.get_node("UI/Chat/Lines")
func history_ready() -> bool: return true
func observer_ready() -> bool: return true
func key(code: Key, pressed: bool):
	var event := InputEventKey.new(); event.physical_keycode = code; event.keycode = code; event.pressed = pressed
	Input.parse_input_event(event)

func _initialize():
	super._initialize(); root.size = Vector2i(1280, 704)

func _process(dt: float) -> bool:
	if phase == "hash" or phase == "finish": return super._process(dt)
	if Time.get_ticks_msec() - started > timeout_ms: return fail("chat timeout")
	if not p("ready") or not game.chat_probe("ready"): return false
	match phase:
		"join":
			seat = p("seat")
			if seat == 0: phase = "history"
			else: game.on_ready(); phase = "ready"
		"ready":
			if p("players") == 2 and p("marked_ready", 1) and p("marked_ready", 2):
				if seat == 1: game.on_start()
				phase = "world"
		"world":
			if p("stage") == 1:
				baseline={"warm_head":p("head")};phase="warmup"
		"warmup":
			if p("head")>=int(baseline.warm_head)+18:
				baseline = {"x": p("x", seat), "y": p("y", seat), "head": p("head"), "shots": p("shots", seat), "ammo": p("ammo", seat), "casts": p("casts", seat), "dashes": p("dashes", seat)}
				key(KEY_ENTER, true); phase = "focus"
		"focus":
			key(KEY_ENTER, false)
			if game.chat_probe("typing"):
				for code in [KEY_W, KEY_SHIFT, KEY_Q, KEY_F]: key(code, true)
				Input.action_press("rsy_fire")
				input_started = Time.get_ticks_msec(); phase = "typing"
		"typing":
			if Time.get_ticks_msec() - input_started > 350:
				for code in [KEY_W, KEY_SHIFT, KEY_Q, KEY_F]: key(code, false)
				Input.action_release("rsy_fire")
				for field in ["x", "y", "shots", "ammo", "casts", "dashes"]:
					if p(field, seat) != baseline[field]: return fail("chat focus leaked gameplay input: " + field)
				if p("head") <= baseline.head + 5: return fail("chat paused simulation: %d -> %d" % [baseline.head,p("head")])
				game.get_node("UI/Chat/Input").text = "draft"
				key(KEY_ESCAPE, true); phase = "cancel"
		"cancel":
			key(KEY_ESCAPE, false)
			if game.chat_probe("typing") == 0:
				if p("menu_open") != 0 or game.get_node("UI/Chat/Input").text != "draft": return fail("Escape did not leave chat alone")
				key(KEY_ENTER, true); phase = "refocus"
		"refocus":
			key(KEY_ENTER, false)
			if game.chat_probe("typing"):
				var input := game.get_node("UI/Chat/Input") as LineEdit
				input.text = "[b]found bolts[/b]" if seat == 1 else "ready Ω"
				input.text_submitted.emit(input.text)
				if input.text != "" or input.has_focus(): return fail("chat submit did not clear/release")
				print("RSY_CHAT_FOCUS role=", mode, " controls_blocked=true simulation_live=true")
				phase = "history"
		"history":
			var text := chat().text
			if not "host: [b]found bolts[/b]" in text or not "client: ready Ω" in text or not "the yard opens" in text: return false
			if chat().bbcode_enabled or not "[b]found bolts[/b]" in chat().get_parsed_text(): return fail("chat interpreted markup")
			if not history_ready(): return false
			if seat == 1: write("allow-observer", {"ready": true})
			if seat == 0:
				if not game.chat_probe("named_observer"):return false
				game.on_chat("watching safely"); print("RSY_CHAT_LATE_HISTORY_OK")
			phase = "observer"
		"observer":
			var text := chat().text
			if not "observer (observer): watching safely" in text or game.chat_probe("pending") != 0: return false
			if not observer_ready(): return false
			for line in ["host: [b]found bolts[/b]", "client: ready Ω", "observer (observer): watching safely", "the yard opens"]:
				if text.count(line) != 1: return fail("duplicate/missing chat history: " + line)
			if game.chat_probe("news_gaps") != 0: return fail("news history gap")
			write("chat-" + mode, {"text": text})
			if not captured and OS.get_environment("RSY_SCREENSHOT") != "": captured = true; capture_scene(OS.get_environment("RSY_SCREENSHOT"))
			print("RSY_CHAT_RESULT role=", mode, " lines=", game.chat_probe("lines"), " plain_text=true stamped=true late_history=true")
			write("stopped-" + mode, {"ready": true}); phase = "hash"
	return false
