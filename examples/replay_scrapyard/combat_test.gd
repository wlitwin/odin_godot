extends SceneTree

var game: Node
var mode := ""
var phase := "join"
var started := 0
var acted := 0
var seat := 0
var directory := ""
var proposal := 0
var answered := 0
var captured := false
var armory := "ballistic"
var encounter := "melee"
var timeout_ms := 55000
var closing:=false
var resource_floor:=0
var participants: Array[String] = ["host", "client", "observer"]

func _initialize() -> void:
	resource_floor=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	mode = OS.get_environment("RSY_ROLE")
	if OS.get_environment("RSY_ENCOUNTER") != "": encounter = OS.get_environment("RSY_ENCOUNTER")
	if OS.get_environment("RSY_ARMORY") != "": armory = OS.get_environment("RSY_ARMORY")
	directory = OS.get_environment("RSY_RESULT_DIR")
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	started = Time.get_ticks_msec()

func expected_totals() -> Dictionary:
	if encounter == "mixed": return {"kills": 3, "damage": 27, "scrap": 9}
	if encounter == "boss": return {"kills": 1 + p("adds"), "damage": 36 + 3 * p("adds"), "scrap": 15 + 3 * p("adds")}
	if encounter == "barrels": return {"kills": 1, "damage": 28, "scrap": 3}
	return {"kills": 4, "damage": 29, "scrap": 12}

func iron_for(player: int) -> int:
	if armory == "mend": return 0 if player == 1 else 6
	if armory == "ordnance": return 4 if player == 1 else 5
	return 2 if player == 1 else 1

func p(field: String, player: int = 1) -> int:
	return game.probe(field, player) if game!=null else 0

func write(name: String, value: Dictionary) -> void:
	if name.begins_with("stopped-"): value["after"] = p("head")
	var path := directory + "/" + name + ".json"
	var file := FileAccess.open(path + ".pending", FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(value))
	file.close()
	assert(DirAccess.rename_absolute(path + ".pending", path) == OK)

func read(name: String) -> Dictionary:
	var path := directory + "/" + name + ".json"
	if not FileAccess.file_exists(path): return {}
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func fail(message: String) -> bool:
	print("RSY_COMBAT_FAIL role=", mode, " phase=", phase, " ", message, " mobs=", p("mobs"), " kills=", p("kills", 1), "/", p("kills", 2), " hp=", p("hp", 1), "/", p("hp", 2), " scrap=", p("scrap", 1), "/", p("scrap", 2))
	print("RSY_NETWORK phase=", p("phase"), " resyncs=", p("resyncs"), " reason=", p("resync_reason"), " large=", p("large_snapshots"), " deferred=", p("egress_deferred"), " tx=", p("tx_bytes"), " rx=", p("rx_bytes"))
	quit(1)
	return true

func capture_scene(path: String) -> void:
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png(path) == OK: print("RSY_SCREENSHOT_OK ", path)

func living_enemy_on_screen() -> bool:
	for child in game.get_node("World").get_children():
		var sprite := child.get_node_or_null("Body") as Sprite2D
		if sprite != null and child.visible and sprite.visible and sprite.texture != null and "zombie_" in sprite.texture.resource_path and sprite.frame_coords.y != 3:
			if root.get_visible_rect().has_point(sprite.get_global_transform_with_canvas().origin): return true
	return false

func finish_game(code:int):
	if closing:return
	closing=true
	if game!=null:game.queue_free();game=null
	await process_frame;await process_frame
	var deadline:=Time.get_ticks_msec()+2000
	while int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))>resource_floor and Time.get_ticks_msec()<deadline:await process_frame
	quit(code)

func _process(_dt: float) -> bool:
	if closing:return false
	var now := Time.get_ticks_msec()
	if now - started > timeout_ms: return fail("timeout")
	# A resync temporarily has no authority observation. Absence is not zero HP.
	if phase != "join" and not p("ready"): return false
	match phase:
		"join":
			if p("ready"):
				seat = p("seat")
				if seat == 0: phase = "world"
				else:
					game.dev_loadout(seat, iron_for(seat))
					phase = "loadout"
		"loadout":
			if p("iron", seat) == iron_for(seat):
				game.on_ready()
				phase = "ready"
		"ready":
			if p("players") == 2 and p("marked_ready", 1) and p("marked_ready", 2):
				if mode == "host": game.on_start()
				phase = "world"
		"world":
			if p("stage") == 1 and p("in_yard", 1) and p("in_yard", 2):
				if armory == "mend":
					if seat > 0: game.dev_drive(1 if seat == 1 else 0, 0, false)
					phase = "position"
				elif encounter == "mixed" or encounter == "boss":
					if seat > 0: game.dev_drive(0, 0, false)
					phase = "observe"
				elif encounter == "barrels":
					if seat == 1: game.dev_aim(1.0, 0.0, true)
					elif seat == 2: game.dev_drive(0, 0, false)
					phase = "ignite"
				else:
					if seat > 0: game.dev_combat(true)
					phase = "fight"
		"observe":
			if p("hp", 1) == 0 or p("hp", 2) == 0: return fail("observed hazard killed a runner")
			if encounter == "boss" and not captured and OS.get_environment("RSY_SCREENSHOT") != "":
				for child in game.get_node("World").get_children():
					var ring := child.get_node_or_null("Telegraph") as Line2D
					if ring != null and child.visible and ring.visible and ring.get_point_count() == 49 and ring.scale.x > 0.4:
						captured = true
						capture_scene(OS.get_environment("RSY_SCREENSHOT"))
						break
			if (encounter == "mixed" and p("spits") > 0 and p("pops") > 0) or (encounter == "boss" and p("slams") > 0):
				if seat > 0: game.dev_combat(true)
				phase = "fight"
		"ignite":
			if p("shots", 1) > 0:
				if seat == 1: game.dev_aim(1.0, 0.0, false)
				phase = "burn"
		"burn":
			if p("barrels") >= 2 and p("dot_pulses") > 0:
				if seat > 0: game.dev_combat(true)
				phase = "fight"
		"position":
			# Put the recipient nearer the approaching enemy than the healer.
			if p("x", 1) >= p("x", 2) + 80:
				if seat == 1: game.dev_drive(0, 0, false)
				phase = "wound"
		"wound":
			if p("hp", 1) < 10:
				if seat == 2: game.dev_aim(1.0, 0.0, true)
				phase = "heal"
		"heal":
			if p("healed", 2) > 0:
				var tab := InputEventKey.new(); tab.physical_keycode = KEY_TAB; tab.keycode = KEY_TAB; tab.pressed = true; Input.parse_input_event(tab)
				if seat == 2: game.dev_aim(1.0, 0.0, false)
				if not captured and OS.get_environment("RSY_SCREENSHOT") != "":
					captured = true
					capture_scene(OS.get_environment("RSY_SCREENSHOT"))
				acted = now
				phase = "settle"
		"fight":
			if p("hp", 1) == 0 or p("hp", 2) == 0: return fail("runner down")
			if not captured and OS.get_environment("RSY_SCREENSHOT") != "" and p("shots", 1) + p("shots", 2) > 0 and living_enemy_on_screen():
				captured = true
				capture_scene(OS.get_environment("RSY_SCREENSHOT"))
			if p("mobs") == 0 and p("scrap", 1) + p("scrap", 2) == int(expected_totals().scrap):
				if seat > 0: game.dev_combat(false)
				acted = now
				phase = "settle"
		"settle":
			if now - acted >= 2500:
				if armory == "mend":
					if p("hp", 1) == 0 or p("healed", 2) == 0 or p("historical_queries", 2) == 0: return fail("historical healing")
					var tally := game.get_node("UI/Tally")
					if not tally.visible or tally.get_node("Column/Grid/Heading3").text != "Mends" or tally.get_node("Column/Grid/Row1_3").text != str(p("healed", 2)) or tally.get_node("Column/Grid/Row2_0").visible: return fail("healing tally or spectator row")
					print("RSY_MENDS_TALLY role=", mode, " mends=", p("healed", 2), " observer_excluded=true")
				else:
					if p("kills", 1) + p("kills", 2) != int(expected_totals().kills): return fail("kill total")
					if p("damage", 1) + p("damage", 2) != int(expected_totals().damage): return fail("clamped damage total")
					if p("shots", 1) == 0 or (encounter != "barrels" and p("shots", 2) == 0): return fail("both shooters")
					if armory == "ordnance" and (p("blasts", 1) == 0 or p("historical_queries", 2) == 0): return fail("grenade/rewound rail")
				print("RSY_COMBAT_RESULT role=", mode, " armory=", armory, " encounter=", encounter, " shots1=", p("shots", 1), " shots2=", p("shots", 2), " kills1=", p("kills", 1), " kills2=", p("kills", 2),
					" damage=", p("damage", 1) + p("damage", 2), " scrap=", p("scrap", 1) + p("scrap", 2), " effects=", p("shot_effects"), " blasts1=", p("blasts", 1), " rails2=", p("rail_queries", 2), " historical2=", p("historical_queries", 2), " healed2=", p("healed", 2), " rejected2=", p("rejected_queries", 2), " spits=", p("spits"), " pops=", p("pops"), " slams=", p("slams"), " adds=", p("adds"), " barrels=", p("barrels"), " dots=", p("dot_pulses"), " status=", p("status_applied"), " cores=", p("cores", 1) + p("cores", 2))
				print("RSY_NETWORK role=", mode, " resyncs=", p("resyncs"), " reason=", p("resync_reason"), " large=", p("large_snapshots"), " deferred=", p("egress_deferred"), " tx=", p("tx_bytes"), " rx=", p("rx_bytes"))
				write("stopped-" + mode, {"ready": true})
				phase = "hash"
		"hash":
			var minimum_tick := 0
			for role in participants:
				var stopped := read("stopped-" + role)
				if stopped.is_empty(): return false
				minimum_tick = maxi(minimum_tick, int(stopped.get("after", 0)))
			if mode == "host":
				var retry := proposal == 0
				var complete := proposal != 0
				var expected := ""
				for role in participants:
					var answer := read("hash-" + role)
					if int(answer.get("tick", 0)) != proposal: complete = false
					elif str(answer.get("hash", "-1")) == "-1": retry = true
					elif expected == "": expected = str(answer.hash)
					elif expected != str(answer.hash): return fail("whole-world hash mismatch")
				if retry:
					if p("head") - 30 < minimum_tick: return false
					proposal = p("head") - 30
					write("proposal", {"tick": proposal})
				elif complete: write("finish", {"tick": proposal, "hash": expected})
			var request := read("proposal")
			var tick := int(request.get("tick", 0))
			if tick > 0 and tick != answered:
				answered = tick
				write("hash-" + mode, {"tick": tick, "hash": str(game.probe_hash(tick))})
			var finish := read("finish")
			if not finish.is_empty():
				print("RSY_COMBAT_HASH role=", mode, " tick=", int(finish.tick), " hash=", finish.hash)
				write("measured-" + mode, {"done": true})
				phase = "finish"
		"finish":
			for role in participants:
				if read("measured-" + role).is_empty(): return false
			print("REPLAY_SCRAPYARD_COMBAT_PEER_OK")
			finish_game(0)
			return false
	return false
