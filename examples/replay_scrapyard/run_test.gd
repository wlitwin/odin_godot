extends "res://combat_test.gd"
const ViewProbe = preload("res://view_probe.gd")

var bought := false
var canceled := false
var seen_floor := 1
var reset_at := 0
var scenery_ids: Array[int] = []
var scenery_floors: Array[int] = []
var near_gate_checked := false
var wipe_view_checked := false
var ping_sent_floor := 0
var ping_seen_floor := 0
var departing_ping_id := 0

# Exercise actual scene lifetimes and observer presentation during the run.
# Constants/geometry are from the preserved original arena and gate arrow.
func check_scenery(open_gate: bool, near_gate: bool = false) -> bool:
	var yard := game.get_node_or_null("World/Arena")
	if yard == null or not game.get_node("World").visible: return not fail("yard hidden during run")
	if yard.get_node("Dirt").get_child_count() != 24 or yard.get_node("Tufts").get_child_count() != 40: return not fail("floor dressing missing")
	var gate := yard.get_node("Gate")
	var hud := game.get_node("UI/CombatHUD")
	if seat > 0:
		if not open_gate:
			var camera := game.get_node("Camera") as Camera2D
			var half := get_root().get_visible_rect().size / camera.zoom / 2
			var expected := camera.global_position.clamp(Vector2(camera.limit_left, camera.limit_top) + half, Vector2(camera.limit_right, camera.limit_bottom) - half)
			if camera.get_screen_center_position().distance_to(expected) > 8: return not fail("camera panned across a floor warp")
		if open_gate and hud.get_node("Ammo").get_global_rect().intersects(game.get_node("UI/Shop").get_global_rect()): return not fail("magazine overlaps shop")
		if not open_gate and abs(hud.get_node("Ammo").offset_bottom + 12) > 1: return not fail("magazine offset not restored on descent")
	elif hud.get_node("Ammo").visible or hud.get_node("Vitals").visible: return not fail("observer personal HUD")
	var boom := gate.get_node("Boom") as Sprite2D
	var arrow := yard.get_node("GateArrow") as Node2D
	if not gate.visible or boom.region_rect != Rect2(70, 166, 49, 4): return not fail("gate art missing")
	if open_gate:
		if abs(boom.rotation - (PI / 2 - 1.25)) > 0.04 or gate.get_node("Pad").modulate.g <= 1.0: return not fail("gate did not open and light")
		var position := Vector2(p("x", seat), p("y", seat)) if seat > 0 else Vector2.ZERO
		var far := position.distance_to(Vector2(1850, 544)) > 370
		if arrow.visible != (seat > 0 and p("hp", seat) > 0 and far and not near_gate): return not fail("gate arrow visibility")
		if arrow.visible:
			if abs(arrow.position.distance_to(position) - 110) > 3: return not fail("gate arrow detached from runner")
			if abs(angle_difference(arrow.rotation, (Vector2(1850, 544) - position).angle())) > 0.03: return not fail("gate arrow points away")
	else:
		if abs(boom.rotation - PI / 2) > 0.04 or arrow.visible: return not fail("new floor gate not closed")
	if not scenery_floors.has(p("floor")):
		for old_id in scenery_ids:
			if is_instance_id_valid(old_id): return not fail("retired floor still alive")
		scenery_floors.append(p("floor")); scenery_ids.append(yard.get_instance_id())
		var geometry: Array = []
		for patch in yard.get_node("Dirt").get_children(): geometry.append([patch.position, patch.size, patch.color])
		for tuft in yard.get_node("Tufts").get_children(): geometry.append([tuft.position, tuft.region_rect, tuft.scale])
		write("scenery-" + str(p("floor")) + "-" + mode, {"geometry": JSON.stringify(geometry).sha256_text()})
		print("RSY_SCENERY_FLOOR role=", mode, " floor=", p("floor"), " dirt=24 tufts=40 prior_floors_freed=true")
	return true

func _initialize() -> void:
	super._initialize()
	timeout_ms = 170000

func _process(dt: float) -> bool:
	if phase == "hash" or phase == "finish": return super._process(dt)
	var now := Time.get_ticks_msec()
	if now - started > timeout_ms: return fail("run loop timeout")
	if phase != "join" and not p("ready"): return false
	match phase:
		"join":
			if p("ready"):
				seat = p("seat")
				if seat == 0: phase = "world"
				else:
					game.dev_loadout(seat, 2 if seat == 1 else 1)
					phase = "loadout"
		"loadout":
			if p("iron", seat) == (2 if seat == 1 else 1): game.on_ready(); phase = "ready"
		"ready":
			if p("players") == 2 and p("marked_ready", 1) and p("marked_ready", 2):
				if seat == 1: game.on_start()
				phase = "world"
		"world":
			if p("stage") == 1 and p("in_yard", 1) and p("in_yard", 2):
				if seat > 0: game.dev_combat(true)
				phase = "fight"
		"fight":
			if p("run") != 0: return fail("unexpected early wipe")
			if p("stage") == 2: phase = "collect"
		"collect":
			if p("drops") == 0:
				if seat > 0: game.dev_combat(false)
				acted = now; bought = false
				phase = "shop"
		"shop":
			if now - acted < 1800: return false # collect late authority pickups
			if not game.get_node("UI/Transitions/Wave").visible or not "CLEAR" in game.get_node("UI/Transitions/Wave/Text").text: return fail("clear announcement absent")
			if not check_scenery(true): return true
			if not captured and OS.get_environment("RSY_SCREENSHOT") != "":
				captured = true
				capture_scene(OS.get_environment("RSY_SCREENSHOT"))
			if not bought and seat > 0:
				var selected_card := 5
				if seen_floor == 1:
					if p("scrap", seat) < 3: return fail("shop funds")
					selected_card = 0 if p("scrap", seat) >= 5 else 2
				var button := game.get_node("UI/Shop/Card" + str(selected_card)) as Button
				if button.disabled: return fail("affordable card disabled")
				button.pressed.emit()
				print("RSY_SHOP_CARD role=", mode, " floor=", seen_floor, " card=", selected_card)
				bought = true
			if seen_floor == 1:
				if p("boost_damage", 1) + p("boost_speed", 1) + p("boost_damage", 2) + p("boost_speed", 2) == 0: return false
			else:
				if p("parts", 1) != 2 or p("parts", 2) != 2: return false
			if seat > 0: game.dev_gate(true)
			phase = "gate"
		"gate":
			if p("depart") > 0 and p("depart") <= 60:
				if seat == 1 and ping_sent_floor != seen_floor:
					if not game.ping(1850.0, 544.0): return fail("departure ping")
					ping_sent_floor = seen_floor
				if game.chat_probe("active_pings") > 0:
					ping_seen_floor = seen_floor; departing_ping_id = game.get_node("World/Pings").get_child(0).get_instance_id()
			if not near_gate_checked and p("depart") > 150:
				var departing := game.get_node("UI/Transitions/Depart") as Label
				if not departing.visible or departing.text != "DESCENDING  3": return fail("departure announcement absent")
				if not check_scenery(true, true): return true
				near_gate_checked = true
				print("RSY_SCENERY_GATE role=", mode, " near_arrow_hidden=true")
				if OS.get_environment("RSY_SCREENSHOT") != "": capture_scene(OS.get_environment("RSY_SCREENSHOT").get_basename() + "-gate.png")
			if seen_floor == 1 and not canceled and p("depart") > 150:
				if seat == 1:
					game.dev_gate(false); game.dev_drive(-1, 0, true)
				acted = now
				phase = "cancel"
			elif p("floor") > seen_floor:
				if ping_seen_floor != seen_floor or game.chat_probe("active_pings") != 0 or is_instance_id_valid(departing_ping_id): return fail("ping did not clear on descent before natural expiry")
				print("RSY_PING_FLOOR role=", mode, " cleared=true from=", seen_floor)
				seen_floor = p("floor")
				if seen_floor == 3:
					if seat > 0: game.dev_gate(false); game.dev_drive(0, 0, false)
					acted = now; phase = "wipe"
				else:
					if seat > 0: game.dev_combat(true)
					phase = "fight"
		"cancel":
			if p("depart") == 0 and now - acted > 400:
				if game.get_node("UI/Transitions/Depart").visible: return fail("canceled countdown still visible")
				canceled = true
				print("RSY_GATE_CANCEL role=", mode)
				if seat == 1: game.dev_drive(0, 0, false); game.dev_gate(true)
				phase = "gate"
		"wipe":
			if now - acted < 250: return false
			if not scenery_floors.has(3):
				if not check_scenery(false): return true
			if p("stage") == 3:
				if p("hp", 1) != 0 or p("hp", 2) != 0: return fail("wipe before everyone down")
				phase = "reset"
		"reset":
			if p("stage") == 3:
				var over := game.get_node("UI/Transitions/Over")
				if not over.visible or not "floor reached  3" in over.get_node("Text").text: return fail("wipe summary absent")
				if not wipe_view_checked:
					wipe_view_checked = true
					print("RSY_TRANSITION_VIEW role=", mode, " clear=true countdown=true cancel=true wipe=true")
					if OS.get_environment("RSY_SCREENSHOT") != "": capture_scene(OS.get_environment("RSY_SCREENSHOT").get_basename() + "-wipe.png")
			if p("run") == 1:
				if not wipe_view_checked: return fail("wipe summary never checked")
				if p("floor") != 1 or p("parts", 1) != 2 or p("parts", 2) != 2: return fail("reset permanence")
				for player in [1, 2]:
					if p("scrap", player) != 0 or p("boost_damage", player) != 0 or p("boost_speed", player) != 0 or p("hp", player) != 14: return fail("reset temporary state")
				reset_at = p("head"); acted = now; phase = "settle"
		"settle":
			if now - acted > 900:
				var history: String = game.get_node("UI/Chat/Lines").text
				for line in ["the platform holds", "floor 2 — deeper", "floor 3 — deeper", "the yard goes quiet", "parts and cores stay"]:
					if history.count(line) != 1: return fail("run history missing or duplicated: " + line)
				if game.chat_probe("news_gaps") != 0: return fail("run news gap")
				print("RSY_CHAT_RUN role=", mode, " transitions_retained=true")
				if game.get_node("UI/Transitions/Over").visible or game.get_node("UI/Transitions/Depart").visible: return fail("stale transition after reset")
				print("RSY_RUN_RESULT role=", mode, " run=", p("run"), " floor=", p("floor"), " clears=", p("clears"),
					" parts1=", p("parts", 1), " parts2=", p("parts", 2), " reset_tick=", reset_at, " canceled=", int(canceled))
				write("stopped-" + mode, {"ready": true})
				phase = "hash"
	return false
